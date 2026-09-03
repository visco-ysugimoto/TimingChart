import 'dart:math' as math;
import 'package:flutter/material.dart';

/// デジタル信号1行分の波形パスを構築する。
///
/// 水平・垂直を個別の線分で描くと拡大時に角が欠けるため、
/// 1本の連続パスとして組み立てる。
Path buildDigitalWaveformPath({
  required List<int> values,
  required List<double> stepPositions,
  required double xOrigin,
  required double cellWidth,
  required double yHigh,
  required double yLow,
}) {
  final path = Path();
  if (values.isEmpty || stepPositions.length < values.length + 1) {
    return path;
  }

  double xAt(int index) => xOrigin + stepPositions[index] * cellWidth;
  double yAt(int value) => value != 0 ? yHigh : yLow;

  path.moveTo(xAt(0), yAt(values[0]));
  for (int t = 0; t < values.length - 1; t++) {
    path.lineTo(xAt(t + 1), yAt(values[t]));
    if (values[t] != values[t + 1]) {
      path.lineTo(xAt(t + 1), yAt(values[t + 1]));
    }
  }
  path.lineTo(xAt(values.length), yAt(values.last));
  return path;
}

/// [buildDigitalWaveformPath] と同じ形状の SVG path d 属性を返す。
String buildDigitalWaveformSvgPathD({
  required List<int> values,
  required List<double> stepPositions,
  required double xOrigin,
  required double cellWidth,
  required double yHigh,
  required double yLow,
  required String Function(double) formatCoord,
}) {
  if (values.isEmpty || stepPositions.length < values.length + 1) {
    return '';
  }

  double xAt(int index) => xOrigin + stepPositions[index] * cellWidth;
  double yAt(int value) => value != 0 ? yHigh : yLow;
  final buffer = StringBuffer();

  void move(double x, double y) =>
      buffer.write('M ${formatCoord(x)} ${formatCoord(y)}');
  void line(double x, double y) =>
      buffer.write(' L ${formatCoord(x)} ${formatCoord(y)}');

  move(xAt(0), yAt(values[0]));
  for (int t = 0; t < values.length - 1; t++) {
    line(xAt(t + 1), yAt(values[t]));
    if (values[t] != values[t + 1]) {
      line(xAt(t + 1), yAt(values[t + 1]));
    }
  }
  line(xAt(values.length), yAt(values.last));
  return buffer.toString();
}

/// 波形描画用のストローク [Paint] を返す。
Paint createWaveformStrokePaint(
  Color color, {
  double strokeWidth = 2.0,
}) {
  return Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.miter
    ..strokeCap = StrokeCap.butt;
}

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

/// 任意の2点間に矢印付きの直線を描画
void drawArrowLine(
  Canvas canvas,
  Offset start,
  Offset end, {
  Color color = Colors.blue,
  double strokeWidth = 2.0,
}) {
  final Paint linePaint =
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;

  canvas.drawLine(start, end, linePaint);

  final double angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
  drawArrowhead(canvas, end, angle, 8.0, linePaint);
}

/// コメントボックスを描画
void drawCommentBox(
  Canvas canvas,
  Rect rect,
  TextPainter textPainter,
  String annId,
  String? selectedAnnotationId, // Added to handle selection state
  Color? borderColor, // コメントごとの枠線色（非選択時）
  Color? backgroundColor, // コメントごとの背景色（null=デフォルト）
) {
  final bool isSelected = selectedAnnotationId == annId;

  // カード風に見せるために角丸＋影付きで描画
  final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

  final Color defaultBackground = const Color(0xFFFDFDFD);
  final Color effectiveBackground = backgroundColor ?? defaultBackground;
  final Color fillColor =
      isSelected ? const Color(0xFFFFF3CD) : effectiveBackground;
  final bool drawBackground = isSelected || fillColor.a > 0;

  if (drawBackground) {
    // 1. さりげないドロップシャドウ
    final RRect shadowRRect = rrect.shift(const Offset(0, 2));
    final Paint shadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill;
    canvas.drawRRect(shadowRRect, shadowPaint);

    // 2. ベース色（選択時と通常時で変える）
    final Paint paintBase =
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, paintBase);
  }

  // 3. 枠線（選択時はアクセントカラー＋太め）
  final Color effectiveBorderColor = borderColor ?? Colors.grey.shade600;
  final bool drawBorder = isSelected || effectiveBorderColor.a > 0;
  if (drawBorder) {
    final Paint paintBorder =
        Paint()
          ..color =
              isSelected ? const Color(0xFFF0AD4E) : effectiveBorderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2.0 : 1.0;
    canvas.drawRRect(rrect, paintBorder);
  }

  // 4. テキストをボックス内で縦横中央揃えで配置
  final double textX = rect.left + (rect.width - textPainter.width) / 2;
  final double textY = rect.top + (rect.height - textPainter.height) / 2;
  textPainter.paint(canvas, Offset(textX, textY));
}

