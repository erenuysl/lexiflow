import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _lexiflowPrimary = Color(0xFF33C4B3);
const Color _lexiflowSecondary = Color(0xFF2DD4BF);
const Color _lexiflowAccent = Color(0xFF30C6D9);

const ColorScheme lexiflowFallbackLightScheme = ColorScheme.light(
  primary: _lexiflowPrimary,
  onPrimary: Colors.white,
  primaryContainer: Color(0xFF5AE0D1),
  onPrimaryContainer: Color(0xFF00201C),
  secondary: _lexiflowSecondary,
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFF6BE8D8),
  onSecondaryContainer: Color(0xFF00201C),
  tertiary: _lexiflowAccent,
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFF69D7E4),
  onTertiaryContainer: Color(0xFF002933),
  surface: Color(0xFFF9FBFB),
  surfaceVariant: Color(0xFFE3F2F1),
  background: Color(0xFFF2F8F7),
  onSurface: Color(0xFF1A1A1A),
  onSurfaceVariant: Color(0xFF444444),
  outline: Color(0xFF7CC6BF),
  outlineVariant: Color(0xFFB6E5E0),
);

const ColorScheme lexiflowFallbackDarkScheme = ColorScheme.dark(
  primary: _lexiflowPrimary,
  onPrimary: Colors.black,
  primaryContainer: Color(0xFF005F5A),
  onPrimaryContainer: Colors.white,
  secondary: _lexiflowSecondary,
  onSecondary: Colors.black,
  secondaryContainer: Color(0xFF00524D),
  onSecondaryContainer: Colors.white,
  tertiary: _lexiflowAccent,
  onTertiary: Colors.black,
  tertiaryContainer: Color(0xFF004854),
  onTertiaryContainer: Colors.white,
  surface: Color(0xFF111518),
  surfaceVariant: Color(0xFF1C2427),
  background: Color(0xFF0C1114),
  onSurface: Colors.white,
  onSurfaceVariant: Colors.white70,
  outline: Color(0xFF3A4C50),
  outlineVariant: Color(0xFF233033),
);

ColorScheme blendWithLexiFlowAccent(ColorScheme scheme) {
  return scheme.copyWith(
    primary: Color.lerp(scheme.primary, _lexiflowPrimary, 0.3)!,
    primaryContainer:
        Color.lerp(scheme.primaryContainer, _lexiflowPrimary, 0.35)!,
    secondary: Color.lerp(scheme.secondary, _lexiflowSecondary, 0.3)!,
    secondaryContainer:
        Color.lerp(scheme.secondaryContainer, _lexiflowSecondary, 0.35)!,
    tertiary: Color.lerp(scheme.tertiary, _lexiflowAccent, 0.3)!,
    tertiaryContainer:
        Color.lerp(scheme.tertiaryContainer, _lexiflowAccent, 0.35)!,
  );
}

class LexiFlowCardsPalette {
  const LexiFlowCardsPalette({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.shadowColor,
    required this.gradient,
  });

  factory LexiFlowCardsPalette.fromScheme(
    ColorScheme scheme, {
    required Brightness brightness,
  }) {
    final tintedScheme = blendWithLexiFlowAccent(scheme);
    final isDark = brightness == Brightness.dark;

    return LexiFlowCardsPalette(
      primary: tintedScheme.primary,
      secondary: tintedScheme.secondary,
      accent: tintedScheme.tertiary,
      background: scheme.background,
      surface: scheme.surface,
      card: isDark ? scheme.surfaceVariant : scheme.surface,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      shadowColor:
          isDark
              ? Colors.black.withOpacity(0.35)
              : Colors.black.withOpacity(0.08),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tintedScheme.primaryContainer.withOpacity(0.9),
          tintedScheme.secondaryContainer.withOpacity(0.9),
        ],
      ),
    );
  }

  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color shadowColor;
  final Gradient gradient;
}

class LexiFlowCardsTheme {
  const LexiFlowCardsTheme._();

  static LexiFlowCardsPalette palette(BuildContext context) {
    final theme = Theme.of(context);
    return LexiFlowCardsPalette.fromScheme(
      theme.colorScheme,
      brightness: theme.brightness,
    );
  }

  static LexiFlowCardsTypography typography(BuildContext context) {
    final currentPalette = palette(context);
    return LexiFlowCardsTypography(currentPalette);
  }
}

class LexiFlowCardsTypography {
  LexiFlowCardsTypography(this.palette);

  final LexiFlowCardsPalette palette;

  TextStyle get headline => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: palette.textPrimary,
    height: 1.3,
  );

  TextStyle get title => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: palette.textPrimary,
    height: 1.35,
  );

  TextStyle get body => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: palette.textSecondary,
    height: 1.5,
  );

  TextStyle get label => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: palette.textPrimary,
    letterSpacing: 0.2,
  );

  TextStyle get button => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: palette.surface,
    letterSpacing: 0.2,
  );
}

extension LexiFlowTypographyExtension on BuildContext {
  LexiFlowCardsTypography get cardsTypography =>
      LexiFlowCardsTheme.typography(this);

  LexiFlowCardsPalette get cardsPalette => LexiFlowCardsTheme.palette(this);
}

extension ColorOpacityExt on Color {
  Color withOpacityFraction(double opacity) =>
      withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}
