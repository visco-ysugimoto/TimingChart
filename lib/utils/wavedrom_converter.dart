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
    List<int>? omissionIndices,
  }) {
    // 1. 波形長を決定
    final int defaultLength =
        config.signals.isNotEmpty
            ? config.signals
                .map((s) => s.values.length)
                .reduce((a, b) => a > b ? a : b)
            : 32;

    // 2. チャート画面順で wave を生成
    List<Map<String, dynamic>> waveSignal = [];

    String _padAndConvert(List<int> original) {
      final padded = List<int>.from(original);
      while (padded.length < defaultLength) {
        padded.add(0);
      }
      return _valuesToWave(padded);
    }

    for (final s in config.signals) {
      waveSignal.add({'name': s.name, 'wave': _padAndConvert(s.values)});
    }

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

      // このブロックは annotations が非null・非空であることが事前条件
      final List<TimingChartAnnotation> annList = annotations;
      final List<int> omitList =
          (omissionIndices != null) ? omissionIndices : config.omissionIndices;

      final wavedromJson = {
        'signal': waveSignal,
        'edge': edgeList,
        if (omitList.isNotEmpty) 'omission': omitList,
        // config には最新の annotations を入れる（引数優先）
        'config': _buildConfig(
          AppConfig(
            formState: config.formState,
            signals: config.signals,
            tableData: config.tableData,
            inputNames: config.inputNames,
            outputNames: config.outputNames,
            hwTriggerNames: config.hwTriggerNames,
            inputVisibility: config.inputVisibility,
            outputVisibility: config.outputVisibility,
            hwTriggerVisibility: config.hwTriggerVisibility,
            rowModes: config.rowModes,
            annotations: annList,
            omissionIndices: omitList,
          ),
        ),
      };

      return const JsonEncoder.withIndent('  ').convert(wavedromJson);
    }

    // アノテーションなしの場合
    final List<TimingChartAnnotation> annList2 =
        (annotations != null && annotations.isNotEmpty)
            ? annotations
            : config.annotations;
    final List<int> omitList2 =
        (omissionIndices != null) ? omissionIndices : config.omissionIndices;

    final wavedromJson = {
      'signal': waveSignal,
      if (omitList2.isNotEmpty) 'omission': omitList2,
      'config': _buildConfig(
        AppConfig(
          formState: config.formState,
          signals: config.signals,
          tableData: config.tableData,
          inputNames: config.inputNames,
          outputNames: config.outputNames,
          hwTriggerNames: config.hwTriggerNames,
          inputVisibility: config.inputVisibility,
          outputVisibility: config.outputVisibility,
          hwTriggerVisibility: config.hwTriggerVisibility,
          rowModes: config.rowModes,
          annotations: annList2,
          omissionIndices: omitList2,
        ),
      ),
    };
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
      'chartOrder': config.signals.map((s) => s.name).toList(),
      'annotations':
          config.annotations
              .map(
                (a) => {
                  'id': a.id,
                  'start': a.startTimeIndex,
                  // range でなければ null を出力（新仕様）
                  'end': a.endTimeIndex,
                  'text': a.text,
                  if (a.offsetX != null) 'offsetX': a.offsetX,
                  if (a.offsetY != null) 'offsetY': a.offsetY,
                  if (a.arrowTipY != null) 'arrowTipY': a.arrowTipY,
                  if (a.arrowHorizontal != null)
                    'arrowHorizontal': a.arrowHorizontal,
                },
              )
              .toList(),
      'omissionIndices': config.omissionIndices,
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
    final List<dynamic> edgeList = map['edge'] ?? []; // Get edge list

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

    // --- アノテーション ---
    List<TimingChartAnnotation> annotations =
        ((cfg['annotations'] ?? []) as List)
            .map(
              (e) => TimingChartAnnotation(
                id: e['id']?.toString() ?? '',
                startTimeIndex: e['start'] ?? 0,
                endTimeIndex: e['end'],
                text: e['text']?.toString() ?? '',
                offsetX: (e['offsetX'] as num?)?.toDouble(),
                offsetY: (e['offsetY'] as num?)?.toDouble(),
                arrowTipY: (e['arrowTipY'] as num?)?.toDouble(),
                arrowHorizontal: e['arrowHorizontal'] as bool?,
              ),
            )
            .toList();

    // config に annotations がない場合、v1互換の node/edge から読み取りを試みる
    if (annotations.isEmpty && edgeList.isNotEmpty) {
      String? nodeString;
      for (final s in signalList) {
        if (s is Map<String, dynamic> && s.containsKey('node')) {
          nodeString = s['node'] as String?;
          break;
        }
      }

      if (nodeString != null) {
        final nodeMap = <String, int>{};
        for (int i = 0; i < nodeString.length; i++) {
          final char = nodeString[i];
          if (char != '.') {
            nodeMap[char] = i;
          }
        }

        int annIdCounter = 0;
        for (final edge in edgeList.cast<String>()) {
          final parts = edge.split(RegExp(r'\s+'));
          if (parts.isEmpty) continue;

          final nodes = parts[0];
          final text = parts.length > 1 ? parts.sublist(1).join(' ') : '';

          if (nodes.contains('<->')) {
            final markers = nodes.split('<->');
            if (markers.length == 2) {
              final startMarker = markers[0];
              final endMarker = markers[1];
              final startIdx = nodeMap[startMarker];
              final endIdx = nodeMap[endMarker];

              if (startIdx != null && endIdx != null) {
                annotations.add(
                  TimingChartAnnotation(
                    id: 'ann${annIdCounter++}',
                    startTimeIndex: startIdx,
                    endTimeIndex: endIdx,
                    text: text,
                  ),
                );
              }
            }
          } else {
            final marker = nodes;
            final idx = nodeMap[marker];
            if (idx != null) {
              annotations.add(
                TimingChartAnnotation(
                  id: 'ann${annIdCounter++}',
                  startTimeIndex: idx,
                  endTimeIndex: idx, // Point annotation
                  text: text,
                ),
              );
            }
          }
        }
      }
    }

    // --- 省略区間 ---
    final List<int> omissionIndices =
        ((map['omission'] ?? cfg['omissionIndices'] ?? []) as List)
            .map((e) => e as int)
            .toList();

    // --- カメラテーブル ---
    final List<List<CellMode>> tableData =
        ((cfg['cameraTable'] ?? []) as List)
            .map(
              (row) =>
                  (row as List).map((idx) => CellMode.values[idx]).toList(),
            )
            .toList();

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
    // config.chartOrder を元に表示順を並べ替え
    List<dynamic> effectiveSignalList = signalList;
    final List<dynamic>? chartOrder = cfg['chartOrder'] as List<dynamic>?;

    if (chartOrder != null && chartOrder.isNotEmpty) {
      final List<String> order = chartOrder.cast<String>();
      final List<dynamic> sortedSignalList = [];

      final Map<String, Map<String, dynamic>> signalMap = {};
      final List<Map<String, dynamic>> signalsWithNoNameOrNode = [];
      for (var s in signalList) {
        if (s is Map<String, dynamic>) {
          final name = s['name']?.toString() ?? '';
          // node を持つ信号は特別扱いして、最後に回す
          if (name.isNotEmpty) {
            signalMap[name] = s;
          } else {
            signalsWithNoNameOrNode.add(s);
          }
        }
      }

      final Set<String> addedSignals = {};

      // chartOrder に従って信号を追加
      for (final name in order) {
        if (signalMap.containsKey(name)) {
          sortedSignalList.add(signalMap[name]!);
          addedSignals.add(name);
        }
      }

      // chartOrder に含まれなかった残りの信号を追加
      for (final entry in signalMap.entries) {
        if (!addedSignals.contains(entry.key)) {
          sortedSignalList.add(entry.value);
        }
      }

      // 名無し信号 (アノテーション行など) を最後に追加
      sortedSignalList.addAll(signalsWithNoNameOrNode);

      effectiveSignalList = sortedSignalList;
    }

    final List<SignalData> signals = [];
    int sigIdx = 0;
    for (final s in effectiveSignalList) {
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
      annotations: annotations,
      omissionIndices: omissionIndices,
    );
  }
}
