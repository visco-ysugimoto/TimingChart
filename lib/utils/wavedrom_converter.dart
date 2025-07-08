import 'dart:convert';

import '../models/backup/app_config.dart';
import '../models/chart/signal_data.dart';
import '../models/chart/timing_chart_annotation.dart';
import '../models/form/form_state.dart';
import '../models/chart/signal_type.dart';
import '../widgets/form/form_tab.dart' show CellMode;

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

  /// WaveDrom 形式(JSON)から AppConfig へ変換します。
  /// AppConfig 形式の JSON と区別するために、トップレベルに "signal" キーが存在することをチェックします。
  static AppConfig? fromWaveDromJson(String jsonString) {
    dynamic decoded;
    try {
      decoded = json.decode(jsonString);
    } catch (_) {
      return null; // JSON でない
    }

    if (decoded is! Map<String, dynamic> || !decoded.containsKey('signal')) {
      return null; // WaveDrom 形式ではない
    }

    final Map<String, dynamic> map = decoded;

    final List<dynamic> signalList = map['signal'] ?? [];
    final Map<String, dynamic> cfg = Map<String, dynamic>.from(
      map['config'] ?? {},
    );

    // --- TimingFormState ---
    final formState = TimingFormState(
      triggerOption: cfg['triggerOption'] ?? 'Single Trigger',
      ioPort: cfg['ioPort'] ?? 0,
      hwPort: cfg['hwPort'] ?? 0,
      camera: cfg['camera'] ?? 0,
      inputCount: cfg['inputCount'] ?? 0,
      outputCount: cfg['outputCount'] ?? 0,
    );

    final int inputCount = formState.inputCount;
    final int hwPort = formState.hwPort;
    final int outputCount = formState.outputCount;

    // --- 名前リスト ---
    List<String> _safeStringList(List<dynamic>? src, int expectedLength) {
      final list = <String>[];
      if (src != null) {
        list.addAll(src.map((e) => e?.toString() ?? ''));
      }
      // パディング
      while (list.length < expectedLength) list.add('');
      if (list.length > expectedLength) {
        list.removeRange(expectedLength, list.length);
      }
      return list;
    }

    final inputNames = _safeStringList(
      cfg['inputNames'] as List<dynamic>?,
      inputCount,
    );
    final outputNames = _safeStringList(
      cfg['outputNames'] as List<dynamic>?,
      outputCount,
    );
    final hwTriggerNames = _safeStringList(
      cfg['hwTriggerNames'] as List<dynamic>?,
      hwPort,
    );

    // --- Visibility ---
    List<bool> _visFromNames(List<String> names) =>
        names.map((n) => n.isNotEmpty).toList();

    final inputVisibility = _visFromNames(inputNames);
    final outputVisibility = _visFromNames(outputNames);
    final hwTriggerVisibility = _visFromNames(hwTriggerNames);

    // --- RowModes ---
    final List<String> rowModes =
        (cfg['rowModes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // --- テーブルデータ (カメラテーブル) ---
    // 循環依存を避けるため、ここでは空リストを設定し、
    // インポート後に UI 側で再生成してもらう。
    final List<List<CellMode>> tableData = [];

    // --- 波形を数値列へ変換 ---
    List<int> _waveToValues(String wave) {
      final List<int> values = [];
      int prev = 0;
      for (final ch in wave.split('')) {
        if (ch == '0' || ch == '1') {
          prev = ch == '1' ? 1 : 0;
          values.add(prev);
        } else if (ch == '.') {
          values.add(prev);
        } else {
          // 'x' などその他は 0 扱い
          values.add(0);
          prev = 0;
        }
      }
      return values;
    }

    // --- SignalData 列を生成 ---
    final List<SignalData> signals = [];
    int sigIdx = 0;
    for (final s in signalList) {
      if (s is Map<String, dynamic>) {
        final name = s['name']?.toString() ?? '';
        final waveStr = s['wave']?.toString() ?? '';
        final values = _waveToValues(waveStr);

        SignalType type;
        if (sigIdx < inputCount) {
          type = SignalType.input;
        } else if (sigIdx < inputCount + hwPort) {
          type = SignalType.hwTrigger;
        } else {
          type = SignalType.output;
        }

        signals.add(
          SignalData(
            name: name.isNotEmpty ? name : '',
            signalType: type,
            values: values,
            isVisible: name.toString().isNotEmpty,
          ),
        );
        sigIdx++;
      }
    }

    // --- AppConfig ---
    return AppConfig(
      formState: formState,
      signals: signals,
      tableData: tableData,
      inputNames: inputNames,
      outputNames: outputNames,
      hwTriggerNames: hwTriggerNames,
      inputVisibility: inputVisibility,
      outputVisibility: outputVisibility,
      hwTriggerVisibility: hwTriggerVisibility,
      rowModes: rowModes,
    );
  }
}
