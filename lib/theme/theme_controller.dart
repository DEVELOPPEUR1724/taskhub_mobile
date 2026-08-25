import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Contrôle binaire clair/sombre (pas de mode "système"), persisté en local
// — même pattern que token/user_id dans auth_service.dart.
class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'dark_mode';

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_prefsKey) ?? false;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}

final themeController = ThemeController();
