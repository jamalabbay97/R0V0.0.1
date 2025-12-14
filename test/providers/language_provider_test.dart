import 'package:flutter_test/flutter_test.dart';
import 'package:r0/providers/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LanguageProvider Tests', () {
    late LanguageProvider provider;

    setUp(() async {
      // Clear shared preferences before each test
      SharedPreferences.setMockInitialValues({});
      provider = LanguageProvider();
      // Wait for async initialization
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('should initialize with default locale (English)', () {
      expect(provider.locale, const Locale('en'));
    });

    test('should change locale when setLocale is called', () async {
      const frenchLocale = Locale('fr');
      
      await provider.setLocale(frenchLocale);

      expect(provider.locale, frenchLocale);
    });

    test('should not notify listeners if locale is the same', () async {
      var notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      // Set to English (already English)
      await provider.setLocale(const Locale('en'));

      // Should not notify since it's the same
      expect(notifyCount, 0);
    });

    test('should notify listeners when locale changes', () async {
      var notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      await provider.setLocale(const Locale('fr'));

      expect(notifyCount, greaterThan(0));
    });

    test('should persist locale to SharedPreferences', () async {
      const frenchLocale = Locale('fr');
      
      await provider.setLocale(frenchLocale);

      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('language_code');

      expect(savedLanguage, 'fr');
    });

    test('should load saved locale from SharedPreferences', () async {
      // Set a locale in preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', 'fr');

      // Create a new provider instance (simulating app restart)
      final newProvider = LanguageProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(newProvider.locale, const Locale('fr'));
    });

    test('should handle switching between locales', () async {
      await provider.setLocale(const Locale('fr'));
      expect(provider.locale, const Locale('fr'));

      await provider.setLocale(const Locale('en'));
      expect(provider.locale, const Locale('en'));

      await provider.setLocale(const Locale('fr'));
      expect(provider.locale, const Locale('fr'));
    });

    test('should maintain locale across multiple setLocale calls', () async {
      await provider.setLocale(const Locale('fr'));
      await provider.setLocale(const Locale('fr'));
      await provider.setLocale(const Locale('fr'));

      expect(provider.locale, const Locale('fr'));
    });
  });
}
