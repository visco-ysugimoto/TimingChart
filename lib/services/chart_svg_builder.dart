import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/chart/io_channel_source.dart';
import '../models/chart/signal_type.dart';
import '../widgets/chart/chart_drawing_util.dart';
import 'chart_svg_annotations.dart';
import 'chart_svg_export_data.dart';
import 'chart_svg_writer.dart';

/// タイミングチャートを SVG 文字列へ変換する。
class ChartSvgBuilder {
  ChartSvgBuilder._();

  static String build(ChartSvgExportData data) {
    final writer = ChartSvgWriter();
    final rowCount = data.signals.length;
    final maxTimeSteps = data.signals.isEmpty
        ? 0
        : data.signals.map((e) => e.length).fold(0, math.max);

    final originY = data.chartMarginTop + data.topCommentAreaHeight;
    final contentHeight = rowCount * data.cellHeight + data.commentAreaHeight;
    final waveClipId = 'wave-clip';
    final defs = StringBuffer()
      ..write(
        '<clipPath id="$waveClipId">'
        '<rect x="${_n(data.chartMarginLeft + data.labelWidth + 1)}" y="${_n(originY)}" '
        'width="${_n(math.max(0, data.totalWidth - data.chartMarginLeft - data.labelWidth - 1))}" '
        'height="${_n(contentHeight)}"/>'
        '</clipPath>',
      );

    _drawLabelMask(writer, data, originY, rowCount);
    _drawGrid(writer, data, originY, rowCount, maxTimeSteps);
    _drawHighlightedLines(writer, data, originY, rowCount);

    writer.group(() {
      _drawWaveforms(writer, data, originY);
      _drawOmissionLines(writer, data, originY, rowCount);
    }, clipPath: waveClipId);

    _drawTimeLabels(writer, data, originY, rowCount, maxTimeSteps);
    _drawLabelsOverlay(writer, data, originY, rowCount);
    ChartSvgAnnotations.render(writer, data, rowCount);

    return writer.build(
      width: data.totalWidth,
      height: data.totalHeight,
      background: ChartSvgWriter.color(data.backgroundColor),
      defs: defs.toString(),
    );
  }

  static void _drawLabelMask(
    ChartSvgWriter writer,
    ChartSvgExportData data,
    double originY,
    int rowCount,
  ) {
    final maskWidth = math.max(0.0, data.labelWidth - 1);
    final maskHeight =
        rowCount * data.cellHeight +
        data.commentAreaHeight +
        data.topCommentAreaHeight;
    writer.rect(
      x: data.chartMarginLeft,
      y: data.chartMarginTop,
      width: maskWidth,
      height: maskHeight,
      fill: ChartSvgWriter.color(data.omissionFillColor),
    );
  }

  static void _drawGrid(
    ChartSvgWriter writer,
    ChartSvgExportData data,
    double originY,
    int rowCount,
    int maxTimeSteps,
  ) {
    final guideColor = ChartSvgWriter.color(Colors.grey, opacity: 0.5);
    final originX = data.chartMarginLeft;

    if (!data.timeUnitIsMs) {
      for (int i = 0; i <= maxTimeSteps; i++) {
        final x = originX + data.labelWidth + i * data.cellWidth;
        writer.line(
          x1: x,
          y1: originY,
          x2: x,
          y2: originY + rowCount * data.cellHeight,
          stroke: guideColor,
        );
      }
    } else {
      double cursorX = originX + data.labelWidth;
      for (int i = 0; i <= maxTimeSteps; i++) {
        if (i > 0) {
          final dur = (i - 1) < data.stepDurationsMs.length
              ? data.stepDurationsMs[i - 1]
              : data.msPerStep;
          cursorX += (dur / data.msPerStep) * data.cellWidth;
        }
        final isActive =
            data.activeStepIndex != null && i == data.activeStepIndex;
        writer.line(
          x1: cursorX,
          y1: originY,
          x2: cursorX,
          y2: originY + rowCount * data.cellHeight,
          stroke: isActive ? ChartSvgWriter.color(Colors.orange) : guideColor,
          strokeWidth: isActive ? 2 : 1,
        );
      }
    }

    int visibleRow = 0;
    for (int j = 0; j < rowCount; j++) {
      final type = j < data.signalTypes.length
          ? data.signalTypes[j]
          : SignalType.input;
      if (!_isVisibleType(data, type)) continue;
      final y = originY + visibleRow * data.cellHeight;
      writer.line(
        x1: originX,
        y1: y,
        x2: data.totalWidth,
        y2: y,
        stroke: guideColor,
      );
      visibleRow++;
    }
    writer.line(
      x1: originX,
      y1: originY + visibleRow * data.cellHeight,
      x2: data.totalWidth,
      y2: originY + visibleRow * data.cellHeight,
      stroke: guideColor,
    );
  }

