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
    expect(find.text('Listen to your wheel.'), findsOneWidget);
    for (final page in ['Tune', 'Wheels', 'Calibration']) {
      await tester.tap(find.text(page).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('FORCE ESTIMATES UNAVAILABLE'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
