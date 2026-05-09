import 'package:flutter/material.dart';
import 'sourcing_manager_dashboard.dart';
import 'caller_dashboard_screen.dart';
import 'broker_dashboard_screen.dart';
import 'access_restricted_screen.dart';
import 'super_admin_dashboard.dart';
import 'login_screen.dart';
import '../utils/role_resolver.dart';

class RoleDashboardContainer extends StatefulWidget {
  const RoleDashboardContainer({super.key});

  @override
  State<RoleDashboardContainer> createState() => _RoleDashboardContainerState();
}

class _RoleDashboardContainerState extends State<RoleDashboardContainer> {
  String _role = 'loading';

  @override
  void initState() {
    super.initState();
    _fetchRole();
  }

  Future<void> _fetchRole() async {
    try {
      final role = await RoleResolver.currentRole();
      if (!mounted) return;
      setState(() => _role = role);
    } catch (e) {
      if (!mounted) return;
      setState(() => _role = 'unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_role == 'loading') {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    switch (_role) {
      case 'caller':
        return const CallerDashboardScreen();
      case 'broker_agent':
      case 'broker_owner':
      case 'broker':
        return const BrokerDashboardScreen();
      case 'sourcing_manager':
        return const SourcingManagerDashboard();
      case 'developer_admin':
      case 'platform_admin':
      case 'admin':
        return const SuperAdminDashboard();
      case 'anonymous':
        return LoginScreen(onAuthStateChanged: _fetchRole);
      default:
        return AccessRestrictedScreen(role: _role);
    }
  }
}
