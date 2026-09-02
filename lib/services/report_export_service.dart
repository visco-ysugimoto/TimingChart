import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/chart/io_channel_source.dart';
import '../models/chart/signal_data.dart';
import '../models/chart/signal_type.dart';
import '../models/chart/timing_chart_annotation.dart';
import '../models/form/camera_table_types.dart';
import '../models/form/form_state.dart';
import '../providers/locale_notifier.dart';
import '../providers/settings_notifier.dart';
import '../providers/timing_chart_controller.dart';
import '../suggestion_loader.dart';
import '../utils/file_utils.dart';
import '../widgets/chart/timing_chart.dart';
import '../widgets/form/form_tab.dart' show FormTabState;
import '../widgets/form/form_tab_constants.dart';
import '../widgets/form/form_tab_rules.dart';
import 'export_service.dart';
import 'report_html_builder.dart';

/// HTML レポートの書き出し。
class ReportExportService {
  static Future<bool> exportHtml({
    required BuildContext context,
    required TimingFormState formState,
    required List<SignalData> chartSignals,
    required List<int> chartPortNumbers,
    required TimingChartController chartController,
    FormTabState? formTabState,
    TimingChartState? timingChartState,
    required List<TimingChartAnnotation> chartAnnotations,
    List<String> inputNames = const [],
    List<String> plcEipInputNames = const [],
    List<String> outputNames = const [],
    List<String> plcEipOutputNames = const [],
    List<IoChannelSource> chartIoSources = const [],
    void Function(String savedPath)? onExported,
  }) async {
    try {
      if (timingChartState != null && formTabState != null) {
        formTabState.setChartDataOnly(chartController.signals);
      }

      await SchedulerBinding.instance.endOfFrame;
      if (!context.mounted) return false;

      final locale =
          Provider.of<LocaleNotifier>(context, listen: false).locale;
      final languageCode = locale.languageCode.toLowerCase();
      final settings = Provider.of<SettingsNotifier>(context, listen: false);
      final isDark = Theme.of(context).brightness == Brightness.dark;

      final plcEipOption = formTabState?.plcOption ?? PlcEipOptions.none;
      final signalsAndPorts = await _resolveSignals(
        chartSignals: chartSignals,
        chartPortNumbers: chartPortNumbers,
        chartIoSources: chartIoSources,
        chartController: chartController,
        timingChartState: timingChartState,
        formState: formState,
        inputNames: inputNames,
        plcEipInputNames: plcEipInputNames,
        outputNames: outputNames,
        plcEipOutputNames: plcEipOutputNames,
        plcEipOption: plcEipOption,
      );

      Uint8List? jpegBytes;
      if (timingChartState != null) {
        jpegBytes = await timingChartState.captureChartJpeg(
          backgroundColor: isDark ? Colors.black : Colors.white,
          quality: 90,
        );
      }
      if (!context.mounted) return false;

      final triggerMarkdown = await _loadTriggerMarkdown(
        triggerOption: formState.triggerOption,
        languageCode: languageCode,
      );

      final html = ReportHtmlBuilder.build(
        ReportHtmlData(
          languageCode: languageCode,
          formState: formState,
          plcEipOption: plcEipOption,
          timeUnitIsMs: settings.timeUnitIsMs,
          msPerStep: settings.msPerStep,
          signals: signalsAndPorts.signals,
          signalPorts: signalsAndPorts.ports,
          signalSources: signalsAndPorts.sources,
          tableData: formTabState?.getTableData() ?? const <List<CellMode>>[],
          rowModes: formTabState?.getRowModes() ?? const <String>[],
          triggerMarkdown: triggerMarkdown,
          chartJpegBase64:
              jpegBytes == null ? null : base64Encode(jpegBytes),
          annotations: chartAnnotations,
        ),
      );

      return FileUtils.exportHtml(
        html,
        saveOptions: ExportService.saveOptionsFromContext(
          context,
          onExported: onExported,
        ),
      );
    } catch (e) {
      debugPrint('HTML report export error: $e');
      return false;
    }
  }

