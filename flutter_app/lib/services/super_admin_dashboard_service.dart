import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/super_admin_snapshot.dart';

typedef SuperAdminDashboardInvoke = Future<dynamic> Function();

class SuperAdminDashboardException implements Exception {
  final String reason;

  const SuperAdminDashboardException(this.reason);

  @override
  String toString() => 'SuperAdminDashboardException($reason)';
}

class SuperAdminDashboardFunctionFailure implements Exception {
  final dynamic details;

  const SuperAdminDashboardFunctionFailure(this.details);
}

class SuperAdminDashboardService {
  final SuperAdminDashboardInvoke _invoke;

  SuperAdminDashboardService({SupabaseClient? client})
      : _invoke = (() async {
          final resolvedClient = client ?? Supabase.instance.client;
          final response =
              await resolvedClient.functions.invoke('super-admin-dashboard');
          return response.data;
        });

  SuperAdminDashboardService.withInvoker(this._invoke);

  Future<SuperAdminDashboardSnapshot> loadSnapshot() async {
    final dynamic data;
    try {
      data = await _invoke();
    } on SuperAdminDashboardException {
      rethrow;
    } catch (error) {
      throw SuperAdminDashboardException(
        _reasonFromThrown(error) ?? 'dashboard_read_failed',
      );
    }

    final body = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : null;

    if (body == null) {
      throw const SuperAdminDashboardException('dashboard_unavailable');
    }
    if (body['ok'] != true) {
      throw SuperAdminDashboardException(
        _reasonFromBody(body) ?? 'dashboard_unavailable',
      );
    }

    return SuperAdminDashboardSnapshot.fromJson(body);
  }

  String? _reasonFromThrown(Object error) {
    if (error is FunctionException) {
      return _reasonFromDetails(error.details);
    }
    if (error is SuperAdminDashboardFunctionFailure) {
      return _reasonFromDetails(error.details);
    }
    return null;
  }

  String? _reasonFromDetails(dynamic details) {
    final body = details is Map<String, dynamic>
        ? details
        : details is Map
            ? Map<String, dynamic>.from(details)
            : null;
    if (body == null) return null;
    return _reasonFromBody(body);
  }

  String? _reasonFromBody(Map<String, dynamic> body) {
    final reason = body['reason']?.toString().trim();
    return reason == null || reason.isEmpty ? null : reason;
  }
}
