import 'dart:math' as math;
import 'dart:ui' show TextDirection;

import 'package:flutter/material.dart';

import '../models/chart/timing_chart_annotation.dart';
import '../utils/comment_text_spans.dart';
import 'chart_svg_export_data.dart';
import 'chart_svg_writer.dart';

/// アノテーション（コメント）を SVG 要素として出力する。
class ChartSvgAnnotations {
  ChartSvgAnnotations._();

  static void render(
    ChartSvgWriter writer,
    ChartSvgExportData data,
    int signalCount,
  ) {
    if (data.annotations.isEmpty) return;

    final originX = data.chartMarginLeft;
    final originY = data.chartMarginTop + data.topCommentAreaHeight;
    final chartBottomY = originY + signalCount * data.cellHeight;
    const bottomLabelAvoidOffset = 20.0;
    final labelExtraY =
        data.showBottomUnitLabels ? bottomLabelAvoidOffset : 0.0;
    final baseCommentY = chartBottomY + 20 + labelExtraY;

    final sorted = _sortAnnotations(data.annotations);
    final placedCommentRects = <Rect>[];
    final placedOnlyCommentRects = <Rect>[];
    final placedArrowRects = <Rect>[];
    final placedTopCommentRects = <Rect>[];
    final boundaryArrowBaseY = <int, double>{};
    final prepared = <_PreparedAnnotation>[];

    for (final ann in sorted) {
      final fontSize = (ann.fontSize != null && ann.fontSize!.isFinite)
          ? ann.fontSize!.clamp(6.0, 72.0)
          : 14.0;
      final fontWeight =
          ann.isBold == true ? FontWeight.bold : FontWeight.normal;
      final effMaxWidth = (ann.maxWidth != null && ann.maxWidth!.isFinite)
          ? ann.maxWidth!.clamp(40.0, 600.0)
          : 600.0;
      final effMaxLines =
          (ann.maxLines != null && ann.maxLines! > 0) ? ann.maxLines : null;
      final useEllipsis = ann.ellipsisEnabled ?? true;
      final textColor = ann.textColorValue != null
          ? Color(ann.textColorValue!)
          : Colors.black;

      final textSpan = buildCommentTextSpan(
        text: ann.text,
        baseStyle: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
        spans: ann.colorSpans,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: effMaxLines,
        ellipsis: (useEllipsis && effMaxLines != null) ? '...' : null,
      );
      textPainter.layout(maxWidth: effMaxWidth);
      final boxWidth = textPainter.width + 10;
      final boxHeight = textPainter.height + 10;

      final perAnnDashedColor = ann.dashedLineColorValue != null
          ? Color(ann.dashedLineColorValue!)
          : data.dashedColor;
      final perAnnArrowColor = ann.arrowColorValue != null
          ? Color(ann.arrowColorValue!)
          : data.arrowColor;
      final borderColor = !ann.isBorderVisible
          ? Colors.transparent
          : (ann.borderColorValue != null
              ? Color(ann.borderColorValue!)
              : Colors.grey.shade600);
      final backgroundColor = ann.backgroundColorValue != null
          ? Color(ann.backgroundColorValue!)
          : null;

      final placementTop = ann.placement == 'top';
      late Rect commentRect;
      Rect? arrowRect;

      if (placementTop) {
        final result = _layoutTopAnnotation(
          data: data,
          ann: ann,
          originX: originX,
          originY: originY,
          boxWidth: boxWidth,
          boxHeight: boxHeight,
          boundaryArrowBaseY: boundaryArrowBaseY,
          placedArrowRects: placedArrowRects,
          placedTopCommentRects: placedTopCommentRects,
        );
        commentRect = result.commentRect;
        arrowRect = result.arrowRect;
      } else if (ann.endTimeIndex != null) {
        double arrowBaseY = chartBottomY + 10 + labelExtraY;
        final startIdx = ann.startTimeIndex;
        final endIdx = ann.endTimeIndex!;
        if (boundaryArrowBaseY.containsKey(startIdx)) {
          arrowBaseY = boundaryArrowBaseY[startIdx]!;
        }
        final arrowStartX = originX + _boundaryX(data, ann.startTimeIndex);
        final arrowEndX = originX + _boundaryX(data, ann.endTimeIndex! + 1);
        const arrowThickness = 4.0;
        var currentArrowRect = Rect.fromLTWH(
          arrowStartX,
          arrowBaseY - arrowThickness / 2,
          arrowEndX - arrowStartX,
          arrowThickness,
        );
        var attempts = 0;
        while ((_overlapsAny(currentArrowRect, placedArrowRects) ||
                _arrowOverlapsComments(
                  currentArrowRect,
                  placedOnlyCommentRects,
                )) &&
            attempts < 15) {
          arrowBaseY += 20;
          currentArrowRect = Rect.fromLTWH(
            arrowStartX,
            arrowBaseY - arrowThickness / 2,
            arrowEndX - arrowStartX,
            arrowThickness,
          );
          attempts++;
        }
        arrowRect = currentArrowRect;
        placedArrowRects.add(arrowRect);
        boundaryArrowBaseY.putIfAbsent(endIdx, () => arrowBaseY);

        double commentY;
        if (boxWidth <= arrowRect.width) {
          commentY = arrowRect.center.dy - boxHeight / 2;
          if (commentY < originY) {
            commentY = arrowRect.bottom + 5;
          }
        } else {
          commentY = arrowRect.bottom + 5;
        }
        final commentX = arrowRect.center.dx - boxWidth / 2;
        commentRect = Rect.fromLTWH(commentX, commentY, boxWidth, boxHeight);
      } else {
        final commentY = baseCommentY;
        final commentX = originX + _boundaryX(data, ann.startTimeIndex);
        commentRect = Rect.fromLTWH(commentX, commentY, boxWidth, boxHeight);
      }

      if (ann.offsetX != null || ann.offsetY != null) {
        commentRect = commentRect.shift(
          Offset(ann.offsetX ?? 0, ann.offsetY ?? 0),
        );
      }

      const double maxTopCommentAreaHeight = 100.0;
      const double topClipPadding = 8.0;
      const double minTopLeftY =
          -(maxTopCommentAreaHeight - topClipPadding);
      if (commentRect.top < minTopLeftY) {
        commentRect = commentRect.translate(0, minTopLeftY - commentRect.top);
      }

      if (placementTop) {
        var topAttempts = 0;
        while (placedTopCommentRects.any((r) => r.overlaps(commentRect)) &&
            topAttempts < 15 &&
            commentRect.top > minTopLeftY) {
          commentRect = commentRect.translate(0, -20);
          topAttempts++;
        }
        placedTopCommentRects.add(commentRect);
        if (arrowRect != null) placedArrowRects.add(arrowRect);
      } else {
        var attempts = 0;
        while (_overlapsAny(commentRect, placedCommentRects) && attempts < 15) {
          commentRect = commentRect.translate(0, 20);
          attempts++;
        }
        placedCommentRects.add(commentRect);
        placedOnlyCommentRects.add(commentRect);
        if (arrowRect != null) placedCommentRects.add(arrowRect);
      }

      prepared.add(
        _PreparedAnnotation(
          ann: ann,
          commentRect: commentRect,
          arrowRect: arrowRect,
          textSpan: textSpan,
          textPainter: textPainter,
          fontSize: fontSize,
          perAnnDashedColor: perAnnDashedColor,
          perAnnArrowColor: perAnnArrowColor,
          borderColor: borderColor,
          backgroundColor: backgroundColor,
          placementTop: placementTop,
        ),
      );
    }

    for (final item in prepared) {
      _drawDashedBoundaries(
        writer,
        data: data,
        ann: item.ann,
        originX: originX,
        originY: originY,
        chartBottomY: chartBottomY,
        commentRect: item.commentRect,
        signalCount: signalCount,
        color: item.perAnnDashedColor,
        placementTop: item.placementTop,
      );
      if (item.ann.isArrowVisible && item.arrowRect != null) {
        _drawSpanArrow(writer, item.arrowRect!, item.perAnnArrowColor);
      }
      _drawConnectorArrow(
        writer,
        data: data,
        ann: item.ann,
        commentRect: item.commentRect,
        originX: originX,
        originY: originY,
        chartBottomY: chartBottomY,
        signalCount: signalCount,
        color: item.perAnnArrowColor,
        placementTop: item.placementTop,
      );
    }

    for (final item in prepared) {
      _drawCommentBox(
        writer,
        _SvgCommentBox(
          rect: item.commentRect,
          textSpan: item.textSpan,
          textPainter: item.textPainter,
          fontSize: item.fontSize,
          borderColor: item.borderColor,
          backgroundColor: item.backgroundColor,
        ),
      );
    }
  }

