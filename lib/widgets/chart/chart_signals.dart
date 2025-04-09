import 'package:flutter/material.dart';
import '../../models/chart/signal_data.dart';

class ChartSignals extends StatelessWidget {
  final List<SignalData> signals;
  final double cellWidth;
  final double cellHeight;
  final int timeSteps;

  const ChartSignals({
    super.key,
    required this.signals,
    required this.cellWidth,
    required this.cellHeight,
    required this.timeSteps,
  }) : assert(cellWidth > 0, 'セル幅は0より大きい必要があります'),
       assert(cellHeight > 0, 'セル高さは0より大きい必要があります'),
       assert(timeSteps > 0, 'タイムステップは0より大きい必要があります');

  @override
  Widget build(BuildContext context) {
    if (signals.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      size: Size(timeSteps * cellWidth, signals.length * cellHeight),
      painter: _ChartSignalsPainter(
        signals: signals,
        cellWidth: cellWidth,
        cellHeight: cellHeight,
        timeSteps: timeSteps,
      ),
    );
  }
}

class _ChartSignalsPainter extends CustomPainter {
  final List<SignalData> signals;
  final double cellWidth;
  final double cellHeight;
  final int timeSteps;
  // 高レベル信号の描画位置オフセット
  static const double waveAmplitude = 10.0;

  _ChartSignalsPainter({
    required this.signals,
    required this.cellWidth,
    required this.cellHeight,
    required this.timeSteps,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      for (int i = 0; i < signals.length; i++) {
        final signal = signals[i];
        final yOffset = i * cellHeight + (cellHeight / 2);
        final paint =
            Paint()
              ..color = signal.color
              ..strokeWidth = 2.0
              ..style = PaintingStyle.stroke;

        // 値がtimeStepsより短い場合の処理
        final valueLength = signal.values.length;
        if (valueLength == 0) continue;

        for (int t = 0; t < valueLength - 1; t++) {
          if (t >= timeSteps - 1) break; // timeSteps内に収める

          final currentValue = signal.values[t];
          final nextValue = signal.values[t + 1];

          // x座標計算
          final xStart = t * cellWidth;
          final xEnd = (t + 1) * cellWidth;

          // y座標計算 (値が1なら上、0なら中央)
          final yCurrent =
              (currentValue == 1) ? (yOffset - waveAmplitude) : yOffset;
          final yNext = (nextValue == 1) ? (yOffset - waveAmplitude) : yOffset;

          // 水平線を描画
          canvas.drawLine(
            Offset(xStart, yCurrent),
            Offset(xEnd, yCurrent),
            paint,
          );

          // 値が変化する場合は垂直線も描画
          if (currentValue != nextValue) {
            canvas.drawLine(Offset(xEnd, yCurrent), Offset(xEnd, yNext), paint);
          }
        }

        // 最後の要素の水平線 (次の値がないため個別処理)
        if (valueLength > 0 && valueLength <= timeSteps) {
          final lastIdx = valueLength - 1;
          final lastValue = signal.values[lastIdx];
          final xStart = lastIdx * cellWidth;
          final xEnd = (lastIdx + 1) * cellWidth;
          final yLast = (lastValue == 1) ? (yOffset - waveAmplitude) : yOffset;

          canvas.drawLine(Offset(xStart, yLast), Offset(xEnd, yLast), paint);
        }
      }
    } catch (e) {
      debugPrint('エラー: 信号の描画中にエラーが発生しました: $e');
    }
  }

  @override
  bool shouldRepaint(covariant _ChartSignalsPainter oldDelegate) {
    return signals != oldDelegate.signals ||
        cellWidth != oldDelegate.cellWidth ||
        cellHeight != oldDelegate.cellHeight ||
        timeSteps != oldDelegate.timeSteps;
  }
}
