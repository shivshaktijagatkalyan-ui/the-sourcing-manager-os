import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lead-from-broker assigns leads to broker sourcing manager', () {
    final source = File('../supabase/functions/lead-from-broker/index.ts')
        .readAsStringSync();

    expect(source, contains("select('id, assigned_sourcing_manager_id')"));
    expect(source, contains('const assignedManagerId = validUuid('));
    expect(
      source,
      contains('assigned_manager_id: assignedManagerId'),
    );
    expect(
      source,
      contains('assigned_sourcing_manager_id: assignedManagerId'),
    );
  });
}
