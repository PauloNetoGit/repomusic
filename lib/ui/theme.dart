// Identidade visual: uma pedaleira vista de cima, no palco.
//
//  * carpete da pedaleira (fundo), trilhos de alumínio (linhas)
//  * fita crepe escrita a marcador (nome do preset — o único elemento "gritante")
//  * latão do painel de amplificador (controles e seleção)
//  * lâmpada piloto vermelha (ligado)
//
// Tipografia: Big Shoulders Display (serigrafia de pedal/amp), Barlow (texto da
// interface) e Permanent Marker (só na fita).
import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF1B1D22); // carpete
  static const surface = Color(0xFF24272E); // folhas e painéis
  static const surface2 = Color(0xFF2C3038);
  static const line = Color(0xFF363A43); // trilho de alumínio
  static const tape = Color(0xFFECE5D3);
  static const ink = Color(0xFF17181B);
  static const brass = Color(0xFFC8A25A);
  static const accent = brass;
  static const text = Color(0xFFE9E6DF);
  static const muted = Color(0xFF9A978F);
  static const led = Color(0xFFE2382D); // lâmpada piloto
  static const danger = Color(0xFFE05A4F);
  static const ok = Color(0xFF6FCF7A); // LED verde
  static const warn = Color(0xFFE8B341);
  static const tolex = Color(0xFF222222);
  static const tweed = Color(0xFF8A6A3E);
}

class AppFonts {
  static const display = 'BigShoulders';
  static const body = 'Barlow';
  static const marker = 'Marker';
}

/// Estilos de texto nomeados pelo papel que cumprem.
class AppText {
  /// Nome de equipamento (serigrafia).
  static TextStyle gear(double size, {Color color = AppColors.text, FontWeight weight = FontWeight.w800}) =>
      TextStyle(fontFamily: AppFonts.display, fontSize: size, fontWeight: weight, height: 1.0, color: color);

  /// Título de seção.
  static const section = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.brass,
    height: 1.1,
  );

  static const caption = TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.35);
  static const value = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.brass, brightness: Brightness.dark).copyWith(
    primary: AppColors.brass,
    onPrimary: AppColors.ink,
    secondary: AppColors.brass,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.danger,
    outline: AppColors.line,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: AppFonts.body);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.display,
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
      ),
    ),
    textTheme: base.textTheme
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text)
        .copyWith(titleLarge: AppText.gear(28), bodySmall: AppText.caption),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      dragHandleColor: AppColors.line,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface2),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.tape,
      contentTextStyle: TextStyle(fontFamily: AppFonts.body, color: AppColors.ink, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.brass,
      thumbColor: AppColors.brass,
      inactiveTrackColor: AppColors.line,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.ink : AppColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.brass : AppColors.surface2,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.brass,
      side: const BorderSide(color: AppColors.line),
      labelStyle: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(
        fontFamily: AppFonts.body,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      checkmarkColor: AppColors.ink,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.brass,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.brass,
      dividerColor: AppColors.line,
      labelStyle: TextStyle(fontFamily: AppFonts.display, fontSize: 19, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontFamily: AppFonts.display, fontSize: 19, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.line)),
    ),
    dividerColor: AppColors.line,
    listTileTheme: const ListTileThemeData(iconColor: AppColors.muted),
  );
}

/// Cor legível (tinta escura ou texto claro) sobre um fundo.
Color onColor(Color c) => c.computeLuminance() > 0.42 ? AppColors.ink : Colors.white;

/// Formata "Música — Artista" como "Música, de Artista" para leitura corrida.
String formatInspiration(String s) {
  final i = s.indexOf(' — ');
  if (i < 0) return s;
  return '${s.substring(0, i)}, de ${s.substring(i + 3)}';
}
