import 'package:flutter/material.dart';

/// Colori semantici dell'app. Il rosso è riservato ai pericoli, l'ambra agli avvisi di cautela,
/// il verde alla categoria "Commestibile". Tutto il resto è bosco: verdi, muschio, terra.
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.paper,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkSoft,
    required this.outline,
    required this.danger,
    required this.dangerBg,
    required this.warn,
    required this.warnBg,
    required this.ok,
    required this.okBg,
  });

  final Color paper;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkSoft;
  final Color outline;
  final Color danger;
  final Color dangerBg;
  final Color warn;
  final Color warnBg;
  final Color ok;
  final Color okBg;

  static const light = Palette(
    paper: Color(0xFFECEFE4),
    surface: Color(0xFFFAFBF6),
    surfaceAlt: Color(0xFFE0E6D3),
    ink: Color(0xFF17221A),
    inkSoft: Color(0xFF4C5B4F),
    outline: Color(0xFFC9D1BB),
    danger: Color(0xFFB3261E),
    dangerBg: Color(0xFFFBE8E4),
    warn: Color(0xFF8A5A00),
    warnBg: Color(0xFFFAEFD2),
    ok: Color(0xFF2E6B3B),
    okBg: Color(0xFFE0EEDD),
  );

  static const dark = Palette(
    paper: Color(0xFF0F1611),
    surface: Color(0xFF18221B),
    surfaceAlt: Color(0xFF223027),
    ink: Color(0xFFE8EEE2),
    inkSoft: Color(0xFFA5B4A7),
    outline: Color(0xFF34443A),
    danger: Color(0xFFFF8F84),
    dangerBg: Color(0xFF3B1B18),
    warn: Color(0xFFE8B75A),
    warnBg: Color(0xFF38290D),
    ok: Color(0xFF8CCB94),
    okBg: Color(0xFF16311C),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).extension<Palette>()!;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) =>
      t < 0.5 ? this : (other as Palette? ?? this);
}

/// Serif di Fraunces: usato solo per i nomi delle specie e i titoli, così il nome latino
/// (in corsivo) è la voce principale dell'app. Il resto resta nel font di sistema.
TextStyle serif({
  double size = 20,
  double weight = 600,
  bool italic = false,
  Color? color,
  double? height,
}) => TextStyle(
  fontFamily: 'Fraunces',
  fontSize: size,
  fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  fontVariations: [
    FontVariation('wght', weight),
    const FontVariation('SOFT', 40),
    const FontVariation('opsz', 36),
  ],
  letterSpacing: -0.2,
  height: height ?? 1.15,
  color: color,
);

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.light ? Palette.light : Palette.dark;
  final primary = b == Brightness.light
      ? const Color(0xFF1F3B2D)
      : const Color(0xFF9CCB86);
  final scheme = ColorScheme(
    brightness: b,
    primary: primary,
    onPrimary: b == Brightness.light ? Colors.white : const Color(0xFF0F1611),
    primaryContainer: b == Brightness.light
        ? const Color(0xFFD3E3C4)
        : const Color(0xFF2B4331),
    onPrimaryContainer: p.ink,
    secondary: const Color(0xFF55793F),
    onSecondary: Colors.white,
    secondaryContainer: p.surfaceAlt,
    onSecondaryContainer: p.ink,
    error: p.danger,
    onError: b == Brightness.light ? Colors.white : const Color(0xFF3B1B18),
    errorContainer: p.dangerBg,
    onErrorContainer: p.danger,
    surface: p.surface,
    onSurface: p.ink,
    onSurfaceVariant: p.inkSoft,
    outline: p.outline,
    outlineVariant: p.outline,
    surfaceContainerHighest: p.surfaceAlt,
  );
  final base = ThemeData(
    brightness: b,
    useMaterial3: true,
    colorScheme: scheme,
  );
  final t = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink);
  return base.copyWith(
    extensions: [p],
    scaffoldBackgroundColor: p.paper,
    textTheme: t.copyWith(
      titleLarge: serif(size: 24, color: p.ink),
      titleMedium: serif(size: 18, color: p.ink),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.paper,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: serif(size: 24, color: p.ink),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.outline),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      elevation: 0,
      height: 68,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.ink),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: t.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        side: BorderSide(color: p.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: t.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.outline, space: 1),
  );
}
