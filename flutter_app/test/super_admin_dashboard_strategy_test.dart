import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sourcing_manager_os/app_config.dart';
import 'package:sourcing_manager_os/models/super_admin_snapshot.dart';
import 'package:sourcing_manager_os/screens/super_admin_dashboard.dart';
import 'package:sourcing_manager_os/services/super_admin_dashboard_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppConfig.isTrainingMode = false;
    AppConfig.mockRole = '';
  });

  test(
      'snapshot parses dashboard contract and defaults missing numbers to zero',
      () {
    final snapshot = SuperAdminDashboardSnapshot.fromJson({
      'ok': true,
      'generated_at': '2026-05-20T08:30:00.000Z',
      'health': {
        'status': 'attention',
        'last_event': 'edge_function_timeout',
      },
      'kpis': {
        'total_organizations': 3,
        'active_projects': 7,
        'total_brokers': 19,
        'total_leads': 124,
        'calls_attempted': 44,
        'scheduled_visits': 12,
        'verified_visits': 8,
        'active_locks': 5,
        'open_disputes': 1,
        'open_risk_alerts': 2,
        'held_sync_reviews': 4,
      },
      'organizations': [
        {
          'id': 'org_1',
          'name': 'Demo Developer',
          'status': 'active',
          'active_users': 6,
          'open_risk_alerts': 1,
          'created_at': '2026-05-18T10:00:00.000Z',
        },
      ],
      'projects': [
        {
          'id': 'project_1',
          'name': 'Harbor Heights',
          'city': 'Mumbai',
          'area': 'Worli',
          'status': 'active',
          'active_leads': 33,
          'verified_visits': 9,
        },
      ],
      'attention_queue': [
        {
          'id': 'attention_1',
          'type': 'risk_alert',
          'severity': 'high',
          'title': 'Repeated GPS mismatch',
          'reason_code': 'gps_mismatch',
          'organization_id': 'org_1',
          'created_at': '2026-05-20T07:00:00.000Z',
        },
      ],
      'workflow_summary': {
        'lead_intake_today': 11,
        'secure_calls_today': 9,
        'site_visits_today': 4,
        'proofs_pending': 2,
        'locks_created_today': 3,
        'payouts_pending_review': 1,
      },
      'audit_events': [
        {
          'id': 'audit_1',
          'event_type': 'organization_created',
          'actor_role': 'platform_admin',
          'organization_id': 'org_1',
          'created_at': '2026-05-20T06:00:00.000Z',
        },
      ],
      'allowed_actions': ['view_health'],
    });

    expect(snapshot.generatedAt, DateTime.parse('2026-05-20T08:30:00.000Z'));
    expect(snapshot.health.status, 'attention');
    expect(snapshot.health.criticalFailures1h, 0);
    expect(snapshot.kpi('total_organizations'), 3);
    expect(snapshot.kpi('active_users'), 0);
    expect(snapshot.workflowSummary.proofsPending, 2);
    expect(snapshot.workflowSummary.payoutsPendingReview, 1);
    expect(snapshot.organizations.single.activeUsers, 6);
    expect(snapshot.projects.single.name, 'Harbor Heights');
    expect(snapshot.attentionQueue.single.reasonCode, 'gps_mismatch');
    expect(snapshot.auditEvents.single.actorRole, 'platform_admin');
    expect(snapshot.allowedActions, contains('view_health'));
  });

  test('screen source uses typed service and does not read tables in loadLive',
      () {
    final source =
        File('lib/screens/super_admin_dashboard.dart').readAsStringSync();
    final loadLive = RegExp(
      r'Future<void> _loadLive\(\) async \{([\s\S]*?)\n  \}',
    ).firstMatch(source)!.group(1)!;

    expect(source, contains('SuperAdminDashboardSnapshot? _snapshot'));
    expect(source, contains('SuperAdminDashboardService'));
    expect(source, isNot(contains('Supabase.instance')));
    expect(source, isNot(contains('.from(')));
    expect(source, isNot(contains('.rpc(')));
    expect(source, isNot(contains('.functions.invoke(')));
    expect(loadLive, isNot(contains('client.from(')));
    expect(loadLive, contains('loadSnapshot()'));
  });

  testWidgets('risk permission only shows risk quick action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4200));
    final snapshot = _snapshotWith(
      allowedActions: const ['can_view_risk_dashboard'],
    );

    await tester.pumpWidget(
      MaterialApp(home: SuperAdminDashboard(initialSnapshot: snapshot)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open Risk Dashboard'), findsOneWidget);
    expect(find.text('View Health'), findsNothing);
    expect(find.text('Broker Reviews'), findsNothing);
    expect(find.text('Diagnostics'), findsNothing);
    expect(find.text('Create Organization'), findsNothing);
    expect(find.text('Invite User'), findsNothing);
    expect(find.text('Assign Role'), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('attention queue navigation is gated by allowed actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4200));
    final item = AdminAttentionItem(
      id: 'attention_safe',
      type: 'risk_alert',
      severity: 'high',
      title: 'Risk item',
      reasonCode: 'risk_review',
      organizationId: 'org_safe',
      createdAt: DateTime.parse('2026-05-20T08:30:00.000Z'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SuperAdminDashboard(
          key: const ValueKey('attention-denied'),
          initialSnapshot: _snapshotWith(attentionQueue: [item]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: SuperAdminDashboard(
          key: const ValueKey('attention-allowed'),
          initialSnapshot: _snapshotWith(
            attentionQueue: [item],
            allowedActions: const ['review_risk'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('dashboard redacts formatted phone and email values',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4200));
    final snapshot = _snapshotWith(
      organizations: [
        AdminOrganizationRow(
          id: 'org_safe',
          name: 'Owner +91 98765 43210 owner@example.com',
          status: 'active',
          activeUsers: 1,
          openRiskAlerts: 0,
          createdAt: DateTime.parse('2026-05-20T08:30:00.000Z'),
        ),
      ],
      projects: const [
        AdminProjectRow(
          id: 'project_safe',
          name: 'Lead 91 9876543210',
          city: 'ops@example.com',
          area: 'Central 919876543210',
          status: 'active',
          activeLeads: 1,
          verifiedVisits: 0,
        ),
      ],
      attentionQueue: [
        AdminAttentionItem(
          id: 'attention_safe',
          type: 'risk_alert',
          severity: 'high',
          title: 'Caller 98765-43210 caller@example.com',
          reasonCode: 'risk_8877665544',
          organizationId: 'org_safe',
          createdAt: DateTime.parse('2026-05-20T08:30:00.000Z'),
        ),
      ],
      auditEvents: [
        AdminAuditEventRow(
          id: 'audit_safe',
          eventType: 'emailed_person@example.com',
          actorRole: 'admin 9876543210',
          organizationId: 'org_safe',
          createdAt: DateTime.parse('2026-05-20T08:30:00.000Z'),
        ),
      ],
      allowedActions: const ['can_view_risk_dashboard'],
    );

    await tester.pumpWidget(
      MaterialApp(home: SuperAdminDashboard(initialSnapshot: snapshot)),
    );
    await tester.pumpAndSettle();

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .join(' ');
    final phoneLike = RegExp(
      r'(?<![A-Za-z0-9_])(?:\+?91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}(?![A-Za-z0-9_])',
    );
    expect(
        RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}').hasMatch(rendered), isFalse);
    expect(phoneLike.hasMatch(rendered), isFalse);
    expect(rendered, contains('[redacted-value]'));
    expect(rendered, contains('[redacted-email]'));
    final searchable = snapshot.toSearchableText();
    expect(phoneLike.hasMatch(searchable), isFalse);
    expect(RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}').hasMatch(searchable),
        isFalse);
    expect(searchable, contains('[redacted-value]'));
    expect(searchable, contains('[redacted-email]'));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('unknown phone-like error reason is not rendered',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));

    await tester.pumpWidget(
      const MaterialApp(
        home: SuperAdminDashboard(initialErrorReason: '9876543210'),
      ),
    );
    await tester.pumpAndSettle();

    final rendered = _renderedText(tester);
    expect(rendered, isNot(contains('9876543210')));
    expect(rendered, contains('Code: dashboard_error'));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('raw badge status and severity values are normalized',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4200));
    final snapshot = _snapshotWith(
      organizations: [
        AdminOrganizationRow(
          id: 'org_safe',
          name: 'Safe Org',
          status: 'active_9876543210',
          activeUsers: 1,
          openRiskAlerts: 0,
          createdAt: DateTime.parse('2026-05-20T08:30:00.000Z'),
        ),
      ],
      projects: const [
        AdminProjectRow(
          id: 'project_safe',
          name: 'Safe Project',
          city: 'Mumbai',
          area: 'Central',
          status: 'owner@example.com',
          activeLeads: 1,
          verifiedVisits: 0,
        ),
      ],
      attentionQueue: [
        AdminAttentionItem(
          id: 'attention_safe',
          type: 'risk_alert',
          severity: 'high_9876543210',
          title: 'Risk item',
          reasonCode: 'risk_9876543210',
          organizationId: 'org_safe',
          createdAt: DateTime.parse('2026-05-20T08:30:00.000Z'),
        ),
      ],
      allowedActions: const ['review_risk'],
    );

    await tester.pumpWidget(
      MaterialApp(home: SuperAdminDashboard(initialSnapshot: snapshot)),
    );
    await tester.pumpAndSettle();

    final rendered = _renderedText(tester);
    final searchable = snapshot.toSearchableText();
    expect(rendered, isNot(contains('active_9876543210')));
    expect(rendered, isNot(contains('high_9876543210')));
    expect(rendered, isNot(contains('owner@example.com')));
    expect(searchable, isNot(contains('9876543210')));
    expect(searchable, isNot(contains('owner@example.com')));
    expect(rendered, contains('UNKNOWN'));
    await tester.binding.setSurfaceSize(null);
  });

  test(
      'service invokes dashboard function and parses typed snapshot on success',
      () async {
    final source = File('lib/services/super_admin_dashboard_service.dart')
        .readAsStringSync();
    var invoked = false;
    final service = SuperAdminDashboardService.withInvoker(() async {
      invoked = true;
      return _dashboardPayload();
    });

    final snapshot = await service.loadSnapshot();

    expect(source, contains("functions.invoke('super-admin-dashboard')"));
    expect(invoked, isTrue);
    expect(snapshot.health.status, 'healthy');
    expect(snapshot.kpi('total_organizations'), 2);
    expect(snapshot.organizations.single.name, 'Demo Developer');
  });

  test('service converts non-ok payload into dashboard exception reason',
      () async {
    final service = SuperAdminDashboardService.withInvoker(() async {
      return {
        'ok': false,
        'reason': 'forbidden_permission_required',
      };
    });

    await expectLater(
      service.loadSnapshot(),
      throwsA(
        isA<SuperAdminDashboardException>().having(
          (error) => error.reason,
          'reason',
          'forbidden_permission_required',
        ),
      ),
    );
  });

  test('service preserves backend reason from failed function invocation',
      () async {
    final service = SuperAdminDashboardService.withInvoker(() async {
      throw const FunctionException(
        status: 403,
        details: {
          'ok': false,
          'reason': 'forbidden_permission_required',
        },
      );
    });

    await expectLater(
      service.loadSnapshot(),
      throwsA(
        isA<SuperAdminDashboardException>().having(
          (error) => error.reason,
          'reason',
          'forbidden_permission_required',
        ),
      ),
    );
  });

  test('service uses deterministic reason for unreadable function failures',
      () async {
    final service = SuperAdminDashboardService.withInvoker(() async {
      throw StateError('network closed');
    });

    await expectLater(
      service.loadSnapshot(),
      throwsA(
        isA<SuperAdminDashboardException>().having(
          (error) => error.reason,
          'reason',
          'dashboard_read_failed',
        ),
      ),
    );
  });

  testWidgets('training mode renders typed demo snapshot labels',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4200));
    AppConfig.isTrainingMode = true;
    AppConfig.mockRole = 'platform_admin';

    await tester.pumpWidget(
      const MaterialApp(home: SuperAdminDashboard()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('ATTENTION QUEUE'), findsOneWidget);
    expect(find.text('WORKFLOW SUMMARY'), findsOneWidget);
    expect(find.text('Demo Developer Group'), findsOneWidget);
    expect(find.text('Repeated GPS variance'), findsWidgets);
    expect(find.text('LEAD INTAKE TODAY'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  test('demo snapshot and screen source do not contain phone-like strings', () {
    final snapshot = buildDemoSuperAdminSnapshot();
    final source =
        File('lib/screens/super_admin_dashboard.dart').readAsStringSync();
    final demoText = snapshot.toSearchableText();
    final phoneLike = RegExp(r'\b[6-9]\d{9}\b');

    expect(phoneLike.hasMatch(demoText), isFalse);
    expect(phoneLike.hasMatch(source), isFalse);
  });
}

String _renderedText(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? '')
      .join(' ');
}

Map<String, dynamic> _dashboardPayload() {
  return {
    'ok': true,
    'generated_at': '2026-05-20T08:30:00.000Z',
    'health': {
      'status': 'healthy',
      'last_event': 'none',
      'critical_failures_1h': 0,
    },
    'kpis': {
      'total_organizations': 2,
    },
    'organizations': [
      {
        'id': 'org_1',
        'name': 'Demo Developer',
        'status': 'active',
      },
    ],
    'projects': const [],
    'attention_queue': const [],
    'workflow_summary': const {},
    'audit_events': const [],
    'allowed_actions': const ['view_health'],
  };
}

SuperAdminDashboardSnapshot _snapshotWith({
  List<AdminOrganizationRow> organizations = const [],
  List<AdminProjectRow> projects = const [],
  List<AdminAttentionItem> attentionQueue = const [],
  List<AdminAuditEventRow> auditEvents = const [],
  List<String> allowedActions = const [],
}) {
  return SuperAdminDashboardSnapshot(
    generatedAt: DateTime.parse('2026-05-20T08:30:00.000Z'),
    health: const AdminHealth(
      status: 'healthy',
      lastEvent: 'none',
      criticalFailures1h: 0,
    ),
    kpis: const {
      'total_organizations': 1,
      'active_projects': 1,
      'active_users': 1,
      'total_brokers': 1,
      'total_leads': 1,
      'calls_attempted': 1,
      'scheduled_visits': 1,
      'verified_visits': 1,
      'active_locks': 1,
      'open_disputes': 1,
      'open_risk_alerts': 1,
      'held_sync_reviews': 1,
    },
    organizations: organizations,
    projects: projects,
    attentionQueue: attentionQueue,
    workflowSummary: const AdminWorkflowSummary(
      leadIntakeToday: 1,
      secureCallsToday: 1,
      siteVisitsToday: 1,
      proofsPending: 1,
      locksCreatedToday: 1,
      payoutsPendingReview: 1,
    ),
    auditEvents: auditEvents,
    allowedActions: allowedActions,
  );
}
