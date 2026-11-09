import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Placeholders neutros (grises planos) cuando no hay foto real.
const List<List<Color>> kTones = [
  [Color(0xFF2A2A2C), Color(0xFF161618)],
  [Color(0xFF26262A), Color(0xFF151517)],
  [Color(0xFF2E2E31), Color(0xFF17171A)],
  [Color(0xFF232326), Color(0xFF141416)],
];

/// Una "foto": si hay archivo/URL real, la muestra; si no, un gris plano.
/// Si [locked] es true, va difuminada (mecánica BeReal: se revela al publicar).
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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
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

    if (!locked) return base;

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: base,
        ),
        Container(color: Colors.black.withValues(alpha: 0.3)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, color: R.papel, size: 28),
              const SizedBox(height: 8),
              Text('Publica para ver', style: R.mono(size: 12, color: R.papel)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Foto doble cámara estilo BeReal: foto grande + inset arriba-izquierda.
/// Tocar la intercambia (la frontal pasa a grande y viceversa).
class DualPhoto extends StatefulWidget {
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
    this.radius = 16,
  });

  @override
  State<DualPhoto> createState() => _DualPhotoState();
}

class _DualPhotoState extends State<DualPhoto> {
  bool _swapped = false;

  @override
  Widget build(BuildContext context) {
    final hasSmall = widget.small != null ||
        (widget.smallUrl != null && widget.smallUrl!.isNotEmpty);

    // Qué va grande y qué va en el inset según el swap.
    final bigFile = _swapped ? widget.small : widget.big;
    final bigUrl = _swapped ? widget.smallUrl : widget.bigUrl;
    final smallFile = _swapped ? widget.big : widget.small;
    final smallUrl = _swapped ? widget.bigUrl : widget.smallUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GrainyPhoto(
                file: bigFile,
                url: bigUrl,
                tone: widget.tone,
                locked: widget.locked),
            if (hasSmall)
              Positioned(
                top: 12,
                left: 12,
                child: GestureDetector(
                  onTap: widget.locked
                      ? null
                      : () => setState(() => _swapped = !_swapped),
                  child: Container(
                    width: 96,
                    height: 128,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 3),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: GrainyPhoto(
                        file: smallFile,
                        url: smallUrl,
                        tone: (widget.tone + 2),
                        locked: widget.locked,
                      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
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
