import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

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

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully.');
  } catch (e, st) {
    debugPrint('Firebase initialization failed: $e\n$st');
  }

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

/// Displays a readable message if the local database cannot initialize.
class StartupErrorApp extends StatelessWidget {
  final String error;

  const StartupErrorApp({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tailor Shop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5EDE3),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4F3A),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Tailor Shop'),
          centerTitle: true,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Color(0xFF6B4F3A),
                ),
                const SizedBox(height: 16),
                const Text(
                  'App could not start',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'The local database could not be initialized.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SelectableText(
                  error,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
