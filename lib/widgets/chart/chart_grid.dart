import 'package:flutter/material.dart';
import 'chart_coordinate_mapper.dart';
import '../../models/chart/signal_type.dart';

/// グリッド描画を管理するクラス
class ChartGridManager {
  final double cellWidth;
  final double cellHeight;
  final double labelWidth;
  final List<String> signalNames;
  final List<SignalType> signalTypes;
  final bool showAllSignalTypes;
  // IO番号(末尾の数字)を表示するかどうか。true で表示、false で非表示。
  final bool showIoNumbers;
  // 行ごとのポート番号 (Input/Output/HWTrigger の元番号)。
  final List<int> portNumbers;
  final Color labelColor;
  // 選択範囲 (行) がある場合にラベルをハイライト
  final int? highlightStartRow;
  final int? highlightEndRow;
  final Color highlightTextColor;

  ChartGridManager({
    required this.cellWidth,
    required this.cellHeight,
    required this.labelWidth,
    required this.signalNames,
    required this.signalTypes,
    required this.portNumbers,
    this.showAllSignalTypes = false,
    this.showIoNumbers = true,
    this.labelColor = Colors.black,
    this.highlightStartRow,
    this.highlightEndRow,
    this.highlightTextColor = Colors.blue,
  });

  /// グリッド線を描画
  void drawGridLines(
    Canvas canvas,
    Size size,
    int signalCount,
    int maxTimeSteps,
  ) {
    final paintGuide =
        Paint()
          ..color = Colors.grey.withOpacity(0.5)
          ..strokeWidth = 1;

    // 縦線（タイムインデックス）
    for (int i = 0; i <= maxTimeSteps; i++) {
      final x = labelWidth + i * cellWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, signalCount * cellHeight),
        paintGuide,
      );
    }

    // 横線（信号区切り）
    int visibleRow = 0;
    for (int j = 0; j < signalCount; j++) {
      // 信号タイプに基づいて色を設定
      final currentSignalType =
          (j >= 0 && j < signalTypes.length)
              ? signalTypes[j]
              : SignalType.input;

      // Control、Group、Task信号は描画しない
      if (!showAllSignalTypes &&
          (currentSignalType == SignalType.control ||
              currentSignalType == SignalType.group ||
              currentSignalType == SignalType.task)) {
        continue;
      }

      final y = visibleRow * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGuide);
      visibleRow++;
    }
    // 最後の線を描画
    canvas.drawLine(
      Offset(0, visibleRow * cellHeight),
      Offset(size.width, visibleRow * cellHeight),
      paintGuide,
    );
  }

  /// 信号名ラベルを描画
  void drawSignalLabels(Canvas canvas, int signalCount) {
    for (int row = 0; row < signalCount; row++) {
      // 信号タイプに基づいて色を設定
      final currentSignalType =
          (row >= 0 && row < signalTypes.length)
              ? signalTypes[row]
              : SignalType.input;

      // Control、Group、Task信号は描画しない
      if (!showAllSignalTypes &&
          (currentSignalType == SignalType.control ||
              currentSignalType == SignalType.group ||
              currentSignalType == SignalType.task)) {
        continue;
      }

      final name = (row < signalNames.length) ? signalNames[row] : "";

      // 種別番号プレフィックスを生成
      String prefix = "";
      if (showIoNumbers && row < portNumbers.length) {
        final num = portNumbers[row];
        if (num > 0) {
          switch (currentSignalType) {
            case SignalType.input:
              prefix = "Input$num: ";
              break;
            case SignalType.output:
              prefix = "Output$num: ";
              break;
            case SignalType.hwTrigger:
              prefix = "HW$num: ";
              break;
            default:
              break;
          }
        }
      }

      final displayName = showIoNumbers ? "$prefix$name" : name;

      // ハイライト判定
      bool isHighlighted = false;
      if (highlightStartRow != null && highlightEndRow != null) {
        final int minRow =
            highlightStartRow! < highlightEndRow!
                ? highlightStartRow!
                : highlightEndRow!;
        final int maxRow =
            highlightStartRow! > highlightEndRow!
                ? highlightStartRow!
                : highlightEndRow!;
        if (row >= minRow && row <= maxRow) {
          isHighlighted = true;
        }
      }

      final textSpan = TextSpan(
        text: displayName,
        style: TextStyle(
          color: isHighlighted ? highlightTextColor : labelColor,
          fontSize: 14,
          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      );
      textPainter.layout(maxWidth: labelWidth - 16);

      final yCenter = row * cellHeight + (cellHeight - textPainter.height) / 2;
      final offset = Offset(6, yCenter);
      textPainter.paint(canvas, offset);
    }
  }

  /// 強調表示された縦線を描画
  void drawHighlightedLines(
    Canvas canvas,
    List<int> highlightIndices,
    Size size,
  ) {
    final paintHighlight =
        Paint()
          ..color = Colors.redAccent
          ..strokeWidth = 2;

    for (final index in highlightIndices) {
      final x = labelWidth + index * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintHighlight);
    }
  }
}

