import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../models/ziq/ziq_import_result.dart';
import '../models/ziq/output_assignment.dart';
import '../models/chart/signal_data.dart';
import '../models/chart/signal_type.dart';
import '../models/chart/io_channel_source.dart';
import '../models/form/form_state.dart';
import '../utils/vxvismgr_parser.dart';
import '../utils/vxvismgr_mapping_loader.dart';
import '../utils/code_trigger_helpers.dart';
import '../utils/csv_io_log_parser.dart';
import '../utils/compute_workers.dart';
import '../providers/form_controllers_notifier.dart';
import '../providers/timing_chart_controller.dart';
import '../widgets/form/form_tab.dart' show FormTabState;
import '../widgets/form/form_tab_constants.dart' show SignalNames;

/// ZIQインポート処理を担当するサービスクラス
class ZiqImportService {
  /// ZIQファイルをインポートして結果を返す
  ///
  /// [files] ZIQ(zip) から抽出した必要ファイル群
  /// [currentFormState] 現在のフォーム状態
  /// [controllersNotifier] コントローラーの管理
  /// [chartController] チャートコントローラー
  /// [formTabState] フォームタブの状態（null可）
  ///
  /// 戻り値: インポート結果
  static Future<ZiqImportResult> importZiq({
    required Map<String, String> files,
    required TimingFormState currentFormState,
    required FormControllersNotifier controllersNotifier,
    required TimingChartController chartController,
    FormTabState? formTabState,
  }) async {
    final mapping = await VxVisMgrMappingLoader.loadMapping();

    final iniContent = files['vxVisMgr.ini'];
    final dioCsvContent = files['DioMonitorLog.csv'];
    final plcCsvContent = files['Plc_DioMonitorLog.csv'];
    final fnlCsvContent = files['FNL_DioMonitorLog.csv'];

    // INIファイルの解析
    final iniResult = _parseIniFile(
      iniContent,
      mapping,
      currentFormState,
      hasPlcCsv: plcCsvContent != null && plcCsvContent.isNotEmpty,
      hasEipCsv: fnlCsvContent != null && fnlCsvContent.isNotEmpty,
    );

    // CSVファイルの処理とチャートデータの構築
    final chartData = await _processCsvFiles(
      dioCsvContent: dioCsvContent,
      plcCsvContent: plcCsvContent,
      fnlCsvContent: fnlCsvContent,
      iniResult: iniResult,
      currentFormState: currentFormState,
      controllersNotifier: controllersNotifier,
      chartController: chartController,
    );

    return ZiqImportResult(
      vxVisMgrIniContent: iniContent,
      dioMonitorLogCsvContent: dioCsvContent,
      plcDioMonitorLogCsvContent: plcCsvContent,
      fnlDioMonitorLogCsvContent: fnlCsvContent,
      vxvisNameToSuggestionId: mapping,
      enabledStatusSignals: iniResult.enabledStatusSignals,
      enabledSignalStructures: iniResult.enabledSignalStructures,
      dioOutputAssignments: iniResult.dioOutputAssignments,
      plcEipOutputAssignments: iniResult.plcEipOutputAssignments,
      plcEipOption: iniResult.plcEipOption,
      triggerOption: iniResult.triggerOption,
      codeTriggerOnPlcEip: iniResult.codeTriggerOnPlcEip,
      useDioTriggerPortWithVirtualIo: iniResult.useDioTriggerPortWithVirtualIo,
      inputPorts: iniResult.inputPorts,
      outputPorts: iniResult.outputPorts,
      chartSignals: chartData.signals,
      chartPortNumbers: chartData.portNumbers,
      chartIoSources: chartData.ioSources,
      stepDurationsMs: chartData.stepDurationsMs,
    );
  }

