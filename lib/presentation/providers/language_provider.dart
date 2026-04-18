import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'language_code';
  Locale _locale = const Locale('en');

  LanguageProvider() {
    _loadSavedLanguage();
  }

  Locale get locale => _locale;

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey);
    if (languageCode != null) {
      _locale = Locale(languageCode);
      Intl.defaultLocale = languageCode;
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;

    _locale = locale;
    Intl.defaultLocale = locale.languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
    notifyListeners();
  }
} 