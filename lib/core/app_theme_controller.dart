import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the app-wide theme selection and keeps it available before the API
/// preferences request completes.
class AppThemeController extends ChangeNotifier {
  static const _preferenceKey = 'employer_theme_mode';

  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _mode = _modeFromValue(preferences.getString(_preferenceKey));
      notifyListeners();
    } catch (_) {
      // Theme persistence is optional.  The app must still be usable when a
      // platform implementation of SharedPreferences is temporarily absent.
    }
  }

  Future<void> setDark(bool enabled) async {
    await setMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setServerValue(String? value) async {
    // "system" is represented as light in this screen because the setting is
    // a simple Dark theme on/off control.  Future server values stay safe.
    await setMode(value == 'dark' ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_preferenceKey, _valueForMode(mode));
    } catch (_) {
      // Keep the selected theme for this session even if it cannot be saved.
    }
  }

  ThemeMode _modeFromValue(String? value) =>
      value == 'dark' ? ThemeMode.dark : ThemeMode.light;

  String _valueForMode(ThemeMode mode) =>
      mode == ThemeMode.dark ? 'dark' : 'light';
}
