import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Gradientes por "tono" para los placeholders de foto (fachada).
const List<List<Color>> kTones = [
  [Color(0xFF1C1C1E), Color(0xFF0B0B0B)],
  [Color(0xFF26301A), Color(0xFF12140B)],
  [Color(0xFF2A2436), Color(0xFF121016)],
  [Color(0xFF30241A), Color(0xFF14100B)],
];

/// Una "foto": si hay archivo real, la muestra; si no, un gradiente granulado
/// (fachada). Si [locked] es true, va difuminada (mecánica BeReal: se revela
/// cuando tú publicas).
class GrainyPhoto extends StatelessWidget {
  final File? file;
  final String? url;
  final int tone;
  final bool locked;
  final BoxFit fit;
  const GrainyPhoto({
    super.key,
    this.file,
    this.url,
    this.tone = 0,
    this.locked = false,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final hasReal = file != null && file!.existsSync();
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: kTones[tone % kTones.length],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
    );
    Widget base = hasReal
        ? Image.file(file!, fit: fit)
        : (url != null && url!.isNotEmpty)
            ? Image.network(
                url!,
                fit: fit,
                loadingBuilder: (c, child, prog) =>
                    prog == null ? child : placeholder,
                errorBuilder: (c, e, s) => placeholder,
              )
            : placeholder;

    // Grano: la textura de spray a baja opacidad, mezclada.
    base = Stack(
      fit: StackFit.expand,
      children: [
        base,
        IgnorePointer(
          child: Opacity(
            opacity: 0.06,
            child: Image.asset('assets/spray.png',
                fit: BoxFit.cover, repeat: ImageRepeat.repeat),
          ),
        ),
      ],
    );

    if (!locked) return base;

    // Difuminado + candado.
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: base,
        ),
        Container(color: Colors.black.withValues(alpha: 0.28)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  color: R.papel, size: 30),
              const SizedBox(height: 8),
              Text('PUBLICA PARA VER',
                  style: R.mono(size: 11, color: R.papel)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Foto doble cámara estilo BeReal: foto grande + inset arriba-izquierda.
class DualPhoto extends StatelessWidget {
  final File? big;
  final File? small;
  final String? bigUrl;
  final String? smallUrl;
  final int tone;
  final bool locked;
  final double radius;
  const DualPhoto({
    super.key,
    this.big,
    this.small,
    this.bigUrl,
    this.smallUrl,
    this.tone = 0,
    this.locked = false,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final hasSmall = small != null || (smallUrl != null && smallUrl!.isNotEmpty);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GrainyPhoto(file: big, url: bigUrl, tone: tone, locked: locked),
            if (hasSmall)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  width: 84,
                  height: 112,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 2.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: GrainyPhoto(
                      file: small,
                      url: smallUrl,
                      tone: (tone + 2),
                      locked: locked,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pastilla de metadato (ubicación / hora) sobre la foto.
class MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const MetaPill({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: R.papel),
            const SizedBox(width: 5),
            Text(text, style: R.mono(size: 10, color: R.papel)),
          ],
        ),
      );
}
