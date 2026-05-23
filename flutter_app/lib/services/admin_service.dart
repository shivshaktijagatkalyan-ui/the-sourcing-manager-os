import 'edge_function_client.dart';

class AdminService {
  AdminService({EdgeFunctionClient? edgeFunctions})
      : _edgeFunctions = edgeFunctions ?? EdgeFunctionClient();

  final EdgeFunctionClient _edgeFunctions;

  Future<Map<String, dynamic>> fetchDashboard() {
    return _edgeFunctions.invokeMap('super-admin-dashboard');
  }

  Future<Map<String, dynamic>> completeOnboarding({
    required Map<String, dynamic> payload,
  }) {
    return _edgeFunctions.invokeMap('complete-onboarding', body: payload);
  }
}
