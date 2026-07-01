import 'dart:typed_data';

import 'package:archive/archive_io.dart';

import 'csv_io_log_parser.dart';

/// ZIQ (ZIP) から必要ファイルを抽出（Isolate 用トップレベル関数）
Map<String, String> readRequiredFilesFromZipBytesIsolate(Uint8List bytes) {
  final result = <String, String>{};
  try {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);

    String? readTextFromArchive(String targetPath) {
      final normalizedTarget = targetPath.replaceAll('\\', '/');
      for (final entry in archive) {
        if (entry.isFile) {
          final name = entry.name.replaceAll('\\', '/');
          if (name.toLowerCase() == normalizedTarget.toLowerCase()) {
            final data = entry.content as List<int>;
            return String.fromCharCodes(data);
          }
        }
      }
      return null;
    }

    String? readByFileNameFallback(String fileName) {
      final lower = fileName.toLowerCase();
      final lowerStem =
          lower.endsWith('.csv') || lower.endsWith('.ini')
              ? lower.substring(0, lower.lastIndexOf('.'))
              : lower;
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final normalized = entry.name.replaceAll('\\', '/');
        final lastSlash = normalized.lastIndexOf('/');
        final base =
            lastSlash >= 0 ? normalized.substring(lastSlash + 1) : normalized;
        final baseLower = base.toLowerCase();
        if (baseLower == lower || baseLower.startsWith(lowerStem)) {
          try {
            final data = entry.content as List<int>;
            return String.fromCharCodes(data);
          } catch (_) {
            // ignore
          }
        }
      }
      return null;
    }

    String? readWithFallback(List<String> targets, String baseName) {
      for (final t in targets) {
        final text = readTextFromArchive(t);
        if (text != null) return text;
      }
      return readByFileNameFallback(baseName);
    }

    final ini = readWithFallback([
      'viscotech/bin/vxVisMgr.ini',
      'bin/vxVisMgr.ini',
      'vxVisMgr.ini',
    ], 'vxVisMgr.ini');
    final dio = readWithFallback([
      'viscotech/Support/DioMonitorLog.csv',
      'Support/DioMonitorLog.csv',
      'DioMonitorLog.csv',
    ], 'DioMonitorLog.csv');
    final plc = readWithFallback([
      'viscotech/Support/Plc_DioMonitorLog.csv',
      'Support/Plc_DioMonitorLog.csv',
      'Plc_DioMonitorLog.csv',
    ], 'Plc_DioMonitorLog.csv');
    final fnl = readWithFallback([
      'viscotech/Support/FNL_DioMonitorLog.csv',
      'Support/FNL_DioMonitorLog.csv',
      'FNL_DioMonitorLog.csv',
    ], 'FNL_DioMonitorLog.csv');

    if (ini != null) result['vxVisMgr.ini'] = ini;
    if (dio != null) result['DioMonitorLog.csv'] = dio;
    if (plc != null) result['Plc_DioMonitorLog.csv'] = plc;
    if (fnl != null) result['FNL_DioMonitorLog.csv'] = fnl;

    return result;
  } catch (_) {
    return result;
  }
}

/// CSV タイムライン解析の Isolate 入力
class CsvTimelineParsePayload {
  final List<String> sources;
  final List<String> contents;

  const CsvTimelineParsePayload({
    required this.sources,
    required this.contents,
  });
}

/// CSV タイムライン解析の Isolate 出力
class CsvTimelineParseResult {
  final CsvTimeline timeline;
  final List<double> stepDurationsMs;

  const CsvTimelineParseResult({
    required this.timeline,
    required this.stepDurationsMs,
  });
}

/// 複数 CSV からタイムラインとステップ長を算出（Isolate 用）
CsvTimelineParseResult parseCsvTimelineIsolate(CsvTimelineParsePayload payload) {
  final pairs = <MapEntry<String, String>>[];
  for (var i = 0; i < payload.sources.length; i++) {
    pairs.add(MapEntry(payload.sources[i], payload.contents[i]));
  }
  final timeline = CsvIoLogParser.parseTimelineMulti(pairs);
  final stepDurationsMs =
      CsvIoLogParserTimestamps.inferStepDurationsMsFromTimeline(timeline);
  return CsvTimelineParseResult(
    timeline: timeline,
    stepDurationsMs: stepDurationsMs,
  );
}
