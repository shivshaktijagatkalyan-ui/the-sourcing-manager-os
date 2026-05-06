import 'package:flutter_test/flutter_test.dart';
import 'manual_smoke_test_sim.dart' as smoke;

void main() {
  test('Manual Smoke Test Simulation', () async {
    await smoke.main();
  });
}
