import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../models/backup/app_config.dart';
import '../providers/settings_notifier.dart';
import '../utils/export_save_options.dart';
import '../models/chart/signal_data.dart';
import '../models/chart/timing_chart_annotation.dart';
import '../models/form/form_state.dart';
import '../providers/timing_chart_controller.dart';
import '../utils/file_utils.dart';
import '../models/form/camera_table_types.dart';
import '../widgets/form/form_tab.dart' show FormTabState;
import '../widgets/chart/timing_chart.dart';
import '../suggestion_loader.dart';

/// エクスポートサービスクラス
class ExportService {
  static ExportSaveOptions saveOptionsFromContext(
    BuildContext context, {
    void Function(String savedPath)? onExported,
  }) {
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    return ExportSaveOptions(
      lastExportDirectory: settings.lastExportDirectory,
      exportSubFolder: settings.exportFolder,
      fileNamePrefix: settings.fileNamePrefix,
      quickExportEnabled: settings.quickExportEnabled,
      onSaved: (path, {required quickSave}) {
        if (!quickSave) {
          FileUtils.rememberExportDirectoryFromPath(
            savedFilePath: path,
            exportSubFolder: settings.exportFolder,
            onBaseDirectoryResolved: (base) {
              settings.lastExportDirectory = base;
            },
          );
        }
        onExported?.call(path);
      },
    );
  }

  /// AppConfigを作成する
  static Future<AppConfig> createAppConfig({
    required TimingFormState formState,
    required List<SignalData> chartSignals,
    required TimingChartController chartController,
    required List<TimingChartAnnotation> chartAnnotations,
    FormTabState? formTabState,
    TimingChartState? timingChartState,
    required List<TextEditingController> inputControllers,
    required List<TextEditingController> outputControllers,
    required List<TextEditingController> hwTriggerControllers,
    required bool timeUnitIsMs,
    required double msPerStep,
    required List<double> stepDurationsMs,
  }) async {
    debugPrint("\n===== _createAppConfig (Chart first) =====");

    List<SignalData> signalData = [];
    List<List<CellMode>> tableData = [];
    List<bool> inputVisibility = [];
    List<bool> outputVisibility = [];
    List<bool> hwTriggerVisibility = [];
    List<String> rowModes = [];

    if (formTabState != null) {
      signalData = formTabState.getSignalDataList();
      tableData = formTabState.getTableData();
      inputVisibility = formTabState.getInputVisibility();
      outputVisibility = formTabState.getOutputVisibility();
      hwTriggerVisibility = formTabState.getHwTriggerVisibility();
      rowModes = formTabState.getRowModes();
    }

    if (timingChartState != null) {
      final orderedNames = chartController.signalNames;
      final mapByName = {for (var s in chartSignals) s.name: s};
      signalData = orderedNames.map((n) => mapByName[n]!).toList();
    } else {
      signalData = List<SignalData>.from(chartSignals);
    }

    debugPrint("信号データが存在します: ${signalData.length}");
    if (signalData.isNotEmpty) {
      debugPrint(
        "信号データが存在します: ${signalData.any((signal) => signal.values.any((val) => val != 0))}",
      );
    }
    debugPrint("===== _createAppConfig _====\n");

    return AppConfig.fromCurrentState(
      formState: formState,
      signals: signalData,
      tableData: tableData,
      inputControllers: inputControllers,
      outputControllers: outputControllers,
      hwTriggerControllers: hwTriggerControllers,
      inputVisibility: inputVisibility,
      outputVisibility: outputVisibility,
      hwTriggerVisibility: hwTriggerVisibility,
      rowModes: rowModes,
      annotations: chartAnnotations,
      omissionIndices: timingChartState?.getOmissionTimeIndices() ?? const [],
      timeUnitIsMs: timeUnitIsMs,
      msPerStep: msPerStep,
      stepDurationsMs: stepDurationsMs,
    );
  }

