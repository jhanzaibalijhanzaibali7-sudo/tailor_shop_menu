// Adds the Android / iOS permissions this app needs to the folders created by
// `flutter create .`. Safe to run more than once (it skips what is present).
//
//   dart run tool/apply_platform_config.dart
import 'dart:io';

const _androidPermissions = <String>[
  'android.permission.RECORD_AUDIO',
  'android.permission.INTERNET',
  'android.permission.CAMERA',
];

const _iosKeys = <String, String>{
  'NSMicrophoneUsageDescription': 'Voice search and voice commands',
  'NSSpeechRecognitionUsageDescription': 'Understand spoken customer commands',
  'NSCameraUsageDescription': 'Photograph the measurement book',
  'NSPhotoLibraryUsageDescription': 'Choose a measurement-book photo',
};

const _speechIntent = '''
      <intent>
        <action android:name="android.speech.RecognitionService"/>
      </intent>
''';

void main() {
  var found = false;
  found |= _patchManifest();
  found |= _patchGradle();
  found |= _patchInfoPlist();
  if (!found) {
    stderr.writeln('No android/ or ios/ folder found. Run "flutter create ." '
        'in the project folder first, then run this script again.');
    exit(1);
  }
  stdout.writeln('Done.');
}

bool _patchManifest() {
  final file = File('android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) return false;
  var m = file.readAsStringSync();
  final before = m;

  final add = StringBuffer();
  for (final perm in _androidPermissions) {
    if (!m.contains(perm)) {
      add.writeln('    <uses-permission android:name="$perm"/>');
    }
  }
  if (!m.contains('android.hardware.camera')) {
    add.writeln('    <uses-feature android:name="android.hardware.camera" '
        'android:required="false"/>');
  }
  if (!m.contains('android.speech.RecognitionService')) {
    if (m.contains('</queries>')) {
      m = m.replaceFirst('</queries>', '$_speechIntent    </queries>');
    } else {
      add.writeln('    <queries>');
      add.write(_speechIntent);
      add.writeln('    </queries>');
    }
  }
  if (add.isNotEmpty) {
    if (!m.contains('<application')) {
      stderr.writeln('AndroidManifest.xml: <application> not found, skipped.');
      return true;
    }
    m = m.replaceFirst('<application', '${add}    <application');
  }
  if (m != before) {
    file.writeAsStringSync(m);
    stdout.writeln('Updated AndroidManifest.xml');
  } else {
    stdout.writeln('AndroidManifest.xml already OK');
  }
  return true;
}

bool _patchGradle() {
  final candidates = [
    File('android/app/build.gradle.kts'),
    File('android/app/build.gradle'),
  ];
  for (final file in candidates) {
    if (!file.existsSync()) continue;
    final text = file.readAsStringSync();
    final pattern = RegExp(r'minSdk(Version)?\s*=?\s*flutter\.minSdkVersion');
    if (!pattern.hasMatch(text)) {
      stdout.writeln('${file.path}: minSdk is not "flutter.minSdkVersion" - '
          'make sure it is at least 24.');
      return true;
    }
    final updated = text.replaceAllMapped(pattern, (match) {
      final whole = match.group(0)!;
      if (whole.contains('=')) return 'minSdk = 24';
      return match.group(1) == null ? 'minSdk 24' : 'minSdkVersion 24';
    });
    file.writeAsStringSync(updated);
    stdout.writeln('Updated ${file.path} (minSdk 24)');
    return true;
  }
  return false;
}

bool _patchInfoPlist() {
  final file = File('ios/Runner/Info.plist');
  if (!file.existsSync()) return false;
  var plist = file.readAsStringSync();
  final add = StringBuffer();
  _iosKeys.forEach((key, text) {
    if (!plist.contains('<key>$key</key>')) {
      add.writeln('\t<key>$key</key>');
      add.writeln('\t<string>$text</string>');
    }
  });
  if (add.isEmpty) {
    stdout.writeln('Info.plist already OK');
    return true;
  }
  final end = plist.lastIndexOf('</dict>');
  if (end < 0) {
    stderr.writeln('Info.plist: closing </dict> not found, skipped.');
    return true;
  }
  plist = plist.substring(0, end) + add.toString() + plist.substring(end);
  file.writeAsStringSync(plist);
  stdout.writeln('Updated Info.plist');
  return true;
}
