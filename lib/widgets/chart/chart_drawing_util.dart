import 'dart:math' as math;
import 'package:flutter/material.dart';

/// キャンバス上に破線を描画するユーティリティ関数
void drawDashedLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint, {
  double dashWidth = 5,
  double dashSpace = 3,
}) {
  final totalDistance = (end - start).distance;
  final dashCount = (totalDistance / (dashWidth + dashSpace)).floor();
  final dashVector = (end - start) / totalDistance * dashWidth;
  final spaceVector = (end - start) / totalDistance * dashSpace;
  Offset currentPoint = start;
  for (int i = 0; i < dashCount; i++) {
    final nextPoint = currentPoint + dashVector;
    canvas.drawLine(currentPoint, nextPoint, paint);
    currentPoint = nextPoint + spaceVector;
  }
  if ((currentPoint - end).distance > 0) {
    canvas.drawLine(currentPoint, end, paint);
  }
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