  /// INIファイルの解析結果
  static _IniParseResult _parseIniFile(
    String? iniContent,
    Map<String, String> mapping,
    TimingFormState currentFormState, {
    bool hasPlcCsv = false,
    bool hasEipCsv = false,
  }) {
    if (iniContent == null) {
      return _IniParseResult(
        enabledStatusSignals: [],
        enabledSignalStructures: [],
        dioOutputAssignments: [],
        plcEipOutputAssignments: [],
        plcEipOption: 'None',
        triggerOption: currentFormState.triggerOption,
        inputPorts: null,
        outputPorts: null,
        shutdownMonitor: false,
        codeTriggerOnPlcEip: false,
        useDioTriggerPortWithVirtualIo: false,
      );
    }

    // IOActiveの解析
    final ioActive = VxVisMgrParser.parseIOActive(iniContent);
    final inputPorts = ioActive?.pinPorts;
    final outputPorts = ioActive?.poutPorts;
    final shutdownMonitor = VxVisMgrParser.parseShutdownMonitor(iniContent);

    // StatusSignalSettingsの解析
    final all = VxVisMgrParser.parseStatusSignalSettings(iniContent);
    final enabledSignalStructures = all.where((s) => s.enabled).toList();
    final enabledStatusSignals =
        enabledSignalStructures.map((e) => e.name).toList();

    // IOSettingの解析
    final ioSetting = VxVisMgrParser.parseIOSetting(iniContent);
    String triggerOption = currentFormState.triggerOption;
    String plcEipOption = 'None';

    if (ioSetting != null) {
      if (ioSetting.plcLinkEnabled) {
        plcEipOption = 'PLC';
      } else if (ioSetting.ethernetIpEnabled) {
        plcEipOption = 'EIP';
      } else if (ioSetting.useVirtualIoOnTrigger == 1) {
        plcEipOption = 'PLC';
      }

      final bool isPlcCommand =
          ioSetting.plcLinkEnabled && ioSetting.plcCommandEnabled;
      final bool isEipCommand =
          ioSetting.ethernetIpEnabled && ioSetting.ethernetIpCommandEnabled;
      if (isPlcCommand || isEipCommand) {
        triggerOption = 'Command Trigger';
      } else {
        triggerOption =
            ioSetting.triggerMode == 0 ? 'Code Trigger' : 'Single Trigger';
      }
    }

    if (triggerOption == 'Code Trigger' && plcEipOption == 'None') {
      if (hasPlcCsv) {
        plcEipOption = 'PLC';
      } else if (hasEipCsv) {
        plcEipOption = 'EIP';
      }
    }

    final bool useDioTriggerPortWithVirtualIo =
        ioSetting?.useDioTriggerPortWithVirtualIo == 1;
    final bool codeTriggerOnPlcEip =
        triggerOption == 'Code Trigger' && plcEipOption != 'None';

    // 出力割り当ての作成
    final dioOutputAssignments = <OutputAssignment>[];
    final plcEipOutputAssignments = <OutputAssignment>[];
    final assignedSignalNames = <String>{};

    for (final s in enabledSignalStructures) {
      if (!s.portNoByIndex.containsKey(0)) continue;
      final n0 = s.portNoByIndex[0]!;
      final type = s.portTypeByIndex[0];
      final suggestionId = mapping[s.name] ?? '';

      final signalName = suggestionId.isNotEmpty ? suggestionId : s.name;

      if (assignedSignalNames.contains(signalName)) {
        debugPrint('INI信号名が重複しています: $signalName (${s.name})');
        continue;
      }
      assignedSignalNames.add(signalName);

      final assignment = OutputAssignment(
        name: s.name,
        suggestionId: suggestionId,
        portNo0: n0 + 1,
        outputIndex1Based: n0 + 1,
      );

      if (type != null && type != 0) {
        plcEipOutputAssignments.add(assignment);
      } else {
        dioOutputAssignments.add(assignment);
      }
    }

    return _IniParseResult(
      enabledStatusSignals: enabledStatusSignals,
      enabledSignalStructures: enabledSignalStructures,
      dioOutputAssignments: dioOutputAssignments,
      plcEipOutputAssignments: plcEipOutputAssignments,
      plcEipOption: plcEipOption,
      triggerOption: triggerOption,
      inputPorts: inputPorts,
      outputPorts: outputPorts,
      shutdownMonitor: shutdownMonitor,
      codeTriggerOnPlcEip: codeTriggerOnPlcEip,
      useDioTriggerPortWithVirtualIo: useDioTriggerPortWithVirtualIo,
    );
  }

  /// CSVファイルの処理とチャートデータの構築
  static Future<_ChartDataResult> _processCsvFiles({
    required String? dioCsvContent,
    required String? plcCsvContent,
    required String? fnlCsvContent,
    required _IniParseResult iniResult,
    required TimingFormState currentFormState,
    required FormControllersNotifier controllersNotifier,
    required TimingChartController chartController,
  }) async {
    // CSVペアの作成
    final csvPairs = <MapEntry<String, String>>[];
    if (dioCsvContent != null && dioCsvContent.isNotEmpty) {
      csvPairs.add(MapEntry('DIO', dioCsvContent));
    }
    if (plcCsvContent != null && plcCsvContent.isNotEmpty) {
      csvPairs.add(MapEntry('PLC', plcCsvContent));
    }
    if (fnlCsvContent != null && fnlCsvContent.isNotEmpty) {
      csvPairs.add(MapEntry('EIP', fnlCsvContent));
    }

    if (csvPairs.isEmpty) {
      return _ChartDataResult(
        signals: [],
        portNumbers: [],
        ioSources: [],
        stepDurationsMs: [],
      );
    }

    // タイムラインの解析（重い CSV 処理は Isolate で実行）
    final parsePayload = CsvTimelineParsePayload(
      sources: csvPairs.map((e) => e.key).toList(),
      contents: csvPairs.map((e) => e.value).toList(),
    );
    final parsed = await compute(parseCsvTimelineIsolate, parsePayload);
    final timeline = parsed.timeline;
    final stepDurationsMs = parsed.stepDurationsMs;

    // チャートデータの構築（この部分は非常に大きいので、別メソッドに分割）
    final chartData = _buildChartData(
      timeline: timeline,
      csvPairs: csvPairs,
      iniResult: iniResult,
      currentFormState: currentFormState,
      controllersNotifier: controllersNotifier,
      stepDurationsMs: stepDurationsMs,
    );

    return _ChartDataResult(
      signals: chartData.signals,
      portNumbers: chartData.portNumbers,
      ioSources: chartData.ioSources,
      stepDurationsMs: stepDurationsMs,
    );
  }