  static _TopLayoutResult _layoutTopAnnotation({
    required ChartSvgExportData data,
    required TimingChartAnnotation ann,
    required double originX,
    required double originY,
    required double boxWidth,
    required double boxHeight,
    required Map<int, double> boundaryArrowBaseY,
    required List<Rect> placedArrowRects,
    required List<Rect> placedTopCommentRects,
  }) {
    const topArrowGap = 12.0;
    var arrowBaseY = originY - topArrowGap;
    Rect? arrowRect;

    late Rect commentRect;
    if (ann.endTimeIndex != null) {
      final startIdx = ann.startTimeIndex;
      if (boundaryArrowBaseY.containsKey(startIdx)) {
        arrowBaseY = boundaryArrowBaseY[startIdx]!;
      }
      final arrowStartX = originX + _boundaryX(data, ann.startTimeIndex);
      final arrowEndX = originX + _boundaryX(data, ann.endTimeIndex! + 1);
      const arrowThickness = 4.0;
      var currentArrowRect = Rect.fromLTWH(
        arrowStartX,
        arrowBaseY - arrowThickness / 2,
        arrowEndX - arrowStartX,
        arrowThickness,
      );
      var attempts = 0;
      while ((_overlapsAny(currentArrowRect, placedArrowRects) ||
              _arrowOverlapsComments(
                currentArrowRect,
                placedTopCommentRects,
              )) &&
          attempts < 15) {
        arrowBaseY -= 20;
        currentArrowRect = Rect.fromLTWH(
          arrowStartX,
          arrowBaseY - arrowThickness / 2,
          arrowEndX - arrowStartX,
          arrowThickness,
        );
        attempts++;
      }
      arrowRect = currentArrowRect;
      boundaryArrowBaseY.putIfAbsent(ann.endTimeIndex!, () => arrowBaseY);

      double commentY;
      if (boxWidth <= arrowRect.width) {
        commentY = arrowRect.center.dy - boxHeight / 2;
        if (commentY + boxHeight > originY) {
          commentY = arrowRect.top - boxHeight - 5;
        }
      } else {
        commentY = arrowRect.top - boxHeight - 5;
      }
      final commentX = arrowRect.center.dx - boxWidth / 2;
      commentRect = Rect.fromLTWH(commentX, commentY, boxWidth, boxHeight);
    } else {
      final commentY = originY - topArrowGap - 6 - boxHeight;
      final commentX = originX + _boundaryX(data, ann.startTimeIndex);
      commentRect = Rect.fromLTWH(commentX, commentY, boxWidth, boxHeight);
    }

    return _TopLayoutResult(commentRect: commentRect, arrowRect: arrowRect);
  }

