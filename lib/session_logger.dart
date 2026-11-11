// session_logger.dart
//
// Minimal, storage-simple session log: one JSON object per line (JSONL)
// in the app's documents directory. Not tied to BLE or any specific sensor.
//
// pubspec.yaml:
//   path_provider: ^2.1.0
//   (optional, for sending to the physio) share_plus: ^10.0.0

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SessionRecord {
  final String id; // unique id (timestamp-based by default)
  final DateTime startedAt;
  final int durationMs;
  final int sampleCount;
  final double avg;
  final double min;
  final double max;

  /// Free-form extras: exercise name, patient notes, pain score, reps, etc.
  final Map<String, dynamic> extra;

  SessionRecord({
    String? id,
    required this.startedAt,
    required this.durationMs,
    required this.sampleCount,
    required this.avg,
    required this.min,
    required this.max,
    this.extra = const {},
  }) : id = id ?? startedAt.microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'durationMs': durationMs,
        'sampleCount': sampleCount,
        'avg': avg,
        'min': min,
        'max': max,
        'extra': extra,
      };

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
        id: j['id'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        durationMs: j['durationMs'] as int,
        sampleCount: j['sampleCount'] as int,
        avg: (j['avg'] as num).toDouble(),
        min: (j['min'] as num).toDouble(),
        max: (j['max'] as num).toDouble(),
        extra: Map<String, dynamic>.from(j['extra'] ?? {}),
      );
}

class SessionLogger {
  final String fileName;
  File? _file;

  SessionLogger({this.fileName = 'sessions.jsonl'});

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/$fileName');
    if (!await f.exists()) await f.create(recursive: true);
    return _file = f;
  }

  /// Append one session (cheap; doesn't rewrite the file).
  Future<void> add(SessionRecord record) async {
    final f = await _getFile();
    await f.writeAsString('${jsonEncode(record.toJson())}\n',
        mode: FileMode.append, flush: true);
  }

  /// Read every session, oldest first. Corrupt lines are skipped.
  Future<List<SessionRecord>> readAll() async {
    final f = await _getFile();
    final records = <SessionRecord>[];
    for (final line in await f.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        records.add(SessionRecord.fromJson(jsonDecode(line)));
      } catch (_) {
        // skip malformed line
      }
    }
    return records;
  }

  /// Sessions between [from] and [to] (inclusive), handy for weekly reports.
  Future<List<SessionRecord>> readRange(DateTime from, DateTime to) async {
    final all = await readAll();
    return all
        .where((r) => !r.startedAt.isBefore(from) && !r.startedAt.isAfter(to))
        .toList();
  }

  Future<void> delete(String id) async {
    final keep = (await readAll()).where((r) => r.id != id).toList();
    final f = await _getFile();
    await f.writeAsString(
      keep.map((r) => '${jsonEncode(r.toJson())}\n').join(),
      flush: true,
    );
  }

  Future<void> clear() async => (await _getFile()).writeAsString('');

  /// CSV string (extras are JSON-encoded into one column).
  Future<String> toCsv() async {
    final rows = await readAll();
    final sb = StringBuffer(
        'id,startedAt,durationMs,sampleCount,avg,min,max,extra\n');
    for (final r in rows) {
      final extra = jsonEncode(r.extra).replaceAll('"', '""');
      sb.writeln('${r.id},${r.startedAt.toIso8601String()},${r.durationMs},'
          '${r.sampleCount},${r.avg},${r.min},${r.max},"$extra"');
    }
    return sb.toString();
  }

  /// Write the CSV to a temp file you can hand to share_plus / email.
  Future<File> exportCsvFile() async {
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/sessions_export.csv');
    return out.writeAsString(await toCsv());
  }
}
