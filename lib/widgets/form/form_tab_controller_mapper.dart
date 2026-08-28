import 'package:flutter/material.dart';

import '../../models/form/form_state.dart';
import '../../utils/code_trigger_helpers.dart';
import 'form_tab_constants.dart';

/// `updateSignalDataFromChartData()` で行っている「信号→各TextEditingControllerへの割当」を整理するヘルパー。
///
/// 目的:
/// - 取り込み（インポート）時の「既存入力を優先しつつ空き枠へ詰める」ロジックを `form_tab.dart` から分離する
/// - 予約領域（32ポート時のカメラ信号枠）などの特殊ルールを局所化する
class FormTabControllerMapper {
  const FormTabControllerMapper._();

  /// 現在入力済みのコントローラー状態から「信号名→index」の逆引きマップを構築します。
  ///
  /// - import 時に「同名信号は同じ場所へ戻す」ために使います。
  static Map<String, Map<String, int>> buildExistingControllerMaps({
    required List<TextEditingController> inputControllers,
    required List<TextEditingController> outputControllers,
    required List<TextEditingController> hwTriggerControllers,
    required List<TextEditingController> plcEipOutputControllers,
    required List<TextEditingController> plcEipInputControllers,
    List<TextEditingController> auxiliaryControllers = const [],
  }) {
    final Map<String, int> existingInputMap = {};
    final Map<String, int> existingOutputMap = {};
    final Map<String, int> existingHwTriggerMap = {};
    final Map<String, int> existingPlcMap = {};
    final Map<String, int> existingPlcInputMap = {};
    final Map<String, int> existingAuxiliaryMap = {};

    for (int i = 0; i < inputControllers.length; i++) {
      if (inputControllers[i].text.isNotEmpty) {
        existingInputMap[inputControllers[i].text] = i;
      }
    }
    for (int i = 0; i < outputControllers.length; i++) {
      if (outputControllers[i].text.isNotEmpty) {
        existingOutputMap[outputControllers[i].text] = i;
      }
    }
    for (int i = 0; i < hwTriggerControllers.length; i++) {
      if (hwTriggerControllers[i].text.isNotEmpty) {
        existingHwTriggerMap[hwTriggerControllers[i].text] = i;
      }
    }
    for (int i = 0; i < plcEipOutputControllers.length; i++) {
      if (plcEipOutputControllers[i].text.isNotEmpty) {
        existingPlcMap[plcEipOutputControllers[i].text] = i;
      }
    }
    for (int i = 0; i < plcEipInputControllers.length; i++) {
      if (plcEipInputControllers[i].text.isNotEmpty) {
        existingPlcInputMap[plcEipInputControllers[i].text] = i;
      }
    }
    for (int i = 0; i < auxiliaryControllers.length; i++) {
      if (auxiliaryControllers[i].text.isNotEmpty) {
        existingAuxiliaryMap[auxiliaryControllers[i].text] = i;
      }
    }

    return {
      'input': existingInputMap,
      'output': existingOutputMap,
      'hwTrigger': existingHwTriggerMap,
      'plc': existingPlcMap,
      'plcInput': existingPlcInputMap,
      'auxiliary': existingAuxiliaryMap,
    };
  }

  static void clearAllControllers({
    required List<TextEditingController> inputControllers,
    required List<TextEditingController> outputControllers,
    required List<TextEditingController> hwTriggerControllers,
    required List<TextEditingController> plcEipInputControllers,
  }) {
    // 一度全クリアしてから、chartData の順に再配置する（既存仕様）
    for (final c in inputControllers) {
      c.text = '';
    }
    for (final c in outputControllers) {
      c.text = '';
    }
    for (final c in hwTriggerControllers) {
      c.text = '';
    }
    for (final c in plcEipInputControllers) {
      c.text = '';
    }
  }

  static int findFirstEmptyIndex(List<TextEditingController> controllers, {int start = 0}) {
    // 指定開始位置から最初の空きスロットを探す。見つからなければ -1。
    for (int j = start; j < controllers.length; j++) {
      if (controllers[j].text.isEmpty) return j;
    }
    return -1;
  }

  static int findOutputTargetIndex({
    required TimingFormState formState,
    required String name,
    required Map<String, int> existingOutputMap,
    required List<TextEditingController> outputControllers,
    required int reservedOutputStart,
    required int Function(String signalId, int totalOutputs, int totalCameras) selectOutputIndex,
  }) {
    // 1) 既に同名が存在するならそこを優先
    int targetIndex = existingOutputMap[name] ?? -1;

    // 32ポート構成での予約範囲チェック
    if (targetIndex != -1 && formState.outputCount == 32) {
      final int reservedEnd = reservedOutputStart + formState.camera * 2 - 1;
      final bool isInReserved = targetIndex >= reservedOutputStart && targetIndex <= reservedEnd;
      final bool isCameraSignal = RegExp(r'^CAMERA_(\d+)_IMAGE_(EXPOSURE|ACQUISITION)').hasMatch(name);
      if (!isCameraSignal && isInReserved) {
        targetIndex = -1;
      }
    }

    // OutputN形式からインデックスを取得
    if (targetIndex == -1) {
      final m = RegExp(r'^Output(\d+)$').firstMatch(name);
      if (m != null) {
        final portNum = int.tryParse(m.group(1)!);
        if (portNum != null && portNum >= 1 && portNum <= formState.outputCount) {
          int candidate = portNum - 1;
          if (formState.outputCount == 32) {
            final int reservedEnd = reservedOutputStart + formState.camera * 2 - 1;
            final bool isInReserved = candidate >= reservedOutputStart && candidate <= reservedEnd;
            final bool isCameraSignal = RegExp(r'^CAMERA_(\d+)_IMAGE_(EXPOSURE|ACQUISITION)').hasMatch(name);
            if (!isCameraSignal && isInReserved) {
              candidate = -1;
            }
          }
          if (candidate != -1) {
            targetIndex = candidate;
          }
        }
      }
    }

    // プリセットマップから検索
    if (targetIndex == -1) {
      targetIndex = selectOutputIndex(name, formState.outputCount, formState.camera);
    }

    // 空きスロット探索（予約領域の後ろ優先）
    if (targetIndex == -1) {
      int startIdx = 0;
      if (formState.outputCount == 32) {
        final int reservedEnd = reservedOutputStart + formState.camera * 2 + 2;
        startIdx = reservedEnd + 1;
        if (startIdx >= outputControllers.length) startIdx = 0;
      }

      int empty = findFirstEmptyIndex(outputControllers, start: startIdx);
      if (empty == -1 && startIdx > 0) {
        empty = findFirstEmptyIndex(outputControllers, start: 0);
        if (empty != -1 && empty >= startIdx) {
          // 0..startIdx-1 を探したいので、範囲外は無効
          empty = -1;
        }
        if (empty == -1) {
          for (int j = 0; j < startIdx && j < outputControllers.length; j++) {
            if (outputControllers[j].text.isEmpty) {
              empty = j;
              break;
            }
          }
        }
      }

      targetIndex = empty;
    }

    return targetIndex;
  }