  /// チャートデータの構築
  /// このメソッドは非常に大きいため、さらに分割することを推奨
  static _ChartDataResult _buildChartData({
    required CsvTimeline timeline,
    required List<MapEntry<String, String>> csvPairs,
    required _IniParseResult iniResult,
    required TimingFormState currentFormState,
    required FormControllersNotifier controllersNotifier,
    required List<double> stepDurationsMs,
  }) {
    final timeLength = timeline.entries.length;
    if (timeLength == 0) {
      return _ChartDataResult(
        signals: [],
        portNumbers: [],
        ioSources: [],
        stepDurationsMs: stepDurationsMs,
      );
    }

    // アクティブポートの検出
    final activePorts = ActivePortDetector.detectActivePorts(csvPairs);
    final activeInputPorts = ActivePortDetector.detectActiveInputPorts(
      csvPairs,
    );

    // 定義済みポートの計算
    final definedPorts = <String, Set<int>>{};
    for (final a in iniResult.dioOutputAssignments) {
      definedPorts.putIfAbsent('DIO', () => <int>{}).add(a.portNo0);
    }
    for (final a in iniResult.plcEipOutputAssignments) {
      final source = iniResult.plcEipOption == 'PLC' ? 'PLC' : 'EIP';
      definedPorts.putIfAbsent(source, () => <int>{}).add(a.portNo0);
    }

    // 未定義のアクティブポートの計算
    final undefinedActivePorts = <String, Set<int>>{};
    for (final source in activePorts.keys) {
      final defined = definedPorts[source] ?? <int>{};
      final active = activePorts[source]!;
      final undefined = active.difference(defined);
      if (undefined.isNotEmpty) {
        undefinedActivePorts[source] = undefined;
      }
    }

    // 割り当て済み信号名の収集
    final assignedNames = <String>{};
    for (final a in iniResult.dioOutputAssignments) {
      assignedNames.add(a.suggestionId.isNotEmpty ? a.suggestionId : a.name);
    }
    for (final a in iniResult.plcEipOutputAssignments) {
      assignedNames.add(a.suggestionId.isNotEmpty ? a.suggestionId : a.name);
    }

    // コントローラーへの信号名の設定
    final inputControllers = controllersNotifier.inputControllers;
    final plcEipInputControllers = controllersNotifier.plcEipInputControllers;
    final outputControllers = controllersNotifier.outputControllers;
    final plcEipOutputControllers = controllersNotifier.plcEipOutputControllers;

    // INIファイルから解析したステータス信号の信号名をコントローラーに設定
    // DIO出力割り当ての信号名をコントローラーに設定
    for (final a in iniResult.dioOutputAssignments) {
      final outIdx = a.outputIndex1Based - 1;
      if (outIdx >= 0 && outIdx < outputControllers.length) {
        final signalName = a.suggestionId.isNotEmpty ? a.suggestionId : a.name;
        if (outputControllers[outIdx].text.isEmpty) {
          outputControllers[outIdx].text = signalName;
          debugPrint(
            'INI信号名: $signalName -> DIO:${a.portNo0} (index:${a.outputIndex1Based})',
          );
        }
      }
    }

    // PLC/EIP出力割り当ての信号名をコントローラーに設定
    if (iniResult.plcEipOption != 'None') {
      for (final a in iniResult.plcEipOutputAssignments) {
        final outIdx = a.outputIndex1Based - 1;
        if (outIdx >= 0 && outIdx < plcEipOutputControllers.length) {
          final signalName =
              a.suggestionId.isNotEmpty ? a.suggestionId : a.name;
          if (plcEipOutputControllers[outIdx].text.isEmpty) {
            plcEipOutputControllers[outIdx].text = signalName;
            debugPrint(
              'INI信号名: $signalName -> ${iniResult.plcEipOption}:${a.portNo0} (index:${a.outputIndex1Based})',
            );
          }
        }
      }
    }

    // コントローラーへの信号名の設定（undefinedActivePorts用）

    for (final source in undefinedActivePorts.keys) {
      final ports = undefinedActivePorts[source]!;
      for (final port in ports) {
        String signalName;
        if (source == 'DIO') {
          signalName = 'Output$port';
        } else if (source == 'PLC') {
          signalName = 'PLO$port';
        } else if (source == 'EIP') {
          signalName = 'ESO$port';
        } else {
          continue;
        }

        if (assignedNames.contains(signalName)) {
          debugPrint('CSV信号名が重複しています: $signalName ($source:$port)');
          continue;
        }

        if (source == 'DIO' && port <= outputControllers.length) {
          if (outputControllers[port - 1].text.isEmpty) {
            outputControllers[port - 1].text = signalName;
            debugPrint('CSV信号名: $signalName -> DIO:$port');
          }
        } else if ((source == 'PLC' || source == 'EIP') &&
            port <= plcEipOutputControllers.length) {
          if (plcEipOutputControllers[port - 1].text.isEmpty) {
            plcEipOutputControllers[port - 1].text = signalName;
            debugPrint('CSV信号名: $signalName -> $source:$port');
          }
        }
      }
    }

    // 入力ポートの処理
    for (final entry in activeInputPorts.entries) {
      final source = entry.key;
      final ports = entry.value.toList()..sort();
      for (final port in ports) {
        if (source == 'DIO') {
          if (port >= 1 && port <= inputControllers.length) {
            if (inputControllers[port - 1].text.isEmpty) {
              inputControllers[port - 1].text = 'Input$port';
              debugPrint('CSV信号名: Input$port -> DIO:$port');
            }
          }
        } else if (source == 'PLC' || source == 'EIP') {
          if (port >= 1 && port <= plcEipInputControllers.length) {
            if (plcEipInputControllers[port - 1].text.isEmpty) {
              final prefix = (source == 'PLC') ? 'PLI' : 'ESI';
              final name = '$prefix$port';
              plcEipInputControllers[port - 1].text = name;
              debugPrint('CSV信号名: $name -> $source:$port');
            }
          }
        }
      }
    }

    // トリガー / Code Trigger 入力名の設定
    final dioInputCount =
        iniResult.inputPorts ?? currentFormState.inputCount;
    if (iniResult.triggerOption == 'Single Trigger' &&
        inputControllers.isNotEmpty) {
      controllersNotifier.setInputText(0, SignalNames.trigger);
    } else if (iniResult.triggerOption == 'Code Trigger') {
      if (iniResult.codeTriggerOnPlcEip) {
        for (final idx in CodeTriggerHelpers.codeBitIndices(dioInputCount)) {
          if (idx >= plcEipInputControllers.length) continue;
          final name = CodeTriggerHelpers.nameForIndex(idx, dioInputCount);
          if (name != null) {
            plcEipInputControllers[idx].text = name;
          }
        }
        if (iniResult.useDioTriggerPortWithVirtualIo) {
          if (inputControllers.isNotEmpty) {
            controllersNotifier.setInputText(0, SignalNames.trigger);
          }
        } else if (plcEipInputControllers.isNotEmpty) {
          plcEipInputControllers[0].text = SignalNames.trigger;
        }
      } else if (inputControllers.isNotEmpty) {
        controllersNotifier.setInputText(0, SignalNames.trigger);
      }
    }

    // ShutdownMonitor=1 の場合、DIO最終入力ポートにシステム起動保持信号を強制設定
    final dioInputPortCount =
        iniResult.inputPorts ?? currentFormState.inputCount;
    final lastDioInputIdx = dioInputPortCount - 1;
    if (iniResult.shutdownMonitor && lastDioInputIdx >= 0) {
      if (dioInputPortCount > inputControllers.length) {
        controllersNotifier.setInputCount(dioInputPortCount);
      }
      if (lastDioInputIdx < inputControllers.length) {
        inputControllers[lastDioInputIdx].text =
            SignalNames.systemKeepRunningSignal;
        debugPrint(
          'ShutdownMonitor: ${SignalNames.systemKeepRunningSignal} -> DIO:$dioInputPortCount',
        );
      }
    }

    // 出力信号の処理
    final outSource = <String, String>{};
    final outNamesDio = <String>[];
    final outTypesDio = <SignalType>[];
    final outPortsDio = <int>[];
    final outValuesDio = <List<int>>[];
    final outNamesPlc = <String>[];
    final outTypesPlc = <SignalType>[];
    final outPortsPlc = <int>[];
    final outValuesPlc = <List<int>>[];

    // DIO出力信号の処理
    int dioOutputs = currentFormState.outputCount;
    for (final a in iniResult.dioOutputAssignments) {
      if (a.outputIndex1Based > dioOutputs) dioOutputs = a.outputIndex1Based;
    }
    for (final source in undefinedActivePorts.keys) {
      if (source == 'DIO') {
        final ports = undefinedActivePorts[source]!;
        for (final port in ports) {
          if (port > dioOutputs) dioOutputs = port;
        }
      }
    }

    final outChartRowsDio = List.generate(
      dioOutputs,
      (_) => List.filled(timeLength, 0),
    );

    // DIO出力割り当ての処理
    for (final a in iniResult.dioOutputAssignments) {
      final outIdx = a.outputIndex1Based - 1;
      final portK = a.portNo0;
      if (outIdx < 0 || outIdx >= dioOutputs) continue;
      int last = 0;
      for (int t = 0; t < timeLength; t++) {
        final e = timeline.entries[t];
        if (e.type == 'OUT' && (e.source == null || e.source == 'DIO')) {
          final row = e.bits;
          final colIdx = row.length - portK;
          final v =
              (colIdx >= 0 && colIdx < row.length && row[colIdx] != 0) ? 1 : 0;
          last = v;
          outChartRowsDio[outIdx][t] = v;
        } else {
          outChartRowsDio[outIdx][t] = last;
        }
      }
    }

    // 未定義DIO出力ポートの処理
    for (final source in undefinedActivePorts.keys) {
      if (source == 'DIO') {
        final ports = undefinedActivePorts[source]!;
        for (final port in ports) {
          final outIdx = port - 1;
          if (outIdx < 0 || outIdx >= dioOutputs) continue;
          int last = 0;
          for (int t = 0; t < timeLength; t++) {
            final e = timeline.entries[t];
            if (e.type == 'OUT' && (e.source == null || e.source == 'DIO')) {
              final row = e.bits;
              final colIdx = row.length - port;
              final v =
                  (colIdx >= 0 && colIdx < row.length && row[colIdx] != 0)
                      ? 1
                      : 0;
              last = v;
              outChartRowsDio[outIdx][t] = v;
            } else {
              outChartRowsDio[outIdx][t] = last;
            }
          }
        }
      }
    }

    // DIO出力信号名の収集
    for (int i = 0; i < dioOutputs; i++) {
      if (i >= outputControllers.length) continue;
      final name = outputControllers[i].text.trim();
      if (name.isEmpty) continue;
      outNamesDio.add(name);
      outTypesDio.add(SignalType.output);
      outPortsDio.add(i + 1);
      outValuesDio.add(outChartRowsDio[i]);

      final s = outSource[name];
      if (s == null) {
        outSource[name] = 'DIO';
      } else if (s == 'PLC' || s == 'EIP' || s == 'PLC/EIP') {
        outSource[name] = 'PLC/EIP';
      }
    }

    // PLC/EIP出力信号の処理
    if (iniResult.plcEipOption != 'None') {
      int plcOutputs = currentFormState.outputCount;
      for (final a in iniResult.plcEipOutputAssignments) {
        if (a.outputIndex1Based > plcOutputs) plcOutputs = a.outputIndex1Based;
      }

      for (final source in undefinedActivePorts.keys) {
        if (source == 'PLC' || source == 'EIP') {
          final ports = undefinedActivePorts[source]!;
          for (final port in ports) {
            if (port > plcOutputs) plcOutputs = port;
          }
        }
      }

      final outChartRowsPlc = List.generate(
        plcOutputs,
        (_) => List.filled(timeLength, 0),
      );
      bool seenPlc = false;
      bool seenEip = false;

      // PLC/EIP出力割り当ての処理
      for (final a in iniResult.plcEipOutputAssignments) {
        final outIdx = a.outputIndex1Based - 1;
        final portK = a.portNo0;
        if (outIdx < 0 || outIdx >= plcOutputs) continue;
        int last = 0;
        for (int t = 0; t < timeLength; t++) {
          final e = timeline.entries[t];
          if (e.type == 'OUT' && (e.source == 'PLC' || e.source == 'EIP')) {
            final row = e.bits;
            final colIdx = row.length - portK;
            final v =
                (colIdx >= 0 && colIdx < row.length && row[colIdx] != 0)
                    ? 1
                    : 0;
            last = v;
            outChartRowsPlc[outIdx][t] = v;
            if (e.source == 'PLC') {
              seenPlc = true;
            } else if (e.source == 'EIP') {
              seenEip = true;
            }
          } else {
            outChartRowsPlc[outIdx][t] = last;
          }
        }
      }

      // 未定義PLC/EIP出力ポートの処理
      for (final source in undefinedActivePorts.keys) {
        if (source == 'PLC' || source == 'EIP') {
          final ports = undefinedActivePorts[source]!;
          for (final port in ports) {
            final outIdx = port - 1;
            if (outIdx < 0 || outIdx >= plcOutputs) continue;
            int last = 0;
            for (int t = 0; t < timeLength; t++) {
              final e = timeline.entries[t];
              if (e.type == 'OUT' && e.source == source) {
                final row = e.bits;
                final colIdx = row.length - port;
                final v =
                    (colIdx >= 0 && colIdx < row.length && row[colIdx] != 0)
                        ? 1
                        : 0;
                last = v;
                outChartRowsPlc[outIdx][t] = v;
                if (e.source == 'PLC') {
                  seenPlc = true;
                } else if (e.source == 'EIP') {
                  seenEip = true;
                }
              } else {
                outChartRowsPlc[outIdx][t] = last;
              }
            }
          }
        }
      }

      // PLC/EIP出力信号名の収集
      for (int i = 0; i < plcOutputs; i++) {
        if (i >= plcEipOutputControllers.length) continue;
        final name = plcEipOutputControllers[i].text.trim();
        if (name.isEmpty) continue;
        outNamesPlc.add(name);
        outTypesPlc.add(SignalType.output);
        outPortsPlc.add(i + 1);
        outValuesPlc.add(outChartRowsPlc[i]);

        final src =
            (seenPlc && seenEip) ? 'PLC/EIP' : (seenPlc ? 'PLC' : 'EIP');
        final s = outSource[name];
        if (s == null) {
          outSource[name] = src;
        } else if (s != src) {
          outSource[name] = 'PLC/EIP';
        }
      }
    }

    // 入力信号の処理
    int inputs = currentFormState.inputCount;
    if (iniResult.shutdownMonitor && dioInputPortCount > inputs) {
      inputs = dioInputPortCount;
    }
    final inChart = <List<int>>[];
    final inNames = <String>[];
    final inTypes = <SignalType>[];

    // DIO入力信号の処理
    for (int idx0 = 0; idx0 < inputs; idx0++) {
      final bool isShutdownKeepPort =
          iniResult.shutdownMonitor && idx0 == lastDioInputIdx;

      String name;
      if (isShutdownKeepPort) {
        name = SignalNames.systemKeepRunningSignal;
      } else {
        if (idx0 >= inputControllers.length) continue;
        name = inputControllers[idx0].text.trim();
        if (name.isEmpty) continue;
      }

      late final List<int> series;
      if (isShutdownKeepPort) {
        // ShutdownMonitor=1: DIO最終ポートはタイムライン全区間を High にする
        series = List.filled(timeLength, 1);
      } else {
        series = List.filled(timeLength, 0);
        for (int t = 0; t < timeLength; t++) {
          final e = timeline.entries[t];
          if (e.type == 'IN' && e.source == 'DIO') {
            final row = e.bits;
            final col = row.length - (idx0 + 1);
            if (col >= 0 && col < row.length) {
              series[t] = row[col] != 0 ? 1 : 0;
            }
          } else if (e.type != 'IN') {
            series[t] = 0;
          }
        }
      }
      inChart.add(series);
      inNames.add(name);
      inTypes.add(SignalType.input);
    }

    // PLC/EIP入力信号の処理
    for (int idx0 = 0; idx0 < inputs; idx0++) {
      if (idx0 >= plcEipInputControllers.length) continue;
      final name = plcEipInputControllers[idx0].text.trim();
      if (name.isEmpty) continue;

      bool allowPlc;
      bool allowEip;
      if (name.startsWith('PLI')) {
        allowPlc = true;
        allowEip = false;
      } else if (name.startsWith('ESI')) {
        allowPlc = false;
        allowEip = true;
      } else {
        if (iniResult.plcEipOption == 'PLC') {
          allowPlc = true;
          allowEip = false;
        } else if (iniResult.plcEipOption == 'EIP') {
          allowPlc = false;
          allowEip = true;
        } else {
          allowPlc = true;
          allowEip = true;
        }
      }

      final series = List.filled(timeLength, 0);
      for (int t = 0; t < timeLength; t++) {
        final e = timeline.entries[t];
        if (e.type == 'IN') {
          final isPlc = e.source == 'PLC';
          final isEip = e.source == 'EIP';
          if ((isPlc && allowPlc) || (isEip && allowEip)) {
            final row = e.bits;
            final col = row.length - (idx0 + 1);
            if (col >= 0 && col < row.length) {
              series[t] = row[col] != 0 ? 1 : 0;
            }
          }
        } else if (e.type != 'IN') {
          series[t] = 0;
        }
      }
      inChart.add(series);
      inNames.add(name);
      inTypes.add(SignalType.input);
    }

    // チャートデータの結合
    final combinedValues = <List<int>>[];
    final combinedNames = <String>[];
    final combinedTypes = <SignalType>[];

    List<int>? synthesizedCodeOption;
    if (iniResult.codeTriggerOnPlcEip &&
        iniResult.triggerOption == 'Code Trigger' &&
        iniResult.plcEipOption != 'None') {
      final source = iniResult.plcEipOption == 'PLC' ? 'PLC' : 'EIP';
      final bitSeries = <List<int>>[];
      for (final idx0 in CodeTriggerHelpers.codeBitIndices(dioInputCount)) {
        bitSeries.add(
          _readInputSeriesFromTimeline(
            timeline: timeline,
            timeLength: timeLength,
            source: source,
            port1Based: idx0 + 1,
          ),
        );
      }
      synthesizedCodeOption =
          CodeTriggerHelpers.synthesizeCodeOptionWave(bitSeries);
    }

    // CODE_OPTIONの処理
    int idxCode = inNames.indexOf(SignalNames.codeOption);
    if (idxCode != -1) {
      combinedNames.add(inNames[idxCode]);
      combinedTypes.add(inTypes[idxCode]);
      combinedValues.add(inChart[idxCode]);
    } else if (synthesizedCodeOption != null) {
      combinedNames.add(SignalNames.codeOption);
      combinedTypes.add(SignalType.input);
      combinedValues.add(synthesizedCodeOption);
    } else {
      if (iniResult.triggerOption == 'Code Trigger') {
        combinedNames.add(SignalNames.codeOption);
        combinedTypes.add(SignalType.input);
        combinedValues.add(List<int>.filled(timeLength, 0));
      }
    }

    // Command Optionの処理
    int idxCmd = inNames.indexOf('Command Option');
    if (idxCmd != -1) {
      combinedNames.add(inNames[idxCmd]);
      combinedTypes.add(inTypes[idxCmd]);
      combinedValues.add(inChart[idxCmd]);
    }

    // その他の入力信号の追加
    for (int i = 0; i < inNames.length; i++) {
      if (i == idxCode || i == idxCmd) continue;
      final name = inNames[i];
      if (iniResult.triggerOption == 'Code Trigger' &&
          CodeTriggerHelpers.isCodeBitName(name, dioInputCount)) {
        continue;
      }
      combinedNames.add(name);
      combinedTypes.add(inTypes[i]);
      combinedValues.add(inChart[i]);
    }

    // HW Triggerの処理
    if (currentFormState.hwPort > 0) {
      final hwTriggerControllers = controllersNotifier.hwTriggerControllers;
      for (int j = 0; j < currentFormState.hwPort; j++) {
        final hwName =
            (j < hwTriggerControllers.length)
                ? hwTriggerControllers[j].text.trim()
                : '';
        if (hwName.isEmpty) continue;
        combinedNames.add(hwName);
        combinedTypes.add(SignalType.hwTrigger);
        combinedValues.add(List<int>.filled(timeLength, 0));
      }
    }

    // 出力信号のマージと追加
    if (timeLength > 0) {
      final dioMap = <String, List<int>>{};
      for (int i = 0; i < outNamesDio.length; i++) {
        dioMap[outNamesDio[i]] = outValuesDio[i];
      }
      final plcMap = <String, List<int>>{};
      for (int i = 0; i < outNamesPlc.length; i++) {
        plcMap[outNamesPlc[i]] = outValuesPlc[i];
      }

      final orderedOutputNames = <String>[];
      for (final n in outNamesDio) {
        if (!orderedOutputNames.contains(n)) orderedOutputNames.add(n);
      }
      for (final n in outNamesPlc) {
        if (!orderedOutputNames.contains(n)) orderedOutputNames.add(n);
      }

      final mergedValuesByName = <String, List<int>>{};
      for (final n in orderedOutputNames) {
        final dio = dioMap[n];
        final plc = plcMap[n];
        if (dio == null && plc != null) {
          mergedValuesByName[n] = plc;
        } else if (dio != null && plc == null) {
          mergedValuesByName[n] = dio;
        } else if (dio != null && plc != null) {
          final len = math.min(dio.length, plc.length);
          final merged = List<int>.from(dio);
          for (int t = 0; t < len; t++) {
            if (plc[t] != 0) merged[t] = plc[t];
          }
          mergedValuesByName[n] = merged;
        }
      }

      for (final n in orderedOutputNames) {
        final v = mergedValuesByName[n];
        if (v == null) continue;
        combinedNames.add(n);
        combinedTypes.add(SignalType.output);
        combinedValues.add(v);
      }
    }

    // SignalDataの構築
    final syncedSignals = <SignalData>[];
    final syncedPorts = <int>[];
    final syncedSources = <IoChannelSource>[];

    final dioInputNameToPort = <String, int>{
      for (int i = 0; i < inputControllers.length; i++)
        if (inputControllers[i].text.trim().isNotEmpty)
          inputControllers[i].text.trim(): i + 1,
    };
    final plcInputNameToPort = <String, int>{
      for (int i = 0; i < plcEipInputControllers.length; i++)
        if (plcEipInputControllers[i].text.trim().isNotEmpty)
          plcEipInputControllers[i].text.trim(): i + 1,
    };

    final outputNameToPort = <String, int>{};
    for (int i = 0; i < outNamesDio.length; i++) {
      outputNameToPort.putIfAbsent(outNamesDio[i], () => outPortsDio[i]);
    }
    for (int i = 0; i < outNamesPlc.length; i++) {
      outputNameToPort.putIfAbsent(outNamesPlc[i], () => outPortsPlc[i]);
    }

    final hwTriggerControllers = controllersNotifier.hwTriggerControllers;
    final hwNameToPort = <String, int>{
      for (int i = 0; i < currentFormState.hwPort; i++)
        if (i < hwTriggerControllers.length &&
            hwTriggerControllers[i].text.trim().isNotEmpty)
          hwTriggerControllers[i].text.trim(): i + 1,
    };

    for (int i = 0; i < combinedNames.length; i++) {
      final name = combinedNames[i];
      final type = combinedTypes[i];
      final vals = combinedValues[i];
      syncedSignals.add(
        SignalData(name: name, signalType: type, values: vals, isVisible: true),
      );

      IoChannelSource source;
      if (type == SignalType.output) {
        source = _mapOutSourceTag(outSource[name] ?? 'DIO');
        if (source == IoChannelSource.plcEip) {
          final resolved = _resolvePlcEipSource(
            iniResult.plcEipOption,
            allowUnknown: true,
          );
          if (resolved != IoChannelSource.unknown) {
            source = resolved;
          }
        }
      } else if (type == SignalType.input) {
        source = _detectIoSourceFor(
          name,
          type,
          iniResult.plcEipOption,
          inputControllers,
          plcEipInputControllers,
        );
      } else {
        source = IoChannelSource.unknown;
      }
      syncedSources.add(source);

      int portNum = 0;
      switch (type) {
        case SignalType.output:
          portNum = outputNameToPort[name] ?? 0;
          break;
        case SignalType.input:
          if (name != SignalNames.codeOption &&
              name != SignalNames.commandOption) {
            switch (source) {
              case IoChannelSource.plc:
              case IoChannelSource.eip:
                portNum = plcInputNameToPort[name] ?? 0;
                break;
              case IoChannelSource.dio:
                portNum = dioInputNameToPort[name] ?? 0;
                break;
              default:
                portNum =
                    dioInputNameToPort[name] ??
                    plcInputNameToPort[name] ??
                    0;
            }
          }
          break;
        case SignalType.hwTrigger:
          portNum = hwNameToPort[name] ?? 0;
          break;
        default:
          portNum = 0;
      }
      syncedPorts.add(portNum);
    }

    debugPrint(
      '[COMBINED] names=${combinedNames.length}, valuesRows=${combinedValues.length}, anyNonZero=${combinedValues.any((r) => r.any((v) => v != 0))}',
    );

    return _ChartDataResult(
      signals: syncedSignals,
      portNumbers: syncedPorts,
      ioSources: syncedSources,
      stepDurationsMs: stepDurationsMs,
    );
  }

