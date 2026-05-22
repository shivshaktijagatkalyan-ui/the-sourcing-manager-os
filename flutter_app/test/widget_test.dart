import 'package:flutter_test/flutter_test.dart';
import 'package:sourcing_manager_os/app_config.dart';
import 'package:sourcing_manager_os/main.dart';

void main() {
  testWidgets('app boots', (tester) async {
    AppConfig.isTrainingMode = true;
    AppConfig.mockRole = 'sourcing_manager';

    await tester.pumpWidget(const SourcingManagerOS());
    await tester.pump();

    expect(find.text('SM OS'), findsOneWidget);
  });
}
