import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../models/chart/signal_data.dart';
import '../../models/chart/signal_type.dart';
import '../../models/form/form_state.dart';
import 'form_tab_constants.dart';

/// `FormTab` の SignalData 再構築（マッピング）を担当するヘルパー。
///
/// 目的:
/// - `form_tab.dart` から「値引き継ぎ/フォールバック探索/portKey管理」を分離し、読みやすさを上げる
/// - UI 依存を最小にしつつ（TextEditingControllerは必要）、振る舞いは変えない
class FormTabSignalMapper {
  const FormTabSignalMapper._();

  // --- ポートキー生成 ---
  // NOTE: portValues は「信号名が変わっても波形を引き継げる」ように、ポート種別+index で保持します。
  static String dioInputKey(int index) => 'dio-input:$index';
  static String plcInputKey(int index) => 'plc-input:$index';
  static String hwKey(int index) => 'hw:$index';
  static String dioOutputKey(int index) => 'dio-output:$index';
  static String plcOutputKey(int index) => 'plc-output:$index';

  // --- フォールバック名 ---
  // NOTE: インポート/表示名ゆれ（Input1 / Input 1 / PLI1 等）を吸収するための候補群です。
  static List<String> inputFallbackNames(int index) => <String>[
    'Input${index + 1}',
    'Input ${index + 1}',
    'PLI${index + 1}',
    'ESI${index + 1}',
  ];

  static List<String> outputFallbackNames(int index) => <String>[
    'Output${index + 1}',
    'Output ${index + 1}',
    'PLO${index + 1}',
    'ESO${index + 1}',
  ];

  /// 信号名の比較用に正規化します（空白/区切り/プレフィックスを除去して小文字化）
  ///
  /// 例:
  /// - `"PLO1: BUSY"` -> `"busy"`
  /// - `"Output  1"` -> `"output1"`
  static String normalizeSignalName(String name) {
    var trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final int colonIndex = trimmed.indexOf(':');
    if (colonIndex >= 0) {
      trimmed = trimmed.substring(colonIndex + 1).trim();
    }
    return trimmed.replaceAll(RegExp(r'[\s_:-]+'), '').toLowerCase();
  }

  /// 既存の波形をできる限り維持しながら、値を解決する
  ///
  /// 優先順位:
  /// 1) portKey（primary/alternate）に紐づく前回値
  /// 2) 完全一致の信号名
  /// 3) additionalNames の完全一致
  /// 4) normalize した信号名の一致（name/additionalNames）
  /// 5) default（全0）
  static List<int> resolveSignalValues({
    required Map<String, List<int>> prevPortValues,
    required Map<String, List<int>> prevValueMap,
    required String primaryKey,
    String? alternateKey,
    required String name,
    List<String> additionalNames = const [],
    required int defaultWaveLength,
  }) {
    final List<int>? fromPort =
        prevPortValues[primaryKey] ??
        (alternateKey != null ? prevPortValues[alternateKey] : null);
    if (fromPort != null) {
      return List<int>.from(fromPort);
    }

    final List<int>? direct = prevValueMap[name];
    if (direct != null) {
      return List<int>.from(direct);
    }

    for (final fallbackName in additionalNames) {
      if (fallbackName.isEmpty) continue;
      final List<int>? fallback = prevValueMap[fallbackName];
      if (fallback != null) {
        return List<int>.from(fallback);
      }
    }

    final String normalized = normalizeSignalName(name);
    final MapEntry<String, List<int>>? normalizedEntry = prevValueMap.entries
        .firstWhereOrNull(
          (entry) => normalizeSignalName(entry.key) == normalized,
        );
    if (normalizedEntry != null) {
      return List<int>.from(normalizedEntry.value);
    }

    for (final fallbackName in additionalNames) {
      if (fallbackName.isEmpty) continue;
      final String fallbackNormalized = normalizeSignalName(fallbackName);
      final MapEntry<String, List<int>>? fallbackEntry = prevValueMap.entries
          .firstWhereOrNull(
            (entry) => normalizeSignalName(entry.key) == fallbackNormalized,
          );
      if (fallbackEntry != null) {
        return List<int>.from(fallbackEntry.value);
      }
    }

    return List.filled(defaultWaveLength, 0);
  }

