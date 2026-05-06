import '../lib/utils/training_runtime.dart';

Future<void> main() async {
  final runtime = TrainingRuntime.instance;
  print('--- 5-POINT MANUAL SMOKE TEST (SIMULATION) ---');

  // 1. Exotel Broker Call
  print('\n[1/5] Exotel Broker Call: Target ID: ${TrainingRuntime.brokerId}');
  final brokerCall = await runtime.initiateCall(TrainingRuntime.brokerId, type: 'broker');
  print('Result: ${brokerCall['ok'] == true ? "PASS (Queued)" : "FAIL"}');

  // 2. Exotel Lead Call
  print('\n[2/5] Exotel Lead Call: Target ID: lead_998');
  final leadCall = await runtime.initiateCall('lead_998', type: 'lead');
  print('Result: ${leadCall['ok'] == true ? "PASS (Queued)" : "FAIL"}');

  // 3. GPS Verification
  print('\n[3/5] GPS Verification: Visit ID lookup...');
  runtime.scheduleSiteVisitFromLead('lead_998');
  final visits = runtime.siteVisitsForManager(TrainingRuntime.sourcingManagerId);
  final visitId = visits.first['id'] as String;
  
  print('Visit ID found: $visitId');
  await runtime.startSiteVisit(visitId);
  final gps = await runtime.verifySiteGps(visitId, 18.9894, 73.1175);
  print('Result: ${gps == true ? "PASS (Verified)" : "FAIL"}');

  // 4. Camera Photo
  print('\n[4/5] Camera Photo: Visit ID: $visitId');
  final photo = await runtime.uploadSitePhoto(visitId);
  print('Result: ${photo == true ? "PASS (Uploaded)" : "FAIL"}');

  // 5. Broker Lock
  print('\n[5/5] Broker Lock: Visit ID: $visitId');
  final lock = await runtime.brokerReviewSiteVisit(visitId, 'approve');
  print('Result: ${lock == true ? "PASS (Approved & Locked)" : "FAIL"}');
  
  final broker = runtime.brokerById(TrainingRuntime.brokerId);
  print('Final Broker: ${broker['company_name']}');
}
