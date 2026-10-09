
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const String _languageKey = 'language';
  static const String _legacySindhiKey = 'sindhi';
  static const String _voiceLanguageKey = 'voice_lang';
  static const String _lastBackupKey = 'last_backup';

  String _language = 'en';

  String get language => _language;

  bool get sindhi => _language == 'sd';

  set sindhi(bool value) {
    setLanguage(value ? 'sd' : 'en');
  }

  String voiceLang = 'auto';
  DateTime? lastBackup;

  /// True when there has never been a backup,
  /// or the most recent backup was over 7 days ago.
  bool get backupOverdue {
    if (lastBackup == null) return true;

    return DateTime.now().difference(lastBackup!).inDays >= 7;
  }

  /// Load saved preferences.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final savedLanguage = prefs.getString(_languageKey);

    if (savedLanguage != null &&
        ['en', 'sd', 'ur'].contains(savedLanguage)) {
      _language = savedLanguage;
    } else {
      // Support the previous Sindhi/English setting.
      _language = prefs.getBool(_legacySindhiKey) == true
          ? 'sd'
          : 'en';
    }

    voiceLang = prefs.getString(_voiceLanguageKey) ?? 'auto';

    final backupValue = prefs.getString(_lastBackupKey);
    lastBackup = backupValue == null
        ? null
        : DateTime.tryParse(backupValue);

    notifyListeners();
  }

  /// Change the app language and save the selection.
  Future<void> setLanguage(String value) async {
    if (!['en', 'sd', 'ur'].contains(value)) {
      return;
    }

    if (_language == value) return;

    _language = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_languageKey, value);

    // Keep the old preference key compatible.
    await prefs.setBool(_legacySindhiKey, value == 'sd');

    notifyListeners();
  }

  /// Retained for compatibility with the old language toggle.
  Future<void> toggleLanguage() async {
    await setLanguage(_language == 'sd' ? 'en' : 'sd');
  }

  /// Translate a label using English, Sindhi, and Urdu.
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

  /// Save the preferred voice recognition language.
  Future<void> setVoiceLang(String value) async {
    voiceLang = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_voiceLanguageKey, value);

    notifyListeners();
  }

  /// Save the current time as the most recent backup.
  Future<void> markBackup() async {
    lastBackup = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastBackupKey,
      lastBackup!.toIso8601String(),
    );

    notifyListeners();
  }

  /// Direction for English versus Sindhi/Urdu.
  TextDirection get direction {
    return _language == 'en'
        ? TextDirection.ltr
        : TextDirection.rtl;
  }

  /// Locale used by MaterialApp.
  Locale get locale => Locale(_language);
}
