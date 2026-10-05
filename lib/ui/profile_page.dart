import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final name = user?.displayName ?? 'No Name';
    final email = user?.email ?? 'No Gmail';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F1E7),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF6D4228),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            CircleAvatar(
              radius: 55,
              backgroundColor: const Color(0xFF7A4A2A),
              child: const Icon(
                Icons.person,
                size: 60,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6D4228),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              email,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.brown.shade500,
              ),
            ),

            const SizedBox(height: 35),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: Color(0xFF7A4A2A),
                ),
                title: const Text(
                  'Full Name',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(name),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF7A4A2A),
                ),
                title: const Text(
                  'Gmail',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(email),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
