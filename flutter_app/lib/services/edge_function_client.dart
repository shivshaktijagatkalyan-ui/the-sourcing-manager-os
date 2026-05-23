import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';

class EdgeFunctionClient {
  EdgeFunctionClient({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  Future<Map<String, dynamic>> invokeMap(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw StateError('Supabase is not configured');
    }

    final response = await _resolvedClient.functions.invoke(
      functionName,
      body: body ?? const <String, dynamic>{},
    );
    final data = response.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{'data': data};
  }
}
