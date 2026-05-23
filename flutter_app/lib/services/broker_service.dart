import 'edge_function_client.dart';

class BrokerService {
  BrokerService({EdgeFunctionClient? edgeFunctions})
      : _edgeFunctions = edgeFunctions ?? EdgeFunctionClient();

  final EdgeFunctionClient _edgeFunctions;

  Future<Map<String, dynamic>> updateVaultWorkflow({
    required Map<String, dynamic> payload,
  }) {
    return _edgeFunctions.invokeMap('broker-vault-workflow', body: payload);
  }

  Future<Map<String, dynamic>> proposeSiteVisit({
    required Map<String, dynamic> payload,
  }) {
    return _edgeFunctions.invokeMap('propose-site-visit', body: payload);
  }
}
