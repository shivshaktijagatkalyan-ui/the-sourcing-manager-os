import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sourcing_manager_os/app_config.dart';
import 'package:sourcing_manager_os/screens/role_dashboard_container.dart';
import 'package:sourcing_manager_os/utils/role_resolver.dart';

void main() {
  tearDown(() {
    AppConfig.isTrainingMode = true;
    AppConfig.mockRole = 'sourcing_manager';
  });

  test(
    'configured APK resolves training dashboard before auth session lookup',
    () async {
      AppConfig.isTrainingMode = true;
      AppConfig.mockRole = 'sourcing_manager';

      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
      );

      final role = await RoleResolver.currentRole(
        client: client,
        isSupabaseConfigured: true,
      );

      expect(role, 'sourcing_manager');
    },
  );

  testWidgets('anonymous role routes to login screen', (tester) async {
    await _pumpRoleDashboard(tester, 'anonymous');

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('ACCESS RESTRICTED'), findsNothing);
  });

  testWidgets('sourcing manager role routes to sourcing dashboard',
      (tester) async {
    await _pumpRoleDashboard(tester, 'sourcing_manager');

    expect(find.text('SOURCING MANAGER HUB'), findsOneWidget);
  });

  testWidgets('broker roles route to broker dashboard', (tester) async {
    await _pumpRoleDashboard(tester, 'broker_agent');

    expect(find.text('BROKER BUSINESS VAULT'), findsWidgets);
  });

  testWidgets('caller role routes to caller dashboard', (tester) async {
    await _pumpRoleDashboard(tester, 'caller');

    expect(find.text('CALLER WORKSPACE'), findsOneWidget);
  });

  testWidgets('admin role routes to super admin dashboard', (tester) async {
    await _pumpRoleDashboard(tester, 'admin');

    expect(find.text('Super Admin Panel'), findsOneWidget);
  });

  testWidgets('unknown role remains fail closed', (tester) async {
    await _pumpRoleDashboard(tester, 'unknown');

    expect(find.text('ACCESS RESTRICTED'), findsOneWidget);
    expect(find.text('ROLE: UNKNOWN'), findsOneWidget);
  });
}

Future<void> _pumpRoleDashboard(WidgetTester tester, String role) async {
  AppConfig.isTrainingMode = true;
  AppConfig.mockRole = role;

  await tester.pumpWidget(
    const MaterialApp(
      home: RoleDashboardContainer(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pump();
}