  /// CSV タイムラインから入力ポート系列を読み取る
  static List<int> _readInputSeriesFromTimeline({
    required CsvTimeline timeline,
    required int timeLength,
    required String source,
    required int port1Based,
  }) {
    final series = List.filled(timeLength, 0);
    for (int t = 0; t < timeLength; t++) {
      final e = timeline.entries[t];
      if (e.type == 'IN' && e.source == source) {
        final row = e.bits;
        final col = row.length - port1Based;
        if (col >= 0 && col < row.length) {
          series[t] = row[col] != 0 ? 1 : 0;
        }
      }
    }
    return series;
  }

  /// 出力ソースタグをIoChannelSourceにマッピング
  static IoChannelSource _mapOutSourceTag(String tag) {
    switch (tag) {
      case 'PLC':
        return IoChannelSource.plc;
      case 'EIP':
        return IoChannelSource.eip;
      case 'PLC/EIP':
        return IoChannelSource.plcEip;
      case 'DIO':
        return IoChannelSource.dio;
      default:
        return IoChannelSource.unknown;
    }
  }

  /// PLC/EIPソースを解決
  static IoChannelSource _resolvePlcEipSource(
    String plcEipOption, {
    bool allowUnknown = false,
  }) {
    if (plcEipOption == 'PLC') return IoChannelSource.plc;
    if (plcEipOption == 'EIP') return IoChannelSource.eip;
    return allowUnknown ? IoChannelSource.unknown : IoChannelSource.dio;
  }