// 後方互換性のためのウィジェット（テスト用）
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

// 後方互換性のためのペインター（テスト用）
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

// 新しいコーディネートマッパーを使用したペインター
class ChartGridPainter extends CustomPainter {
  final ChartCoordinateMapper mapper;
  final List<String> signalNames;
  final double gridInterval;

  ChartGridPainter({
    required this.mapper,
    required this.signalNames,
    this.gridInterval = 50.0, // デフォルトのグリッド間隔（ピクセル）
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final gridPaint =
          Paint()
            ..color = Colors.grey.withOpacity(0.3)
            ..strokeWidth = 1.0;

      final textPaint = TextStyle(color: Colors.black87, fontSize: 12);

      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      );

      // 水平グリッド線（信号の区切り）
      for (int i = 0; i <= mapper.signalCount; i++) {
        final y =
            i == 0
                ? mapper.topPadding
                : (i == mapper.signalCount
                    ? mapper.topPadding +
                        mapper.signalCount * mapper.signalTotalHeight
                    : mapper.getSignalBottomY(i - 1));

        canvas.drawLine(
          Offset(mapper.leftPadding, y),
          Offset(mapper.leftPadding + mapper.chartAreaWidth, y),
          gridPaint,
        );

        // 信号名ラベルを描画（左側）
        if (i < mapper.signalCount && i < signalNames.length) {
          final signalCenterY = mapper.getSignalCenterY(i);
          textPainter.text = TextSpan(text: signalNames[i], style: textPaint);
          textPainter.layout(maxWidth: mapper.leftPadding - 10);
          textPainter.paint(
            canvas,
            Offset(
              mapper.leftPadding - textPainter.width - 5,
              signalCenterY - textPainter.height / 2,
            ),
          );
        }
      }

      // 垂直グリッド線（時間軸）
      // 適切な時間間隔を計算
      final timeInterval = mapper.calculateTimeGridInterval(gridInterval);
      final numTimeLines = (mapper.totalTime / timeInterval).ceil() + 1;

      for (int i = 0; i <= numTimeLines; i++) {
        final time = i * timeInterval;
        if (time > mapper.totalTime) break;

        final x = mapper.mapTimeToX(time);

        // グリッド線
        canvas.drawLine(
          Offset(x, mapper.topPadding),
          Offset(x, mapper.topPadding + mapper.chartAreaHeight),
          gridPaint,
        );

        // 時間ラベル
        textPainter.text = TextSpan(
          text: time.toStringAsFixed(1),
          style: textPaint,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            x - textPainter.width / 2,
            mapper.topPadding + mapper.chartAreaHeight + 5,
          ),
        );
      }
    } catch (e) {
      debugPrint('エラー: グリッドの描画中にエラーが発生しました: $e');
    }
  }

  @override
  bool shouldRepaint(covariant ChartGridPainter oldDelegate) {
    return mapper != oldDelegate.mapper ||
        signalNames != oldDelegate.signalNames ||
        gridInterval != oldDelegate.gridInterval;
  }
}
