import 'dart:io';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const Rastrapp());

class Rastrapp extends StatelessWidget {
  const Rastrapp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'rastrapp',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const PantallaPrincipal(),
    );
  }
}

/// Coordenadas en grados decimales.
class Coordenadas {
  final double latitud;
  final double longitud;
  final double? altitud;
  const Coordenadas(this.latitud, this.longitud, [this.altitud]);

  Uri get enlaceGoogleMaps => Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud');

  Uri get enlaceOpenStreetMap => Uri.parse(
      'https://www.openstreetmap.org/?mlat=$latitud&mlon=$longitud#map=17/$latitud/$longitud');

  @override
  String toString() =>
      '${latitud.toStringAsFixed(6)}, ${longitud.toStringAsFixed(6)}';
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final _selector = ImagePicker();

  File? _foto;
  Map<String, IfdTag> _metadatos = {};
  Coordenadas? _ubicacionExif;
  Position? _ubicacionDispositivo;
  String? _errorUbicacion;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    // Pedimos el permiso de ubicación una sola vez al abrir la app, para que
    // no interrumpa al tomar la foto.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await Geolocator.checkPermission() == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    });
  }

  Future<void> _obtenerImagen(ImageSource fuente) async {
    // Pedimos la ubicación del teléfono en paralelo, como respaldo por si la
    // cámara no escribe GPS en el EXIF.
    final futuroUbicacion =
        fuente == ImageSource.camera ? _ubicacionActual() : null;

    final archivo = await _selector.pickImage(source: fuente);
    if (archivo == null) return;

    setState(() => _cargando = true);
    final bytes = await archivo.readAsBytes();
    final metadatos = await readExifFromBytes(bytes);

    Position? posicion;
    String? error;
    if (futuroUbicacion != null) {
      try {
        posicion = await futuroUbicacion;
      } catch (e) {
        error = e.toString();
      }
    }

    setState(() {
      _foto = File(archivo.path);
      _metadatos = metadatos;
      _ubicacionExif = _extraerGps(metadatos);
      _ubicacionDispositivo = posicion;
      _errorUbicacion = error;
      _cargando = false;
    });
  }

  Future<Position> _ubicacionActual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'El GPS del teléfono está desactivado';
    }
    final permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      throw 'Permiso de ubicación denegado';
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Convierte los campos GPS del EXIF (grados, minutos, segundos) a decimal.
  Coordenadas? _extraerGps(Map<String, IfdTag> metadatos) {
    final lat = metadatos['GPS GPSLatitude'];
    final latRef = metadatos['GPS GPSLatitudeRef'];
    final lon = metadatos['GPS GPSLongitude'];
    final lonRef = metadatos['GPS GPSLongitudeRef'];
    if (lat == null || lon == null) return null;

    double aDecimal(IfdTag etiqueta, IfdTag? referencia) {
      final partes = etiqueta.values
          .toList()
          .cast<Ratio>()
          .map((r) => r.denominator == 0 ? 0.0 : r.numerator / r.denominator)
          .toList();
      final grados = partes[0] +
          (partes.length > 1 ? partes[1] / 60 : 0) +
          (partes.length > 2 ? partes[2] / 3600 : 0);
      final ref = referencia?.printable.trim().toUpperCase();
      return (ref == 'S' || ref == 'W') ? -grados : grados;
    }

    double? altitud;
    final alt = metadatos['GPS GPSAltitude'];
    if (alt != null) {
      final r = alt.values.toList().cast<Ratio>().first;
      if (r.denominator != 0) {
        altitud = r.numerator / r.denominator;
        if (metadatos['GPS GPSAltitudeRef']?.printable == '1') {
          altitud = -altitud;
        }
      }
    }

    try {
      return Coordenadas(aDecimal(lat, latRef), aDecimal(lon, lonRef), altitud);
    } catch (_) {
      return null;
    }
  }

  void _copiar(String texto) {
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copiado')));
  }

  String _textoCompleto() {
    final lineas = <String>[];
    if (_ubicacionExif != null) lineas.add('GPS (EXIF): $_ubicacionExif');
    final p = _ubicacionDispositivo;
    if (p != null) {
      lineas.add('GPS (teléfono): ${p.latitude}, ${p.longitude}');
    }
    for (final e in _metadatos.entries) {
      lineas.add('${e.key}: ${e.value.printable}');
    }
    return lineas.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final p = _ubicacionDispositivo;
    // Ocultamos campos binarios grandes (miniaturas, MakerNote) que no se leen.
    final filas = _metadatos.entries
        .where((e) =>
            !e.key.startsWith('JPEGThumbnail') &&
            !e.key.contains('MakerNote') &&
            e.value.printable.length < 200)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('rastrapp'),
        actions: [
          if (_metadatos.isNotEmpty || p != null)
            IconButton(
              tooltip: 'Copiar todo',
              icon: const Icon(Icons.copy),
              onPressed: () => _copiar(_textoCompleto()),
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _foto == null
              ? const Center(child: Text('Toma una foto para ver sus metadatos'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_foto!, height: 260, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 16),
                    Text('Ubicación',
                        style: Theme.of(context).textTheme.titleMedium),
                    _FilaUbicacion(
                      titulo: 'Desde el EXIF de la foto',
                      valor: _ubicacionExif == null
                          ? 'Sin GPS en el EXIF'
                          : '$_ubicacionExif'
                              '${_ubicacionExif!.altitud != null ? '  ·  ${_ubicacionExif!.altitud!.toStringAsFixed(1)} m' : ''}',
                      coordenadas: _ubicacionExif,
                      alCopiar: _ubicacionExif == null
                          ? null
                          : () => _copiar('$_ubicacionExif'),
                    ),
                    _FilaUbicacion(
                      titulo: 'Desde el GPS del teléfono',
                      valor: p != null
                          ? '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}'
                              '  ·  ±${p.accuracy.toStringAsFixed(0)} m'
                          : (_errorUbicacion ?? 'No disponible (solo con cámara)'),
                      coordenadas: p == null
                          ? null
                          : Coordenadas(p.latitude, p.longitude, p.altitude),
                      alCopiar: p == null
                          ? null
                          : () => _copiar('${p.latitude}, ${p.longitude}'),
                    ),
                    const SizedBox(height: 16),
                    Text('EXIF (${filas.length} campos)',
                        style: Theme.of(context).textTheme.titleMedium),
                    if (filas.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('La imagen no tiene metadatos EXIF'),
                      ),
                    for (final e in filas)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.key),
                        subtitle: SelectableText(e.value.printable),
                      ),
                  ],
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'galeria',
            tooltip: 'Elegir de la galería',
            onPressed: () => _obtenerImagen(ImageSource.gallery),
            child: const Icon(Icons.photo_library),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'camara',
            onPressed: () => _obtenerImagen(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Tomar foto'),
          ),
        ],
      ),
    );
  }
}

class _FilaUbicacion extends StatelessWidget {
  final String titulo;
  final String valor;
  final Coordenadas? coordenadas;
  final VoidCallback? alCopiar;
  const _FilaUbicacion({
    required this.titulo,
    required this.valor,
    this.coordenadas,
    this.alCopiar,
  });

  Future<void> _abrir(BuildContext context, Uri enlace) async {
    final abierto =
        await launchUrl(enlace, mode: LaunchMode.externalApplication);
    if (!abierto && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el mapa')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = coordenadas;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.place),
      title: Text(titulo),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(valor),
          if (c != null)
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('Google Maps'),
                  onPressed: () => _abrir(context, c.enlaceGoogleMaps),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.public, size: 18),
                  label: const Text('OpenStreetMap'),
                  onPressed: () => _abrir(context, c.enlaceOpenStreetMap),
                ),
              ],
            ),
        ],
      ),
      trailing: alCopiar == null
          ? null
          : IconButton(icon: const Icon(Icons.copy), onPressed: alCopiar),
    );
  }
}
