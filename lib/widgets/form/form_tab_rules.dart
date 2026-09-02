import '../../models/chart/signal_type.dart';
import '../../utils/code_trigger_helpers.dart';
import 'form_tab_constants.dart';

/// `FormTab` 周辺の「画面ルール（選択肢/判定）」を集約します。
///
/// - UI 側の分岐（選択肢の出し分け）や
/// - Code Trigger 時の信号タイプ/可視性など
///
class FormTabRules {
  const FormTabRules._();

  /// Input/Output Port の選択肢（現状仕様）
  static const List<int> portOptions = <int>[6, 16, 32, 64];

  /// Input Port 数に応じた Trigger Option 選択肢（現状仕様）
  ///
  /// - Input=6 のときは Code Trigger を選べない
  static List<String> triggerOptionsForInputCount(int inputCount) {
    if (inputCount == FormTabConstants.minInputPorts) {
      return <String>[TriggerOptions.single, TriggerOptions.command];
    }
    return <String>[
      TriggerOptions.single,
      TriggerOptions.code,
      TriggerOptions.command,
    ];
  }

  /// Code Trigger 時の入力信号タイプを判定する
  static SignalType inferInputSignalType({
    required String triggerOption,
    required int inputCount,
    required int index,
    bool codeTriggerOnPlcEip = false,
    bool isPlcEipChannel = false,
  }) {
    if (triggerOption != TriggerOptions.code) return SignalType.input;

    if (codeTriggerOnPlcEip) {
      // CODE_OPTION を PLC/EIP で表現: DIO 側はロックしない
      if (!isPlcEipChannel) return SignalType.input;
    } else {
      // 従来: DIO 側で Code 領域をロック、PLI/ESI 側はロックしない
      if (isPlcEipChannel) return SignalType.input;
    }

    if (inputCount >= FormTabConstants.maxInputPorts) {
      if (index >= FormTabConstants.codeTrigger32ControlStart &&
          index <= FormTabConstants.codeTrigger32ControlEnd) {
        return SignalType.control;
      }
      if (index >= FormTabConstants.codeTrigger32GroupStart &&
          index <= FormTabConstants.codeTrigger32GroupEnd) {
        return SignalType.group;
      }
      if (index >= FormTabConstants.codeTrigger32TaskStart &&
          index <= FormTabConstants.codeTrigger32TaskEnd) {
        return SignalType.task;
      }
    } else if (inputCount == FormTabConstants.standardInputPorts) {
      if (index >= FormTabConstants.codeTrigger16ControlStart &&
          index <= FormTabConstants.codeTrigger16ControlEnd) {
        return SignalType.control;
      }
      if (index >= FormTabConstants.codeTrigger16GroupStart &&
          index <= FormTabConstants.codeTrigger16GroupEnd) {
        return SignalType.group;
      }
      if (index >= FormTabConstants.codeTrigger16TaskStart &&
          index <= FormTabConstants.codeTrigger16TaskEnd) {
        return SignalType.task;
      }
    }

    return SignalType.input;
  }

  /// Code Trigger 時の入力信号のデフォルト可視性を判定する
  ///
  /// 現状仕様:
  /// - index=0 と “Code領域外” は表示
  static bool inferInputVisibility({
    required String triggerOption,
    required int inputCount,
    required int index,
    bool codeTriggerOnPlcEip = false,
    bool isPlcEipChannel = false,
  }) {
    if (triggerOption != TriggerOptions.code) return true;

    if (codeTriggerOnPlcEip) {
      if (!isPlcEipChannel) return true;
    } else {
      if (isPlcEipChannel) return true;
    }

    if (inputCount >= FormTabConstants.maxInputPorts) {
      return index == 0 || index > FormTabConstants.codeTrigger32TaskEnd;
    }
    if (inputCount == FormTabConstants.standardInputPorts) {
      return index == 0 || index > FormTabConstants.codeTrigger16TaskEnd;
    }
    return true;
  }

  /// CODE_OPTION に畳む Control/Group/Task ビットはチャートへ出さない。
  static bool shouldIncludeOnChart({
    required bool isVisible,
    required SignalType signalType,
    required String name,
    required String triggerOption,
    required int inputCount,
  }) {
    if (!isVisible) return false;
    if (signalType == SignalType.control ||
        signalType == SignalType.group ||
        signalType == SignalType.task) {
      return false;
    }
    if (triggerOption == TriggerOptions.code &&
        CodeTriggerHelpers.isCodeBitName(name, inputCount)) {
      return false;
    }
    return true;
  }
}
