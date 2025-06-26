import 'package:flutter/material.dart';
import '../../widgets/form/form_tab.dart';
import '../../widgets/chart/chart_signals.dart';
import '../form/form_state.dart';
import 'signal_type.dart';

/// チャートデータ生成器
/// フォーム情報とカメラテーブルから最適な時系列データを生成するクラス
class ChartDataGenerator {
  /// 各モードに対応する信号パターンを生成
  static List<int> generateSignalPattern(
    CellMode mode, {
    int length = 32,
    int phase = 0,
    int period = 8,
  }) {
    List<int> pattern = List.filled(length, 0);

    switch (mode) {
      case CellMode.mode1: // 入力信号: クロック/データ信号
        // クロック信号パターン（周期的な方形波）
        for (int i = 0; i < length; i++) {
          pattern[i] = ((i + phase) % period < period / 2) ? 1 : 0;
        }
        break;

      case CellMode.mode2: // 出力信号: 応答型
        // 少し遅れて応答するパターン
        // 位相シフトをかけて入力に対する応答をシミュレート
        for (int i = 2; i < length; i++) {
          pattern[i] = ((i - 2 + phase) % period < period / 2) ? 1 : 0;
        }
        break;

      case CellMode.mode3: // HWトリガー: パルス信号
        // トリガーパルスパターン（特定位置でのみHigh）
        for (int i = 0; i < length; i++) {
          // 周期の開始位置でパルス（1サイクルだけHigh）
          if ((i + phase) % period == 0) {
            pattern[i] = 1;
          }
        }
        break;

      case CellMode.mode4: // バースト信号
        // バースト的なパターン
        for (int i = 0; i < length; i++) {
          if (((i + phase) % (period * 2) >= period) &&
              ((i + phase) % (period * 2) < period + period / 2)) {
            pattern[i] = 1;
          }
        }
        break;

      case CellMode.mode5: // 特殊信号
        // 長いHighと短いHighの組み合わせ
        for (int i = 0; i < length; i++) {
          int cyclePos = (i + phase) % (period * 2);
          if ((cyclePos < period / 2) ||
              (cyclePos >= period && cyclePos < period + period / 4)) {
            pattern[i] = 1;
          }
        }
        break;

      case CellMode.none:
      default:
        // モードなしの場合はすべて0（Low）
        break;
    }

    return pattern;
  }

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

    // カメラ数
    final int cameraCount = formState.camera;

    // カメラテーブルから各信号のモードを割り当て
    List<_SignalInfo> signalsWithModes = _assignModesToSignals(
      activeSignals,
      tableData,
      cameraCount,
    );

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

  /// 信号とカメラテーブルを照合して、適切なモードを割り当てる
  static List<_SignalInfo> _assignModesToSignals(
    List<_SignalInfo> signals,
    List<List<CellMode>> tableData,
    int cameraCount,
  ) {
    // モードのマッピング
    final modeMapping = {
      SignalType.input: CellMode.mode1,
      SignalType.output: CellMode.mode2,
      SignalType.hwTrigger: CellMode.mode3,
    };

    // 各信号タイプごとのカウンター
    Map<SignalType, int> typeCount = {
      SignalType.input: 0,
      SignalType.output: 0,
      SignalType.hwTrigger: 0,
    };

    // 各信号に適切なモードを割り当て
    for (final signal in signals) {
      // この信号タイプのカウントを増やす
      typeCount[signal.type] = (typeCount[signal.type] ?? 0) + 1;

      // この信号タイプのインデックスを取得
      int typeIndex = typeCount[signal.type]! - 1;

      // カメラテーブルから該当の信号タイプに一致するモードを検索
      CellMode foundMode = CellMode.none;

      // テーブルを順に探索
      outerLoop:
      for (int row = 0; row < tableData.length; row++) {
        for (
          int col = 0;
          col < tableData[row].length && col < cameraCount;
          col++
        ) {
          CellMode currentMode = tableData[row][col];

          // 信号タイプに対応するモードを見つけた場合
          if (currentMode == modeMapping[signal.type]) {
            // すでに割り当て済みの同じタイプの信号の数を数える
            int alreadyAssignedCount = 0;

            for (int r = 0; r <= row; r++) {
              for (int c = 0; c < tableData[r].length && c < cameraCount; c++) {
                if ((r < row) || (r == row && c < col)) {
                  if (tableData[r][c] == modeMapping[signal.type]) {
                    alreadyAssignedCount++;
                  }
                }
              }
            }

            // この信号のインデックスと一致するか確認
            if (alreadyAssignedCount == typeIndex) {
              foundMode = currentMode;
              break outerLoop;
            }
          }
        }
      }

      // 一致するモードが見つからなかった場合はデフォルトを使用
      if (foundMode == CellMode.none) {
        foundMode = modeMapping[signal.type] ?? CellMode.none;
      }

      signal.mode = foundMode;
    }

    return signals;
  }

  /// 特定の信号に対応するカメラモードを見つける
  static List<CellMode> _findCameraModesForSignal(
    _SignalInfo signal,
    List<List<CellMode>> tableData,
  ) {
    List<CellMode> modes = [];

    // 対応するモードマッピング
    CellMode targetMode;
    switch (signal.type) {
      case SignalType.input:
        targetMode = CellMode.mode1;
        break;
      case SignalType.output:
        targetMode = CellMode.mode2;
        break;
      case SignalType.hwTrigger:
        targetMode = CellMode.mode3;
        break;
      default:
        targetMode = CellMode.none;
    }

    // 該当の信号タイプと一致するモードを含むカメラを探す
    int matchCount = 0;

    for (int row = 0; row < tableData.length; row++) {
      for (int col = 0; col < tableData[row].length; col++) {
        if (tableData[row][col] == targetMode) {
          matchCount++;

          // 該当の信号と一致するカメラを見つけた場合
          if (matchCount == signal.index + 1) {
            // このカメラ（列）のすべてのモードを収集
            for (int r = 0; r < tableData.length; r++) {
              if (col < tableData[r].length &&
                  tableData[r][col] != CellMode.none) {
                modes.add(tableData[r][col]);
              }
            }
            return modes;
          }
        }
      }
    }

    return modes;
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
