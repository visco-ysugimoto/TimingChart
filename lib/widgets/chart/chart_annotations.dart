import 'package:flutter/material.dart';
import '../../models/chart/timing_chart_annotation.dart';
import 'chart_coordinate_mapper.dart';
import 'dart:math' as math;

/// アノテーション（コメント）管理とレンダリングを担当するクラス
class ChartAnnotationsManager {
  // アノテーションの描画に必要な設定
  final List<TimingChartAnnotation> annotations;
  final double cellWidth;
  final double cellHeight;
  final double labelWidth;
  final List<int> highlightTimeIndices;

  // 選択中のアノテーションID
  final String? selectedAnnotationId;

  // アノテーションの当たり判定用マップ（IDとRect）
  final Map<String, Rect> annotationRects = {};
  final List<Rect> _placedArrowRects = [];

  ChartAnnotationsManager({
    required this.annotations,
    required this.cellWidth,
    required this.cellHeight,
    required this.labelWidth,
    required this.highlightTimeIndices,
    this.selectedAnnotationId,
  });

  /// アノテーションの描画
  void drawAnnotations(Canvas canvas, Size size, int signalCount) {
    // 既存のアノテーションRectをクリア
    annotationRects.clear();
    _placedArrowRects.clear();

    // ベース座標と必要な値を計算
    final chartBottomY = signalCount * cellHeight;
    final double baseCommentY = chartBottomY + 20;

    if (annotations.isEmpty) {
      debugPrint('アノテーションが空のため描画しません');
      return;
    }

    debugPrint('描画するアノテーション数: ${annotations.length}');

    // アノテーションの並べ替え
    final sortedAnnotations = _sortAnnotations();

    // 衝突回避用のリスト
    final List<Rect> placedCommentRects = [];

    // 境界線描画用のペイント
    final double dashWidth = 5;
    final double dashSpace = 3;

    for (final ann in sortedAnnotations) {
      debugPrint(
        'アノテーション描画: ID=${ann.id}, text=${ann.text}, start=${ann.startTimeIndex}, end=${ann.endTimeIndex}',
      );

      double commentX, commentY;
      Rect commentRect;
      Rect? arrowRect;

      final textSpan = TextSpan(
        text: ann.text,
        style: const TextStyle(color: Colors.black, fontSize: 14),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '...',
        textAlign: TextAlign.left,
      );
      textPainter.layout(maxWidth: 120);
      final textWidth = textPainter.width;
      final textHeight = textPainter.height;
      final boxWidth = textWidth + 10;
      final boxHeight = textHeight + 10;

      if (ann.endTimeIndex != null) {
        // 範囲コメントの場合
        double arrowBaseY = chartBottomY + 10;
        final double arrowStartX = labelWidth + ann.startTimeIndex * cellWidth;
        final double arrowEndX =
            labelWidth + (ann.endTimeIndex! + 1) * cellWidth;
        const double arrowThickness = 4;
        Rect currentArrowRect = Rect.fromLTWH(
          arrowStartX,
          arrowBaseY - arrowThickness / 2,
          arrowEndX - arrowStartX,
          arrowThickness,
        );

        int attempts = 0;
        while ((_placedArrowRects.any((r) => r.overlaps(currentArrowRect)) ||
                isArrowOverlappingCommentBoxes(
                  currentArrowRect,
                  placedCommentRects,
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
        _placedArrowRects.add(arrowRect);

        commentY = arrowRect.bottom + 5;
        commentX = arrowRect.center.dx - boxWidth / 2;
        commentRect = Rect.fromLTWH(commentX, commentY, boxWidth, boxHeight);
      } else {
        // 単一ポイントコメントの場合
        commentY = baseCommentY;
        commentX =
            labelWidth +
            ann.startTimeIndex * cellWidth +
            cellWidth / 2 -
            boxWidth / 2;
        commentRect = Rect.fromLTWH(commentX, commentY, boxWidth, boxHeight);
      }

      int attempts = 0;
      while (placedCommentRects.any((r) => r.overlaps(commentRect)) &&
          attempts < 15) {
        commentY += 20;
        commentRect = Rect.fromLTWH(commentX, commentY, boxWidth, boxHeight);
        attempts++;
      }

      debugPrint(
        'コメントボックスの位置: X=${commentRect.left}, Y=${commentRect.top}, Width=${commentRect.width}, Height=${commentRect.height}',
      );

      placedCommentRects.add(commentRect);

      // アノテーションIDに対応するRectを保存 (ここが重要！)
      annotationRects[ann.id] = commentRect;

      // 先に境界線を描画
      // 左側の垂直線
      final double startX = labelWidth + ann.startTimeIndex * cellWidth;
      final double boundaryEndY = commentRect.top;

      debugPrint('左境界線: x=$startX, y1=0, y2=$boundaryEndY');

      // 境界線の色を設定
      final boundaryPaint =
          Paint()
            ..color = Colors.black.withOpacity(0.7)
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;

      // 垂直の破線を描画
      drawDashedLine(
        canvas,
        Offset(startX, 0),
        Offset(startX, boundaryEndY),
        boundaryPaint,
        dashWidth: dashWidth,
        dashSpace: dashSpace,
      );

      // 範囲コメントの右側の垂直線
      if (ann.endTimeIndex != null) {
        final double endX = labelWidth + (ann.endTimeIndex! + 1) * cellWidth;
        debugPrint('右境界線: x=$endX, y1=0, y2=$boundaryEndY');

        drawDashedLine(
          canvas,
          Offset(endX, 0),
          Offset(endX, boundaryEndY),
          boundaryPaint,
          dashWidth: dashWidth,
          dashSpace: dashSpace,
        );
      }

      // コメントボックスの描画
      _drawCommentBox(canvas, commentRect, textPainter, ann.id);

      // 矢印の描画
      if (arrowRect != null) {
        _drawArrow(canvas, arrowRect);
      }
    }
  }

  /// コメントボックスを描画
  void _drawCommentBox(
    Canvas canvas,
    Rect rect,
    TextPainter textPainter,
    String annId,
  ) {
    final isSelected = selectedAnnotationId == annId;
    final paintBg =
        Paint()
          ..color = isSelected ? Colors.yellow.withOpacity(0.3) : Colors.white
          ..style = PaintingStyle.fill;
    final paintBorder =
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2.0 : 1.0;
    canvas.drawRect(rect, paintBg);
    canvas.drawRect(rect, paintBorder);
    textPainter.paint(canvas, rect.topLeft.translate(4, 4));
  }

  /// 矢印を描画
  void _drawArrow(Canvas canvas, Rect arrowRect) {
    final paintArrowLine =
        Paint()
          ..color = Colors.blue
          ..strokeWidth = 4;
    final startPt = Offset(arrowRect.left, arrowRect.center.dy);
    final endPt = Offset(arrowRect.right, arrowRect.center.dy);
    canvas.drawLine(startPt, endPt, paintArrowLine);
    const double headLength = 8;
    drawArrowhead(canvas, startPt, math.pi, headLength, paintArrowLine);
    drawArrowhead(canvas, endPt, 0, headLength, paintArrowLine);
  }

  /// アノテーションのソート
  List<TimingChartAnnotation> _sortAnnotations() {
    final sortedAnnotations = [...annotations];
    sortedAnnotations.sort((a, b) {
      // 単一セルと範囲コメントを区別
      if (a.endTimeIndex == null && b.endTimeIndex != null) {
        return -1; // 単一セルを優先
      } else if (a.endTimeIndex != null && b.endTimeIndex == null) {
        return 1;
      } else {
        // 同じタイプ同士の場合
        if (a.endTimeIndex == null && b.endTimeIndex == null) {
          // 単一セルの場合はstartTimeIndexで昇順
          return a.startTimeIndex.compareTo(b.startTimeIndex);
        } else {
          // 範囲コメントの場合
          if (a.endTimeIndex == b.endTimeIndex) {
            // endTimeIndexが同じ場合はstartTimeIndexで昇順
            return a.startTimeIndex.compareTo(b.startTimeIndex);
          } else {
            // endTimeIndexで昇順
            return a.endTimeIndex!.compareTo(b.endTimeIndex!);
          }
        }
      }
    });
    return sortedAnnotations;
  }

  /// 矢印とコメントボックスの衝突検出
  bool isArrowOverlappingCommentBoxes(Rect arrowRect, List<Rect> commentBoxes) {
    for (final boxRect in commentBoxes) {
      final bool horizontalOverlap =
          !(arrowRect.right < boxRect.left || arrowRect.left > boxRect.right);
      final bool verticalOverlap =
          !(arrowRect.bottom < boxRect.top || arrowRect.top > boxRect.bottom);
      if (horizontalOverlap && verticalOverlap) {
        return true;
      }
    }
    return false;
  }

  /// 矢印描画ユーティリティ
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

  /// 破線描画ユーティリティ
  void drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashWidth = 10, // デバッグ用に大きくする
    double dashSpace = 5, // デバッグ用に大きくする
  }) {
    debugPrint('=== drawDashedLine Debug ===');
    debugPrint('Start: $start');
    debugPrint('End: $end');
    debugPrint('Paint color: ${paint.color}');
    debugPrint('Paint strokeWidth: ${paint.strokeWidth}');

    if ((start - end).distance < 0.1) {
      debugPrint('Line too short, skipping');
      return;
    }

    // デバッグ用に線を太くする
    paint.strokeWidth = 1.0;
    // デバッグ用に色を目立つように変更
    paint.color = Colors.black.withOpacity(0.7);

    final totalDistance = (end - start).distance;
    debugPrint('Total distance: $totalDistance');

    final patternLength = dashWidth + dashSpace;
    debugPrint('Pattern length: $patternLength');

    if (patternLength <= 0) {
      debugPrint('Invalid pattern length');
      return;
    }

    final path = Path();
    final dashCount = (totalDistance / patternLength).floor();
    debugPrint('Dash count: $dashCount');
    final delta = end - start;

    Offset currentPoint = start;
    for (int i = 0; i < dashCount; i++) {
      final nextPoint = currentPoint + delta * (dashWidth / totalDistance);
      debugPrint(
        'Drawing dash $i: ${currentPoint.dx},${currentPoint.dy} -> ${nextPoint.dx},${nextPoint.dy}',
      );

      path.moveTo(currentPoint.dx, currentPoint.dy);
      path.lineTo(nextPoint.dx, nextPoint.dy);
      currentPoint = nextPoint + delta * (dashSpace / totalDistance);
    }

    final remainingDistance = (end - currentPoint).distance;
    if (remainingDistance > 0.1) {
      debugPrint(
        'Drawing remaining: ${currentPoint.dx},${currentPoint.dy} -> ${end.dx},${end.dy}',
      );
      path.moveTo(currentPoint.dx, currentPoint.dy);
      path.lineTo(end.dx, end.dy);
    }

    canvas.drawPath(path, paint);
    debugPrint('=== End drawDashedLine ===\n');
  }

  /// コメントボックスの当たり判定用のRectMapを取得
  Map<String, Rect> getAnnotationRects() {
    return Map<String, Rect>.from(annotationRects);
  }
}

// 後方互換性のためのウィジェット（テスト用）
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

// 後方互換性のためのペインター（テスト用）
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
    double dashWidth = 10, // デバッグ用に大きくする
    double dashSpace = 5, // デバッグ用に大きくする
  }) {
    debugPrint('=== drawDashedLine Debug ===');
    debugPrint('Start: $start');
    debugPrint('End: $end');
    debugPrint('Paint color: ${paint.color}');
    debugPrint('Paint strokeWidth: ${paint.strokeWidth}');

    if ((start - end).distance < 0.1) {
      debugPrint('Line too short, skipping');
      return;
    }

    // デバッグ用に線を太くする
    paint.strokeWidth = 2.0;
    // デバッグ用に色を目立つように変更
    paint.color = Colors.black;

    final totalDistance = (end - start).distance;
    debugPrint('Total distance: $totalDistance');

    final patternLength = dashWidth + dashSpace;
    debugPrint('Pattern length: $patternLength');

    if (patternLength <= 0) {
      debugPrint('Invalid pattern length');
      return;
    }

    final path = Path();
    final dashCount = (totalDistance / patternLength).floor();
    debugPrint('Dash count: $dashCount');
    final delta = end - start;

    Offset currentPoint = start;
    for (int i = 0; i < dashCount; i++) {
      final nextPoint = currentPoint + delta * (dashWidth / totalDistance);
      debugPrint(
        'Drawing dash $i: ${currentPoint.dx},${currentPoint.dy} -> ${nextPoint.dx},${nextPoint.dy}',
      );

      path.moveTo(currentPoint.dx, currentPoint.dy);
      path.lineTo(nextPoint.dx, nextPoint.dy);
      currentPoint = nextPoint + delta * (dashSpace / totalDistance);
    }

    final remainingDistance = (end - currentPoint).distance;
    if (remainingDistance > 0.1) {
      debugPrint(
        'Drawing remaining: ${currentPoint.dx},${currentPoint.dy} -> ${end.dx},${end.dy}',
      );
      path.moveTo(currentPoint.dx, currentPoint.dy);
      path.lineTo(end.dx, end.dy);
    }

    canvas.drawPath(path, paint);
    debugPrint('=== End drawDashedLine ===\n');
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

// 新しいコーディネートマッパーを使用したペインター
class ChartAnnotationsPainter extends CustomPainter {
  final List<TimingChartAnnotation> annotations;
  final ChartCoordinateMapper mapper;

  ChartAnnotationsPainter({required this.annotations, required this.mapper});

  @override
  void paint(Canvas canvas, Size size) {
    try {
      // 描画済みの矩形を記録して衝突回避
      final List<Rect> placedRects = [];
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      // アノテーションをソート（時間順）
      final sortedAnnotations = [...annotations]
        ..sort((a, b) => a.startTimeIndex.compareTo(b.startTimeIndex));

      for (final annotation in sortedAnnotations) {
        // 時間をX座標に変換
        final startTime = annotation.startTimeIndex.toDouble();
        final xStart = mapper.mapTimeToX(startTime);
        double xEnd;

        // 範囲アノテーションの場合
        if (annotation.endTimeIndex != null) {
          final endTime = annotation.endTimeIndex!.toDouble();
          xEnd = mapper.mapTimeToX(endTime);
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
          Offset(xStart, mapper.topPadding),
          Offset(xStart, mapper.topPadding + mapper.chartAreaHeight / 2),
          linePaint,
        );
        debugPrint("endTimeIndex: ${annotation.endTimeIndex}");

        // 範囲アノテーションの場合は終了位置にも線を引く
        if (annotation.endTimeIndex != null) {
          drawDashedLine(
            canvas,
            Offset(xEnd, mapper.topPadding),
            Offset(xEnd, mapper.topPadding + mapper.chartAreaHeight / 2),
            linePaint,
          );

          // 水平線を描画（範囲を示す）
          final arrowY = mapper.topPadding + mapper.chartAreaHeight / 2 + 10;
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
        double textY = mapper.topPadding + mapper.chartAreaHeight / 2 + 20;
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
    double dashWidth = 10, // デバッグ用に大きくする
    double dashSpace = 5, // デバッグ用に大きくする
  }) {
    debugPrint('=== drawDashedLine Debug ===');
    debugPrint('Start: $start');
    debugPrint('End: $end');
    debugPrint('Paint color: ${paint.color}');
    debugPrint('Paint strokeWidth: ${paint.strokeWidth}');

    if ((start - end).distance < 0.1) {
      debugPrint('Line too short, skipping');
      return;
    }

    // デバッグ用に線を太くする
    paint.strokeWidth = 2.0;
    // デバッグ用に色を目立つように変更
    paint.color = Colors.black.withOpacity(0.7);

    final totalDistance = (end - start).distance;
    debugPrint('Total distance: $totalDistance');

    final patternLength = dashWidth + dashSpace;
    debugPrint('Pattern length: $patternLength');

    if (patternLength <= 0) {
      debugPrint('Invalid pattern length');
      return;
    }

    final path = Path();
    final dashCount = (totalDistance / patternLength).floor();
    debugPrint('Dash count: $dashCount');
    final delta = end - start;

    Offset currentPoint = start;
    for (int i = 0; i < dashCount; i++) {
      final nextPoint = currentPoint + delta * (dashWidth / totalDistance);
      debugPrint(
        'Drawing dash $i: ${currentPoint.dx},${currentPoint.dy} -> ${nextPoint.dx},${nextPoint.dy}',
      );

      path.moveTo(currentPoint.dx, currentPoint.dy);
      path.lineTo(nextPoint.dx, nextPoint.dy);
      currentPoint = nextPoint + delta * (dashSpace / totalDistance);
    }

    final remainingDistance = (end - currentPoint).distance;
    if (remainingDistance > 0.1) {
      debugPrint(
        'Drawing remaining: ${currentPoint.dx},${currentPoint.dy} -> ${end.dx},${end.dy}',
      );
      path.moveTo(currentPoint.dx, currentPoint.dy);
      path.lineTo(end.dx, end.dy);
    }

    canvas.drawPath(path, paint);
    debugPrint('=== End drawDashedLine ===\n');
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
  bool shouldRepaint(covariant ChartAnnotationsPainter oldDelegate) {
    return annotations != oldDelegate.annotations ||
        mapper != oldDelegate.mapper;
  }
}
