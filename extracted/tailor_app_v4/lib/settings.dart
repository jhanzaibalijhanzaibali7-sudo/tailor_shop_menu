import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide settings (UI language + voice recognition language).
///
/// Persisted with shared_preferences. The old `sindhi` key from v3 is reused,
/// so users keep their language choice after updating.
class AppSettings extends ChangeNotifier {
  bool sindhi = false;

  /// One of: auto, sd, ur, hi, en
  String voiceLang = 'auto';

  /// When a backup was last shared/saved by the user (null = never).
  DateTime? lastBackup;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    sindhi = prefs.getBool('sindhi') ?? false;
    voiceLang = prefs.getString('voice_lang') ?? 'auto';
    final raw = prefs.getString('last_backup');
    lastBackup = raw == null ? null : DateTime.tryParse(raw);
  }

  /// True when there was no backup yet or the last one is over a week old.
  bool get backupOverdue {
    final last = lastBackup;
    return last == null || DateTime.now().difference(last).inDays >= 7;
  }

  Future<void> markBackup() async {
    lastBackup = DateTime.now();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_backup', lastBackup!.toIso8601String());
  }

  Future<void> toggleLanguage() async {
    sindhi = !sindhi;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sindhi', sindhi);
  }

  Future<void> setVoiceLang(String value) async {
    voiceLang = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voice_lang', value);
  }

  /// Pick the English or Sindhi text depending on the current language.
  String t(String en, String sd) => sindhi ? sd : en;

  TextDirection get direction => sindhi ? TextDirection.rtl : TextDirection.ltr;
}

/// Makes [AppSettings] available to the whole widget tree (including dialogs
/// and bottom sheets, which live under the Navigator).
class AppScope extends InheritedNotifier<AppSettings> {
  const AppScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }
}
