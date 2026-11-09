import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

/// PIEZA DE TESIS — reconstrucción de la galería del dispositivo.
///
/// Demuestra, para la memoria, qué vería una app con acceso al carrete: enumera
/// cada foto con su fecha y su GPS, y exporta el manifiesto resultante. Es lo
/// que una herramienta de vigilancia exfiltraría; acá se hace visible en lugar
/// de ocultarse.
///
/// LÍMITES DE SEGURIDAD (deliberados, no quitar):
///  1. Solo corre en `kDebugMode`. En release es código muerto.
///  2. El permiso de galería vive únicamente en el manifest de debug, así que
///     un build de participante ni siquiera puede pedirlo.
///  3. NO sube nada. No importa `backend.dart`. Lee local, exporta local /
///     portapapeles. Pensado para correr SOLO en el teléfono de la autora.
class DevGaleriaScreen extends StatefulWidget {
  const DevGaleriaScreen({super.key});

  @override
  State<DevGaleriaScreen> createState() => _DevGaleriaScreenState();
}

/// Una entrada del manifiesto: lo que la app puede leer de cada archivo.
class _Item {
  final AssetEntity asset;
  final String title;
  final DateTime date;
  final double? lat;
  final double? lng;
  _Item(this.asset, this.title, this.date, this.lat, this.lng);

  Map<String, dynamic> toJson() => {
        'archivo': title,
        'fecha': date.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'tipo': asset.type.name,
        'ancho': asset.width,
        'alto': asset.height,
      };
}

class _DevGaleriaScreenState extends State<DevGaleriaScreen> {
  static const Color _bg = Color(0xFF14202E);

  PermissionState? _perm;
  bool _loading = false;
  String _status = '';
  int _total = 0; // nº real de assets en el álbum "todo"
  final List<_Item> _items = []; // metadatos ya leídos
  final Map<String, Uint8List?> _thumbs = {}; // cache de miniaturas visibles

  @override
  void initState() {
    super.initState();
    // Candado duro: esta pantalla no debe existir fuera de debug.
    assert(kDebugMode, 'DevGaleriaScreen solo puede abrirse en debug');
  }

  Future<void> _pedirYcargar() async {
    if (!kDebugMode) return;
    setState(() {
      _loading = true;
      _status = 'Pidiendo permiso…';
    });

    final ps = await PhotoManager.requestPermissionExtend();
    _perm = ps;
    if (!ps.hasAccess) {
      setState(() {
        _loading = false;
        _status = ps == PermissionState.limited
            ? 'Acceso limitado: el sistema solo entregó algunas fotos.'
            : 'Permiso denegado. Actívalo en Ajustes del teléfono.';
      });
      return;
    }

    setState(() => _status = 'Leyendo álbumes…');

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common, // imágenes + video
      onlyAll: true, // el álbum virtual "todo / recientes"
    );
    if (paths.isEmpty) {
      setState(() {
        _loading = false;
        _status = 'No se encontró ningún álbum.';
      });
      return;
    }

    final all = paths.first;
    _total = await all.assetCountAsync;

    _items.clear();
    _thumbs.clear();

    const pageSize = 80;
    final pages = (_total / pageSize).ceil();
    for (var p = 0; p < pages; p++) {
      final batch = await all.getAssetListPaged(page: p, size: pageSize);
      for (final a in batch) {
        final title = await a.titleAsync;
        // latlngAsync (LatLng?) lee el GPS del EXIF aunque no venga en el
        // índice; si no, caemos al que ya trae el AssetEntity.
        final ll = await a.latlngAsync();
        double? lat = ll?.latitude ?? a.latitude;
        double? lng = ll?.longitude ?? a.longitude;
        if (lat == 0) lat = null;
        if (lng == 0) lng = null;
        _items.add(_Item(
          a,
          title.isEmpty ? a.id : title,
          a.createDateTime,
          lat,
          lng,
        ));
      }
      if (!mounted) return;
      setState(() => _status = 'Leídos ${_items.length} / $_total…');
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = 'Listo.';
    });
  }

  Future<Uint8List?> _thumb(_Item it) async {
    if (_thumbs.containsKey(it.asset.id)) return _thumbs[it.asset.id];
    final data =
        await it.asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
    _thumbs[it.asset.id] = data;
    return data;
  }

  Future<void> _exportar() async {
    final conGps = _items.where((i) => i.lat != null).length;
    final manifiesto = {
      'generado': DateTime.now().toIso8601String(),
      'dispositivo': 'solo-autora (pieza de tesis)',
      'total_archivos': _items.length,
      'con_gps': conGps,
      'items': _items.map((i) => i.toJson()).toList(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(manifiesto);
    await Clipboard.setData(ClipboardData(text: jsonStr));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _bg,
      content: Text(
        'Manifiesto copiado: ${_items.length} archivos, $conGps con GPS',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final conGps = _items.where((i) => i.lat != null).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reconstrucción de galería · tesis'),
        backgroundColor: _bg,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: _bg,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DEMO · solo este teléfono · no se sube nada',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.orangeAccent),
                ),
                const SizedBox(height: 8),
                Text(
                  _items.isEmpty
                      ? (_status.isEmpty ? 'Sin leer' : _status)
                      : '${_items.length} archivos · $conGps con GPS'
                          '${_items.length < _total ? ' · de $_total' : ''}',
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13, color: Colors.white),
                ),
                if (_perm == PermissionState.limited)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'iOS entregó acceso limitado: esto es un subconjunto.',
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.white54),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Leer galería'),
                      onPressed: _loading ? null : _pedirYcargar,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy_all, size: 18),
                      label: const Text('Exportar manifiesto'),
                      onPressed: _items.isEmpty ? null : _exportar,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text(
                      _loading ? _status : 'Toca «Leer galería»',
                      style: const TextStyle(color: Colors.white38),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _Cell(
                      item: _items[i],
                      thumbLoader: _thumb,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final _Item item;
  final Future<Uint8List?> Function(_Item) thumbLoader;
  const _Cell({required this.item, required this.thumbLoader});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder<Uint8List?>(
          future: thumbLoader(item),
          builder: (_, snap) {
            if (snap.data == null) {
              return Container(color: Colors.white10);
            }
            return Image.memory(snap.data!, fit: BoxFit.cover);
          },
        ),
        // El metadato encima de la foto: el punto de la demo.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            color: Colors.black54,
            child: Text(
              item.lat != null
                  ? '📍 ${item.date.toIso8601String().substring(0, 10)}'
                  : item.date.toIso8601String().substring(0, 10),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: item.lat != null
                    ? Colors.lightBlueAccent
                    : Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