  /// 信号名からIOソースを検出
  static IoChannelSource _detectIoSourceFor(
    String label,
    SignalType type,
    String plcEipOption,
    List<TextEditingController> inputControllers,
    List<TextEditingController> plcEipInputControllers,
  ) {
    if (type != SignalType.input && type != SignalType.output) {
      return IoChannelSource.unknown;
    }

    final prefix = _extractLabelPrefix(label).toUpperCase();
    final prefSource = _sourceFromPrefix(prefix, type);
    if (prefSource != IoChannelSource.unknown) {
      if (prefSource == IoChannelSource.plcEip) {
        return _resolvePlcEipSource(plcEipOption, allowUnknown: true);
      }
      return prefSource;
    }

    if (type == SignalType.input) {
      if (_findControllerIndexByLabel(label, inputControllers) != -1) {
        return IoChannelSource.dio;
      }
      if (_findControllerIndexByLabel(label, plcEipInputControllers) != -1) {
        return _resolvePlcEipSource(plcEipOption, allowUnknown: true);
      }
    }

    return IoChannelSource.unknown;
  }

  /// ラベルのプレフィックスを抽出
  static String _extractLabelPrefix(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '';
    final colonIdx = trimmed.indexOf(':');
    if (colonIdx != -1) {
      return trimmed.substring(0, colonIdx);
    }
    final spaceIdx = trimmed.indexOf(' ');
    if (spaceIdx != -1) {
      return trimmed.substring(0, spaceIdx);
    }
    return trimmed;
  }

