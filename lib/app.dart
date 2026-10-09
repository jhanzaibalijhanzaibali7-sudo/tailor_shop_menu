import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'settings.dart';
import 'welcome_page.dart';
import 'signup_page.dart';

/// Makes AppSettings available to all pages in the app.
class AppScope extends InheritedNotifier<AppSettings> {
  const AppScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();

    assert(scope != null, 'AppScope was not found in the widget tree.');

    return scope!.notifier!;
  }
}

class TailorApp extends StatelessWidget {
  final AppSettings settings;

  const TailorApp({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      child: AnimatedBuilder(
        animation: settings,
        builder: (context, child) {
          return MaterialApp(
            title: 'Tailor Shop',
            debugShowCheckedModeBanner: false,

            // Temporary diagnostic test: keep Flutter's built-in locale English.
            locale: const Locale('en'),

            supportedLocales: const [
              Locale('en'),
              Locale('sd'),
              Locale('ur'),
            ],

            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFF5EDE3),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6B4F3A),
                primary: const Color(0xFF6B4F3A),
                secondary: const Color(0xFF8D6E63),
                surface: const Color(0xFFF5EDE3),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFF5EDE3),
                foregroundColor: Color(0xFF4E342E),
                centerTitle: true,
              ),
            ),

            builder: (context, child) {
              return Directionality(
                textDirection: settings.direction,
                child: child ?? const SizedBox.shrink(),
              );
            },

            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5EDE3),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6B4F3A),
              ),
            ),
          );
        }

        if (snapshot.data != null) {
          return const WelcomePage();
        }

        return const SignupPage();
      },
    );
  }
}
