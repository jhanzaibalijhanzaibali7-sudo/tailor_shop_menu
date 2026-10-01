import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/db.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  final settings = AppSettings();
  await settings.load();

  try {
    await DB.instance.init();
  } catch (e, st) {
    debugPrint('Database failed to open: $e\n$st');
    runApp(StartupErrorApp(error: e.toString()));
    return;
  }

  runApp(TailorApp(settings: settings));
}
