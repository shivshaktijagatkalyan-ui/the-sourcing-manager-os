import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sourcing_manager_os/app_config.dart';
import 'package:sourcing_manager_os/screens/choose_role_screen.dart';
import 'package:sourcing_manager_os/screens/login_screen.dart';
import 'package:sourcing_manager_os/utils/auth_service.dart';
import 'package:sourcing_manager_os/utils/role_resolver.dart';

void main() {
  tearDown(() {
    AppConfig.isTrainingMode = false;
    AppConfig.mockRole = '';
  });

  testWidgets('login screen has required auth and access controls',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Request Access'), findsOneWidget);
    expect(find.text('Training Mode'), findsOneWidget);
  });

  testWidgets('choose role screen uses required signup choices',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChooseRoleScreen()));

    expect(find.text('I am Sourcing Manager'), findsOneWidget);
    expect(find.text('I am Broker'), findsOneWidget);
    expect(find.text('I am Caller'), findsOneWidget);
    expect(find.text('I am Admin / Developer'), findsOneWidget);
  });

  testWidgets('caller role opens invite-code signup screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChooseRoleScreen()));

    await tester.tap(find.text('I am Caller'));
    await tester.pumpAndSettle();

    expect(find.text('Caller Registration'), findsOneWidget);
    expect(find.text('Invite Code / Organization Code'), findsOneWidget);
  });

  test('training mode routes to sourcing manager demo without session',
      () async {
    AppConfig.isTrainingMode = true;
    AppConfig.mockRole = 'sourcing_manager';

    final role = await RoleResolver.currentRole(isSupabaseConfigured: true);

    expect(role, 'sourcing_manager');
  });

  test('training broker credential resolves broker dashboard role', () {
    AppConfig.isTrainingMode = true;
    AppConfig.mockRole = 'sourcing_manager';

    final role = RoleResolver.roleForTrainingLoginEmail(
      'jitu.broker.uat@sourcing-manager-os.test',
    );

    expect(role, 'broker_owner');
  });

  test(
      'web Google OAuth redirect returns to localhost root without training query',
      () {
    final redirect = AuthService.webOAuthRedirectUrl(
      base: Uri.parse(
        'http://127.0.0.1:5055/?training=true&mockRole=broker_owner',
      ),
    );

    expect(redirect, 'http://127.0.0.1:5055/');
  });

  testWidgets('training broker login sets broker owner before refresh',
      (tester) async {
    AppConfig.isTrainingMode = true;
    AppConfig.mockRole = 'sourcing_manager';
    var refreshed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          onAuthStateChanged: () {
            refreshed = true;
          },
        ),
      ),
    );

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(
      fields.at(0),
      'jitu.broker.uat@sourcing-manager-os.test',
    );
    await tester.enterText(
      fields.at(1),
      'PilotTest@2026!Secure',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(AppConfig.mockRole, 'broker_owner');
    expect(refreshed, true);
  });

  test('broker signup sends selected_role and safe broker metadata', () {
    final source =
        File('lib/screens/broker_signup_screen.dart').readAsStringSync();

    expect(source, contains("'selected_role': 'broker_owner'"));
    expect(source, contains("'full_name': _fullNameController.text.trim()"));
    expect(source, contains("'company_name': _companyController.text.trim()"));
    expect(source, contains("'area': _areaController.text.trim()"));
    expect(source, contains("'city': _cityController.text.trim()"));
    expect(source, contains('signUp('));
    expect(source, contains("functions.invoke('complete-onboarding'"));
    expect(source, isNot(contains('service_role')));
  });

  test('signup flow refreshes root role after onboarding completes', () {
    final loginSource =
        File('lib/screens/login_screen.dart').readAsStringSync();
    final chooseRoleSource =
        File('lib/screens/choose_role_screen.dart').readAsStringSync();
    final sourcingSignupSource =
        File('lib/screens/sourcing_manager_signup_screen.dart')
            .readAsStringSync();
    final brokerSignupSource =
        File('lib/screens/broker_signup_screen.dart').readAsStringSync();
    final callerSignupSource =
        File('lib/screens/caller_signup_screen.dart').readAsStringSync();

    expect(loginSource, contains('ChooseRoleScreen('));
    expect(
        loginSource, contains('onAuthStateChanged: widget.onAuthStateChanged'));
    expect(
        chooseRoleSource, contains('final VoidCallback? onAuthStateChanged'));
    expect(chooseRoleSource, contains('SourcingManagerSignupScreen('));
    expect(chooseRoleSource, contains('BrokerSignupScreen('));
    expect(chooseRoleSource, contains('CallerSignupScreen('));
    expect(
        chooseRoleSource, contains('onAuthStateChanged: onAuthStateChanged'));
    expect(sourcingSignupSource, contains('widget.onAuthStateChanged?.call()'));
    expect(brokerSignupSource, contains('widget.onAuthStateChanged?.call()'));
    expect(callerSignupSource, contains('widget.onAuthStateChanged?.call()'));
  });

  test('complete onboarding activates broker signup path safely', () {
    final source = File('../supabase/functions/complete-onboarding/index.ts')
        .readAsStringSync();

    expect(source, contains('selected_role'));
    expect(source, contains('broker_owner'));
    expect(source, contains('brokers_public'));
    expect(source, contains('role_assignments'));
    expect(source, contains("'active'"));
    expect(source, contains('user_onboarded'));
    expect(source, isNot(contains('phone')));
    expect(source, isNot(contains('service_role')));
  });
}