  static void _drawHighlightedLines(
    ChartSvgWriter writer,
    ChartSvgExportData data,
    double originY,
    int rowCount,
  ) {
    if (data.highlightTimeIndices.isEmpty) return;
    final originX = data.chartMarginLeft;
    final stroke = ChartSvgWriter.color(Colors.redAccent);
    final height = rowCount * data.cellHeight + data.commentAreaHeight;

    for (final index in data.highlightTimeIndices) {
      final x = originX + _boundaryX(data, index);
      writer.line(
        x1: x,
        y1: originY,
        x2: x,
        y2: originY + height,
        stroke: stroke,
        strokeWidth: 2,
      );
    }
  }

  static void _drawWaveforms(
    ChartSvgWriter writer,
    ChartSvgExportData data,
    double originY,
  ) {
    final originX = data.chartMarginLeft;
    final stepPositions = _stepPositions(data);
    int visibleRow = 0;

    for (int row = 0; row < data.signals.length; row++) {
      final rowData = data.signals[row];
      final type = row < data.signalTypes.length
          ? data.signalTypes[row]
          : SignalType.input;
      if (!_isVisibleType(data, type)) continue;

      final yLow = originY + visibleRow * data.cellHeight + data.cellHeight * 0.75;
      final yHigh = originY + visibleRow * data.cellHeight + data.cellHeight * 0.25;
      final stroke = ChartSvgWriter.color(_colorForRow(data, row, type));
      final pathD = buildDigitalWaveformSvgPathD(
        values: rowData,
        stepPositions: stepPositions,
        xOrigin: originX + data.labelWidth,
        cellWidth: data.cellWidth,
        yHigh: yHigh,
        yLow: yLow,
        formatCoord: ChartSvgWriter.formatCoord,
      );
      if (pathD.isNotEmpty) {
        writer.path(
          d: pathD,
          fill: 'none',
          stroke: stroke,
          strokeWidth: 2,
          strokeLinejoin: 'miter',
          strokeLinecap: 'butt',
        );
      }

      visibleRow++;
    }
  }

  static void _drawOmissionLines(
    ChartSvgWriter writer,
    ChartSvgExportData data,
    double originY,
    int rowCount,
  ) {
    if (data.omissionTimeIndices.isEmpty) return;
    final originX = data.chartMarginLeft;
    final chartBottom = originY + rowCount * data.cellHeight;
    final stroke = ChartSvgWriter.color(data.omissionColor);
    final fill = ChartSvgWriter.color(data.omissionFillColor);

    for (final t in data.omissionTimeIndices) {
      final x = originX + _boundaryX(data, t);
      _drawDoubleWavyVerticalLine(
        writer,
        x,
        originY,
        chartBottom,
        stroke: stroke,
        fill: fill,
      );
    }
  }

  static void _drawTimeLabels(
    ChartSvgWriter writer,
    ChartSvgExportData data,
    double originY,
    int rowCount,
    int maxTimeSteps,
  ) {
    if (!data.showBottomUnitLabels) return;
    final originX = data.chartMarginLeft;
    int visibleRow = 0;
    for (int j = 0; j < rowCount; j++) {
      final type = j < data.signalTypes.length
          ? data.signalTypes[j]
          : SignalType.input;
      if (!_isVisibleType(data, type)) continue;
      visibleRow++;
    }
    final baseY = originY + visibleRow * data.cellHeight + 4;
    final fill = ChartSvgWriter.color(data.labelColor, opacity: 0.8);

    if (!data.timeUnitIsMs) {
      final stepStride = data.cellWidth <= 0
          ? 1
          : (80 / data.cellWidth).ceil().clamp(1, 1000000);
      for (int i = 0; i <= maxTimeSteps; i += stepStride) {
        final x = originX + data.labelWidth + i * data.cellWidth;
        writer.text(
          x: x,
          y: baseY + 12,
          text: '$i',
          fill: fill,
          fontSize: 12,
          textAnchor: 'middle',
        );
      }
    } else {
      double cursorX = originX + data.labelWidth;
      double cursorMs = 0.0;
      double lastLabelX = -1e9;
      for (int i = 0; i <= maxTimeSteps; i++) {
        if (i > 0) {
          final dur = (i - 1) < data.stepDurationsMs.length
              ? data.stepDurationsMs[i - 1]
              : data.msPerStep;
          cursorX += (dur / data.msPerStep) * data.cellWidth;
          cursorMs += dur;
        }
        if (cursorX - lastLabelX >= 80) {
          writer.text(
            x: cursorX,
            y: baseY + 12,
            text: '${cursorMs.round()} ms',
            fill: fill,
            fontSize: 12,
            textAnchor: 'middle',
          );
          lastLabelX = cursorX;
        }
      }
    }
  }

