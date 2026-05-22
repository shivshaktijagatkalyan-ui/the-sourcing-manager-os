import 'package:flutter/material.dart';
import 'admin_signup_screen.dart';
import 'caller_signup_screen.dart';
import 'sourcing_manager_signup_screen.dart';
import 'broker_signup_screen.dart';
import 'executive_onboarding_screen.dart';
import '../utils/premium_ui.dart';
import '../utils/auth_service.dart';

class ChooseRoleScreen extends StatefulWidget {
  final VoidCallback? onAuthStateChanged;

  const ChooseRoleScreen({super.key, this.onAuthStateChanged});

  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends State<ChooseRoleScreen> {
  final bool _isProcessing = false;

  Future<void> _serverOnboard(String role) async {
    final client = AuthService().clientOrNull;
    final user = client?.auth.currentUser;

    if (client == null || user == null) {
      _navigateToSignup(role);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExecutiveOnboardingScreen(
          initialRole: role,
          onAuthStateChanged: widget.onAuthStateChanged,
        ),
      ),
    );
  }

  void _navigateToSignup(String role) {
    final onAuthStateChanged = widget.onAuthStateChanged;
    Widget screen;
    if (role == 'sourcing_manager') {
      screen = SourcingManagerSignupScreen(onAuthStateChanged: onAuthStateChanged);
    } else if (role.contains('broker')) {
      screen = BrokerSignupScreen(onAuthStateChanged: onAuthStateChanged);
    } else if (role == 'admin' || role == 'developer_admin') {
      screen = const AdminSignupScreen();
    } else {
      screen = CallerSignupScreen(onAuthStateChanged: onAuthStateChanged);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumUI.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white54),
      ),
      body: Stack(
        children: [
          Container(
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  PremiumUI.primary.withValues(alpha: 0.1),
                  PremiumUI.background,
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.people_alt_outlined, size: 64, color: PremiumUI.primary),
                  const SizedBox(height: 24),
                  Text(
                    'SECURE ONBOARDING',
                    textAlign: TextAlign.center,
                    style: PremiumUI.h1.copyWith(fontSize: 24, letterSpacing: 3),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select your role to start using Sourcing Manager OS',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 48),
                  _buildRoleCard(
                    context,
                    title: 'I am Sourcing Manager',
                    subtitle: 'Manage brokers, leads & payouts',
                    icon: Icons.business_center_outlined,
                    color: PremiumUI.primary,
                    onTap: () => _serverOnboard('sourcing_manager'),
                  ),
                  const SizedBox(height: 16),
                  _buildRoleCard(
                    context,
                    title: 'I am Broker',
                    subtitle: 'Upload leads & track commissions',
                    icon: Icons.handshake_outlined,
                    color: PremiumUI.secondary,
                    onTap: () => _serverOnboard('broker_owner'),
                  ),
                  const SizedBox(height: 16),
                  _buildRoleCard(
                    context,
                    title: 'I am Caller',
                    subtitle: 'Work assigned call queues by invite only',
                    icon: Icons.support_agent_outlined,
                    color: PremiumUI.accent,
                    onTap: () => _navigateToSignup('caller'),
                  ),
                  const SizedBox(height: 16),
                  _buildRoleCard(
                    context,
                    title: 'I am Admin / Developer',
                    subtitle: 'Request restricted administrative access',
                    icon: Icons.admin_panel_settings_outlined,
                    color: PremiumUI.danger,
                    onTap: () => _navigateToSignup('admin'),
                  ),
                  const SizedBox(height: 32),
                  PremiumUI.glassCard(
                    color: Colors.white10,
                    child: Row(
                      children: [
                        const Icon(Icons.security_outlined, color: Colors.white38, size: 20),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Your Google identity will be used for secure access. No extra passwords needed.',
                            style: PremiumUI.subtitle.copyWith(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: PremiumUI.primary),
                    SizedBox(height: 24),
                    Text('Provisioning Secure Environment...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}