  /// チャート専用または Code Trigger 自動命名の信号はコントローラーへ割り当てない
  static bool shouldSkipChartToControllerAssignment({
    required TimingFormState formState,
    required String name,
  }) {
    if (name == SignalNames.codeOption || name == SignalNames.commandOption) {
      return true;
    }
    if (formState.triggerOption == TriggerOptions.code &&
        CodeTriggerHelpers.isCodeBitName(name, formState.inputCount)) {
      return true;
    }
    return false;
  }

  static void assignInputSignal({
    required TimingFormState formState,
    required String name,
    required Map<String, int> existingInputMap,
    required Map<String, int> existingPlcInputMap,
    required List<TextEditingController> inputControllers,
    required List<TextEditingController> plcEipInputControllers,
    required String contactInputWaitingName,
    required int contactInputWaitingIndex32,
  }) {
    if (shouldSkipChartToControllerAssignment(formState: formState, name: name)) {
      return;
    }

    // PLC/EIP入力として既存にある場合は PLC/EIP 側へ戻す
    if (existingPlcInputMap.containsKey(name)) {
      final plcTargetIndex = existingPlcInputMap[name]!;
      if (plcTargetIndex >= 0 && plcTargetIndex < plcEipInputControllers.length) {
        plcEipInputControllers[plcTargetIndex].text = name;
      }
      return;
    }

    // 1) 同名が既にあった場所を優先
    int targetIndex = existingInputMap[name] ?? -1;
    // 2) CONTACT_INPUT_WAITING は 32ポート時に固定位置へ寄せる
    if (targetIndex == -1 && name == contactInputWaitingName) {
      if (formState.inputCount >= 32 && inputControllers.length >= 30) {
        targetIndex = contactInputWaitingIndex32;
      }
    }
    // 3) 空きスロット
    if (targetIndex == -1) {
      targetIndex = findFirstEmptyIndex(inputControllers);
    }

    if (targetIndex >= 0 && targetIndex < inputControllers.length) {
      inputControllers[targetIndex].text = name;
    }
  }

  static void assignOutputSignal({
    required TimingFormState formState,
    required String name,
    required Map<String, int> existingOutputMap,
    required Map<String, int> existingPlcMap,
    required List<TextEditingController> outputControllers,
    required int reservedOutputStart,
    required int Function(String signalId, int totalOutputs, int totalCameras) selectOutputIndex,
  }) {
    if (existingPlcMap.containsKey(name)) {
      // PLC/EIP出力はここでは触らない（既存仕様）
      return;
    }

    final targetIndex = findOutputTargetIndex(
      formState: formState,
      name: name,
      existingOutputMap: existingOutputMap,
      outputControllers: outputControllers,
      reservedOutputStart: reservedOutputStart,
      selectOutputIndex: selectOutputIndex,
    );

    if (targetIndex >= 0 && targetIndex < outputControllers.length) {
      outputControllers[targetIndex].text = name;
    }
  }

  static void assignHwTriggerSignal({
    required String name,
    required Map<String, int> existingHwTriggerMap,
    required List<TextEditingController> hwTriggerControllers,
  }) {
    // 1) 同名が既にあった場所を優先 → 2) 空きスロット
    int targetIndex = existingHwTriggerMap[name] ?? -1;
    if (targetIndex == -1) {
      targetIndex = findFirstEmptyIndex(hwTriggerControllers);
    }
    if (targetIndex >= 0 && targetIndex < hwTriggerControllers.length) {
      hwTriggerControllers[targetIndex].text = name;
    }
  }

  static void assignAuxiliarySignal({
    required String name,
    required Map<String, int> existingAuxiliaryMap,
    required List<TextEditingController> auxiliaryControllers,
    required VoidCallback onNeedAdditionalSlot,
  }) {
    int targetIndex = existingAuxiliaryMap[name] ?? -1;
    if (targetIndex == -1) {
      targetIndex = findFirstEmptyIndex(auxiliaryControllers);
    }
    if (targetIndex == -1) {
      onNeedAdditionalSlot();
      targetIndex = auxiliaryControllers.length - 1;
    }
    if (targetIndex >= 0 && targetIndex < auxiliaryControllers.length) {
      auxiliaryControllers[targetIndex].text = name;
    }
  }
}


