import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spoke_lab/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native app opens local data and navigates offline', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('measure-dashboard')), findsOneWidget);
    for (final page in ['Wheels', 'Tension', 'Measure']) {
      await tester.tap(find.text(page).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byKey(const Key('workshop-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calibration').last);
    await tester.pumpAndSettle();
    expect(find.text('VALIDATED FORCE UNAVAILABLE'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