  static void _drawLabelsOverlay(
    ChartSvgWriter writer,
    ChartSvgExportData data,
    double originY,
    int rowCount,
  ) {
    final overlayWidth = math.max(
      0.0,
      data.chartMarginLeft + data.labelWidth - 1,
    );
    final overlayHeight = rowCount * data.cellHeight;

    if (data.topCommentAreaHeight > 0) {
      writer.rect(
        x: 0,
        y: data.chartMarginTop,
        width: overlayWidth,
        height: data.topCommentAreaHeight,
        fill: ChartSvgWriter.color(data.backgroundColor),
      );
    }

    writer.rect(
      x: 0,
      y: originY,
      width: overlayWidth,
      height: overlayHeight,
      fill: ChartSvgWriter.color(data.backgroundColor),
    );

    final gridColor = ChartSvgWriter.color(data.labelColor, opacity: 0.2);
    for (int i = 0; i <= rowCount; i++) {
      final y = originY + i * data.cellHeight;
      writer.line(x1: 0, y1: y, x2: overlayWidth, y2: y, stroke: gridColor);
    }

    final borderX = data.chartMarginLeft + data.labelWidth;
    writer.line(
      x1: borderX,
      y1: originY,
      x2: borderX,
      y2: originY + overlayHeight,
      stroke: ChartSvgWriter.color(data.labelColor, opacity: 0.35),
    );

    int visibleRow = 0;
    for (int row = 0; row < rowCount; row++) {
      final type = row < data.signalTypes.length
          ? data.signalTypes[row]
          : SignalType.input;
      if (!_isVisibleType(data, type)) continue;

      final displayName = _labelForRow(data, row);
      final textColor = row < data.waveColorArgb.length &&
              data.waveColorArgb[row] != null
          ? ChartSvgWriter.color(Color(data.waveColorArgb[row]!))
          : ChartSvgWriter.color(data.labelColor);

      final yCenter = originY + visibleRow * data.cellHeight + data.cellHeight / 2;
      writer.text(
        x: data.chartMarginLeft + 6,
        y: yCenter + 5,
        text: displayName,
        fill: textColor,
        fontSize: 14,
      );
      visibleRow++;
    }
  }

  static String _labelForRow(ChartSvgExportData data, int row) {
    final name = row < data.signalNames.length ? data.signalNames[row] : '';
    final type = row < data.signalTypes.length
        ? data.signalTypes[row]
        : SignalType.input;
    final showIo = row < data.showIoPerRow.length &&
        data.showIoPerRow[row] &&
        row < data.portNumbers.length &&
        data.portNumbers[row] > 0;
    if (!showIo) return name;

    final port = data.portNumbers[row];
    final source = row < data.ioSources.length
        ? data.ioSources[row]
        : IoChannelSource.unknown;
    final prefix = switch (type) {
      SignalType.input => '${_inputPrefix(data, source)}$port: ',
      SignalType.output => '${_outputPrefix(data, source)}$port: ',
      SignalType.hwTrigger => 'HW$port: ',
      _ => '',
    };
    return '$prefix$name';
  }

  static String _inputPrefix(ChartSvgExportData data, IoChannelSource source) {
    return switch (_effectiveSource(data, source)) {
      IoChannelSource.plc => 'PLI',
      IoChannelSource.eip => 'ESI',
      _ => 'Input',
    };
  }

