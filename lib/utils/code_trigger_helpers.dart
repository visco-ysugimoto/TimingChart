import '../models/chart/timing_chart_annotation.dart';
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

  /// いずれかの信号名が Code Trigger ビットか
  static bool containsCodeBitName(Iterable<String> names, int inputCount) {
    for (final name in names) {
      if (isCodeBitName(name.trim(), inputCount)) return true;
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
    final length =
        bitSeries.map((s) => s.length).fold(0, (a, b) => a > b ? a : b);
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

  /// 前後が同一ビットパターンのゼロ区間を、同コード継続とみなして埋める
  ///
  /// 例: CODE_OPTION が `1,0,1` で両側が同じビット列なら `1,1,1` にする。
  /// [bitSeries] は in-place で更新される。
  static void fillSameCodeGaps({
    required List<int> indices,
    required List<List<int>> bitSeries,
    required int inputCount,
  }) {
    if (indices.isEmpty || bitSeries.isEmpty) return;
    if (indices.length != bitSeries.length) return;

    final orWave = synthesizeCodeOptionWave(bitSeries);
    final length = orWave.length;
    if (length == 0) return;

    final patterns = List<String>.generate(
      length,
      (t) => formatCodeBitPatternAt(
        t: t,
        indices: indices,
        bitSeries: bitSeries,
        inputCount: inputCount,
      ),
    );

    int t = 0;
    while (t < length) {
      if (orWave[t] != 0) {
        t++;
        continue;
      }

      final gapStart = t;
      while (t < length && orWave[t] == 0) {
        t++;
      }
      final gapEnd = t;

      // 先頭/末尾のゼロ区間は埋めない（両隣が必要）
      if (gapStart == 0 || gapEnd >= length) continue;

      final before = gapStart - 1;
      final after = gapEnd;
      if (orWave[before] == 0 || orWave[after] == 0) continue;
      if (patterns[before] != patterns[after]) continue;

      for (int g = gapStart; g < gapEnd; g++) {
        for (int i = 0; i < bitSeries.length; i++) {
          if (g < bitSeries[i].length && before < bitSeries[i].length) {
            bitSeries[i][g] = bitSeries[i][before];
          }
        }
      }
    }
  }

  /// 時刻 [t] の Control/Group/Task ビット列を文字列化する
  ///
  /// 各グループ内はポート番号の大きい側を左（上位ビット）にする。
  /// 例: Control Code1..4 = `C:b4b3b2b1` → `C:0100` なら Code3=1
  static String formatCodeBitPatternAt({
    required int t,
    required List<int> indices,
    required List<List<int>> bitSeries,
    required int inputCount,
  }) {
    final control = <int>[];
    final group = <int>[];
    final task = <int>[];

    for (int i = 0; i < indices.length; i++) {
      final idx = indices[i];
      final bit =
          (i < bitSeries.length && t < bitSeries[i].length)
              ? (bitSeries[i][t] != 0 ? 1 : 0)
              : 0;
      final name = nameForIndex(idx, inputCount) ?? '';
      if (name.startsWith('Control')) {
        control.add(bit);
      } else if (name.startsWith('Group')) {
        group.add(bit);
      } else if (name.startsWith('Task')) {
        task.add(bit);
      }
    }

    // 収集はポート昇順（下位→上位）なので、表示は反転して上位を左にする
    String bits(List<int> xs) => xs.reversed.map((b) => b.toString()).join();
    return 'C:${bits(control)} G:${bits(group)} T:${bits(task)}';
  }

  static bool _isIdlePattern(String pattern) => !pattern.contains('1');

  /// 個別ビット系列の変化点にコメント（アノテーション）を生成する
  ///
  /// - 全ビット 0 の区間はコメントしない
  /// - 同一ビット列の継続中は、最初の High 時刻だけコメントする
  ///
  /// [indices] と [bitSeries] は同じ順序・同じ長さであること。
  static List<TimingChartAnnotation> buildCodeBitChangeAnnotations({
    required List<int> indices,
    required List<List<int>> bitSeries,
    required int inputCount,
  }) {
    if (indices.isEmpty || bitSeries.isEmpty) return const [];
    if (indices.length != bitSeries.length) return const [];

    final length =
        bitSeries.map((s) => s.length).fold(0, (a, b) => a > b ? a : b);
    if (length == 0) return const [];

    final result = <TimingChartAnnotation>[];
    String? prevActivePattern;

    for (int t = 0; t < length; t++) {
      final pattern = formatCodeBitPatternAt(
        t: t,
        indices: indices,
        bitSeries: bitSeries,
        inputCount: inputCount,
      );
      if (_isIdlePattern(pattern)) {
        // 真のアイドル区間。次に別コードが来たら新規コメント対象にする
        prevActivePattern = null;
        continue;
      }
      if (pattern != prevActivePattern) {
        result.add(
          TimingChartAnnotation(
            id: 'auto_codebit_${t}_${result.length}',
            startTimeIndex: t,
            endTimeIndex: null,
            text: pattern,
          ),
        );
        prevActivePattern = pattern;
      }
    }
    return result;
  }
}
