import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'settings.dart';
import 'ui/home_page.dart';

class TailorApp extends StatelessWidget {
  final AppSettings settings;
  const TailorApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Tailor Shop',
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
          // Flutter's built-in widget translations (date picker, tooltips,
          // back button ...) do not include Sindhi, so Urdu - the closest
          // right-to-left Arabic-script locale - is used for those. All app
          // text itself is Sindhi.
          locale: Locale(settings.sindhi ? 'ur' : 'en'),
          supportedLocales: const [Locale('en'), Locale('ur')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Applies RTL to every route, dialog and bottom sheet.
          builder: (context, child) => Directionality(
            textDirection: settings.direction,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const HomePage(),
        ),
      ),
    );
  }
}

/// Shown instead of the app when the database cannot be opened.
class StartupErrorApp extends StatelessWidget {
  final String error;
  const StartupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'The database could not be opened.\nڊيٽابيس کولي نه سگهيو.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 12),
                Text(error, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
