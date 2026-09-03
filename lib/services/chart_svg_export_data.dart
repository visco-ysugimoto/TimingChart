import 'package:flutter/material.dart';

import '../models/chart/io_channel_source.dart';
import '../models/chart/signal_type.dart';
import '../models/chart/timing_chart_annotation.dart';

/// HTML/SVG エクスポート用のチャート描画パラメータ。
class ChartSvgExportData {
  final List<List<int>> signals;
  final List<String> signalNames;
  final List<SignalType> signalTypes;
  final List<TimingChartAnnotation> annotations;
  final double cellWidth;
  final double cellHeight;
  final double labelWidth;
  final double commentAreaHeight;
  final double topCommentAreaHeight;
  final double chartMarginLeft;
  final double chartMarginTop;
  final double totalWidth;
  final double totalHeight;
  final List<int> highlightTimeIndices;
  final List<int> omissionTimeIndices;
  final bool showAllSignalTypes;
  final List<bool> showIoPerRow;
  final List<int> portNumbers;
  final List<IoChannelSource> ioSources;
  final String plcEipMode;
  final bool timeUnitIsMs;
  final double msPerStep;
  final List<double> stepDurationsMs;
  final bool showBottomUnitLabels;
  final Color labelColor;
  final Color backgroundColor;
  final Color dashedColor;
  final Color omissionColor;
  final Color omissionFillColor;
  final Color arrowColor;
  final Map<SignalType, Color> signalColors;
  final List<int?> waveColorArgb;
  final int? activeStepIndex;

  const ChartSvgExportData({
    required this.signals,
    required this.signalNames,
    required this.signalTypes,
    required this.annotations,
    required this.cellWidth,
    required this.cellHeight,
    required this.labelWidth,
    required this.commentAreaHeight,
    required this.topCommentAreaHeight,
    required this.chartMarginLeft,
    required this.chartMarginTop,
    required this.totalWidth,
    required this.totalHeight,
    this.highlightTimeIndices = const [],
    this.omissionTimeIndices = const [],
    this.showAllSignalTypes = false,
    this.showIoPerRow = const [],
    this.portNumbers = const [],
    this.ioSources = const [],
    this.plcEipMode = 'None',
    this.timeUnitIsMs = false,
    this.msPerStep = 1.0,
    this.stepDurationsMs = const [],
    this.showBottomUnitLabels = true,
    required this.labelColor,
    required this.backgroundColor,
    required this.dashedColor,
    required this.omissionColor,
    required this.omissionFillColor,
    required this.arrowColor,
    required this.signalColors,
    this.waveColorArgb = const [],
    this.activeStepIndex,
  });
}
