import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sourcing_manager_os/screens/broker_upload.dart';
import 'package:sourcing_manager_os/utils/training_runtime.dart';

void main() {
  test(
      'broker dashboard exposes premium vault sections without sensitive tables',
      () {
    final source =
        File('lib/screens/broker_dashboard_screen.dart').readAsStringSync();

    const requiredSections = [
      'BROKER BUSINESS VAULT',
      'MY FOLLOW-UPS',
      'MY VISIT / LOCK PIPELINE',
      'MY BOOKING / BROKERAGE STATUS',
      'MY BUSINESS IMPROVEMENT TIPS',
    ];

    for (final section in requiredSections) {
      expect(source, contains(section));
    }

    expect(source, isNot(contains("from('leads_sensitive')")));
    expect(source, isNot(contains("from('brokers_sensitive')")));
    expect(source, isNot(contains('tel:')));
    expect(source, isNot(contains('wa.me')));
  });

  test('broker dashboard source does not reference raw contact fields', () {
    final source =
        File('lib/screens/broker_dashboard_screen.dart').readAsStringSync();
    final forbiddenContactFields = RegExp(
      r'\b(phone|mobile|customer_contact|phone_number|whatsapp)\b|tel:|wa\.me',
      caseSensitive: false,
    );

    expect(source, isNot(contains(forbiddenContactFields)));
  });

  test('broker dashboard data contract covers live sources and safety rules',
      () {
    final contract =
        File('../docs/architecture/broker-dashboard-data-contract.md')
            .readAsStringSync();

    for (final source in [
      'brokers_public',
      'leads_public',
      'broker_followups',
      'site_visits',
      'site_visit_proposals',
      'broker_locks',
      'data_loans',
      'broker_activity_logs',
      'broker_goals',
    ]) {
      expect(contract, contains(source));
    }

    expect(contract, contains('TrainingRuntime'));
    expect(
      contract,
      contains('AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode'),
    );
    expect(contract, contains('must not render or directly query'));
  });

  test('broker secure call sends only lead id through edge function', () {
    final source =
        File('lib/screens/broker_dashboard_screen.dart').readAsStringSync();

    expect(source, contains('functions'));
    expect(source, contains('invoke'));
    expect(source, contains("'broker-self-secure-call'"));
    expect(source, contains("'lead_id': leadId"));
    expect(source, isNot(contains("'lead_alias':")));
    expect(source, isNot(contains("'customer_contact':")));
    expect(source, isNot(contains("'contact':")));
  });

  test('broker dashboard primary intake uses broker self-upload flow', () {
    final source =
        File('lib/screens/broker_dashboard_screen.dart').readAsStringSync();

    expect(source, contains('BrokerUploadScreen'));
    expect(source, isNot(contains('const AddLeadFromBrokerScreen()')));
  });

  test('broker dashboard merges live projects with manager context', () {
    final source =
        File('lib/screens/broker_dashboard_screen.dart').readAsStringSync();

    expect(
      source,
      contains('Each live project with its connected sourcing manager'),
    );
    expect(source, contains('_buildLiveProjectManagerCard'));
    expect(source, contains(r'SM: $managerName'));
    expect(source, isNot(contains('CONNECTED SOURCING MANAGERS')));
  });

  test('broker dashboard merges visit proposal and broker lock context', () {
    final source =
        File('lib/screens/broker_dashboard_screen.dart').readAsStringSync();

    expect(source, contains('MY VISIT / LOCK PIPELINE'));
    expect(
      source,
      contains(
        'Lead, project, visit proposal, site visit, and broker lock in one flow',
      ),
    );
    expect(source, contains('_buildVisitLockPipelineCard'));
    expect(source, contains(r'Proposal: ${proposal.replaceAll'));
    expect(source, contains(r'Brokerage: ${brokerage.replaceAll'));
  });

  test('broker dashboard exposes profile completion and badge path', () {
    final dashboard =
        File('lib/screens/broker_dashboard_screen.dart').readAsStringSync();
    final card =
        File('lib/widgets/complete_profile_card.dart').readAsStringSync();
    final profile =
        File('lib/screens/profile_completion_screen.dart').readAsStringSync();

    expect(dashboard, contains('_brokerProfileMissingFields'));
    expect(dashboard, contains('missingFields: _brokerProfileMissingFields()'));
    expect(dashboard, contains('Verified Broker Badge'));
    expect(dashboard, contains('BLUE TICK READY'));
    expect(dashboard, contains('Performance Goal Path'));
    expect(card, contains('Verified Broker badge'));
    expect(card, contains('START REVIEW'));
    expect(profile, contains('Verified Broker Badge Review'));
  });

  testWidgets('broker upload requires safe lead metadata before submit',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BrokerUploadScreen()));

    await tester.ensureVisible(find.text('Encrypt and Secure Lead'));
    await tester.tap(find.text('Encrypt and Secure Lead'));
    await tester.pump();

    expect(find.text('Alias required'), findsOneWidget);
    expect(find.text('Required for one-time encrypted upload'), findsOneWidget);
    expect(find.text('Area required'), findsOneWidget);
    expect(find.text('Property info required'), findsOneWidget);
  });

  testWidgets('broker upload rejects inverted budget range', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BrokerUploadScreen()));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Budget QA Lead');
    await tester.enterText(fields.at(1), '9999999999');
    await tester.enterText(fields.at(2), 'Mira Road');
    await tester.enterText(fields.at(4), 'QA Tower');
    await tester.enterText(fields.at(5), '10000000');
    await tester.enterText(fields.at(6), '8000000');
    await tester.ensureVisible(find.text('Encrypt and Secure Lead'));
    await tester.tap(find.text('Encrypt and Secure Lead'));
    await tester.pump();

    expect(find.text('Budget max must be greater than min'), findsOneWidget);
  });

  test('broker upload training path preserves property info', () {
    final source = File('lib/screens/broker_upload.dart').readAsStringSync();

    expect(source, contains('propertyName: _propertyController.text.trim()'));
  });

  test('training secure call increments broker call attempts', () async {
    final runtime = TrainingRuntime.instance;
    final leadId = runtime.addLeadFromBroker(
      brokerId: TrainingRuntime.brokerId,
      alias: 'Call QA ${DateTime.now().microsecondsSinceEpoch}',
      area: 'Mira Road',
      city: 'Mumbai',
      budgetMin: 8000000,
      budgetMax: 10000000,
    );
    final before = runtime.brokerDashboardStats()['calls_attempted'] as int;

    final result = await runtime.initiateCall(leadId, type: 'lead');

    expect(result['ok'], true);
    expect(runtime.brokerDashboardStats()['calls_attempted'], before + 1);
  });

  test('training grant access creates missing data loan', () {
    final runtime = TrainingRuntime.instance;
    final leadId = runtime.addLeadFromBroker(
      brokerId: TrainingRuntime.brokerId,
      alias: 'Access QA ${DateTime.now().microsecondsSinceEpoch}',
      area: 'Mira Road',
      city: 'Mumbai',
      budgetMin: 8000000,
      budgetMax: 10000000,
    );

    expect(runtime.updateDataLoanStatus(leadId, 'grant_access'), true);
    final lead =
        runtime.brokerLeadRows().firstWhere((row) => row['id'] == leadId);
    expect(lead['loan'], 'Active');
  });

  test('training broker lead rows keep project and update fields for actions',
      () {
    final runtime = TrainingRuntime.instance;
    final leadId = runtime.addLeadFromBroker(
      brokerId: TrainingRuntime.brokerId,
      alias: 'Project QA ${DateTime.now().microsecondsSinceEpoch}',
      area: 'Mira Road',
      city: 'Mumbai',
      budgetMin: 8000000,
      budgetMax: 10000000,
    );

    final lead =
        runtime.brokerLeadRows().firstWhere((row) => row['id'] == leadId);

    expect(lead['project_id'], TrainingRuntime.projectId);
    expect('${lead['updated_at']}', isNotEmpty);
    expect(runtime.proposeSiteVisitFromLead(leadId), true);
  });

  test('training vault actions mirror live SM followup and issue mutations',
      () {
    final runtime = TrainingRuntime.instance;
    final leadId = runtime.addLeadFromBroker(
      brokerId: TrainingRuntime.brokerId,
      alias: 'Vault QA ${DateTime.now().microsecondsSinceEpoch}',
      area: 'Mira Road',
      city: 'Mumbai',
      budgetMin: 8000000,
      budgetMax: 10000000,
    );

    expect(runtime.assignLeadToSourcingManager(leadId), true);
    var lead =
        runtime.brokerLeadRows().firstWhere((row) => row['id'] == leadId);
    expect(lead['conversion_stage'], 'assigned_to_sm');

    expect(
      runtime.setBrokerLeadFollowup(
        leadId,
        DateTime.now().add(const Duration(days: 1)),
      ),
      true,
    );
    lead = runtime.brokerLeadRows().firstWhere((row) => row['id'] == leadId);
    expect(lead['conversion_stage'], 'call_later');
    expect('${lead['followup']}', isNot('Not Set'));

    expect(runtime.raiseBrokerIssue(leadId, 'brokerage_credit'), true);
    lead = runtime.brokerLeadRows().firstWhere((row) => row['id'] == leadId);
    expect(lead['brokerage_status'], 'disputed');
    expect('${lead['updated_at']}', isNotEmpty);
  });

  test('training booking and brokerage status updates mutate lead rows', () {
    final runtime = TrainingRuntime.instance;
    final leadId = runtime.addLeadFromBroker(
      brokerId: TrainingRuntime.brokerId,
      alias: 'Stage QA ${DateTime.now().microsecondsSinceEpoch}',
      area: 'Mira Road',
      city: 'Mumbai',
      budgetMin: 8000000,
      budgetMax: 10000000,
    );

    expect(runtime.updateBrokerLeadBookingStage(leadId, 'token_paid'), true);
    expect(
      runtime.updateBrokerLeadBrokerageStatus(leadId, 'eligible'),
      true,
    );

    final lead =
        runtime.brokerLeadRows().firstWhere((row) => row['id'] == leadId);
    expect(lead['booking_stage'], 'token_paid');
    expect(lead['brokerage_status'], 'eligible');
    expect('${lead['updated_at']}', isNotEmpty);
  });

  test('broker dashboard keeps lead update time for priority actions', () {
    final source =
        File('lib/screens/broker_dashboard_screen.dart').readAsStringSync();

    expect(source, contains("'updated_at': lead['updated_at']"));
  });

  test('broker lead action sheet is scroll-safe for small viewports', () {
    final source =
        File('lib/screens/broker_dashboard_screen.dart').readAsStringSync();
    final start = source.indexOf('void _showLeadActions');
    final end = source.indexOf('Widget _actionTile', start);
    final actionSheetSource = source.substring(start, end);

    expect(actionSheetSource, contains('isScrollControlled: true'));
    expect(actionSheetSource, contains('SingleChildScrollView'));
  });

  test('broker training action paths do not invoke live Supabase functions',
      () {
    final source =
        File('lib/screens/broker_dashboard_screen.dart').readAsStringSync();
    final liveFunctionGuard = RegExp(
      r'if \(AppConfig\.isSupabaseConfigured\) \{\s*'
      r'final response = await Supabase\.instance\.client',
      dotAll: true,
    );

    expect(source, isNot(contains(liveFunctionGuard)));
    expect(
      source,
      contains('AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode'),
    );
    expect(source, contains("case 'assign_to_sm':"));
    expect(source, contains('assignLeadToSourcingManager'));
    expect(source, contains('DateTime.tryParse'));
    expect(source, contains('updateBrokerLeadBookingStage'));
    expect(source, contains('updateBrokerLeadBrokerageStatus'));
  });
}