  /// プレフィックスからソースを判定
  static IoChannelSource _sourceFromPrefix(
    String prefixUpper,
    SignalType type,
  ) {
    if (prefixUpper.startsWith('PLIN') ||
        prefixUpper.startsWith('PLI') ||
        prefixUpper.startsWith('PLON') ||
        prefixUpper.startsWith('PLO')) {
      return IoChannelSource.plc;
    }
    if (prefixUpper.startsWith('ESIN') ||
        prefixUpper.startsWith('ESI') ||
        prefixUpper.startsWith('ESON') ||
        prefixUpper.startsWith('ESO')) {
      return IoChannelSource.eip;
    }
    if (prefixUpper.startsWith('PLC/EIP')) {
      return IoChannelSource.plcEip;
    }
    if (prefixUpper.startsWith('INPUT') || prefixUpper.startsWith('OUTPUT')) {
      return IoChannelSource.dio;
    }
    return IoChannelSource.unknown;
  }

  /// コントローラーリストからラベルでインデックスを検索
  static int _findControllerIndexByLabel(
    String label,
    List<TextEditingController> controllers,
  ) {
    final target = label.trim();
    for (int i = 0; i < controllers.length; i++) {
      if (controllers[i].text.trim() == target) {
        return i;
      }
    }
    final colonIdx = target.indexOf(':');
    if (colonIdx != -1) {
      final suffix = target.substring(colonIdx + 1).trim();
      if (suffix.isNotEmpty) {
        for (int i = 0; i < controllers.length; i++) {
          if (controllers[i].text.trim() == suffix) {
            return i;
          }
        }
      }
    }
    return -1;
  }
}