  static Future<
      ({List<SignalData> signals, List<int> ports, List<IoChannelSource> sources})
  > _resolveSignals({
    required List<SignalData> chartSignals,
    required List<int> chartPortNumbers,
    required List<IoChannelSource> chartIoSources,
    required TimingChartController chartController,
    required TimingChartState? timingChartState,
    required TimingFormState formState,
    required List<String> inputNames,
    required List<String> plcEipInputNames,
    required List<String> outputNames,
    required List<String> plcEipOutputNames,
    required String plcEipOption,
  }) async {
    final signals = <SignalData>[];
    final ports = <int>[];
    final sources = <IoChannelSource>[];

    Future<void> addLabeled(
      SignalData original,
      int port,
      IoChannelSource source,
    ) async {
      final labelName = await _displayLabel(original.name);
      signals.add(original.copyWith(name: labelName));
      ports.add(port);
      sources.add(source);
    }

    final usedChartIndexes = <int>{};

    int takeChartIndex(String name) {
      for (var i = 0; i < chartSignals.length; i++) {
        if (usedChartIndexes.contains(i)) continue;
        if (chartSignals[i].name == name) {
          usedChartIndexes.add(i);
          return i;
        }
      }
      return -1;
    }

    IoChannelSource sourceOf(int chartIndex, SignalData signal) {
      final fromName = ReportHtmlBuilder.inferSourceFromName(signal.name);
      if (_isPlcEipSource(fromName)) return fromName;
      if (chartIndex >= 0 && chartIndex < chartIoSources.length) {
        final source = chartIoSources[chartIndex];
        if (source != IoChannelSource.unknown) return source;
      }
      return IoChannelSource.dio;
    }

    if (timingChartState != null) {
      for (final name in chartController.signalNames) {
        final index = takeChartIndex(name);
        if (index < 0) continue;
        final original = chartSignals[index];
        final port =
            index < chartPortNumbers.length ? chartPortNumbers[index] : 0;
        await addLabeled(original, port, sourceOf(index, original));
      }
      for (var i = 0; i < chartSignals.length; i++) {
        if (usedChartIndexes.contains(i)) continue;
        final original = chartSignals[i];
        final port = i < chartPortNumbers.length ? chartPortNumbers[i] : 0;
        await addLabeled(original, port, sourceOf(i, original));
      }
    } else {
      for (var i = 0; i < chartSignals.length; i++) {
        final port = i < chartPortNumbers.length ? chartPortNumbers[i] : 0;
        await addLabeled(chartSignals[i], port, sourceOf(i, chartSignals[i]));
      }
    }

    await _mergeNamedInputs(
      formState: formState,
      inputNames: inputNames,
      plcEipInputNames: plcEipInputNames,
      plcEipOption: plcEipOption,
      signals: signals,
      ports: ports,
      sources: sources,
    );
    await _mergeNamedOutputs(
      formState: formState,
      outputNames: outputNames,
      plcEipOutputNames: plcEipOutputNames,
      plcEipOption: plcEipOption,
      signals: signals,
      ports: ports,
      sources: sources,
    );

    return (signals: signals, ports: ports, sources: sources);
  }

  static bool _isPlcEipSource(IoChannelSource source) {
    return source == IoChannelSource.plc ||
        source == IoChannelSource.eip ||
        source == IoChannelSource.plcEip;
  }

  static IoChannelSource _plcEipSourceOf(String plcEipOption) {
    return plcEipOption == PlcEipOptions.eip
        ? IoChannelSource.eip
        : IoChannelSource.plc;
  }

  static int _indexOfNamed({
    required List<SignalData> signals,
    required List<IoChannelSource> sources,
    required bool isPlcEipChannel,
    required List<String> candidates,
    SignalType? signalType,
  }) {
    for (var i = 0; i < signals.length; i++) {
      final plc = i < sources.length && _isPlcEipSource(sources[i]);
      if (plc != isPlcEipChannel) continue;
      if (signalType != null &&
          signals[i].signalType != signalType &&
          !_isCompatibleInputType(signals[i].signalType, signalType)) {
        continue;
      }
      if (candidates.contains(signals[i].name)) return i;
    }
    return -1;
  }

  static bool _isCompatibleInputType(SignalType actual, SignalType expected) {
    if (actual == expected) return true;
    const family = {
      SignalType.input,
      SignalType.control,
      SignalType.group,
      SignalType.task,
    };
    return family.contains(actual) && family.contains(expected);
  }

  /// チャート非表示の入力（Code Trigger ビットや PLI/ESI）を信号一覧へ足す。
  static Future<void> _mergeNamedInputs({
    required TimingFormState formState,
    required List<String> inputNames,
    required List<String> plcEipInputNames,
    required String plcEipOption,
    required List<SignalData> signals,
    required List<int> ports,
    required List<IoChannelSource> sources,
  }) async {
    Future<void> merge(
      List<String> names, {
      required bool isPlcEipChannel,
    }) async {
      final limit =
          names.length < formState.inputCount
              ? names.length
              : formState.inputCount;
      final source =
          isPlcEipChannel
              ? _plcEipSourceOf(plcEipOption)
              : IoChannelSource.dio;
      for (var i = 0; i < limit; i++) {
        final raw = names[i].trim();
        if (raw.isEmpty) continue;
        final type = FormTabRules.inferInputSignalType(
          triggerOption: formState.triggerOption,
          inputCount: formState.inputCount,
          index: i,
          codeTriggerOnPlcEip: formState.codeTriggerOnPlcEip,
          isPlcEipChannel: isPlcEipChannel,
        );
        final port = i + 1;
        final labelName = await _displayLabel(raw);
        final existing = _indexOfNamed(
          signals: signals,
          sources: sources,
          isPlcEipChannel: isPlcEipChannel,
          candidates: [labelName, raw],
          signalType: type,
        );
        if (existing >= 0) {
          if (existing < ports.length && ports[existing] <= 0) {
            ports[existing] = port;
          }
          continue;
        }
        signals.add(
          SignalData(
            name: labelName,
            signalType: type,
            values: const [],
          ),
        );
        ports.add(port);
        sources.add(source);
      }
    }

    await merge(inputNames, isPlcEipChannel: false);
    if (plcEipOption != PlcEipOptions.none) {
      await merge(plcEipInputNames, isPlcEipChannel: true);
    }
  }

