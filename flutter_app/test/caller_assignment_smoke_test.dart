import 'dart:convert';
import '../lib/utils/training_runtime.dart';

void main() async {
  final runtime = TrainingRuntime.instance;
  print('--- SMOKE TEST: CALLER ASSIGNMENT & SECURE CALL ---');

  // Step 1: Assignment (Sourcing Manager Action)
  print('\n[1/3] Action: Assign Lead L-998 (lead_998) to Caller Rahul (user_rahul)');
  final assigned = runtime.assignLeadToCaller('lead_998', TrainingRuntime.callerRahulId);
  print('Assignment Result: ${assigned ? "SUCCESS" : "FAIL"}');

  // Verify Data Loan
  final leads = runtime.callerAssignedLeads(TrainingRuntime.callerRahulId);
  final isAssigned = leads.any((l) => l['id'] == 'lead_998');
  print('Verification: Lead in Caller Queue? ${isAssigned ? "YES" : "NO"}');

  // Step 2: Secure Call (Caller Action)
  print('\n[2/3] Action: Caller Rahul initiates Secure Call to L-998');
  final callResult = await runtime.initiateCall('lead_998', type: 'lead');
  print('Network Payload (JSON): ${jsonEncode(callResult)}');

  // Verification Check (The Constitutional Rule)
  final hasPii = jsonEncode(callResult).contains('+91') || jsonEncode(callResult).contains('9876543210');
  print('Constitutional Check: PII in Payload? ${hasPii ? "FAIL (PII EXPOSED)" : "PASS (CLEAN)"}');

  // Step 3: Audit Verification
  print('\n[3/3] Action: Verifying audit events for secure logging');
  final noPiiInAudit = runtime.auditHasNoPii();
  print('Audit Log Security: PII in Audit? ${!noPiiInAudit ? "FAIL" : "PASS (DATALESS)"}');
}
