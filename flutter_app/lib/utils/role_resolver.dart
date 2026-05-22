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

  static const Map<String, String> _trainingLoginRolesByEmail = {
    'jitu.broker.uat@sourcing-manager-os.test': 'broker_owner',
    'antigravity.test@gmail.com': 'broker_owner',
    'vinod.sourcing-manager@sourcing-manager-os.test': 'sourcing_manager',
    'shivshaktijagatkalyan@gmail.com': 'sourcing_manager',
    'rahul.caller.uat@sourcing-manager-os.test': 'caller',
    'rahul.caller@example.com': 'caller',
  };

  static String roleForTrainingLoginEmail(String email) {
    final normalized = email.trim().toLowerCase();
    final exactRole = _trainingLoginRolesByEmail[normalized];
    if (exactRole != null) return exactRole;

    if (normalized.contains('broker')) return 'broker_owner';
    if (normalized.contains('caller')) return 'caller';
    if (normalized.contains('admin')) return 'platform_admin';

    return AppConfig.mockRole.isNotEmpty
        ? AppConfig.mockRole
        : 'sourcing_manager';
  }

  static String _localRole() {
    if (!AppConfig.allowsTrainingMode) return 'anonymous';

    final override = Uri.base.queryParameters['mockRole']?.trim();
    if (override != null && _localTestRoles.contains(override)) {
      if (override == 'anonymous' &&
          AppConfig.mockRole.isNotEmpty &&
          AppConfig.mockRole != 'anonymous') {
        return AppConfig.mockRole;
      }
      return override;
    }
    if (AppConfig.isTrainingMode) {
      return AppConfig.mockRole.isNotEmpty
          ? AppConfig.mockRole
          : 'sourcing_manager';
    }
    return 'anonymous';
  }

  static Future<String> currentRole({
    SupabaseClient? client,
    bool? isSupabaseConfigured,
  }) async {
    final supabaseConfigured =
        isSupabaseConfigured ?? AppConfig.isSupabaseConfigured;

    if (AppConfig.isTrainingMode || !supabaseConfigured) {
      return _localRole();
    }

    final supabase = client ?? Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return 'anonymous';

    try {
      final assignment = await supabase
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
      final pilot = await supabase
          .from('pilot_users')
          .select('role, status')
          .eq('user_id', user.id)
          .maybeSingle();

      final role = pilot?['role'];
      final status = pilot?['status'];

      // Explicit status gates — never fall through to 'unknown'
      if (status == 'suspended') return 'suspended';
      if (status == 'pending') return 'pending';

      if (status == 'active' && role is String && role.isNotEmpty) {
        return role;
      }
    } catch (_) {
      return 'unknown';
    }

    return 'unknown';
  }
}
