import 'package:flutter/material.dart';

class ChartGrid extends StatelessWidget {
  final int timeSteps;
  final double cellWidth;
  final double cellHeight;
  final int signalCount;

  const ChartGrid({
    super.key,
    required this.timeSteps,
    required this.cellWidth,
    required this.cellHeight,
    required this.signalCount,
  }) : assert(timeSteps > 0, 'タイムステップは0より大きい必要があります'),
       assert(cellWidth > 0, 'セル幅は0より大きい必要があります'),
       assert(cellHeight > 0, 'セル高さは0より大きい必要があります'),
       assert(signalCount >= 0, '信号数は0以上である必要があります');

  @override
  Widget build(BuildContext context) {
    if (signalCount == 0) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      size: Size(timeSteps * cellWidth, signalCount * cellHeight),
      painter: _ChartGridPainter(
        timeSteps: timeSteps,
        cellWidth: cellWidth,
        cellHeight: cellHeight,
        signalCount: signalCount,
      ),
    );
  }
}

class _ChartGridPainter extends CustomPainter {
  final int timeSteps;
  final double cellWidth;
  final double cellHeight;
  final int signalCount;

  _ChartGridPainter({
    required this.timeSteps,
    required this.cellWidth,
    required this.cellHeight,
    required this.signalCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final paint =
          Paint()
            ..color = Colors.grey.withOpacity(0.3)
            ..strokeWidth = 1.0;

      // 縦線を描画
      for (int i = 0; i <= timeSteps; i++) {
        final x = i * cellWidth;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }

      // 横線を描画
      for (int i = 0; i <= signalCount; i++) {
        final y = i * cellHeight;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } catch (e) {
      debugPrint('エラー: グリッドの描画中にエラーが発生しました: $e');
    }
  }

  @override
  bool shouldRepaint(covariant _ChartGridPainter oldDelegate) {
    return timeSteps != oldDelegate.timeSteps ||
        cellWidth != oldDelegate.cellWidth ||
        cellHeight != oldDelegate.cellHeight ||
        signalCount != oldDelegate.signalCount;
  }
}
