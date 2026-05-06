import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';

class RoleResolver {
  static const Set<String> adminRoles = {
    'admin',
    'platform_admin',
    'developer_admin',
  };

  static const Set<String> brokerRoles = {
    'broker',
    'broker_owner',
    'broker_agent',
  };

  static bool isAdminRole(String role) => adminRoles.contains(role);

  static bool isBrokerRole(String role) => brokerRoles.contains(role);

  static bool isSourcingRole(String role) => role == 'sourcing_manager';

  static bool isCallerRole(String role) => role == 'caller';

  static const Set<String> _localTestRoles = {
    'sourcing_manager',
    'broker',
    'broker_owner',
    'broker_agent',
    'caller',
    'admin',
    'platform_admin',
    'developer_admin',
    'unknown',
    'anonymous',
  };

  static String _localRole() {
    final override = Uri.base.queryParameters['mockRole']?.trim();
    if (override != null && _localTestRoles.contains(override)) {
      return override;
    }
    return AppConfig.isTrainingMode ? AppConfig.mockRole : 'anonymous';
  }

  static Future<String> currentRole() async {
    if (!AppConfig.isSupabaseConfigured) {
      return _localRole();
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return 'anonymous';

    try {
      final assignment = await client
          .from('role_assignments')
          .select('role_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .maybeSingle();

      final roleId = assignment?['role_id'];
      if (roleId is String && roleId.isNotEmpty) return roleId;
    } catch (_) {
      // Fall back to the legacy pilot_users role below.
    }

    try {
      final pilot = await client
          .from('pilot_users')
          .select('role, status')
          .eq('user_id', user.id)
          .maybeSingle();

      final role = pilot?['role'];
      final status = pilot?['status'];
      if (status == 'active' && role is String && role.isNotEmpty) {
        return role;
      }
    } catch (_) {
      return 'unknown';
    }

    return 'unknown';
  }
}
