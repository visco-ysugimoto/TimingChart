import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends ChangeNotifier {
  static const _kLocaleCodeKey = 'localeCode';

  Locale _locale = const Locale('ja');
  SharedPreferences? _prefs;
  late final Future<void> initialized;

  LocaleNotifier() {
    initialized = _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final code = _prefs?.getString(_kLocaleCodeKey);
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    _prefs?.setString(_kLocaleCodeKey, locale.languageCode);
    notifyListeners();
  }
}
