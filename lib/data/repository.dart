import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'models.dart';

abstract class AppRepository {
  Future<AppData> load();
  Future<void> save(AppData data);
  Future<bool> export(AppData data, {required bool csv});
}

class LocalRepository implements AppRepository {
  LocalRepository(this.directory);
  final Directory directory;
  static const _platform = MethodChannel('org.spokelab/storage');
  static Future<LocalRepository> open() async {
    final path = await _platform.invokeMethod<String>('directory');
    if (path == null) {
      throw StateError('Local storage unavailable');
    }
    return LocalRepository(Directory(path));
  }

  File get _file => File('${directory.path}/spoke_lab.json');
  File get _backup => File('${directory.path}/spoke_lab.backup.json');
  @override
  Future<AppData> load() async {
    if (!await _file.exists()) {
      if (await _backup.exists()) {
        return _read(_backup);
      }
      return AppData.empty();
    }
    // A corrupt file is surfaced to the user, never silently replaced with defaults.
    return _read(_file);
  }

  Future<AppData> _read(File f) async => AppData.fromJson(
    jsonDecode(await f.readAsString()) as Map<String, dynamic>,
  );
  @override
  Future<void> save(AppData data) async {
    await directory.create(recursive: true);
    final pending = File('${directory.path}/spoke_lab.pending.json');
    await pending.writeAsString(jsonEncode(data.toJson()), flush: true);
    if (await _file.exists()) {
      await _file.copy(_backup.path);
    }
    await pending.rename(_file.path);
  }

  @override
  Future<bool> export(AppData data, {required bool csv}) async =>
      await _platform.invokeMethod<bool>('export', {
        'name': csv ? 'spoke-lab.csv' : 'spoke-lab.json',
        'mime': csv ? 'text/csv' : 'application/json',
        'content': csv
            ? readingsCsv(data)
            : const JsonEncoder.withIndent('  ').convert(data.toJson()),
      }) ??
      false;
}

String readingsCsv(AppData data) {
  String cell(Object? value) {
    var text = value?.toString() ?? '';
    if (RegExp(r'^[=+@\-\t\r]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  final rows = <List<Object?>>[
    [
      'session_id',
      'wheel_id',
      'wheel_name',
      'side',
      'spoke_or_pair',
      'frequency_hz',
      'spread_percent',
      'plucks',
      'mode',
      'created_at',
      'capture_source',
      'profile',
      'force_status',
      'algorithm',
    ],
    ...data.readings.map(
      (r) => [
        r.sessionId,
        r.wheelId,
        data.wheels.where((w) => w.id == r.wheelId).firstOrNull?.name ?? '',
        r.side.name,
        r.spokeIndex,
        r.frequencyHz,
        r.spreadPercent,
        r.plucks,
        r.mode,
        r.createdAt.toIso8601String(),
        r.captureSource,
        r.fingerprint,
        'unavailable-unvalidated',
        'fft-yin-v1',
      ],
    ),
  ];
  return rows.map((r) => r.map(cell).join(',')).join('\r\n');
}

class MemoryRepository implements AppRepository {
  MemoryRepository([AppData? initial]) : data = initial ?? AppData.empty();
  AppData data;
  @override
  Future<AppData> load() async => data;
  @override
  Future<void> save(AppData value) async {
    data = value;
  }

  @override
  Future<bool> export(AppData value, {required bool csv}) async => true;
}
