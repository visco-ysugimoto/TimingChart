import 'package:flutter/material.dart';
import '../../widgets/form/form_tab.dart';

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
  int phase = 0;

  _SignalInfo({required this.name, required this.index, required this.type});
}
