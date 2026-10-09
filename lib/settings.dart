
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const String _languageKey = 'language';
  static const String _legacySindhiKey = 'sindhi';

  String _language = 'en';

  String get language => _language;

  bool get sindhi => _language == 'sd';

  set sindhi(bool value) {
    setLanguage(value ? 'sd' : 'en');
  }

  String voiceLang = 'auto';
  DateTime? lastBackup;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Purani saved language setting ko bhi support karein.
    final savedLanguage = prefs.getString(_languageKey);

    if (savedLanguage != null &&
        ['en', 'sd', 'ur'].contains(savedLanguage)) {
      _language = savedLanguage;
    } else {
      _language = prefs.getBool(_legacySindhiKey) == true
          ? 'sd'
          : 'en';
    }

    voiceLang = prefs.getString('voice_lang') ?? 'auto';

    final backupValue = prefs.getString('last_backup');
    lastBackup = backupValue == null
        ? null
        : DateTime.tryParse(backupValue);
  }

  Future<void> setLanguage(String value) async {
    if (!['en', 'sd', 'ur'].contains(value)) {
      return;
    }

    if (_language == value) return;

    _language = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value);
    await prefs.setBool(_legacySindhiKey, value == 'sd');

    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    await setLanguage(_language == 'sd' ? 'en' : 'sd');
  }

  String t(String en, String sd, [String? ur]) {
    switch (_language) {
      case 'sd':
        return sd;
      case 'ur':
        return ur ?? en;
      default:
        return en;
    }
  }

  TextDirection get direction {
    return _language == 'en'
        ? TextDirection.ltr
        : TextDirection.rtl;
  }

  Locale get locale {
    return Locale(_language);
  }
}
