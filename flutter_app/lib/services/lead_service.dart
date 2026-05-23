import 'edge_function_client.dart';

class LeadService {
  LeadService({EdgeFunctionClient? edgeFunctions})
      : _edgeFunctions = edgeFunctions ?? EdgeFunctionClient();

  final EdgeFunctionClient _edgeFunctions;

  Future<Map<String, dynamic>> uploadBrokerLead({
    required Map<String, dynamic> payload,
  }) {
    return _edgeFunctions.invokeMap('broker-upload-lead', body: payload);
  }

  Future<Map<String, dynamic>> createLeadFromBroker({
    required Map<String, dynamic> payload,
  }) {
    return _edgeFunctions.invokeMap('lead-from-broker', body: payload);
  }
}
