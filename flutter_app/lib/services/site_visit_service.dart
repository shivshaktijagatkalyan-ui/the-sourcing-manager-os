import 'edge_function_client.dart';

class SiteVisitService {
  SiteVisitService({EdgeFunctionClient? edgeFunctions})
      : _edgeFunctions = edgeFunctions ?? EdgeFunctionClient();

  final EdgeFunctionClient _edgeFunctions;

  Future<Map<String, dynamic>> verifyGps({
    required String siteVisitId,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) {
    return _edgeFunctions.invokeMap(
      'verify-site-gps',
      body: <String, dynamic>{
        'site_visit_id': siteVisitId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_meters': accuracyMeters,
      },
    );
  }

  Future<Map<String, dynamic>> verifyProof({
    required Map<String, dynamic> payload,
  }) {
    return _edgeFunctions.invokeMap('verify-site-visit-proof', body: payload);
  }
}