  /// `prevValueMap` / `prevPortValues` から最長の長さを取り、波形長を決める
  ///
  /// NOTE: 既存波形の長さが 32 を超える場合はそれに追従し、既存がない場合のみ fallbackLength を採用します。
  static int computeDefaultWaveLength({
    required Map<String, List<int>> prevValueMap,
    required Map<String, List<int>> prevPortValues,
    required int fallbackLength,
  }) {
    int defaultWaveLength = 0;
    for (final values in prevValueMap.values) {
      defaultWaveLength = math.max(defaultWaveLength, values.length);
    }
    for (final values in prevPortValues.values) {
      defaultWaveLength = math.max(defaultWaveLength, values.length);
    }
    return defaultWaveLength == 0 ? fallbackLength : defaultWaveLength;
  }

  /// 入力信号マップを構築
  ///
  /// - `inferSignalType` / `inferVisibility` は FormTab 側のルールを注入するためのコールバックです。
  /// - PLC/EIP が有効な場合、DIO入力の後ろに PLC/EIP 入力を「別キー（inputCount + i）」で追加します。
  static Map<int, SignalData> buildInputSignalMap({
    required TimingFormState formState,
    required List<TextEditingController> inputControllers,
    required List<TextEditingController> plcEipInputControllers,
    required String plcEipOption,
    required List<bool> inputVisibility,
    required SignalType Function(int index, {bool isPlcEipChannel})
        inferSignalType,
    required bool Function(int index, {bool isPlcEipChannel}) inferVisibility,
    required Map<String, List<int>> prevPortValues,
    required Map<String, List<int>> prevValueMap,
    required int defaultWaveLength,
  }) {
    final Map<int, SignalData> inputSignalMap = {};

    for (int i = 0; i < formState.inputCount; i++) {
      if (i < inputControllers.length && inputControllers[i].text.isNotEmpty) {
        final String name = inputControllers[i].text;
        final List<int> values = resolveSignalValues(
          prevPortValues: prevPortValues,
          prevValueMap: prevValueMap,
          primaryKey: dioInputKey(i),
          alternateKey: plcInputKey(i),
          name: name,
          additionalNames: inputFallbackNames(i),
          defaultWaveLength: defaultWaveLength,
        );

        inputSignalMap[i] = SignalData(
          name: name,
          signalType: inferSignalType(i, isPlcEipChannel: false),
          values: values,
          isVisible: inferVisibility(i, isPlcEipChannel: false),
        );
      }
    }

    // PLC/EIP入力信号
    if (plcEipOption != PlcEipOptions.none) {
      for (int i = 0; i < formState.inputCount; i++) {
        if (i < plcEipInputControllers.length &&
            plcEipInputControllers[i].text.isNotEmpty) {
          final String name = plcEipInputControllers[i].text;
          final int key = formState.inputCount + i;
          final List<int> values = resolveSignalValues(
            prevPortValues: prevPortValues,
            prevValueMap: prevValueMap,
            primaryKey: plcInputKey(i),
            alternateKey: dioInputKey(i),
            name: name,
            additionalNames: inputFallbackNames(i),
            defaultWaveLength: defaultWaveLength,
          );
          inputSignalMap[key] = SignalData(
            name: name,
            signalType: inferSignalType(i, isPlcEipChannel: true),
            values: values,
            isVisible:
                inferVisibility(i, isPlcEipChannel: true),
          );
        }
      }
    }

    return inputSignalMap;
  }