  /// エクスポート前の確認を行う
  static Future<bool> confirmExport({
    required BuildContext context,
    required int tabIndex,
    required TimingChartController chartController,
    required List<SignalData> chartSignals,
    FormTabState? formTabState,
    TimingChartState? timingChartState,
  }) async {
    debugPrint("===== _confirmExport =====");
    debugPrint("信号データが見つかりません: $tabIndex");

    if (tabIndex == 1 && timingChartState != null) {
      List<List<int>> chartData = chartController.signals;
      debugPrint("信号データが存在します: ${chartData.length}");
      if (chartData.isNotEmpty) {
        debugPrint("信号データ: ${chartData[0].take(10)}...");
        final hasNonZero = chartData.any(
          (row) => row.any((value) => value != 0),
        );
        debugPrint("信号データに0が含まれているか: $hasNonZero");

        if (hasNonZero) {
          return true;
        }
      }
    }

    List<SignalData> signalData = [];

    if (formTabState != null) {
      signalData = formTabState.getSignalDataList();
    }

    if (signalData.isEmpty ||
        !signalData.any((signal) => signal.values.any((value) => value != 0))) {
      final shouldUpdate =
          await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('信号データが見つかりません'),
                  content: const Text(
                    'エクスポートする前に「Update Chart」ボタンをクリックして信号データを更新することをお勧めします。\n\n'
                    'このまま進めますか？',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('このまま進める'),
                    ),
                  ],
                ),
          ) ??
          false;

      return shouldUpdate;
    }

    return true;
  }

  /// JSONエクスポートを実行する
  static Future<bool> exportConfig({
    required BuildContext context,
    required int tabIndex,
    required TimingFormState formState,
    required List<SignalData> chartSignals,
    required TimingChartController chartController,
    required List<TimingChartAnnotation> chartAnnotations,
    FormTabState? formTabState,
    TimingChartState? timingChartState,
    required List<TextEditingController> inputControllers,
    required List<TextEditingController> outputControllers,
    required List<TextEditingController> hwTriggerControllers,
    required bool timeUnitIsMs,
    required double msPerStep,
    required List<double> stepDurationsMs,
    void Function(String savedPath)? onExported,
  }) async {
    // チャートデータをフォームに同期
    if (timingChartState != null && formTabState != null) {
      final chartData = chartController.signals;
      formTabState.setChartDataOnly(chartData);
    }

    await SchedulerBinding.instance.endOfFrame;
    if (!context.mounted) return false;

    // エクスポート確認
    final shouldContinue = await confirmExport(
      context: context,
      tabIndex: tabIndex,
      chartController: chartController,
      chartSignals: chartSignals,
      formTabState: formTabState,
      timingChartState: timingChartState,
    );
    if (!shouldContinue) return false;

    // タブがチャートタブの場合、再度同期
    if (tabIndex == 1 && timingChartState != null && formTabState != null) {
      final chartData = chartController.signals;
      formTabState.setChartDataOnly(chartData);
    }

    await SchedulerBinding.instance.endOfFrame;

    // AppConfigを作成してエクスポート
    final config = await createAppConfig(
      formState: formState,
      chartSignals: chartSignals,
      chartController: chartController,
      chartAnnotations: chartAnnotations,
      formTabState: formTabState,
      timingChartState: timingChartState,
      inputControllers: inputControllers,
      outputControllers: outputControllers,
      hwTriggerControllers: hwTriggerControllers,
      timeUnitIsMs: timeUnitIsMs,
      msPerStep: msPerStep,
      stepDurationsMs: stepDurationsMs,
    );

    final success = await FileUtils.exportWaveDrom(
      config,
      annotations: chartAnnotations,
      omissionIndices: timingChartState?.getOmissionTimeIndices(),
      saveOptions: saveOptionsFromContext(context, onExported: onExported),
    );

    return success;
  }

  /// JPEGエクスポートを実行する
  static Future<bool> exportChartImageJpeg({
    required BuildContext context,
    required TimingChartState? timingChartState,
    void Function(String savedPath)? onExported,
  }) async {
    await SchedulerBinding.instance.endOfFrame;
    if (!context.mounted) return false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final bytes = await timingChartState?.captureChartJpeg(
      backgroundColor: bg,
      quality: 90,
    );
    if (bytes == null) {
      return false;
    }

    final ok = await FileUtils.exportJpegBytes(
      bytes,
      saveOptions: saveOptionsFromContext(context, onExported: onExported),
    );
    return ok;
  }

  /// XLSXエクスポートを実行する
  static Future<bool> exportXlsx({
    required BuildContext context,
    void Function(String savedPath)? onExported,
    required List<SignalData> chartSignals,
    required List<int> chartPortNumbers,
    required TimingChartController chartController,
    required List<TextEditingController> inputControllers,
    required List<TextEditingController> outputControllers,
    required List<TextEditingController> hwTriggerControllers,
    FormTabState? formTabState,
    TimingChartState? timingChartState,
    required List<TimingChartAnnotation> chartAnnotations,
    List<int>? omissionIndices,
  }) async {
    try {
      // チャートデータをフォームに同期
      if (timingChartState != null && formTabState != null) {
        final chartData = chartController.signals;
        formTabState.setChartDataOnly(chartData);
      }

      await SchedulerBinding.instance.endOfFrame;

      debugPrint('=== IO Information: ID to Label conversion ===');

      // 入力名の変換
      List<String> inputNames = [];
      for (int i = 0; i < inputControllers.length; i++) {
        final inputText = inputControllers[i].text.trim();
        if (inputText.isNotEmpty) {
          final labelName = await labelOfId(inputText);
          debugPrint('Converting Input[$i]: $inputText -> $labelName');
          inputNames.add(labelName);
        } else {
          inputNames.add('');
        }
      }

      // 出力名の変換
      List<String> outputNames = [];
      for (int i = 0; i < outputControllers.length; i++) {
        final outputText = outputControllers[i].text.trim();
        if (outputText.isNotEmpty) {
          final labelName = await labelOfId(outputText);
          debugPrint('Converting Output[$i]: $outputText -> $labelName');
          outputNames.add(labelName);
        } else {
          outputNames.add('');
        }
      }

      // HWトリガー名の変換
      List<String> hwTriggerNames = [];
      for (int i = 0; i < hwTriggerControllers.length; i++) {
        final hwText = hwTriggerControllers[i].text.trim();
        if (hwText.isNotEmpty) {
          final labelName = await labelOfId(hwText);
          debugPrint('Converting HW Trigger[$i]: $hwText -> $labelName');
          hwTriggerNames.add(labelName);
        } else {
          hwTriggerNames.add('');
        }
      }

      debugPrint('=== End IO conversion ===');

      // 信号データの変換
      List<SignalData> signalData = [];
      // ポート番号（信号型と並び順に対応）
      List<int> signalPorts = [];

      if (timingChartState != null) {
        final orderedNames = chartController.signalNames;
        final mapByName = {for (var s in chartSignals) s.name: s};
        final Map<String, List<int>> portsByName = {};
        for (int i = 0;
            i < chartSignals.length && i < chartPortNumbers.length;
            i++) {
          final name = chartSignals[i].name;
          portsByName.putIfAbsent(name, () => []).add(chartPortNumbers[i]);
        }

        debugPrint('=== XLSX Export: ID to Label conversion ===');
        debugPrint('Ordered signal IDs: $orderedNames');

        for (String signalId in orderedNames) {
          if (mapByName.containsKey(signalId)) {
            final originalSignal = mapByName[signalId]!;
            final labelName = await labelOfId(signalId);
            debugPrint('Converting: $signalId -> $labelName');
            final modifiedSignal = originalSignal.copyWith(name: labelName);
            signalData.add(modifiedSignal);

            final list = portsByName[signalId];
            if (list != null && list.isNotEmpty) {
              signalPorts.add(list.removeAt(0));
            } else {
              signalPorts.add(0);
            }
          }
        }

        for (var signal in chartSignals) {
          if (!orderedNames.contains(signal.name)) {
            final labelName = await labelOfId(signal.name);
            debugPrint(
              'Converting additional signal: ${signal.name} -> $labelName',
            );
            final modifiedSignal = signal.copyWith(name: labelName);
            signalData.add(modifiedSignal);

            final list = portsByName[signal.name];
            if (list != null && list.isNotEmpty) {
              signalPorts.add(list.removeAt(0));
            } else {
              signalPorts.add(0);
            }
          }
        }

        debugPrint(
          'Final signal names for XLSX: ${signalData.map((s) => s.name).toList()}',
        );
        debugPrint('=== End conversion ===');
      } else {
        for (int i = 0; i < chartSignals.length; i++) {
          final signal = chartSignals[i];
          final labelName = await labelOfId(signal.name);
          debugPrint(
            'Converting from _chartSignals: ${signal.name} -> $labelName',
          );
          final modifiedSignal = signal.copyWith(name: labelName);
          signalData.add(modifiedSignal);
          final port =
              (i < chartPortNumbers.length) ? chartPortNumbers[i] : 0;
          signalPorts.add(port);
        }
      }

      // XLSXエクスポート
      final success = await FileUtils.exportXlsx(
        inputNames: inputNames,
        outputNames: outputNames,
        hwTriggerNames: hwTriggerNames,
        chartSignals: signalData,
        chartPorts: signalPorts,
        chartAnnotations: chartAnnotations,
        omissionIndices:
            omissionIndices ??
            timingChartState?.getOmissionTimeIndices() ??
            const [],
        saveOptions: saveOptionsFromContext(context, onExported: onExported),
      );

      return success;
    } catch (e) {
      debugPrint('XLSX export error: $e');
      return false;
    }
  }
}
