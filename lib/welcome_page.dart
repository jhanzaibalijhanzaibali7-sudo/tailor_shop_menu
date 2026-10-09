
import 'package:flutter/material.dart';
import 'app.dart';
import 'ui/home_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5EDE3),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'logo.png',
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 25),
                Text(
                  settings.t(
                    'Welcome to Max Tailor',
                    'ميڪس درزي ۾ ڀليڪار',
                    'میکس ٹیلر میں خوش آمدید',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4E342E),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  settings.t(
                    'Manage your tailor shop easily',
                    'پنهنجي درزي جي دڪان کي آساني سان سنڀاليو',
                    'اپنی درزی کی دکان آسانی سے سنبھالیں',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B4F3A),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B4F3A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HomePage(),
                        ),
                      );
                    },
                    child: Text(
                      settings.t(
                        'Get Started',
                        'شروع ڪريو',
                        'شروع کریں',
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