  /// HWトリガー信号マップを構築
  ///
  /// - HWポート数に応じて controllers を走査し、空でないものだけ採用します。
  static Map<int, SignalData> buildHwTriggerSignalMap({
    required TimingFormState formState,
    required List<TextEditingController> hwTriggerControllers,
    required List<bool> hwTriggerVisibility,
    required Map<String, List<int>> prevPortValues,
    required Map<String, List<int>> prevValueMap,
    required int defaultWaveLength,
  }) {
    final Map<int, SignalData> hwTriggerSignalMap = {};

    for (int i = 0; i < formState.hwPort; i++) {
      if (i < hwTriggerControllers.length &&
          hwTriggerControllers[i].text.isNotEmpty) {
        final String name = hwTriggerControllers[i].text;
        final List<int> values = resolveSignalValues(
          prevPortValues: prevPortValues,
          prevValueMap: prevValueMap,
          primaryKey: hwKey(i),
          name: name,
          defaultWaveLength: defaultWaveLength,
        );
        hwTriggerSignalMap[i] = SignalData(
          name: name,
          signalType: SignalType.hwTrigger,
          values: values,
          isVisible: i < hwTriggerVisibility.length ? hwTriggerVisibility[i] : true,
        );
      }
    }

    return hwTriggerSignalMap;
  }

  /// 出力信号マップを構築
  ///
  /// - DIO 出力: `0..outputCount-1`
  /// - PLC/EIP 出力: `outputCount + i` として追加（チャート上では追加行扱い）
  static Map<int, SignalData> buildOutputSignalMap({
    required TimingFormState formState,
    required List<TextEditingController> outputControllers,
    required List<TextEditingController> plcEipOutputControllers,
    required String plcEipOption,
    required List<bool> outputVisibility,
    required Map<String, List<int>> prevPortValues,
    required Map<String, List<int>> prevValueMap,
    required int defaultWaveLength,
  }) {
    final Map<int, SignalData> outputSignalMap = {};

    // DIO出力
    for (int i = 0; i < formState.outputCount; i++) {
      if (i < outputControllers.length && outputControllers[i].text.isNotEmpty) {
        final String name = outputControllers[i].text;

        final List<int> values = resolveSignalValues(
          prevPortValues: prevPortValues,
          prevValueMap: prevValueMap,
          primaryKey: dioOutputKey(i),
          alternateKey: plcOutputKey(i),
          name: name,
          additionalNames: outputFallbackNames(i),
          defaultWaveLength: defaultWaveLength,
        );

        outputSignalMap[i] = SignalData(
          name: name,
          signalType: SignalType.output,
          values: values,
          isVisible: i < outputVisibility.length ? outputVisibility[i] : true,
        );
      }
    }

    // PLC/EIP出力
    if (plcEipOption != PlcEipOptions.none) {
      for (int i = 0; i < formState.outputCount; i++) {
        if (i < plcEipOutputControllers.length &&
            plcEipOutputControllers[i].text.isNotEmpty) {
          final String prefix =
              plcEipOption == PlcEipOptions.plc ? 'PLO' : 'ESO';
          final String base = '$prefix${i + 1}';
          final String user = plcEipOutputControllers[i].text;

          // 既存仕様:
          // - user が "PLO12" / "ESO12" 形式で、かつ数字部分が正しく解釈できるなら、そのまま採用
          // - それ以外は "PLO12: <user>" / "ESO12: <user>" を採用（userが空なら base）
          String label;
          if ((user.startsWith('PLO') || user.startsWith('ESO')) &&
              user.length > 3) {
            final String portStr = user.substring(3);
            final int? port = int.tryParse(portStr);
            if (port != null && port > 0) {
              label = user;
            } else {
              label = user.isNotEmpty ? '$base: $user' : base;
            }
          } else {
            label = user.isNotEmpty ? '$base: $user' : base;
          }
          final int key = formState.outputCount + i;

          final String fallbackBase = 'Output ${i + 1}';
          final List<String> additionalNames =
              <String>[
                user,
                base,
                'Output${i + 1}',
                fallbackBase,
                ...outputFallbackNames(i),
              ].where((element) => element.trim().isNotEmpty).toSet().toList();

          final List<int> values = resolveSignalValues(
            prevPortValues: prevPortValues,
            prevValueMap: prevValueMap,
            primaryKey: plcOutputKey(i),
            alternateKey: dioOutputKey(i),
            name: label,
            additionalNames: additionalNames,
            defaultWaveLength: defaultWaveLength,
          );

          outputSignalMap[key] = SignalData(
            name: label,
            signalType: SignalType.output,
            values: values,
            isVisible: i < outputVisibility.length ? outputVisibility[i] : true,
          );
        }
      }
    }

    return outputSignalMap;
  }