  static void _drawDashedBoundaries(
    ChartSvgWriter writer, {
    required ChartSvgExportData data,
    required TimingChartAnnotation ann,
    required double originX,
    required double originY,
    required double chartBottomY,
    required Rect commentRect,
    required int signalCount,
    required Color color,
    required bool placementTop,
  }) {
    if (!ann.isDashedLineVisible) return;
    final stroke = ChartSvgWriter.color(color, opacity: 0.5);
    final startX = originX + _boundaryX(data, ann.startTimeIndex);
    final resolvedArrowTipY = (ann.arrowTipRowIndex != null &&
            ann.arrowTipRowIndex! >= 0 &&
            ann.arrowTipRowIndex! < signalCount)
        ? originY + (ann.arrowTipRowIndex! + 0.5) * data.cellHeight
        : ann.arrowTipY != null
        ? originY + ann.arrowTipY!
        : null;
    final useHorizontal = ann.arrowHorizontal != false;
    final anchorY = useHorizontal
        ? commentRect.center.dy
        : (resolvedArrowTipY ?? commentRect.top);
    final topY = placementTop
        ? math.min(originY, math.min(commentRect.top, anchorY))
        : originY;
    final bottomY = math.max(chartBottomY, anchorY);

    _dashedLine(writer, startX, topY, startX, bottomY, stroke);
    if (ann.endTimeIndex != null) {
      final endX = originX + _boundaryX(data, ann.endTimeIndex! + 1);
      _dashedLine(writer, endX, topY, endX, bottomY, stroke);
    }
  }