  static String _outputPrefix(ChartSvgExportData data, IoChannelSource source) {
    return switch (_effectiveSource(data, source)) {
      IoChannelSource.plc => 'PLO',
      IoChannelSource.eip => 'ESO',
      _ => 'Output',
    };
  }

  static IoChannelSource _effectiveSource(
    ChartSvgExportData data,
    IoChannelSource source,
  ) {
    if (source == IoChannelSource.plcEip) {
      if (data.plcEipMode == 'PLC') return IoChannelSource.plc;
      if (data.plcEipMode == 'EIP') return IoChannelSource.eip;
      return IoChannelSource.unknown;
    }
    return source;
  }

  static bool _isVisibleType(ChartSvgExportData data, SignalType type) {
    if (data.showAllSignalTypes) return true;
    return type != SignalType.control &&
        type != SignalType.group &&
        type != SignalType.task;
  }

  static Color _colorForRow(
    ChartSvgExportData data,
    int row,
    SignalType type,
  ) {
    if (row >= 0 &&
        row < data.waveColorArgb.length &&
        data.waveColorArgb[row] != null) {
      return Color(data.waveColorArgb[row]!);
    }
    return data.signalColors[type] ?? Colors.grey;
  }

  static List<double> _stepPositions(ChartSvgExportData data) {
    final maxLen = data.signals.isEmpty
        ? 0
        : data.signals.map((e) => e.length).fold(0, math.max);
    final positions = List<double>.filled(maxLen + 1, 0.0);
    for (int t = 0; t < maxLen; t++) {
      final delta = data.timeUnitIsMs
          ? ((t < data.stepDurationsMs.length && data.msPerStep > 0)
              ? data.stepDurationsMs[t] / data.msPerStep
              : 1.0)
          : 1.0;
      positions[t + 1] = positions[t] + delta;
    }
    return positions;
  }

  static double _boundaryX(ChartSvgExportData data, int boundaryIndex) {
    if (!data.timeUnitIsMs) {
      return data.labelWidth + boundaryIndex * data.cellWidth;
    }
    double steps = 0.0;
    for (int t = 0; t < boundaryIndex; t++) {
      final durSteps = (t < data.stepDurationsMs.length && data.msPerStep > 0)
          ? data.stepDurationsMs[t] / data.msPerStep
          : 1.0;
      steps += durSteps;
    }
    return data.labelWidth + steps * data.cellWidth;
  }

  static void _drawDoubleWavyVerticalLine(
    ChartSvgWriter writer,
    double x,
    double y1,
    double y2, {
    required String stroke,
    required String fill,
    double amplitude = 3.0,
    double wavelength = 12.0,
    double gap = 8.0,
  }) {
    if (y2 <= y1) return;
    final halfGap = gap / 2;
    final leftX = x - halfGap;
    final rightX = x + halfGap;

    writer.rect(
      x: leftX - amplitude,
      y: y1,
      width: gap + amplitude * 2,
      height: y2 - y1,
      fill: fill,
    );
    writer.path(
      d: _wavyPath(leftX, y1, y2, amplitude, wavelength),
      fill: 'none',
      stroke: stroke,
      strokeWidth: 2,
    );
    writer.path(
      d: _wavyPath(rightX, y1, y2, amplitude, wavelength),
      fill: 'none',
      stroke: stroke,
      strokeWidth: 2,
    );
  }

  static String _wavyPath(
    double x,
    double y1,
    double y2,
    double amplitude,
    double wavelength,
  ) {
    final buf = StringBuffer('M ${_n(x)} ${_n(y1)}');
    double currentY = y1;
    var toRight = true;
    while (currentY < y2) {
      final nextY = math.min(currentY + wavelength / 2, y2);
      final controlY = (currentY + nextY) / 2;
      final controlX = x + (toRight ? amplitude : -amplitude);
      buf.write(' Q ${_n(controlX)} ${_n(controlY)} ${_n(x)} ${_n(nextY)}');
      toRight = !toRight;
      currentY = nextY;
    }
    return buf.toString();
  }

  static String _n(double value) {
    final rounded = (value * 100).round() / 100;
    if (rounded == rounded.roundToDouble()) {
      return rounded.toStringAsFixed(0);
    }
    return rounded.toStringAsFixed(2);
  }
}
