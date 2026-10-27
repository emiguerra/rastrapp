import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identidad gráfica de rastro: negro granulado, verde ácido, tipo pixelada +
/// monoespaciada. Estructura BeReal, piel rastro.
class R {
  static const Color negro = Color(0xFF050505);
  static const Color oliva = Color(0xFF17180F);
  static const Color verde = Color(0xFFC8F31D);
  static const Color papel = Color(0xFFF2F2EE);
  static const Color gris = Color(0xFF8A8A85);

  /// Wordmark / títulos pixelados.
  static TextStyle pixel({double size = 26, Color color = papel}) =>
      GoogleFonts.silkscreen(fontSize: size, color: color, letterSpacing: 1);

  /// Etiquetas monoespaciadas (uppercase, tracked).
  static TextStyle mono({
    double size = 12,
    Color color = gris,
    FontWeight weight = FontWeight.w700,
  }) =>
      GoogleFonts.spaceMono(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: 1.2,
      );

  /// Display / cuerpo.
  static TextStyle display({
    double size = 22,
    Color color = papel,
    FontWeight weight = FontWeight.w800,
  }) =>
      GoogleFonts.interTight(fontSize: size, color: color, fontWeight: weight);

  static ThemeData theme() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: negro,
      colorScheme: base.colorScheme.copyWith(
        primary: verde,
        surface: oliva,
        brightness: Brightness.dark,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: GoogleFonts.interTight().fontFamily,
        bodyColor: papel,
        displayColor: papel,
      ),
    );
  }
}

/// Cajita con borde verde, como las de la convocatoria: [14/10] [AM].
class PillBox extends StatelessWidget {
  final String text;
  const PillBox(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: R.verde, width: 1.3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: R.mono(size: 11, color: R.verde)),
      );
}

/// Wordmark "rastro." en pixel verde (como "ReBeal." en BeReal).
class Wordmark extends StatelessWidget {
  final double size;
  const Wordmark({super.key, this.size = 24});
  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(children: [
          TextSpan(text: 'rastro', style: R.pixel(size: size, color: R.papel)),
          TextSpan(text: '.', style: R.pixel(size: size, color: R.verde)),
        ]),
      );
}