  /// DIO 出力と PLO/ESO を、フォーム設定から信号一覧へ足す。
  static Future<void> _mergeNamedOutputs({
    required TimingFormState formState,
    required List<String> outputNames,
    required List<String> plcEipOutputNames,
    required String plcEipOption,
    required List<SignalData> signals,
    required List<int> ports,
    required List<IoChannelSource> sources,
  }) async {
    Future<void> mergeDio() async {
      final limit =
          outputNames.length < formState.outputCount
              ? outputNames.length
              : formState.outputCount;
      for (var i = 0; i < limit; i++) {
        final raw = outputNames[i].trim();
        if (raw.isEmpty) continue;
        final labelName = await _displayLabel(raw);
        final existing = _indexOfNamed(
          signals: signals,
          sources: sources,
          isPlcEipChannel: false,
          candidates: [labelName, raw],
          signalType: SignalType.output,
        );
        if (existing >= 0) {
          if (existing < ports.length && ports[existing] <= 0) {
            ports[existing] = i + 1;
          }
          continue;
        }
        signals.add(
          SignalData(
            name: labelName,
            signalType: SignalType.output,
            values: const [],
          ),
        );
        ports.add(i + 1);
        sources.add(IoChannelSource.dio);
      }
    }

    Future<void> mergePlcEip() async {
      if (plcEipOption == PlcEipOptions.none) return;
      final limit =
          plcEipOutputNames.length < formState.outputCount
              ? plcEipOutputNames.length
              : formState.outputCount;
      final source = _plcEipSourceOf(plcEipOption);
      for (var i = 0; i < limit; i++) {
        final raw = plcEipOutputNames[i].trim();
        if (raw.isEmpty) continue;
        final label = _plcEipOutputLabel(
          user: raw,
          index: i,
          plcEipOption: plcEipOption,
        );
        final labelName = await _displayLabel(label);
        final userLabel = await _displayLabel(raw);
        final prefix = plcEipOption == PlcEipOptions.plc ? 'PLO' : 'ESO';
        final base = '$prefix${i + 1}';
        final existing = _indexOfNamed(
          signals: signals,
          sources: sources,
          isPlcEipChannel: true,
          candidates: [labelName, label, userLabel, raw, base],
          signalType: SignalType.output,
        );
        if (existing >= 0) {
          if (existing < ports.length && ports[existing] <= 0) {
            ports[existing] = i + 1;
          }
          signals[existing] = signals[existing].copyWith(name: labelName);
          continue;
        }
        signals.add(
          SignalData(
            name: labelName,
            signalType: SignalType.output,
            values: const [],
          ),
        );
        ports.add(i + 1);
        sources.add(source);
      }
    }

    await mergeDio();
    await mergePlcEip();
  }

  /// `PLO2: AUTO_MODE` はコロン以降の ID を表示ラベルへ変換する。
  static Future<String> _displayLabel(String name) async {
    return labelOfId(ReportHtmlBuilder.signalIdForLabel(name));
  }

  static String _plcEipOutputLabel({
    required String user,
    required int index,
    required String plcEipOption,
  }) {
    final prefix = plcEipOption == PlcEipOptions.plc ? 'PLO' : 'ESO';
    final base = '$prefix${index + 1}';
    if ((user.startsWith('PLO') || user.startsWith('ESO')) && user.length > 3) {
      final port = int.tryParse(user.substring(3));
      if (port != null && port > 0) return user;
    }
    return user.isNotEmpty ? '$base: $user' : base;
  }

  static Future<String> _loadTriggerMarkdown({
    required String triggerOption,
    required String languageCode,
  }) async {
    final primary = ReportHtmlBuilder.triggerDocAssetPath(
      triggerOption: triggerOption,
      languageCode: languageCode,
    );
    final fallback = ReportHtmlBuilder.triggerDocAssetPath(
      triggerOption: triggerOption,
      languageCode: 'en',
    );
    try {
      return await rootBundle.loadString(primary);
    } catch (_) {
      try {
        return await rootBundle.loadString(fallback);
      } catch (e) {
        debugPrint('Trigger help markdown missing: $e');
        return '';
      }
    }
  }
}
