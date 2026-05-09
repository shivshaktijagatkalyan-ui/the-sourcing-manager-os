import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backend migration defines proposal confirmation workflow safely', () {
    final migration = File(
      '../supabase/migrations/20260507000600_site_visit_proposal_confirmation.sql',
    ).readAsStringSync();

    for (final table in [
      'site_visit_proposals',
      'site_visits',
      'site_visit_confirmations',
      'audit_events',
    ]) {
      expect(migration, contains(table));
    }

    for (final status in [
      'proposed',
      'accepted',
      'scheduled',
      'client_reached_site',
      'gps_verified',
      'qr_verified',
      'photo_uploaded',
      'visit_done',
      'broker_review_pending',
      'completed',
      'no_show',
      'cancelled',
      'rejected',
    ]) {
      expect(migration, contains("'$status'"));
    }

    expect(migration, contains('ENABLE ROW LEVEL SECURITY'));
    expect(migration, isNot(contains('leads_sensitive')));
    expect(migration, isNot(contains('brokers_sensitive')));
  });

  test('required site visit edge functions exist and stay dataless', () {
    const functions = [
      'propose-site-visit',
      'review-site-visit-proposal',
      'confirm-site-visit-arrival',
      'verify-site-visit-proof',
    ];

    for (final name in functions) {
      final source =
          File('../supabase/functions/$name/index.ts').readAsStringSync();
      expect(source, contains('currentUser(req)'));
      expect(source, contains('organization_id'));
      expect(source, contains('recordAudit'));
      expect(source, isNot(contains('phone')));
      expect(source, isNot(contains('service_role')));
      expect(source, isNot(contains('console.')));
      expect(source, isNot(contains('leads_sensitive')));
      expect(source, isNot(contains('brokers_sensitive')));
    }
  });

  test('dashboards expose proposal and confirmation surfaces', () {
    final broker =
        File('lib/screens/broker_dashboard_screen.dart').readAsStringSync();
    final sm =
        File('lib/screens/sourcing_manager_dashboard.dart').readAsStringSync();

    expect(broker, contains('Propose Site Visit'));
    expect(broker, contains('Visits Proposed'));
    expect(broker, contains('Visits Done'));
    expect(broker, contains('Verified Visits'));
    expect(broker, contains("'propose-site-visit'"));

    expect(sm, contains('Visit Proposals'));
    expect(sm, contains('Scheduled Visits'));
    expect(sm, contains('Client Reached'));
    expect(sm, contains('No Shows'));
    expect(sm, contains('Broker-wise Visit Performance'));
    expect(sm, contains("'review-site-visit-proposal'"));
    expect(sm, contains("'confirm-site-visit-arrival'"));
    expect(sm, contains("'verify-site-visit-proof'"));

    for (final source in [broker, sm]) {
      expect(source, isNot(contains('tel:')));
      expect(source, isNot(contains('wa.me')));
      expect(source, isNot(contains('api.whatsapp.com')));
      expect(source, isNot(contains('Export Contacts')));
      expect(source, isNot(contains("from('leads_sensitive')")));
      expect(source, isNot(contains("from('brokers_sensitive')")));
    }
  });
}
