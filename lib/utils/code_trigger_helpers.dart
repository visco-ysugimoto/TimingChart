import '../widgets/form/form_tab_constants.dart';

/// Code Trigger の Control/Group/Task ビットに関する共通ロジック
class CodeTriggerHelpers {
  CodeTriggerHelpers._();

  /// Code Trigger 用ビット名（index は 0-based）
  static String? nameForIndex(int index, int inputCount) {
    if (inputCount >= FormTabConstants.maxInputPorts) {
      if (index >= FormTabConstants.codeTrigger32ControlStart &&
          index <= FormTabConstants.codeTrigger32ControlEnd) {
        return 'Control Code$index(bit)';
      }
      if (index >= FormTabConstants.codeTrigger32GroupStart &&
          index <= FormTabConstants.codeTrigger32GroupEnd) {
        return 'Group Code$index(bit)';
      }
      if (index >= FormTabConstants.codeTrigger32TaskStart &&
          index <= FormTabConstants.codeTrigger32TaskEnd) {
        return 'Task Code$index(bit)';
      }
    } else if (inputCount == FormTabConstants.standardInputPorts) {
      if (index >= FormTabConstants.codeTrigger16ControlStart &&
          index <= FormTabConstants.codeTrigger16ControlEnd) {
        return 'Control Code$index(bit)';
      }
      if (index >= FormTabConstants.codeTrigger16GroupStart &&
          index <= FormTabConstants.codeTrigger16GroupEnd) {
        return 'Group Code$index(bit)';
      }
      if (index >= FormTabConstants.codeTrigger16TaskStart &&
          index <= FormTabConstants.codeTrigger16TaskEnd) {
        return 'Task Code$index(bit)';
      }
    }
    return null;
  }

  /// Control/Group/Task ビット名かどうか（CODE_OPTION 合成用の個別系列）
  static bool isCodeBitName(String name, int inputCount) {
    for (int i = 1; i < inputCount; i++) {
      if (nameForIndex(i, inputCount) == name) return true;
    }
    return false;
  }

  /// Control/Group/Task 領域の 0-based index 一覧（ポート2以降）
  static List<int> codeBitIndices(int inputCount) {
    final indices = <int>[];
    for (int i = 1; i < inputCount; i++) {
      if (nameForIndex(i, inputCount) != null) {
        indices.add(i);
      }
    }
    return indices;
  }

  /// 複数ビット系列を OR 合成して CODE_OPTION 波形を生成
  static List<int> synthesizeCodeOptionWave(List<List<int>> bitSeries) {
    if (bitSeries.isEmpty) return [];
    final length = bitSeries.map((s) => s.length).fold(0, (a, b) => a > b ? a : b);
    if (length == 0) return [];

    final result = List<int>.filled(length, 0);
    for (int t = 0; t < length; t++) {
      for (final series in bitSeries) {
        if (t < series.length && series[t] != 0) {
          result[t] = 1;
          break;
        }
      }
    }
    return result;
  }
}
