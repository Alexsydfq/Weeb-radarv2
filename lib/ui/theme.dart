import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../edition.dart';

/// Kolory akcentu do wyboru w ustawieniach (u znajomych ze zwykłymi nazwami).
Map<String, Color> get accentPresets => friendsEdition ? _plainPresets : _vocaloidPresets;

const _plainPresets = <String, Color>{
  'Stalowy': calmAccent,
  'Morski': Color(0xFF39C5BB),
  'Niebieski': Color(0xFF3A6EF0),
  'Lawendowy': Color(0xFFB9A6FF),
  'Zielony': Color(0xFF7ED957),
  'Żółty': Color(0xFFFFD23F),
  'Pomarańczowy': Color(0xFFFF9F1C),
  'Czerwony': Color(0xFFE5395C),
  'Różowy': Color(0xFFF4A6C6),
};

const _vocaloidPresets = <String, Color>{
  'Miku': Color(0xFF39C5BB),
  'Teto': Color(0xFFE5395C),
  'Luka': Color(0xFFF4A6C6),
  'Rin': Color(0xFFFFD23F),
  'Len': Color(0xFFFF9F1C),
  'KAITO': Color(0xFF3A6EF0),
  'GUMI': Color(0xFF7ED957),
  'IA': Color(0xFFB9A6FF),
  'Sakura': Color(0xFFFF7EB6),
  'Neon': Color(0xFF00E5FF),
};

/// Nadpisanie fontu (np. w zrzutach ekranu generowanych bez internetu).
String? fontOverride;

ThemeData buildTheme(Color accent, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    // Zaokrąglony font z japońskimi znakami (M PLUS Rounded 1c), pobierany przy pierwszym uruchomieniu.
    // U znajomych zwykły systemowy font.
    fontFamily: fontOverride ?? (friendsEdition ? null : GoogleFonts.mPlusRounded1c().fontFamily),
    fontFamilyFallback: fontOverride == null ? null : const ['Emoji'],
    scaffoldBackgroundColor: Colors.transparent,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface.withValues(alpha: 0.72),
      indicatorColor: accent.withValues(alpha: 0.35),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface.withValues(alpha: 0.55),
      indicatorColor: accent.withValues(alpha: 0.35),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