  static void _drawCommentBox(ChartSvgWriter writer, _SvgCommentBox box) {
    final fill = box.backgroundColor != null
        ? ChartSvgWriter.color(box.backgroundColor!)
        : '#FDFDFD';
    writer.rect(
      x: box.rect.left,
      y: box.rect.top,
      width: box.rect.width,
      height: box.rect.height,
      fill: fill,
      stroke: ChartSvgWriter.color(box.borderColor),
      rx: 8,
    );

    final textX = box.rect.left + 5;
    final spans = _tspansFromLaidOutText(box.textPainter, box.textSpan);
    writer.tspanGroup(
      x: textX,
      y: box.rect.top + box.fontSize + 4,
      spans: spans,
      fontSize: box.fontSize,
    );
  }

  static List<
    ({String text, String fill, String fontWeight, bool newLine, double dy})
  >
  _tspansFromLaidOutText(TextPainter painter, TextSpan span) {
    final fullText = span.toPlainText();
    if (fullText.isEmpty) return const [];

    final runs = _styledRunsFromTextSpan(span);
    final lines = _lineRanges(painter, fullText);
    if (lines.isEmpty) {
      return [
        for (final run in runs)
          if (run.end > run.start)
            (
              text: fullText.substring(run.start, run.end),
              fill: run.fill,
              fontWeight: run.fontWeight,
              newLine: false,
              dy: 0.0,
            ),
      ];
    }

    final result =
        <
          ({
            String text,
            String fill,
            String fontWeight,
            bool newLine,
            double dy,
          })
        >[];
    for (final line in lines) {
      var firstOnLine = true;
      for (final run in runs) {
        final start = math.max(run.start, line.start);
        final end = math.min(run.end, line.end);
        if (end <= start) continue;
        result.add((
          text: fullText.substring(start, end),
          fill: run.fill,
          fontWeight: run.fontWeight,
          newLine: firstOnLine,
          dy: firstOnLine ? line.dy : 0.0,
        ));
        firstOnLine = false;
      }
      if (firstOnLine) {
        result.add((
          text: '',
          fill: '#000000',
          fontWeight: 'normal',
          newLine: true,
          dy: line.dy,
        ));
      }
    }
    return result;
  }

  static List<({int start, int end, String fill, String fontWeight})>
  _styledRunsFromTextSpan(TextSpan span) {
    final result = <({int start, int end, String fill, String fontWeight})>[];
    var offset = 0;
    void walk(TextSpan node, TextStyle? inherited) {
      final style = node.style == null
          ? inherited
          : (inherited?.merge(node.style) ?? node.style);
      final text = node.text;
      if (text != null && text.isNotEmpty) {
        result.add((
          start: offset,
          end: offset + text.length,
          fill: ChartSvgWriter.color(style?.color ?? Colors.black),
          fontWeight: style?.fontWeight == FontWeight.bold ? 'bold' : 'normal',
        ));
        offset += text.length;
      }
      if (node.children != null) {
        for (final child in node.children!) {
          if (child is TextSpan) walk(child, style);
        }
      }
    }

    walk(span, span.style);
    return result;
  }

