
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'settings.dart';
import 'welcome_page.dart';
import 'signup_page.dart';
import 'data/db.dart';

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

            // Keeping the existing temporary English diagnostic setting.
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

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _initializingUid;
  Future<void>? _databaseFuture;

  Future<void> _initializeDatabase(String uid) {
    if (_initializingUid == uid && _databaseFuture != null) {
      return _databaseFuture!;
    }

    _initializingUid = uid;
    _databaseFuture = DB.instance.init(userId: uid);

    return _databaseFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = snapshot.data;

        if (user == null) {
          return const SignupPage();
        }

        return FutureBuilder<void>(
          future: _initializeDatabase(user.uid),
          builder: (context, databaseSnapshot) {
            if (databaseSnapshot.connectionState !=
                ConnectionState.done) {
              return const _LoadingScreen();
            }

            if (databaseSnapshot.hasError) {
              return Scaffold(
                backgroundColor: const Color(0xFFF5EDE3),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.storage_rounded,
                          size: 48,
                          color: Color(0xFF6B4F3A),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Database could not be opened.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4E342E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please retry. Your existing data has not '
                          'been intentionally deleted.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _initializingUid = null;
                              _databaseFuture = null;
                            });
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return const WelcomePage();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5EDE3),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6B4F3A),
        ),
      ),
    );
  }
}
