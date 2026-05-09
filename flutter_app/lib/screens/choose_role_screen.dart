import 'package:flutter/material.dart';
import 'caller_signup_screen.dart';
import 'sourcing_manager_signup_screen.dart';
import 'broker_signup_screen.dart';

class ChooseRoleScreen extends StatelessWidget {
  final VoidCallback? onAuthStateChanged;

  const ChooseRoleScreen({super.key, this.onAuthStateChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Choose Your Role'),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.people_outline,
                size: 80, color: Color(0xFFF5B545)),
            const SizedBox(height: 32),
            const Text(
              'Select Your Role in the Sourcing Manager OS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose the role that best describes your function',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 48),
            _RoleCard(
              title: 'I am Sourcing Manager',
              subtitle: 'Manage brokers, leads, and site visits',
              icon: Icons.business_center_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => SourcingManagerSignupScreen(
                          onAuthStateChanged: onAuthStateChanged,
                        )),
              ),
            ),
            const SizedBox(height: 16),
            _RoleCard(
              title: 'I am Broker',
              subtitle: 'Submit leads and track performance',
              icon: Icons.handshake_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => BrokerSignupScreen(
                          onAuthStateChanged: onAuthStateChanged,
                        )),
              ),
            ),
            const SizedBox(height: 16),
            _RoleCard(
              title: 'I am Caller',
              subtitle: 'Requires invite code or access request',
              icon: Icons.headset_mic_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => CallerSignupScreen(
                          onAuthStateChanged: onAuthStateChanged,
                        )),
              ),
            ),
            const SizedBox(height: 16),
            _RoleCard(
              title: 'I am Admin / Developer',
              subtitle: 'Restricted to platform administrators',
              icon: Icons.admin_panel_settings_outlined,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Admin access can only be granted by existing administrators.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF18212F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 32, color: const Color(0xFFF5B545)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
