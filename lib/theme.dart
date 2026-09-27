import 'package:flutter/material.dart';

/// Identité visuelle de la chorale : aubergine (robe de chœur), or
/// (partitions, lumière) et fond crème (papier à musique).
/// Toutes les pages utilisent ce thème : éviter les couleurs codées en dur
/// dans les écrans, sauf pour un sens précis (rouge = supprimer, etc.).
class CouleursChorale {
  static const aubergine = Color(0xFF3F2A56);
  static const aubergineFonce = Color(0xFF2A1B3D);
  static const or = Color(0xFFC9A227);
  static const creme = Color(0xFFF8F5EF);
  static const bordure = Color(0xFFE7E0D4);

  /// Aubergine adouci (textes secondaires sur fond clair).
  static const aubergineClair = Color(0xFF8C77A8);

  /// Fonds de bandeaux et d'encadrés.
  static const lavande = Color(0xFFEFE9F4);
  static const lavandeFonce = Color(0xFFE2D8EC);
}

ThemeData themeChorale() {
  final scheme = ColorScheme.fromSeed(
    seedColor: CouleursChorale.aubergine,
    primary: CouleursChorale.aubergine,
    secondary: CouleursChorale.or,
    surface: Colors.white,
  );
  final arrondi = BorderRadius.circular(14);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: CouleursChorale.creme,
    appBarTheme: const AppBarTheme(
      backgroundColor: CouleursChorale.aubergine,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: arrondi,
        side: const BorderSide(color: CouleursChorale.bordure),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: CouleursChorale.aubergine,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CouleursChorale.bordure),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CouleursChorale.aubergine,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: CouleursChorale.or,
      foregroundColor: CouleursChorale.aubergineFonce,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: CouleursChorale.aubergine,
      unselectedItemColor: Color(0xFF8A8494),
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      elevation: 8,
    ),
    chipTheme: ChipThemeData(
      selectedColor: CouleursChorale.or.withValues(alpha: 0.25),
      side: const BorderSide(color: CouleursChorale.bordure),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: CouleursChorale.bordure),
  );
}
