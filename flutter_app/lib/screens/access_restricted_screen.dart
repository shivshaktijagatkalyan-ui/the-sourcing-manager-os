import 'package:flutter/material.dart';

class AccessRestrictedScreen extends StatelessWidget {
  final String role;
  const AccessRestrictedScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_outlined, size: 80, color: Colors.orangeAccent),
              const SizedBox(height: 24),
              Text(
                'ACCESS RESTRICTED',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'ROLE: ${role.replaceAll('_', ' ').toUpperCase()}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Aapke account ke liye koi dashboard assign nahi kiya gaya hai.\n\nSourcing Manager application ka access lene ke liye kripya apne administrator se sampark karein.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 48),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.logout),
                label: const Text('LOGOUT & RETRY'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
