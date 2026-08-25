import 'package:flutter/material.dart';

const _adaiOrange = Color(0xFFE57A44);

class AppTheme {
  static ThemeData get light {
    const background = Color(0xFFF4F1ED);
    const surface = Color(0xFFFFFFFF);
    const surfaceSoft = Color(0xFFF7F3EF);
    const border = Color(0xFFDDD5CE);
    const onSurface = Color(0xFF211C19);
    const onSurfaceVariant = Color(0xFF70665F);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: _adaiOrange,
      brightness: Brightness.light,
    ).copyWith(
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceSoft,
      onSurfaceVariant: onSurfaceVariant,
      outlineVariant: border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      cardColor: surface,
      dividerColor: border,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _adaiOrange),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  static ThemeData get dark {
    const background = Color(0xFF0B0A0A);
    const surface = Color(0xFF121111);
    const surfaceSoft = Color(0xFF161515);
    const border = Color(0xFF1F1E1E);
    const onSurface = Color(0xFFEDEDED);
    const onSurfaceVariant = Color(0xFF878787);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: _adaiOrange,
      brightness: Brightness.dark,
    ).copyWith(
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceSoft,
      onSurfaceVariant: onSurfaceVariant,
      outlineVariant: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      cardColor: surface,
      dividerColor: border,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _adaiOrange),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
