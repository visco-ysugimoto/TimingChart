import 'package:flutter/material.dart';
import '../../models/chart/signal_data.dart';
import '../../models/chart/signal_type.dart';
import 'chart_coordinate_mapper.dart';
import 'dart:math' as math;

/// 信号波形描画を管理するクラス
class ChartSignalsManager {
  final double cellWidth;
  final double cellHeight;
  final double labelWidth;
  final List<SignalType> signalTypes;
  static const double waveAmplitude = 10;

  ChartSignalsManager({
    required this.cellWidth,
    required this.cellHeight,
    required this.labelWidth,
    required this.signalTypes,
  });

  /// 信号タイプに基づいて色を返す
  Color _getColorForSignalType(SignalType type) {
    switch (type) {
      case SignalType.input:
        return Colors.blue;
      case SignalType.output:
        return Colors.red;
      case SignalType.hwTrigger:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// 信号波形を描画
  void drawSignalWaveforms(Canvas canvas, List<List<int>> signals) {
    var paintLine = Paint()..strokeWidth = 2;

    for (int row = 0; row < signals.length; row++) {
      final rowData = signals[row];
      final yOffset = row * cellHeight + (cellHeight / 2);

      // 信号タイプに基づいて色を設定
      final currentSignalType =
          (row >= 0 && row < signalTypes.length)
              ? signalTypes[row]
              : SignalType.input;

      paintLine =
          Paint()
            ..color = _getColorForSignalType(currentSignalType)
            ..strokeWidth = 2;

      // 波形の描画
      for (int t = 0; t < rowData.length - 1; t++) {
        final currentValue = rowData[t];
        final nextValue = rowData[t + 1];

        final xStart = labelWidth + t * cellWidth;
        final xEnd = labelWidth + (t + 1) * cellWidth;

        final yCurrent =
            (currentValue == 1) ? (yOffset - waveAmplitude) : yOffset;
        final yNext = (nextValue == 1) ? (yOffset - waveAmplitude) : yOffset;

        // 水平線
        canvas.drawLine(
          Offset(xStart, yCurrent),
          Offset(xEnd, yCurrent),
          paintLine,
        );

        // 値変化なら垂直線
        if (currentValue != nextValue) {
          canvas.drawLine(
            Offset(xEnd, yCurrent),
            Offset(xEnd, yNext),
            paintLine,
          );
        }
      }

      // 最後の値の描画（空の場合にエラーを防ぐため）
      if (rowData.isNotEmpty) {
        final lastIndex = rowData.length - 1;
        final lastValue = rowData[lastIndex];
        final xStart = labelWidth + lastIndex * cellWidth;
        final xEnd = labelWidth + (lastIndex + 1) * cellWidth;
        final yLast = (lastValue == 1) ? (yOffset - waveAmplitude) : yOffset;
        canvas.drawLine(Offset(xStart, yLast), Offset(xEnd, yLast), paintLine);
      }
    }
  }

  /// 選択範囲のハイライトを描画
  void drawSelectionHighlight(
    Canvas canvas,
    int? startSignalIndex,
    int? endSignalIndex,
    int? startTimeIndex,
    int? endTimeIndex,
  ) {
    if (startSignalIndex == null ||
        endSignalIndex == null ||
        startTimeIndex == null ||
        endTimeIndex == null) {
      return;
    }

    final stSig = math.min(startSignalIndex, endSignalIndex);
    final edSig = math.max(startSignalIndex, endSignalIndex);
    final stTime = math.min(startTimeIndex, endTimeIndex);
    final edTime = math.max(startTimeIndex, endTimeIndex);

    final selectionRect = Rect.fromLTWH(
      labelWidth + stTime * cellWidth,
      stSig * cellHeight,
      (edTime - stTime + 1) * cellWidth,
      (edSig - stSig + 1) * cellHeight,
    );

    final paintSelection =
        Paint()
          ..color = Colors.blue.withOpacity(0.2)
          ..style = PaintingStyle.fill;

    canvas.drawRect(selectionRect, paintSelection);
  }
}

/// デジタル信号を描画するウィジェット
///
/// このウィジェットは、タイミングチャート上にデジタル信号を描画します。
/// 各信号はHigh/Lowの2つの状態を持ち、時間に応じて状態が変化します。
class ChartSignals extends StatelessWidget {
  /// 座標変換マッパー
  final ChartCoordinateMapper mapper;

  /// 信号データ
  /// 各要素は[time, value]のペアで、timeは時間、valueは信号値（0または1）
  final List<List<double>> signals;

  /// 信号タイプ
  final SignalType signalType;

  /// 信号の線の太さ
  final double strokeWidth;

  /// コンストラクタ
  ///
  /// [mapper] 座標変換マッパー
  /// [signals] 信号データ
  /// [signalType] 信号タイプ
  /// [strokeWidth] 信号の線の太さ
  ///
  /// 例外:
  /// - [ArgumentError] パラメータが不正な場合
  ChartSignals({
    super.key,
    required this.mapper,
    required this.signals,
    required this.signalType,
    this.strokeWidth = 2.0,
  }) : assert(signals.isNotEmpty, '信号データは空であってはいけません'),
       assert(strokeWidth > 0, '線の太さは0より大きい必要があります');

  /// 信号タイプに基づいて色を返す
  Color _getColorForSignalType() {
    switch (signalType) {
      case SignalType.input:
        return Colors.blue;
      case SignalType.output:
        return Colors.red;
      case SignalType.hwTrigger:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForSignalType();
    return CustomPaint(
      painter: _ChartSignalsPainter(
        mapper: mapper,
        signals: signals,
        color: color,
        strokeWidth: strokeWidth,
      ),
      size: Size.infinite,
    );
  }
}

/// デジタル信号を描画するペインター
class _ChartSignalsPainter extends CustomPainter {
  /// 座標変換マッパー
  final ChartCoordinateMapper mapper;

  /// 信号データ
  final List<List<double>> signals;

  /// 信号の色
  final Color color;

  /// 信号の線の太さ
  final double strokeWidth;

  /// コンストラクタ
  ///
  /// [mapper] 座標変換マッパー
  /// [signals] 信号データ
  /// [color] 信号の色
  /// [strokeWidth] 信号の線の太さ
  _ChartSignalsPainter({
    required this.mapper,
    required this.signals,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    for (var i = 0; i < signals.length; i++) {
      _drawSignal(canvas, paint, signals[i], i);
    }
  }

  /// 1つの信号を描画
  ///
  /// [canvas] 描画対象のキャンバス
  /// [paint] 描画に使用するペイント
  /// [signal] 信号データ
  /// [signalIndex] 信号のインデックス
  void _drawSignal(
    Canvas canvas,
    Paint paint,
    List<double> signal,
    int signalIndex,
  ) {
    if (signal.isEmpty) return;

    final path = Path();
    var isFirst = true;

    for (var i = 0; i < signal.length; i += 2) {
      final time = signal[i];
      final value = signal[i + 1];

      final x = mapper.mapTimeToX(time);
      final y =
          value == 1
              ? mapper.getSignalHighY(signalIndex)
              : mapper.getSignalLowY(signalIndex);

      if (isFirst) {
        path.moveTo(x, y);
        isFirst = false;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChartSignalsPainter oldDelegate) {
    return oldDelegate.mapper != mapper ||
        oldDelegate.signals != signals ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// 新しいコーディネートマッパーを使用したペインター
class ChartSignalsPainter extends CustomPainter {
  final List<SignalData> signals;
  final ChartCoordinateMapper mapper;

  ChartSignalsPainter({required this.signals, required this.mapper});

  /// 信号タイプに基づいて色を返す
  Color _getColorForSignalType(SignalType type) {
    switch (type) {
      case SignalType.input:
        return Colors.blue;
      case SignalType.output:
        return Colors.red;
      case SignalType.hwTrigger:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    try {
      for (int i = 0; i < signals.length; i++) {
        final signal = signals[i];
        final signalColor = _getColorForSignalType(signal.signalType);

        // 信号の色を使用
        final highPaint =
            Paint()
              ..color = signalColor
              ..strokeWidth = 2.0
              ..style = PaintingStyle.stroke;

        final lowPaint =
            Paint()
              ..color = signalColor
              ..strokeWidth = 2.0
              ..style = PaintingStyle.stroke;

        final transitionPaint =
            Paint()
              ..color = signalColor
              ..strokeWidth = 1.0
              ..style = PaintingStyle.stroke;

        // 信号のY座標を取得
        final signalYHigh = mapper.getSignalHighY(i);
        final signalYLow = mapper.getSignalLowY(i);

        // 値がない場合はスキップ
        if (signal.values.isEmpty) continue;

        // 時間ステップごとに描画
        double lastX = mapper.leftPadding;
        int lastValue = 0; // デフォルト値

        for (int t = 0; t < signal.values.length; t++) {
          final currentValue = signal.values[t];

          // 時間をX座標に変換（各値は等間隔と仮定）
          final timeStep = mapper.totalTime / (signal.values.length - 1);
          final currentTime = t * timeStep;
          final currentX = mapper.mapTimeToX(currentTime);

          // Y座標を計算
          final currentY = (currentValue == 1) ? signalYHigh : signalYLow;
          final lastY = (lastValue == 1) ? signalYHigh : signalYLow;

          // 水平線を描画
          if (t > 0) {
            canvas.drawLine(
              Offset(lastX, lastY),
              Offset(currentX, lastY),
              (lastValue == 1) ? highPaint : lowPaint,
            );
          }

          // 値が変化する場合は垂直線も描画
          if (currentValue != lastValue) {
            canvas.drawLine(
              Offset(currentX, lastY),
              Offset(currentX, currentY),
              transitionPaint,
            );
          }

          lastX = currentX;
          lastValue = currentValue;
        }

        // 最後の値から右端までの線を描画
        final endX = mapper.leftPadding + mapper.chartAreaWidth;
        if (endX > lastX) {
          final lastY = (lastValue == 1) ? signalYHigh : signalYLow;
          canvas.drawLine(
            Offset(lastX, lastY),
            Offset(endX, lastY),
            (lastValue == 1) ? highPaint : lowPaint,
          );
        }
      }
    } catch (e) {
      debugPrint('エラー: 信号の描画中にエラーが発生しました: $e');
    }
  }

  @override
  bool shouldRepaint(covariant ChartSignalsPainter oldDelegate) {
    return signals != oldDelegate.signals || mapper != oldDelegate.mapper;
  }
}
