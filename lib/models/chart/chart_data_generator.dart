import 'package:flutter/material.dart';
import '../../widgets/form/form_tab.dart';
import '../../widgets/chart/chart_signals.dart';
import '../form/form_state.dart';
import 'signal_type.dart';

/// チャートデータ生成器
/// フォーム情報とカメラテーブルから最適な時系列データを生成するクラス
class ChartDataGenerator {
  /// カメラテーブルと信号情報から最適な時系列データを生成
  static List<List<int>> generateTimingChart({
    required TimingFormState formState,
    required List<TextEditingController> inputControllers,
    required List<TextEditingController> outputControllers,
    required List<TextEditingController> hwTriggerControllers,
    required List<List<CellMode>> tableData,
    int timeLength = 32,
  }) {
    // 有効な信号のリスト（テキストフィールドに入力がある信号）
    List<_SignalInfo> activeSignals = [];

    // 信号情報を収集
    // 入力信号
    for (int i = 0; i < formState.inputCount; i++) {
      if (i < inputControllers.length && inputControllers[i].text.isNotEmpty) {
        activeSignals.add(
          _SignalInfo(
            name: inputControllers[i].text,
            index: i,
            type: SignalType.input,
          ),
        );
      }
    }

    // HWトリガー信号 (Input の次に追加)
    for (int i = 0; i < formState.hwPort; i++) {
      if (i < hwTriggerControllers.length &&
          hwTriggerControllers[i].text.isNotEmpty) {
        activeSignals.add(
          _SignalInfo(
            name: hwTriggerControllers[i].text,
            index: i,
            type: SignalType.hwTrigger,
          ),
        );
      }
    }

    // 出力信号 (最後)
    for (int i = 0; i < formState.outputCount; i++) {
      if (i < outputControllers.length &&
          outputControllers[i].text.isNotEmpty) {
        activeSignals.add(
          _SignalInfo(
            name: outputControllers[i].text,
            index: i,
            type: SignalType.output,
          ),
        );
      }
    }

    // カメラモードに依存したパターン生成は削除したため、
    // activeSignals をそのまま使用する
    List<_SignalInfo> signalsWithModes = activeSignals;

    // 各信号に適切な波形パターンを生成
    List<List<int>> chartData = [];
    for (int i = 0; i < signalsWithModes.length; i++) {
      final signal = signalsWithModes[i];

      // 入力値が空の場合は全て0の配列を返す
      if (signal.name.trim().isEmpty) {
        chartData.add(List.filled(timeLength, 0));
        continue;
      }
      // 既存の自動生成ロジックを削除し、全て0の配列のみ返す
      chartData.add(List.filled(timeLength, 0));
    }

    return chartData;
  }

  /// 2つの信号名が関連しているかをチェック
  static bool _areSignalsRelated(String name1, String name2) {
    // 名前のパターンマッチングに基づく簡易的な関連性チェック

    // 対応関係マッピング
    const relatedPatterns = {
      'CLK': ['DATA', 'ENABLE', 'VALID'],
      'DATA': ['VALID', 'READY'],
      'ADDR': ['DATA', 'WE', 'OE'],
      'WE': ['DATA', 'ADDR'],
      'CS': ['DATA', 'READY'],
      'RESET': ['READY', 'STATUS'],
      'SCLK': ['MOSI', 'MISO'],
      'MOSI': ['MISO'],
      'TRIGGER': ['READY', 'DATA'],
    };

    // 名前からキーワードを抽出
    String key1 = _extractKeyword(name1);
    String key2 = _extractKeyword(name2);

    // 関連性チェック
    if (relatedPatterns.containsKey(key1)) {
      return relatedPatterns[key1]!.any((pattern) => key2.contains(pattern));
    }

    // 逆方向の関連性もチェック
    if (relatedPatterns.containsKey(key2)) {
      return relatedPatterns[key2]!.any((pattern) => key1.contains(pattern));
    }

    return false;
  }

  /// 信号名からキーワードを抽出
  static String _extractKeyword(String signalName) {
    // 値の部分を除去（「:」以降を取り除く）
    String nameOnly = signalName.split(':').first.trim();

    // よくある信号名パターンを抽出
    for (final pattern in [
      'CLK',
      'CLOCK',
      'SCLK',
      'DATA',
      'ADDR',
      'ADDRESS',
      'WE',
      'OE',
      'CS',
      'ENABLE',
      'READY',
      'VALID',
      'STATUS',
      'RESET',
      'MOSI',
      'MISO',
      'TRIGGER',
      'START',
      'STOP',
    ]) {
      if (nameOnly.toUpperCase().contains(pattern)) {
        return pattern;
      }
    }

    return nameOnly.toUpperCase();
  }

  // 信号名リストを生成
  static List<String> generateSignalNames({
    required List<TextEditingController> inputControllers,
    required List<TextEditingController> outputControllers,
    required List<TextEditingController> hwTriggerControllers,
    required TimingFormState formState,
  }) {
    List<String> names = [];

    // 入力信号
    for (int i = 0; i < formState.inputCount; i++) {
      if (i < inputControllers.length && inputControllers[i].text.isNotEmpty) {
        names.add(inputControllers[i].text);
      }
    }

    // HWトリガー信号
    for (int i = 0; i < formState.hwPort; i++) {
      if (i < hwTriggerControllers.length &&
          hwTriggerControllers[i].text.isNotEmpty) {
        names.add(hwTriggerControllers[i].text);
      }
    }

    // 出力信号
    for (int i = 0; i < formState.outputCount; i++) {
      if (i < outputControllers.length &&
          outputControllers[i].text.isNotEmpty) {
        names.add(outputControllers[i].text);
      }
    }

    return names;
  }

  // 信号タイプリストを生成
  static List<SignalType> generateSignalTypes({
    required List<TextEditingController> inputControllers,
    required List<TextEditingController> outputControllers,
    required List<TextEditingController> hwTriggerControllers,
    required TimingFormState formState,
  }) {
    List<SignalType> types = [];

    // 入力信号
    for (int i = 0; i < formState.inputCount; i++) {
      if (i < inputControllers.length && inputControllers[i].text.isNotEmpty) {
        types.add(SignalType.input);
      }
    }

    // HWトリガー信号
    for (int i = 0; i < formState.hwPort; i++) {
      if (i < hwTriggerControllers.length &&
          hwTriggerControllers[i].text.isNotEmpty) {
        types.add(SignalType.hwTrigger);
      }
    }

    // 出力信号
    for (int i = 0; i < formState.outputCount; i++) {
      if (i < outputControllers.length &&
          outputControllers[i].text.isNotEmpty) {
        types.add(SignalType.output);
      }
    }

    return types;
  }
}

/// 内部で使用する信号情報クラス
class _SignalInfo {
  final String name;
  final int index;
  final SignalType type;
  CellMode mode;
  int phase = 0;

  _SignalInfo({
    required this.name,
    required this.index,
    required this.type,
    this.mode = CellMode.none,
  });
}
