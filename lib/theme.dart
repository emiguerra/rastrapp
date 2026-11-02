import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Camuflaje BeReal: negro puro, blanco, grises neutros, tipografía sans limpia.
/// La identidad gráfica de rastro (verde ácido, pixel, grano) se reserva para la
/// revelación (panel, expediente, instalación). La app que usa el participante
/// debe ser indistinguible de una red social normal.
///
/// Se conservan los nombres de la API (`R.verde`, `R.oliva`, `pixel()`, `mono()`)
/// y solo cambian sus valores a neutros, así las ~10 pantallas heredan el cambio.
class R {
  static const Color negro = Color(0xFF000000); // fondo
  static const Color oliva = Color(0xFF1A1A1C); // superficie (tarjetas, inputs)
  static const Color verde = Color(0xFFFFFFFF); // "acento" → blanco (botones BeReal)
  static const Color papel = Color(0xFFFFFFFF); // texto
  static const Color gris = Color(0xFF8E8E93); // texto secundario (gris iOS)

  /// Wordmark / títulos (antes pixelada; ahora sans gruesa y limpia).
  static TextStyle pixel({double size = 26, Color color = papel}) => GoogleFonts.inter(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      );

  /// Etiquetas (antes monoespaciada; ahora sans con poco tracking).
  static TextStyle mono({
    double size = 12,
    Color color = gris,
    FontWeight weight = FontWeight.w600,
  }) =>
      GoogleFonts.inter(fontSize: size, color: color, fontWeight: weight, letterSpacing: 0.2);

  /// Cuerpo / display.
  static TextStyle display({
    double size = 22,
    Color color = papel,
    FontWeight weight = FontWeight.w700,
  }) =>
      GoogleFonts.interTight(fontSize: size, color: color, fontWeight: weight);

  static ThemeData theme() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: negro,
      colorScheme: base.colorScheme.copyWith(
        primary: papel,
        surface: oliva,
        brightness: Brightness.dark,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: GoogleFonts.inter().fontFamily,
        bodyColor: papel,
        displayColor: papel,
      ),
    );
  }
}

/// Cajita con borde, estilo pastilla.
class PillBox extends StatelessWidget {
  final String text;
  const PillBox(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: R.papel, width: 1.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: R.mono(size: 11, color: R.papel)),
      );
}

/// Wordmark "rastro." — sans gruesa, blanca (estilo "BeReal.").
class Wordmark extends StatelessWidget {
  final double size;
  const Wordmark({super.key, this.size = 24});
  @override
  Widget build(BuildContext context) => Text(
        'rastro.',
        style: R.pixel(size: size, color: R.papel),
      );
}
