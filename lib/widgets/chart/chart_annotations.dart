import 'package:flutter/material.dart';
import '../../models/chart/timing_chart_annotation.dart';
import 'dart:math' as math;

class ChartAnnotations extends StatelessWidget {
  final List<TimingChartAnnotation> annotations;
  final double cellWidth;
  final double cellHeight;
  final int timeSteps;

  const ChartAnnotations({
    super.key,
    required this.annotations,
    required this.cellWidth,
    required this.cellHeight,
    required this.timeSteps,
  }) : assert(cellWidth > 0, 'セル幅は0より大きい必要があります'),
       assert(cellHeight > 0, 'セル高さは0より大きい必要があります'),
       assert(timeSteps > 0, 'タイムステップは0より大きい必要があります');

  @override
  Widget build(BuildContext context) {
    if (annotations.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      size: Size(timeSteps * cellWidth, cellHeight * 2),
      painter: _ChartAnnotationsPainter(
        annotations: annotations,
        cellWidth: cellWidth,
        cellHeight: cellHeight,
        timeSteps: timeSteps,
      ),
    );
  }
}

class _ChartAnnotationsPainter extends CustomPainter {
  final List<TimingChartAnnotation> annotations;
  final double cellWidth;
  final double cellHeight;
  final int timeSteps;

  _ChartAnnotationsPainter({
    required this.annotations,
    required this.cellWidth,
    required this.cellHeight,
    required this.timeSteps,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      // 描画済みの矩形を記録して衝突回避
      final List<Rect> placedRects = [];
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      // アノテーションをソート（startTimeIndexで昇順）
      final sortedAnnotations = [...annotations]
        ..sort((a, b) => a.startTimeIndex.compareTo(b.startTimeIndex));

      for (final annotation in sortedAnnotations) {
        // 範囲外チェック
        if (annotation.startTimeIndex < 0 ||
            annotation.startTimeIndex >= timeSteps) {
          debugPrint('警告: アノテーションのタイムステップが範囲外です: ${annotation.startTimeIndex}');
          continue;
        }

        // 開始位置を計算
        final xStart = annotation.startTimeIndex * cellWidth;
        double xEnd;

        // 範囲アノテーションの場合
        if (annotation.endTimeIndex != null) {
          // 範囲の終了位置を計算
          final endTimeIndex = math.min(
            annotation.endTimeIndex!,
            timeSteps - 1,
          );
          xEnd = (endTimeIndex + 1) * cellWidth;
        } else {
          // 単一ポイントの場合
          xEnd = xStart;
        }

        // アノテーションの線を描画
        final linePaint =
            Paint()
              ..color = Colors.blue.withOpacity(0.7)
              ..strokeWidth = 1.0
              ..style = PaintingStyle.stroke;

        // 垂直線を描画（点線）
        drawDashedLine(
          canvas,
          Offset(xStart, 0),
          Offset(xStart, size.height / 2),
          linePaint,
        );

        // 範囲アノテーションの場合は終了位置にも線を引く
        if (annotation.endTimeIndex != null) {
          drawDashedLine(
            canvas,
            Offset(xEnd, 0),
            Offset(xEnd, size.height / 2),
            linePaint,
          );

          // 水平線を描画（範囲を示す）
          final arrowY = size.height / 2 + 10;
          canvas.drawLine(
            Offset(xStart, arrowY),
            Offset(xEnd, arrowY),
            linePaint,
          );

          // 矢印ヘッドを描画
          drawArrowhead(canvas, Offset(xStart, arrowY), math.pi, 6, linePaint);
          drawArrowhead(canvas, Offset(xEnd, arrowY), 0, 6, linePaint);
        }

        // テキストを描画
        textPainter.text = TextSpan(
          text: annotation.text,
          style: const TextStyle(color: Colors.blue, fontSize: 12),
        );

        textPainter.layout(maxWidth: 150);

        // テキスト位置を計算（中央揃えで）
        double textX;
        if (annotation.endTimeIndex != null) {
          // 範囲アノテーションの場合は範囲の中央
          textX = (xStart + xEnd) / 2 - textPainter.width / 2;
        } else {
          // 単一ポイントの場合
          textX = xStart - textPainter.width / 2;
        }

        // 衝突回避（既存の矩形と重なる場合は位置調整）
        double textY = size.height / 2 + 20;
        Rect textRect = Rect.fromLTWH(
          textX,
          textY,
          textPainter.width,
          textPainter.height,
        );

        int attempts = 0;
        const yStep = 20.0;
        while (placedRects.any((r) => r.overlaps(textRect)) && attempts < 5) {
          textY += yStep;
          textRect = Rect.fromLTWH(
            textX,
            textY,
            textPainter.width,
            textPainter.height,
          );
          attempts++;
        }

        // 背景を描画（読みやすさのため）
        final bgPaint =
            Paint()
              ..color = Colors.white.withOpacity(0.8)
              ..style = PaintingStyle.fill;
        canvas.drawRect(textRect, bgPaint);

        // テキストを描画
        textPainter.paint(canvas, Offset(textX, textY));

        // 描画した矩形を記録
        placedRects.add(textRect);
      }
    } catch (e) {
      debugPrint('エラー: アノテーションの描画中にエラーが発生しました: $e');
    }
  }

  void drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashWidth = 5,
    double dashSpace = 3,
  }) {
    final distance = (end - start).distance;
    final dashCount = (distance / (dashWidth + dashSpace)).floor();

    final dashVector = (end - start) / distance * dashWidth;
    final spaceVector = (end - start) / distance * dashSpace;

    Offset currentPoint = start;
    for (int i = 0; i < dashCount; i++) {
      final dashEnd = currentPoint + dashVector;
      canvas.drawLine(currentPoint, dashEnd, paint);
      currentPoint = dashEnd + spaceVector;
    }

    // 残りの距離を描画
    if ((end - currentPoint).distance > 0) {
      canvas.drawLine(currentPoint, end, paint);
    }
  }

  void drawArrowhead(
    Canvas canvas,
    Offset tip,
    double angle,
    double length,
    Paint paint,
  ) {
    final p1 = Offset(
      tip.dx - length * math.cos(angle - math.pi / 6),
      tip.dy - length * math.sin(angle - math.pi / 6),
    );
    final p2 = Offset(
      tip.dx - length * math.cos(angle + math.pi / 6),
      tip.dy - length * math.sin(angle + math.pi / 6),
    );

    canvas.drawLine(tip, p1, paint);
    canvas.drawLine(tip, p2, paint);
  }

  @override
  bool shouldRepaint(covariant _ChartAnnotationsPainter oldDelegate) {
    return annotations != oldDelegate.annotations ||
        cellWidth != oldDelegate.cellWidth ||
        cellHeight != oldDelegate.cellHeight ||
        timeSteps != oldDelegate.timeSteps;
  }
}
