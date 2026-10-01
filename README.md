# Tailor Shop Manager v4 (Sindhi / English)

Offline-first Flutter app: customers, measurements (with measurement-book photo),
orders, payments, reports, backup/restore and Sindhi / Roman Sindhi voice commands.

## First-time setup

The zip you sent contained only `lib/` and `pubspec.yaml`, so the `android/` and
`ios/` folders must be generated once:

```
cd tailor_shop_manager
flutter create . --project-name tailor_shop_manager --org com.example.tailor
flutter pub get
flutter analyze
flutter test
flutter run
```

Then add the platform permissions: run `dart run tool/apply_platform_config.dart`
(adds the entries below; safe to run twice) or add them by hand.

### Android – `android/app/src/main/AndroidManifest.xml`

Inside `<manifest>` (before `<application>`):

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>
<queries>
  <intent><action android:name="android.speech.RecognitionService"/></intent>
  <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>
</queries>
```

In `android/app/build.gradle(.kts)` set `minSdk = 24` (speech_to_text needs 21+, 24 is safe).

### iOS – `ios/Runner/Info.plist`

```xml
<key>NSMicrophoneUsageDescription</key><string>Voice search and voice commands</string>
<key>NSSpeechRecognitionUsageDescription</key><string>Understand spoken customer commands</string>
<key>NSCameraUsageDescription</key><string>Photograph the measurement book</string>
<key>NSPhotoLibraryUsageDescription</key><string>Choose a measurement-book photo</string>
```

## Voice commands

Say the customer name plus what you want, in Roman Sindhi, Sindhi script, Hindi/Urdu
style or English:

| Intent | Examples |
|---|---|
| Measurements | "Jahanzeb ji maap", "Jahanzeb ji maap dikha", "Ahmed ji measurement", "Ahmed ka measurement dikhao" |
| Orders | "Jahanzeb jo order kholo", "Salman jo order kholo", "Jahanzeb ka order kholo" |
| Balance | "Jahanzeb te ketro paiso baqi aa", "Salman ka kitna paisa baqi hai" |

Menu ⋮ → *Voice language* lets you force Sindhi / Urdu / Hindi / English recognition.
The default (Automatic) uses Sindhi if the phone has it, otherwise Urdu, Indian English.

## Reports

Reports → share icon exports every order as a CSV file (Excel / Google Sheets).

## Backup / restore

* Backup writes one JSON file **including the measurement photos** and opens the share sheet.
* Restore replaces all data. A safety copy is saved first (last 5 kept).
* Old v3 backups can still be restored.
* The menu shows the date of the last backup; a reminder appears after 7 days without one.
