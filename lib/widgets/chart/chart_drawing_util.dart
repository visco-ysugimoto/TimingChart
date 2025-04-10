import 'dart:math' as math;
import 'package:flutter/material.dart';

/// キャンバス上に破線を描画するユーティリティ関数
void drawDashedLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint, {
  double dashWidth = 5.0,
  double dashSpace = 3.0,
}) {
  final double totalDistance = (end - start).distance;
  final double patternLength = dashWidth + dashSpace;
  final int dashCount = (totalDistance / patternLength).floor();

  debugPrint('=== drawDashedLine Debug ===');
  debugPrint('Start: $start');
  debugPrint('End: $end');
  debugPrint('Paint color: ${paint.color}');
  debugPrint('Paint strokeWidth: ${paint.strokeWidth}');
  debugPrint('Total distance: $totalDistance');
  debugPrint('Pattern length: $patternLength');
  debugPrint('Dash count: $dashCount');

  // 破線の各セグメントを描画
  for (int i = 0; i < dashCount; i++) {
    final double startFraction = i * patternLength / totalDistance;
    final double endFraction = (i * patternLength + dashWidth) / totalDistance;
    final Offset currentPoint = Offset.lerp(start, end, startFraction)!;
    final Offset nextPoint = Offset.lerp(start, end, endFraction)!;

    debugPrint(
      'Drawing dash $i: ${currentPoint.dx.toStringAsFixed(2)},${currentPoint.dy.toStringAsFixed(2)} -> ${nextPoint.dx.toStringAsFixed(2)},${nextPoint.dy.toStringAsFixed(2)}',
    );
    canvas.drawLine(currentPoint, nextPoint, paint);
  }

  // 残りの部分を描画
  final double remainingStartFraction =
      dashCount * patternLength / totalDistance;
  if (remainingStartFraction < 1.0) {
    final Offset currentPoint =
        Offset.lerp(start, end, remainingStartFraction)!;
    debugPrint(
      'Drawing remaining: ${currentPoint.dx.toStringAsFixed(2)},${currentPoint.dy.toStringAsFixed(2)} -> ${end.dx.toStringAsFixed(2)},${end.dy.toStringAsFixed(2)}',
    );
    canvas.drawLine(currentPoint, end, paint);
  }
  debugPrint('=== End drawDashedLine ===\n');
}

/// キャンバス上に矢印ヘッドを描画するユーティリティ関数
void drawArrowhead(
  Canvas canvas,
  Offset tip,
  double angle,
  double length,
  Paint paint,
) {
  final leftEnd = Offset(
    tip.dx - length * math.cos(angle - math.pi / 6),
    tip.dy - length * math.sin(angle - math.pi / 6),
  );
  final rightEnd = Offset(
    tip.dx - length * math.cos(angle + math.pi / 6),
    tip.dy - length * math.sin(angle + math.pi / 6),
  );
  canvas.drawLine(tip, leftEnd, paint);
  canvas.drawLine(tip, rightEnd, paint);
}