  static List<({int start, int end, double dy})> _lineRanges(
    TextPainter painter,
    String text,
  ) {
    if (text.isEmpty) return const [];
    final metrics = painter.computeLineMetrics();
    if (metrics.isEmpty) {
      return [(start: 0, end: text.length, dy: 0.0)];
    }

    final ranges = <({int start, int end, double dy})>[];
    var offset = 0;
    var lineIndex = 0;
    while (offset < text.length && lineIndex < text.length + 4) {
      final boundary = painter.getLineBoundary(
        TextPosition(offset: offset, affinity: TextAffinity.downstream),
      );
      final start = math.max(offset, boundary.start).clamp(0, text.length);
      var end = boundary.end.clamp(0, text.length);
      if (end <= start) {
        if (offset < text.length &&
            (text.codeUnitAt(offset) == 0x0A ||
                text.codeUnitAt(offset) == 0x0D)) {
          end = start;
        } else {
          offset += 1;
          continue;
        }
      }
      var contentEnd = end;
      while (contentEnd > start) {
        final code = text.codeUnitAt(contentEnd - 1);
        if (code == 0x0A || code == 0x0D) {
          contentEnd--;
        } else {
          break;
        }
      }
      final dy = lineIndex == 0
          ? 0.0
          : (lineIndex < metrics.length
                ? metrics[lineIndex].baseline - metrics[lineIndex - 1].baseline
                : painter.preferredLineHeight);
      ranges.add((start: start, end: contentEnd, dy: dy));
      lineIndex++;
      var next = boundary.end;
      if (next <= offset) next = offset + 1;
      offset = next;
    }
    return ranges;
  }

  static void _drawSpanArrow(
    ChartSvgWriter writer,
    Rect arrowRect,
    Color color,
  ) {
    final stroke = ChartSvgWriter.color(color);
    final y = arrowRect.center.dy;
    writer.line(
      x1: arrowRect.left,
      y1: y,
      x2: arrowRect.right,
      y2: y,
      stroke: stroke,
      strokeWidth: 4,
    );
    _arrowhead(writer, arrowRect.left, y, math.pi, stroke);
    _arrowhead(writer, arrowRect.right, y, 0, stroke);
  }

  static void _drawConnectorArrow(
    ChartSvgWriter writer, {
    required ChartSvgExportData data,
    required TimingChartAnnotation ann,
    required Rect commentRect,
    required double originX,
    required double originY,
    required double chartBottomY,
    required int signalCount,
    required Color color,
    required bool placementTop,
  }) {
    if (!ann.isArrowVisible) return;

    final boundaryStart = originX + _boundaryX(data, ann.startTimeIndex);
    final boundaryEnd = ann.endTimeIndex != null
        ? originX + _boundaryX(data, ann.endTimeIndex! + 1)
        : boundaryStart;
    final originalCommentCenterX = ann.endTimeIndex != null
        ? (boundaryStart + boundaryEnd) / 2
        : boundaryStart;
    final movedInX =
        (commentRect.center.dx - originalCommentCenterX).abs() > 1.0;
    if (!movedInX) return;

    final resolvedArrowTipY = (ann.arrowTipRowIndex != null &&
            ann.arrowTipRowIndex! >= 0 &&
            ann.arrowTipRowIndex! < signalCount)
        ? originY + (ann.arrowTipRowIndex! + 0.5) * data.cellHeight
        : ann.arrowTipY != null
        ? originY + ann.arrowTipY!
        : null;
    final useHorizontal = ann.arrowHorizontal != false;
    final boundaryEndY = math.max(chartBottomY, resolvedArrowTipY ?? commentRect.top);
    final anchorY = useHorizontal
        ? commentRect.center.dy
        : (resolvedArrowTipY ?? boundaryEndY);

    final endX = originalCommentCenterX;
    final endY = anchorY;
    final double startX;
    final double startY;
    if (useHorizontal) {
      startX = commentRect.right;
      startY = anchorY;
    } else if (placementTop) {
      startX = commentRect.center.dx;
      startY = commentRect.bottom;
    } else {
      startX = commentRect.center.dx;
      startY = commentRect.top;
    }

    _drawArrowLine(writer, startX, startY, endX, endY, color);
  }