/// 矢印を描画
void drawArrow(Canvas canvas, Rect arrowRect, {Color color = Colors.blue}) {
  final paintArrowLine =
      Paint()
        ..color = color
        ..strokeWidth = 4;
  final startPt = Offset(arrowRect.left, arrowRect.center.dy);
  final endPt = Offset(arrowRect.right, arrowRect.center.dy);
  canvas.drawLine(startPt, endPt, paintArrowLine);
  const double headLength = 8;
  // Call existing drawArrowhead from this file
  drawArrowhead(canvas, startPt, math.pi, headLength, paintArrowLine);
  drawArrowhead(canvas, endPt, 0, headLength, paintArrowLine);
}

void drawWavyVerticalLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint, {
  double amplitude = 4.0,
  double wavelength = 12.0,
}) {
  // 垂直方向の波線を描画するユーティリティ関数
  // start.dy < end.dy を前提
  if (end.dy <= start.dy) return;

  final Path path = Path()..moveTo(start.dx, start.dy);

  // 半波長ごとに quadraticBezierTo を使って滑らかな曲線を描く
  double currentY = start.dy;
  bool toRight = true; // 最初は右に振れる

  while (currentY < end.dy) {
    final double nextY = (currentY + wavelength / 2).clamp(start.dy, end.dy);
    final double controlY = (currentY + nextY) / 2;
    final double controlX = start.dx + (toRight ? amplitude : -amplitude);

    path.quadraticBezierTo(controlX, controlY, start.dx, nextY);

    toRight = !toRight; // 向きを反転
    currentY = nextY;
  }

  canvas.drawPath(path, paint);
}

/// 2本の波線を垂直に並べ、その間を塗りつぶして描画する
void drawDoubleWavyVerticalLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint strokePaint, {
  double amplitude = 3.0,
  double wavelength = 12.0,
  double gap = 8.0, // 2本の波線間の距離
  Color fillColor = Colors.white,
}) {
  if (end.dy <= start.dy) return;

  // 左右にオフセット
  final double halfGap = gap / 2;

  final Path leftPath = Path()..moveTo(start.dx - halfGap, start.dy);
  final Path rightPath = Path()..moveTo(start.dx + halfGap, start.dy);

  // List to accumulate offsets for area fill
  final List<Offset> leftPoints = [Offset(start.dx - halfGap, start.dy)];
  final List<Offset> rightPoints = [Offset(start.dx + halfGap, start.dy)];

  double currentY = start.dy;
  bool toRight = true;

  while (currentY < end.dy) {
    final double nextY = (currentY + wavelength / 2).clamp(start.dy, end.dy);
    final double controlY = (currentY + nextY) / 2;

    // left
    final double controlXLeft =
        start.dx - halfGap + (toRight ? amplitude : -amplitude);
    leftPath.quadraticBezierTo(
      controlXLeft,
      controlY,
      start.dx - halfGap,
      nextY,
    );
    leftPoints.add(Offset(start.dx - halfGap, nextY));

    // right (位相は同じ向き)
    final double controlXRight =
        start.dx + halfGap + (toRight ? amplitude : -amplitude);
    rightPath.quadraticBezierTo(
      controlXRight,
      controlY,
      start.dx + halfGap,
      nextY,
    );
    rightPoints.add(Offset(start.dx + halfGap, nextY));

    toRight = !toRight;
    currentY = nextY;
  }

  // 塗りつぶし領域を作成
  final Path areaPath =
      Path()..moveTo(leftPoints.first.dx, leftPoints.first.dy);
  for (var p in leftPoints.skip(1)) {
    areaPath.lineTo(p.dx, p.dy);
  }
  for (var p in rightPoints.reversed) {
    areaPath.lineTo(p.dx, p.dy);
  }
  areaPath.close();

  // 塗りつぶし
  final Paint fillPaint =
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;
  canvas.drawPath(areaPath, fillPaint);

  // 枠線（2本の波線）
  canvas.drawPath(leftPath, strokePaint);
  canvas.drawPath(rightPath, strokePaint);
}
