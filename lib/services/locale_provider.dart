import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's current [Locale] and persists the user's choice locally,
/// so the language sticks after the app is reopened.
///
/// Kazakh (Latin script) is the default/initial language, per BiletFlow spec.
class LocaleProvider extends ChangeNotifier {
  static const String _prefsKey = 'biletflow_locale';
  static const Locale defaultLocale = Locale('kk');

  static const List<Locale> supportedLocales = [
    Locale('kk'),
    Locale('ru'),
    Locale('en'),
  ];

  Locale _locale = defaultLocale;
  Locale get locale => _locale;

  /// Loads a previously saved language preference, if any.
  Future<void> loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && supportedLocales.any((l) => l.languageCode == saved)) {
        _locale = Locale(saved);
        notifyListeners();
      }
    } catch (_) {
      // If local storage is unavailable for any reason, silently keep the default.
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode == _locale.languageCode) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, locale.languageCode);
    } catch (_) {
      // Non-fatal: the language still changes for this session.
    }
  }
}
