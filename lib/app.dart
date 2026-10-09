
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'settings.dart';
import 'ui/welcome_page.dart';
import 'ui/signup_page.dart';

class TailorApp extends StatelessWidget {
  final AppSettings settings;

  const TailorApp({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, child) {
        return MaterialApp(
          title: 'Tailor Shop',
          debugShowCheckedModeBanner: false,

          // Selected language: English, Sindhi, or Urdu.
          locale: settings.locale,

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

          // Preserve the brown and cream app theme.
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor:
                const Color(0xFFF5EDE3),
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

          // English uses LTR; Sindhi and Urdu use RTL.
          builder: (context, child) {
            return Directionality(
              textDirection: settings.direction,
              child: child ?? const SizedBox.shrink(),
            );
          },

          home: const AuthGate(),
        );
      },
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
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
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
