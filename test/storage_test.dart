import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:spoke_lab/data/models.dart';
import 'package:spoke_lab/data/repository.dart';

void main() {
  test(
    'local storage survives restart and maintains a previous snapshot',
    () async {
      final directory = await Directory.systemTemp.createTemp('spokelab-test-');
      try {
        final repo = LocalRepository(directory);
        await repo.save(AppData.empty());
        final updated = AppData(
          wheels: [
            const WheelProfile(
              id: 'wheel-2',
              name: 'Road wheel',
              tireState: '40 psi',
            ),
          ],
        );
        await repo.save(updated);
        expect(
          (await LocalRepository(directory).load()).wheels.single.name,
          'Road wheel',
        );
        final backup = jsonDecode(
          await File('${directory.path}/spoke_lab.backup.json').readAsString(),
        );
        expect(backup['wheels'][0]['id'], 'first-wheel');
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
  test('corrupt data is surfaced and remains untouched', () async {
    final directory = await Directory.systemTemp.createTemp(
      'spokelab-corrupt-',
    );
    try {
      final file = File('${directory.path}/spoke_lab.json');
      await file.writeAsString('{broken');
      await expectLater(
        LocalRepository(directory).load(),
        throwsFormatException,
      );
      expect(await file.readAsString(), '{broken');
    } finally {
      await directory.delete(recursive: true);
    }
  });
  test('unsupported version cannot silently reset data', () {
    expect(
      () => AppData.fromJson({'schemaVersion': 99}),
      throwsFormatException,
    );
  });
}
