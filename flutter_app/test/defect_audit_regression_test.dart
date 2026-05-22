import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  test('broker dashboard uses 0-100 trust score rank thresholds', () {
    final source = _source('lib/screens/broker_dashboard_screen.dart');

    expect(source, contains('if (score >= 80) return \'Gold\';'));
    expect(source, contains('if (score >= 60) return \'Silver\';'));
    expect(source, contains('if (score >= 40) return \'Bronze\';'));
    expect(source, isNot(contains('score >= 4.5')));
    expect(source, isNot(contains('score >= 3.5')));
    expect(source, isNot(contains('score >= 2.5')));
  });

  test('training mode role refresh is not started inside setState', () {
    final source = _source('lib/main.dart');
    final start = source.indexOf('void _enableTrainingMode()');
    final end = source.indexOf('@override', start);
    final method = source.substring(start, end);

    expect(method, contains('setState(() {'));
    expect(method, contains('AppConfig.isTrainingMode = true;'));
    expect(method, contains('});\n    _fetchRole();'));
    expect(
      RegExp(r'setState\(\(\) \{[\s\S]*_fetchRole\(\);[\s\S]*\}\);')
          .hasMatch(method),
      isFalse,
    );
  });

  test('broker dashboard exposes refresh errors and avoids misleading badge',
      () {
    final source = _source('lib/screens/broker_dashboard_screen.dart');

    expect(source, contains("_showSnack('Dashboard refresh failed."));
    expect(source, isNot(contains("PremiumUI.statusBadge('DATALESS'")));
  });

  test('broker profile save goes through audited vault workflow', () {
    final profileSource = _source('lib/screens/profile_completion_screen.dart');
    final functionSource =
        _source('../supabase/functions/broker-vault-workflow/index.ts');

    expect(profileSource, contains("invoke('broker-vault-workflow'"));
    expect(profileSource, contains("'action': 'update_broker_profile'"));
    expect(profileSource, isNot(contains("from('brokers_public').update")));
    expect(functionSource, contains('"update_broker_profile"'));
    expect(functionSource, contains('broker_profile_updated'));
  });

  test('broker lead actions pass explicit assignment and loan context', () {
    final source = _source('lib/screens/broker_dashboard_screen.dart');

    expect(source, contains('_showCallerPicker(leadId)'));
    expect(source, contains('_showSmPicker('));
    expect(
      RegExp(
        r"'sourcing_manager_id':\s*smId",
      ).hasMatch(source),
      true,
    );
    expect(source, contains("'loan_id': lead['loan_id']"));
    expect(source, contains("'purpose': 'call'"));
  });

  test('role dashboard delegates auth listening to main navigation', () {
    final source = _source('lib/screens/role_dashboard_container.dart');

    expect(source, isNot(contains('StreamSubscription<AuthState>')));
    expect(source, isNot(contains('authStateStream.listen')));
  });

  test('platform admin organizations route stays on super admin surface', () {
    final source = _source('lib/main.dart');
    final organizationsStart = source.indexOf("title: 'Organizations'");
    final projectsStart = source.indexOf("title: 'Projects'");
    final organizationsTile =
        source.substring(organizationsStart, projectsStart);

    expect(organizationsTile, contains('SuperAdminDashboard'));
    expect(organizationsTile, isNot(contains('_select(9)')));
  });

  test('training-mode write flows do not call live Supabase branches', () {
    final writeFlowSources = [
      _source('lib/screens/add_broker_screen.dart'),
      _source('lib/screens/add_lead_from_broker.dart'),
      _source('lib/screens/caller_lead_queue_screen.dart'),
    ];

    for (final source in writeFlowSources) {
      expect(
        source,
        isNot(contains('if (AppConfig.isSupabaseConfigured) {')),
      );
      expect(
        source,
        contains('AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode'),
      );
    }
  });
}
