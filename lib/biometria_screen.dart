import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'backend.dart';
import 'capture_flow.dart';
import 'perfil_editor.dart';
import 'theme.dart';

/// Verificación de identidad biométrica (facial). Es simbólica para el
/// participante —el ritual de entregar el rostro para entrar— y le sirve a la
/// investigadora como llave rostro → alias para el match en la entrevista.
class BiometriaScreen extends StatefulWidget {
  const BiometriaScreen({super.key});
  @override
  State<BiometriaScreen> createState() => _BiometriaScreenState();
}

enum _Fase { intro, analizando, listo }

class _BiometriaScreenState extends State<BiometriaScreen>
    with SingleTickerProviderStateMixin {
  _Fase _fase = _Fase.intro;
  File? _rostro;
  bool _finalizando = false;
  late final AnimationController _scan;

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  Future<void> _escanear() async {
    String? path;
    try {
      // Escáner facial en vivo (nativo): la parte interactiva pasa ahí.
      path = await scanFaceNative();
    } catch (_) {
      // Si el escáner nativo no está disponible, respaldo: foto frontal simple.
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );
      path = x?.path;
    }
    if (path == null) return; // canceló
    setState(() {
      _rostro = File(path!);
      _fase = _Fase.analizando;
    });
    // Guarda el rostro como avatar local (persistente).
    try {
      final dir = await getApplicationDocumentsDirectory();
      final local = '${dir.path}/avatar.jpg';
      await _rostro!.copy(local);
      await Backend.setRostroLocal(local);
    } catch (_) {}
    // Sube el rostro verificado y lo asocia al perfil.
    final url = await Backend.uploadRostro(_rostro!);
    await Backend.ensureProfile(rostroUrl: url);
    if (!mounted) return;
    setState(() => _fase = _Fase.listo);
  }

  void _continuar() {
    // Siguiente paso del alta: crear el perfil (foto elegida + nombre).
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PerfilEditor(onboarding: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wordmark(size: 24),
              const SizedBox(height: 8),
              Text('CREA TU AVATAR',
                  style: R.mono(size: 12, color: R.verde)),
              const Spacer(),
              Center(child: _marco()),
              const SizedBox(height: 26),
              Center(child: _texto()),
              const Spacer(),
              _boton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _marco() {
    const size = 240.0;
    return SizedBox(
      width: size,
      height: size * 1.25,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(140),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fondo / rostro capturado
            if (_rostro != null)
              Image.file(_rostro!, fit: BoxFit.cover)
            else
              Container(
                color: R.oliva,
                child: const Icon(Icons.face_retouching_natural,
                    color: R.gris, size: 90),
              ),
            // Óvalo guía
            CustomPaint(painter: _OvalPainter(_fase == _Fase.listo)),
            // Línea de escaneo
            if (_fase == _Fase.analizando)
              AnimatedBuilder(
                animation: _scan,
                builder: (_, _) => Align(
                  alignment: Alignment(0, _scan.value * 2 - 1),
                  child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: R.verde,
                      boxShadow: [
                        BoxShadow(
                            color: R.verde.withValues(alpha: 0.7),
                            blurRadius: 12,
                            spreadRadius: 1),
                      ],
                    ),
                  ),
                ),
              ),
            // Check final
            if (_fase == _Fase.listo)
              Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Icon(Icons.check_circle,
                    color: R.verde, size: 72),
              ),
          ],
        ),
      ),
    );
  }

  Widget _texto() {
    switch (_fase) {
      case _Fase.intro:
        return Text(
          'mira a la cámara y escanéate\npara crear tu avatar.',
          textAlign: TextAlign.center,
          style: R.mono(size: 12, color: R.gris),
        );
      case _Fase.analizando:
        return Text('CREANDO TU AVATAR…',
            style: R.mono(size: 13, color: R.verde));
      case _Fase.listo:
        return Column(
          children: [
            Text('¡LISTO!', style: R.mono(size: 14, color: R.verde)),
            const SizedBox(height: 6),
            Text('tu avatar quedó activado.',
                textAlign: TextAlign.center,
                style: R.mono(size: 11, color: R.gris)),
          ],
        );
    }
  }

  Widget _boton() {
    final (label, onTap) = switch (_fase) {
      _Fase.intro => ('ESCANEARME', _escanear),
      _Fase.analizando => ('CREANDO…', null),
      _Fase.listo => ('CONTINUAR', _finalizando ? null : _continuar),
    };
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: R.verde,
          foregroundColor: R.negro,
          disabledBackgroundColor: R.oliva,
          padding: const EdgeInsets.symmetric(vertical: 17),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999)),
        ),
        child: (_fase == _Fase.analizando || _finalizando)
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: R.verde))
            : Text(label,
                style: R.mono(
                    size: 14,
                    color: onTap == null ? R.gris : R.negro)),
      ),
    );
  }
}

/// Óvalo guía con brackets, estilo escáner.
class _OvalPainter extends CustomPainter {
  final bool ok;
  _OvalPainter(this.ok);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = (ok ? R.verde : R.verde.withValues(alpha: 0.6))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromLTWH(14, 10, size.width - 28, size.height - 20);
    canvas.drawOval(rect, p);
  }

  @override
  bool shouldRepaint(covariant _OvalPainter old) => old.ok != ok;
}