  static void _drawArrowLine(
    ChartSvgWriter writer,
    double startX,
    double startY,
    double endX,
    double endY,
    Color color,
  ) {
    final stroke = ChartSvgWriter.color(color);
    writer.line(
      x1: startX,
      y1: startY,
      x2: endX,
      y2: endY,
      stroke: stroke,
      strokeWidth: 2,
    );
    final angle = math.atan2(endY - startY, endX - startX);
    _arrowhead(writer, endX, endY, angle, stroke);
  }

  static void _arrowhead(
    ChartSvgWriter writer,
    double tipX,
    double tipY,
    double angle,
    String stroke,
  ) {
    const length = 8.0;
    final leftX = tipX - length * math.cos(angle - math.pi / 6);
    final leftY = tipY - length * math.sin(angle - math.pi / 6);
    final rightX = tipX - length * math.cos(angle + math.pi / 6);
    final rightY = tipY - length * math.sin(angle + math.pi / 6);
    writer.line(x1: tipX, y1: tipY, x2: leftX, y2: leftY, stroke: stroke, strokeWidth: 2);
    writer.line(x1: tipX, y1: tipY, x2: rightX, y2: rightY, stroke: stroke, strokeWidth: 2);
  }

  static void _dashedLine(
    ChartSvgWriter writer,
    double x1,
    double y1,
    double x2,
    double y2,
    String stroke,
  ) {
    writer.line(
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      stroke: stroke,
      strokeWidth: 2,
      strokeDasharray: '5 3',
    );
  }

  static bool _overlapsAny(Rect rect, List<Rect> others) {
    for (final other in others) {
      if (rect.overlaps(other)) return true;
    }
    return false;
  }

  static bool _arrowOverlapsComments(Rect arrowRect, List<Rect> commentBoxes) {
    for (final box in commentBoxes) {
      final horizontal =
          arrowRect.right > box.left && arrowRect.left < box.right;
      final vertical =
          arrowRect.bottom > box.top && arrowRect.top < box.bottom;
      if (horizontal && vertical) return true;
    }
    return false;
  }

  static List<TimingChartAnnotation> _sortAnnotations(
    List<TimingChartAnnotation> annotations,
  ) {
    final sorted = [...annotations];
    sorted.sort((a, b) {
      final aIsRange = a.endTimeIndex != null;
      final bIsRange = b.endTimeIndex != null;
      if (aIsRange && !bIsRange) return -1;
      if (!aIsRange && bIsRange) return 1;
      if (aIsRange) {
        final cmpEnd = a.endTimeIndex!.compareTo(b.endTimeIndex!);
        return cmpEnd != 0
            ? cmpEnd
            : a.startTimeIndex.compareTo(b.startTimeIndex);
      }
      return a.startTimeIndex.compareTo(b.startTimeIndex);
    });
    return sorted;
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
}

class _PreparedAnnotation {
  final TimingChartAnnotation ann;
  final Rect commentRect;
  final Rect? arrowRect;
  final TextSpan textSpan;
  final TextPainter textPainter;
  final double fontSize;
  final Color perAnnDashedColor;
  final Color perAnnArrowColor;
  final Color borderColor;
  final Color? backgroundColor;
  final bool placementTop;

  const _PreparedAnnotation({
    required this.ann,
    required this.commentRect,
    required this.arrowRect,
    required this.textSpan,
    required this.textPainter,
    required this.fontSize,
    required this.perAnnDashedColor,
    required this.perAnnArrowColor,
    required this.borderColor,
    this.backgroundColor,
    required this.placementTop,
  });
}

class _SvgCommentBox {
  final Rect rect;
  final TextSpan textSpan;
  final TextPainter textPainter;
  final double fontSize;
  final Color borderColor;
  final Color? backgroundColor;

  const _SvgCommentBox({
    required this.rect,
    required this.textSpan,
    required this.textPainter,
    required this.fontSize,
    required this.borderColor,
    this.backgroundColor,
  });
}

class _TopLayoutResult {
  final Rect commentRect;
  final Rect? arrowRect;

  const _TopLayoutResult({required this.commentRect, this.arrowRect});
}
