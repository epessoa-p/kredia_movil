import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette {
  static const Color ink = Color(0xFF13273D);
  static const Color deepBlue = Color(0xFF1E5E9D);
  static const Color aqua = Color(0xFF19C5B6);
  static const Color sand = Color(0xFFFFF8EE);
  static const Color rose = Color(0xFFFF6B6B);

  // Neutros y semánticos (mismos valores que la web: kredia-ui.css)
  static const Color primary = Color(0xFF2563EB);
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color text = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color border = Color(0xFFE3E8EF);
  static const Color borderStrong = Color(0xFFCFD7E3);
  static const Color background = Color(0xFFF4F6FA);
}

/// Escala ÚNICA de tamaños de letra (equivale a --fs-* de la web).
/// En las pantallas se usa `Theme.of(context).textTheme.*` (o `AppText.*`), nunca `fontSize:` suelto.
class AppFontSize {
  static const double xs = 11;   // etiquetas, chips, ayudas
  static const double sm = 12;   // textos secundarios, tablas
  static const double base = 14; // texto normal, formularios, botones
  static const double md = 16;   // títulos de tarjeta / sección
  static const double lg = 20;   // título de pantalla
  static const double xl = 24;   // cifras grandes (KPI)
}

/// Medidas compartidas de botones y bordes.
class AppShape {
  static const double radius = 10;
  static const double buttonHeight = 44;
  static const double buttonHeightSm = 36;
  static BorderRadius get borderRadius => BorderRadius.circular(radius);
}

class AppTheme {
  static ThemeData light() {
    TextStyle sora(double size, FontWeight weight) =>
        GoogleFonts.sora(fontSize: size, fontWeight: weight, color: AppPalette.text);
    TextStyle dm(double size, FontWeight weight, [Color color = AppPalette.text]) =>
        GoogleFonts.dmSans(fontSize: size, fontWeight: weight, color: color);

    // Mapa: displaySmall/headline → KPI y títulos; title* → secciones; body* → texto; label* → botones/chips.
    final textTheme = TextTheme(
      displayLarge: sora(AppFontSize.xl, FontWeight.w700),
      displayMedium: sora(AppFontSize.xl, FontWeight.w700),
      displaySmall: sora(AppFontSize.xl, FontWeight.w700),
      headlineLarge: sora(AppFontSize.xl, FontWeight.w700),
      headlineMedium: sora(AppFontSize.lg, FontWeight.w700),
      headlineSmall: sora(AppFontSize.lg, FontWeight.w700),
      titleLarge: sora(AppFontSize.lg, FontWeight.w600),
      titleMedium: dm(AppFontSize.md, FontWeight.w700),
      titleSmall: dm(AppFontSize.base, FontWeight.w700),
      bodyLarge: dm(AppFontSize.md, FontWeight.w500),
      bodyMedium: dm(AppFontSize.base, FontWeight.w500),
      bodySmall: dm(AppFontSize.sm, FontWeight.w500, AppPalette.textMuted),
      labelLarge: dm(AppFontSize.base, FontWeight.w700),
      labelMedium: dm(AppFontSize.sm, FontWeight.w600),
      labelSmall: dm(AppFontSize.xs, FontWeight.w600),
    );

    final buttonShape = RoundedRectangleBorder(borderRadius: AppShape.borderRadius);
    final buttonText = WidgetStatePropertyAll(dm(AppFontSize.base, FontWeight.w700));
    const buttonPadding = WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16));
    const buttonMinSize = WidgetStatePropertyAll(Size(64, AppShape.buttonHeight));

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppPalette.sand,
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: AppPalette.deepBlue,
        secondary: AppPalette.aqua,
        surface: Colors.white,
        error: AppPalette.rose,
      ),

      // ── Botones: un solo diseño (alto, radio, letra) ──────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: buttonText,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: buttonText,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: buttonText,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          foregroundColor: const WidgetStatePropertyAll(AppPalette.text),
          side: const WidgetStatePropertyAll(BorderSide(color: AppPalette.borderStrong)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: buttonText,
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
          minimumSize: const WidgetStatePropertyAll(Size(48, AppShape.buttonHeightSm)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(buttonShape),
          minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppPalette.text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: sora(AppFontSize.md, FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        labelStyle: dm(AppFontSize.sm, FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: const BorderSide(color: AppPalette.border),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: dm(AppFontSize.base, FontWeight.w500, Colors.white),
        shape: RoundedRectangleBorder(borderRadius: AppShape.borderRadius),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: sora(AppFontSize.md, FontWeight.w700),
        contentTextStyle: dm(AppFontSize.base, FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStatePropertyAll(dm(AppFontSize.xs, FontWeight.w600)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedLabelStyle: dm(AppFontSize.xs, FontWeight.w700),
        unselectedLabelStyle: dm(AppFontSize.xs, FontWeight.w500),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: dm(AppFontSize.base, FontWeight.w500, AppPalette.textMuted),
        hintStyle: dm(AppFontSize.base, FontWeight.w400, AppPalette.textMuted),
        helperStyle: dm(AppFontSize.xs, FontWeight.w500, AppPalette.textMuted),
        errorStyle: dm(AppFontSize.xs, FontWeight.w600, AppPalette.danger),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppPalette.deepBlue, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        color: Colors.white,
      ),
    );
  }
}
