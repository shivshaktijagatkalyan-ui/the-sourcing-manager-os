import 'package:flutter_test/flutter_test.dart';
import 'package:sourcing_manager_os/main.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const SourcingManagerOS());
    expect(find.text('SM OS'), findsOneWidget);
  });
}
