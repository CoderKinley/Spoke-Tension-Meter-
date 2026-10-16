// Diagnostic fallback for environments where Flutter cannot spawn its runner.
// Uses test_api internals pinned transitively by the Flutter SDK. Prefer flutter test.
// ignore_for_file: depend_on_referenced_packages, implementation_imports, avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_api/src/backend/declarer.dart';
import 'package:test_api/src/backend/group.dart';
import 'package:test_api/src/backend/invoker.dart';
import 'package:test_api/src/backend/test.dart';
import 'package:test_api/src/backend/suite.dart';
import 'package:test_api/src/backend/suite_platform.dart';
import 'package:test_api/src/backend/runtime.dart';
import '../test/dsp_test.dart' as dsp;
import '../test/physics_test.dart' as physics;
import '../test/controller_test.dart' as controller;
import '../test/storage_test.dart' as storage;
import '../test/app_test.dart' as app;
import '../test/dashboard_test.dart' as dashboard;
import '../test/guide_test.dart' as guide;

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final declarer = Declarer();
  declarer.declare(() {
    group('DSP', dsp.main);
    group('Physics', physics.main);
    group('Controller', controller.main);
    group('Storage', storage.main);
    group('Widgets', app.main);
    group('Dashboard', dashboard.main);
    group('Guide', guide.main);
  });
  final suite = Suite(declarer.build(), SuitePlatform(Runtime.vm));
  var total = 0, failed = 0;
  Future<void> visit(Group group, List<Group> parents) async {
    if (group.setUpAll != null || group.tearDownAll != null) {
      throw StateError(
        'Group-wide fixtures require the normal flutter test runner.',
      );
    }
    for (final entry in group.entries) {
      if (entry is Group) {
        await visit(entry, [...parents, entry]);
      }
      if (entry is Test) {
        total++;
        final live = entry.load(suite, groups: parents);
        final messages = live.onMessage.listen((m) => print(m.text));
        await Invoker.guard(() => live.run());
        if (live.state.result.isFailing) {
          failed++;
          for (final error in live.errors) {
            print('FAIL ${entry.name}: $error');
          }
        } else {
          print('PASS ${entry.name}');
        }
        await messages.cancel();
        await live.close();
      }
    }
  }

  await visit(suite.group, [suite.group]);
  print('RESULT: $total tests, $failed failed');
  exit(failed == 0 ? 0 : 1);
}