/// INIファイル解析結果
class _IniParseResult {
  final List<String> enabledStatusSignals;
  final List<StatusSignalSetting> enabledSignalStructures;
  final List<OutputAssignment> dioOutputAssignments;
  final List<OutputAssignment> plcEipOutputAssignments;
  final String plcEipOption;
  final String triggerOption;
  final int? inputPorts;
  final int? outputPorts;
  final bool shutdownMonitor;
  final bool codeTriggerOnPlcEip;
  final bool useDioTriggerPortWithVirtualIo;

  _IniParseResult({
    required this.enabledStatusSignals,
    required this.enabledSignalStructures,
    required this.dioOutputAssignments,
    required this.plcEipOutputAssignments,
    required this.plcEipOption,
    required this.triggerOption,
    this.inputPorts,
    this.outputPorts,
    this.shutdownMonitor = false,
    this.codeTriggerOnPlcEip = false,
    this.useDioTriggerPortWithVirtualIo = false,
  });
}

/// チャートデータ構築結果
class _ChartDataResult {
  final List<SignalData> signals;
  final List<int> portNumbers;
  final List<IoChannelSource> ioSources;
  final List<double> stepDurationsMs;

  _ChartDataResult({
    required this.signals,
    required this.portNumbers,
    required this.ioSources,
    required this.stepDurationsMs,
  });
}
