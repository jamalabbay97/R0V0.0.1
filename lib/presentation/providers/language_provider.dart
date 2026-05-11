import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'language_code';
  Locale _locale = const Locale('en');

  LanguageProvider() {
    _loadSavedLanguage();
  }

  Locale get locale => _locale;

  bool _isWebStorageDenied(Object error) {
    if (!kIsWeb) {
      return false;
    }
    final text = error.toString().toLowerCase();
    return text.contains('securityerror') ||
        text.contains('localstorage') ||
        text.contains('sessionstorage') ||
        text.contains('access is denied') ||
        text.contains('indexeddb');
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey);
      if (languageCode != null) {
        _locale = Locale(languageCode);
        Intl.defaultLocale = languageCode;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode && !_isWebStorageDenied(e)) {
        debugPrint('Failed to load saved language: $e');
      }
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;

    _locale = locale;
    Intl.defaultLocale = locale.languageCode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, locale.languageCode);
    } catch (e) {
      if (kDebugMode && !_isWebStorageDenied(e)) {
        debugPrint('Failed to persist language: $e');
      }
    }
    notifyListeners();
  }
} 
