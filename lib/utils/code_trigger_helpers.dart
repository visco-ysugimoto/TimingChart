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

  /// 時刻 [t] の Task/Group/Control ビット列を文字列化する
  ///
  /// 各グループ内はポート番号の大きい側を左（上位ビット）にする。
  /// 表示順は実信号と同じ Task → Group → Control。
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

    // 収集はポート昇順（下位→上位）なので、表示は反転して上位を左にする。
    // 実信号の並び（Task → Group → Control）に合わせて TGC 順で出す。
    String bits(List<int> xs) => xs.reversed.map((b) => b.toString()).join();
    return 'T:${bits(task)} G:${bits(group)} C:${bits(control)}';
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

  /// ヘルプ／マニュアルに掲載されている制御コード
  ///
  /// グループ・タスクが必要なのは、特定のタスクを指定するコマンドだけ。
  /// 例: タスク実行・アクティブタスク切り替え・ロード・アンロード。
  /// 全タスクアンロードやロット開始などは制御コードのみ。
  static const List<CodeControlCommand> knownControlCommands = [
    CodeControlCommand(code: 1, requiresGroup: true, requiresTask: true),
    CodeControlCommand(code: 2),
    CodeControlCommand(code: 3, requiresGroup: true, requiresTask: true),
    CodeControlCommand(code: 4, requiresGroup: true, requiresTask: true),
    CodeControlCommand(code: 5, requiresGroup: true, requiresTask: true),
    CodeControlCommand(code: 9),
    CodeControlCommand(code: 10),
    CodeControlCommand(code: 12),
    CodeControlCommand(code: 34),
    CodeControlCommand(code: 35),
    CodeControlCommand(code: 37),
    CodeControlCommand(code: 38),
    CodeControlCommand(code: 39),
    CodeControlCommand(code: 40),
    CodeControlCommand(code: 42),
    CodeControlCommand(code: 43),
    CodeControlCommand(code: 44),
    CodeControlCommand(code: 45),
    CodeControlCommand(code: 48),
    CodeControlCommand(code: 49),
  ];

  static List<int> get knownControlCodes =>
      knownControlCommands.map((c) => c.code).toList(growable: false);

  static CodeControlCommand commandSpec(int code) {
    for (final command in knownControlCommands) {
      if (command.code == code) return command;
    }
    return CodeControlCommand(code: code);
  }

  /// グループ / タスク番号の仕様上の上限（1〜50）
  static const int documentedGroupTaskMax = 50;

  /// 入力ポート数に応じた Control / Group / Task のビット幅
  static CodeOptionBitWidths bitWidths(int inputCount) {
    if (inputCount >= FormTabConstants.maxInputPorts) {
      return const CodeOptionBitWidths(control: 8, group: 6, task: 6);
    }
    return const CodeOptionBitWidths(control: 4, group: 3, task: 6);
  }

  /// [width] bit に収まる制御コードだけを返す
  static List<int> availableControlCodes(int inputCount) {
    final int maxValue = (1 << bitWidths(inputCount).control) - 1;
    return knownControlCodes.where((code) => code <= maxValue).toList();
  }

  static int maxGroupNumber(int inputCount) {
    final int bitMax = (1 << bitWidths(inputCount).group) - 1;
    return documentedGroupTaskMax < bitMax ? documentedGroupTaskMax : bitMax;
  }

  static int maxTaskNumber(int inputCount) {
    final int bitMax = (1 << bitWidths(inputCount).task) - 1;
    return documentedGroupTaskMax < bitMax ? documentedGroupTaskMax : bitMax;
  }

  /// 左が MSB のビット列。範囲外の値はクリップする。
  static String formatBits(int value, int width) {
    if (width <= 0) return '';
    final int maxValue = (1 << width) - 1;
    final int clamped = value < 0 ? 0 : (value > maxValue ? maxValue : value);
    return clamped.toRadixString(2).padLeft(width, '0');
  }

  /// コマンド名とビット列を結合したコメント本文
  ///
  /// 実信号の並び（Task → Group → Control）に合わせて TGC 順。
  /// グループ／タスクが不要な制御コードでは `T:` `G:` を付けない。
  /// 例: `タスクロード T:000101 G:001010 C:00000100`
  /// 例: `全タスクアンロード C:00001100`
  static String formatCodeOptionComment({
    required String commandName,
    required int controlCode,
    int group = 0,
    int task = 0,
    required int inputCount,
  }) {
    final widths = bitWidths(inputCount);
    final spec = commandSpec(controlCode);
    final parts = <String>[];
    final name = commandName.trim();
    if (name.isNotEmpty) parts.add(name);
    if (spec.requiresTask) {
      parts.add('T:${formatBits(task, widths.task)}');
    }
    if (spec.requiresGroup) {
      parts.add('G:${formatBits(group, widths.group)}');
    }
    parts.add('C:${formatBits(controlCode, widths.control)}');
    return parts.join(' ');
  }
}

/// CODE_OPTION を構成する各領域のビット幅
class CodeOptionBitWidths {
  final int control;
  final int group;
  final int task;

  const CodeOptionBitWidths({
    required this.control,
    required this.group,
    required this.task,
  });
}

/// 制御コードのグループ／タスク要否
class CodeControlCommand {
  final int code;
  final bool requiresGroup;
  final bool requiresTask;

  const CodeControlCommand({
    required this.code,
    this.requiresGroup = false,
    this.requiresTask = false,
  });
}
