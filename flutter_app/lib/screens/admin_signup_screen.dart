import 'package:flutter/material.dart';

class AdminSignupScreen extends StatelessWidget {
  const AdminSignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Admin Signup'),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings_outlined, size: 80, color: Colors.redAccent),
            const SizedBox(height: 32),
            const Text(
              'Admin Access Restricted',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Open admin signup is not allowed for security reasons. Please contact the system administrator to request access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                // In a real app, this could open an email client or show contact info
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please contact support@smos.com for admin access')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5B545),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('REQUEST ACCESS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Role Selection', style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }
}