  /// portValues（前回値を引き継ぐためのキー→波形マップ）を組み立てる
  ///
  /// 目的:
  /// - 再構築後も「同じポートの波形」を引き継げるようにする
  /// - 信号名変更や順序入れ替えに強くする
  static Map<String, List<int>> buildPortValues({
    required TimingFormState formState,
    required Map<int, SignalData> inputSignalMap,
    required Map<int, SignalData> outputSignalMap,
    required Map<int, SignalData> hwTriggerSignalMap,
  }) {
    final Map<String, List<int>> newPortValues = {};

    for (final entry in inputSignalMap.entries) {
      if (entry.key < formState.inputCount) {
        newPortValues[dioInputKey(entry.key)] = List<int>.from(entry.value.values);
      } else {
        final plcIndex = entry.key - formState.inputCount;
        newPortValues[plcInputKey(plcIndex)] = List<int>.from(entry.value.values);
      }
    }
    for (final entry in hwTriggerSignalMap.entries) {
      newPortValues[hwKey(entry.key)] = List<int>.from(entry.value.values);
    }
    for (final entry in outputSignalMap.entries) {
      if (entry.key < formState.outputCount) {
        newPortValues[dioOutputKey(entry.key)] = List<int>.from(entry.value.values);
      } else {
        final plcIndex = entry.key - formState.outputCount;
        newPortValues[plcOutputKey(plcIndex)] = List<int>.from(entry.value.values);
      }
    }

    return newPortValues;
  }

  /// signalDataList を信号マップから組み立て、前回順序を可能な範囲で維持する
  ///
  /// NOTE:
  /// - `prevOrder` に存在した信号名は可能な限りその順序に寄せます（完全一致のみ）。
  /// - Code/Command Option の強制挿入など、FormTab固有の「追加信号」は呼び出し側が担当します。
  static List<SignalData> populateSignalDataList({
    required TimingFormState formState,
    required String plcEipOption,
    required Map<int, SignalData> inputSignalMap,
    required Map<int, SignalData> outputSignalMap,
    required Map<int, SignalData> hwTriggerSignalMap,
    required List<String> prevOrder,
  }) {
    final List<SignalData> list = [];

    // 入力
    for (int i = 0; i < formState.inputCount; i++) {
      final v = inputSignalMap[i];
      if (v != null) list.add(v);
    }

    // PLC/EIP入力
    if (plcEipOption != PlcEipOptions.none) {
      for (int i = 0; i < formState.inputCount; i++) {
        final int key = formState.inputCount + i;
        final v = inputSignalMap[key];
        if (v != null) list.add(v);
      }
    }

    // HW
    for (int i = 0; i < formState.hwPort; i++) {
      final v = hwTriggerSignalMap[i];
      if (v != null) list.add(v);
    }

    // 出力
    for (int i = 0; i < formState.outputCount; i++) {
      final v = outputSignalMap[i];
      if (v != null) list.add(v);
    }

    // 追加出力（PLC/EIP等）
    final List<int> extraKeys =
        outputSignalMap.keys.where((k) => k >= formState.outputCount).toList()
          ..sort();
    for (final k in extraKeys) {
      list.add(outputSignalMap[k]!);
    }

    if (prevOrder.isNotEmpty) {
      list.sort((a, b) {
        final int ia = prevOrder.indexOf(a.name);
        final int ib = prevOrder.indexOf(b.name);
        if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
        if (ia >= 0) return -1;
        if (ib >= 0) return 1;
        return 0;
      });
    }

    return list;
  }
}


