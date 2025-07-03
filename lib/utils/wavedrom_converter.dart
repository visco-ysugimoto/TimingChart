import 'dart:convert';

import '../models/backup/app_config.dart';
import '../models/chart/signal_data.dart';
import '../models/chart/timing_chart_annotation.dart';

/// AppConfig から WaveDrom 形式(JSON)へ変換するユーティリティ
class WaveDromConverter {
  const WaveDromConverter._();

  /// AppConfig を WaveDrom の JSON 文字列へ変換します。
  /// 返値は human-readable なインデント付き JSON です。
  static String toWaveDromJson(
    AppConfig config, {
    List<TimingChartAnnotation>? annotations,
  }) {
    // 1. 信号部（入力 → HWトリガ → 出力 の順で、欠番も保持）
    final int defaultLength =
        config.signals.isNotEmpty ? config.signals.first.values.length : 32;

    final Map<String, SignalData> _sigMap = {
      for (final s in config.signals) s.name: s,
    };

    List<Map<String, dynamic>> waveSignal = [];

    // ヘルパー
    String _waveForName(String name) {
      if (name.isNotEmpty && _sigMap.containsKey(name)) {
        return _valuesToWave(_sigMap[name]!.values);
      }
      return _valuesToWave(List.filled(defaultLength, 0));
    }

    void _appendSignals(List<String> names) {
      for (final name in names) {
        waveSignal.add({'name': name, 'wave': _waveForName(name)});
      }
    }

    _appendSignals(config.inputNames);
    _appendSignals(config.hwTriggerNames);
    _appendSignals(config.outputNames);

    // 2. アノテーションを node/edge で表現 (WaveDrom v1)
    if (annotations != null &&
        annotations.isNotEmpty &&
        waveSignal.isNotEmpty) {
      final timeSteps = defaultLength;

      // node 文字列を構築 (最初の信号に付加)
      final charList = List.filled(timeSteps, '.');
      final List<String> edgeList = [];

      int letterCode = 97; // 'a'

      String _nextLetter() {
        final letter = String.fromCharCode(letterCode);
        letterCode++;
        if (letterCode > 122) {
          // wrap to 'A'
          letterCode = 65;
        }
        return letter;
      }

      for (final ann in annotations) {
        final startIdx = ann.startTimeIndex;
        final endIdx = ann.endTimeIndex ?? ann.startTimeIndex;
        if (startIdx >= timeSteps || endIdx >= timeSteps) continue;

        if (startIdx == endIdx) {
          // 単一点コメント
          final nodeLetter = _nextLetter();
          charList[startIdx] = nodeLetter;
          edgeList.add('$nodeLetter ${ann.text}');
        } else {
          // 範囲コメント
          final startLetter = _nextLetter();
          final endLetter = _nextLetter();
          charList[startIdx] = startLetter;
          charList[endIdx] = endLetter;
          edgeList.add('$startLetter<->$endLetter ${ann.text}');
        }
      }

      final nodeString = charList.join();

      // アノテーション専用の行を追加してノードを配置
      waveSignal.add({
        'name': '',
        // 波形は全長 x で埋めて目立たないようにする
        'wave': ''.padLeft(timeSteps, 'x'),
        'node': nodeString,
      });

      final wavedromJson = {
        'signal': waveSignal,
        'edge': edgeList,
        'config': _buildConfig(config),
      };

      return const JsonEncoder.withIndent('  ').convert(wavedromJson);
    }

    // アノテーションなしの場合
    final wavedromJson = {'signal': waveSignal, 'config': _buildConfig(config)};
    return const JsonEncoder.withIndent('  ').convert(wavedromJson);
  }

  /// 0/1 のリストを WaveDrom が理解できる文字列表現へ変換
  /// 連続する同値は '.' で圧縮する
  static String _valuesToWave(List<int> values) {
    if (values.isEmpty) return '';
    final buffer = StringBuffer();
    int? prev;
    for (final v in values) {
      if (prev != null && v == prev) {
        buffer.write('.');
      } else {
        buffer.write(v == 1 ? '1' : '0');
      }
      prev = v;
    }
    return buffer.toString();
  }

  /// エクスポート用の設定メタデータを生成
  static Map<String, dynamic> _buildConfig(AppConfig config) {
    return {
      'triggerOption': config.formState.triggerOption,
      'ioPort': config.formState.ioPort,
      'hwPort': config.formState.hwPort,
      'camera': config.formState.camera,
      'inputCount': config.formState.inputCount,
      'outputCount': config.formState.outputCount,
      'inputNames': config.inputNames,
      'outputNames': config.outputNames,
      'hwTriggerNames': config.hwTriggerNames,
      'cameraTable':
          config.tableData
              .map((row) => row.map((cell) => cell.index).toList())
              .toList(),
      'rowModes': config.rowModes,
    };
  }
}
