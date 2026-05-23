import 'edge_function_client.dart';

class CallerService {
  CallerService({EdgeFunctionClient? edgeFunctions})
      : _edgeFunctions = edgeFunctions ?? EdgeFunctionClient();

  final EdgeFunctionClient _edgeFunctions;

  Future<Map<String, dynamic>> initiateSecureCall({
    required String leadId,
    String? dataLoanId,
  }) {
    return _edgeFunctions.invokeMap(
      'initiate-call',
      body: <String, dynamic>{
        'lead_id': leadId,
        if (dataLoanId != null) 'data_loan_id': dataLoanId,
      },
    );
  }

  Future<Map<String, dynamic>> updateWorkflow({
    required Map<String, dynamic> payload,
  }) {
    return _edgeFunctions.invokeMap('manage-caller-workflow', body: payload);
  }
}
