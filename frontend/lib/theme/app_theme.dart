import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens — Outfit type, soft neutrals, green working accent.
abstract final class AppTheme {
  static const background = Color(0xFFF5F5F5);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF0F0F0);
  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xFF8A8A8A);
  static const textTertiary = Color(0xFFB0B0B0);
  static const border = Color(0xFFE8E8E8);

  static const green = Color(0xFF22C55E);
  static const greenMuted = Color(0xFFDCFCE7);
  static const greenText = Color(0xFF16A34A);

  static const navBar = Color(0xFF1C1C1E);
  static const navBarActive = Color(0xFF3A3A3C);

  /// Legacy accent — kept for screens not yet restyled.
  static const slate = Color(0xFF3D4F6F);

  static const actionClockIn = Color(0xFF22C55E);
  static const actionClockOut = Color(0xFF111111);
  static const actionBreak = Color(0xFF111111);

  static const radiusSm = 10.0;
  static const radiusMd = 14.0;
  static const radiusLg = 24.0;
  static const radiusPill = 28.0;
  static const radiusNav = 32.0;

  static const navBarHeight = 64.0;
  static const pagePadding = 24.0;
  static const pageTopPadding = 20.0;

  static TextStyle _outfit({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    List<FontFeature>? fontFeatures,
  }) =>
      GoogleFonts.outfit(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontFeatures: fontFeatures,
      );

  static BoxDecoration bordered({double radius = radiusMd, Color? color}) =>
      BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      );

  static BoxDecoration softCard({double radius = radiusLg}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
      );

  static ThemeData materialTheme() {
    final base = ThemeData(
      colorScheme: const ColorScheme.light(
        primary: textPrimary,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: background,
      dividerColor: border,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme),
      filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle()),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButtonStyle()),
    );
  }

  static TextStyle greeting(BuildContext context) => _outfit(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        letterSpacing: 1.2,
        height: 1.2,
      );

  static TextStyle pageTitle(BuildContext context) => _outfit(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: textPrimary,
        height: 1.1,
      );

  static TextStyle subtitle(BuildContext context) => _outfit(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.4,
      );

  static TextStyle rowTitle(BuildContext context) => _outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle rowMeta(BuildContext context) => _outfit(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      );

  static TextStyle sectionTitle(BuildContext context) => _outfit(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        letterSpacing: 1.1,
      );

  static TextStyle badge(BuildContext context) => _outfit(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      );

  static TextStyle navLabel({required bool selected}) => _outfit(
        fontSize: 10,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.45),
      );

  static Color eventIconColor(String? type) => textSecondary;

  static Color actionColor(String endpoint) => switch (endpoint) {
        'in' || 'break/end' => actionClockIn,
        _ => actionClockOut,
      };

  static ButtonStyle actionButtonStyle(String endpoint) =>
      filledButtonStyle().copyWith(
        backgroundColor: WidgetStatePropertyAll(actionColor(endpoint)),
      );

  static ButtonStyle breakOutlinedButtonStyle() => outlinedButtonStyle().copyWith(
        foregroundColor: const WidgetStatePropertyAll(textPrimary),
        backgroundColor: const WidgetStatePropertyAll(surface),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.08)),
        side: const WidgetStatePropertyAll(BorderSide.none),
      );

  static InputDecoration inputDecoration(String label) {
    final borderShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: const BorderSide(color: AppTheme.border),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: _outfit(color: textSecondary, fontSize: 14),
      filled: true,
      fillColor: surface,
      border: borderShape,
      enabledBorder: borderShape,
      focusedBorder: borderShape.copyWith(
        borderSide: const BorderSide(color: textPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  static ButtonStyle filledButtonStyle() => FilledButton.styleFrom(
        backgroundColor: textPrimary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: surfaceMuted,
        disabledForegroundColor: textTertiary,
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        elevation: 0,
        textStyle: _outfit(fontSize: 15, fontWeight: FontWeight.w600),
      );

  static ButtonStyle outlinedButtonStyle() => OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        backgroundColor: surface,
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        textStyle: _outfit(fontSize: 14, fontWeight: FontWeight.w600),
      );
}
