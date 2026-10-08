import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage extends ChangeNotifier {
  static final shared = AppLanguage();
  static const _key = 'employer_app_locale';
  Locale _locale = const Locale('en');
  Locale get locale => _locale;
  // Flutter's Material translations only support standard locale codes. Keep
  // the selected Hinglish code for app copy, while Material uses Hindi safely.
  Locale get materialLocale =>
      _locale.languageCode == 'hinglish' ? const Locale('hi') : _locale;
  Future<void> restore() async {
    final code = (await SharedPreferences.getInstance()).getString(_key);
    if (code != null && code.isNotEmpty) _locale = Locale(code);
  }

  Future<void> select(String code) async {
    if (_locale.languageCode == code) return;
    _locale = Locale(code);
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(_key, code);
  }

  static String label(String code) =>
      const {
        'en': 'English',
        'hi': 'हिन्दी',
        'hinglish': 'Hindi + English',
        'ta': 'தமிழ்',
        'te': 'తెలుగు',
        'bn': 'বাংলা',
        'mr': 'मराठी',
      }[code] ??
      code;
}
