import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'broker dashboard exposes premium vault sections without sensitive tables',
      () {
    final source =
        File('lib/screens/broker_dashboard_screen.dart').readAsStringSync();

    const requiredSections = [
      'BROKER BUSINESS VAULT',
      'MY FOLLOW-UPS',
      'MY SITE VISITS',
      'MY BROKER LOCKS',
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
}
