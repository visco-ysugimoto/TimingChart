import 'package:flutter/material.dart';
import '../../models/chart/timing_chart_annotation.dart';
import 'chart_coordinate_mapper.dart';
import 'dart:math' as math;
import 'chart_drawing_util.dart';

// コメントボックス再描画用データクラス
class _CommentBoxData {
  final Rect rect;
  final TextPainter painter;
  final String annId;
  const _CommentBoxData({
    required this.rect,
    required this.painter,
    required this.annId,
  });
}

/// アノテーション（コメント）管理とレンダリングを担当するクラス
class ChartAnnotationsManager {
  // アノテーションの描画に必要な設定
  final List<TimingChartAnnotation> annotations;
  final double cellWidth;
  final double cellHeight;
  final double labelWidth;
  final List<int> highlightTimeIndices;
  final Color dashedColor;
  final Color arrowColor;
  // 時間軸（非等間隔）用
  final bool timeUnitIsMs;
  final double msPerStep;
  final List<double> stepDurationsMs;

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
    this.dashedColor = Colors.black,
    this.arrowColor = Colors.blue,
    this.timeUnitIsMs = false,
    this.msPerStep = 1.0,
    this.stepDurationsMs = const [],
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
    // 矢印配置時に参照する、コメントボックスのみの矩形リスト
    final List<Rect> _placedOnlyCommentRects = [];

    // コメントボックス再描画用に記録するリスト
    final List<_CommentBoxData> _commentBoxDrawData = [];

    // 境界線描画用のペイント
    final double dashWidth = 5;
    final double dashSpace = 3;

    // 隣接する範囲（例: s1-e1 と e1-e2）で矢印Yを共有するためのマップ
    final Map<int, double> _boundaryArrowBaseY = {};

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
        // 直前の範囲の終端とこの範囲の開始が一致する場合、同じYを優先的に使用
        final int _startIdx = ann.startTimeIndex;
        final int _endIdx = ann.endTimeIndex!;
        if (_boundaryArrowBaseY.containsKey(_startIdx)) {
          arrowBaseY = _boundaryArrowBaseY[_startIdx]!;
        }
        final double arrowStartX = _boundaryX(ann.startTimeIndex);
        final double arrowEndX = _boundaryX(ann.endTimeIndex! + 1);
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
                  _placedOnlyCommentRects,
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
        // この範囲の終端インデックスに対応するYを記録（後続の隣接範囲で共有）
        _boundaryArrowBaseY.putIfAbsent(_endIdx, () => arrowBaseY);

        // コメントボックス配置ロジック
        // 1) ボックス幅が矢印幅以下 → 矢印の中心に重ねる
        // 2) ボックス幅が矢印幅より大きい → 矢印の下に配置

        if (boxWidth <= arrowRect.width) {
          // 矢印中心に配置（上下中央合わせ）
          commentY = arrowRect.center.dy - boxHeight / 2;
          if (commentY < 0) {
            // 画面外に出る場合は下に配置
            commentY = arrowRect.bottom + 5;
          }
        } else {
          // 矢印の下に配置
          commentY = arrowRect.bottom + 5;
        }
        commentX = arrowRect.center.dx - boxWidth / 2;
        commentRect = Rect.fromLTWH(commentX, commentY, boxWidth, boxHeight);
      } else {
        // 単一ポイントコメントの場合
        commentY = baseCommentY;
        // 指定 index の境界線にボックス左を合わせる
        commentX = _boundaryX(ann.startTimeIndex);
        commentRect = Rect.fromLTWH(commentX, commentY, boxWidth, boxHeight);
      }

      // ユーザー移動オフセットを適用
      if (ann.offsetX != null || ann.offsetY != null) {
        commentRect = commentRect.shift(
          Offset(ann.offsetX ?? 0, ann.offsetY ?? 0),
        );
      }

      int attempts = 0;
      while (placedCommentRects.any((r) => r.overlaps(commentRect)) &&
          attempts < 15) {
        // ユーザーが動かした場合はY方向にのみ最小調整（衝突しない位置へ）
        commentRect = commentRect.translate(0, 20);
        attempts++;
      }

      debugPrint(
        'コメントボックスの位置: X=${commentRect.left}, Y=${commentRect.top}, Width=${commentRect.width}, Height=${commentRect.height}',
      );

      placedCommentRects.add(commentRect);
      _placedOnlyCommentRects.add(commentRect);

      // 矢印や矢印-コメント間の領域を占有扱いにして、
      // 後続のコメントボックスが割り込まないようにする
      if (arrowRect != null) {
        // 矢印本体
        placedCommentRects.add(arrowRect);

        // 矢印とコメントボックスの間に隙間がある場合はその領域も予約
        if (commentRect.top > arrowRect.bottom) {
          final double gapLeft = math.min(arrowRect.left, commentRect.left);
          final double gapRight = math.max(arrowRect.right, commentRect.right);
          final Rect gapRect = Rect.fromLTRB(
            gapLeft,
            arrowRect.bottom,
            gapRight,
            commentRect.top,
          );
          placedCommentRects.add(gapRect);
        } else if (commentRect.bottom < arrowRect.top) {
          // ボックスが矢印の上にあるケース（理論上）
          final double gapLeft = math.min(arrowRect.left, commentRect.left);
          final double gapRight = math.max(arrowRect.right, commentRect.right);
          final Rect gapRect = Rect.fromLTRB(
            gapLeft,
            commentRect.bottom,
            gapRight,
            arrowRect.top,
          );
          placedCommentRects.add(gapRect);
        } else {
          // ボックスが矢印と重なっている場合 → 矢印直下の一定領域を予約
          final Rect reserved = Rect.fromLTRB(
            arrowRect.left,
            arrowRect.bottom,
            arrowRect.right,
            arrowRect.bottom + boxHeight + 10,
          );
          placedCommentRects.add(reserved);
        }
      }

      // アノテーションIDに対応するRectを保存 (ここが重要！)
      annotationRects[ann.id] = commentRect;

      // 先に境界線を描画
      // 単一点コメントの場合はセル中央に破線を置く
      double startX = _boundaryX(ann.startTimeIndex);
      // 破線終点の見直し:
      // - 水平ON: コメントボックス中心Yまで常に延長（チャート外でも）
      // - 水平OFF: 先端がチャート内ならその先端Yまで、外ならチャート下端まで
      final bool useHorizontalForDashed = ann.arrowHorizontal != false;
      final double anchorYForDashed =
          useHorizontalForDashed
              ? commentRect.center.dy
              : (ann.arrowTipY ?? commentRect.top);
      // 破線は常にチャート下端までは描画。先端が下側に外れていればその先まで延長
      final double boundaryEndY = math.max(chartBottomY, anchorYForDashed);

      debugPrint('左境界線: x=$startX, y1=0, y2=$boundaryEndY');

      // 境界線の色を設定
      final boundaryPaint =
          Paint()
            ..color = dashedColor.withAlpha((0.5 * 255).round())
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
        final double endX = _boundaryX(ann.endTimeIndex! + 1);
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

      // コメントボックスは最後にまとめて描画するため記録のみ行う
      _commentBoxDrawData.add(
        _CommentBoxData(rect: commentRect, painter: textPainter, annId: ann.id),
      );

      // 矢印の描画
      if (arrowRect != null) {
        drawArrow(canvas, arrowRect, color: arrowColor);
      }

      // X方向にコメントが移動している場合は、破線位置とコメントボックスを結ぶ矢印を追加
      final double originalCommentCenterX = ann.endTimeIndex != null
          ? (_boundaryX(ann.startTimeIndex) + _boundaryX(ann.endTimeIndex! + 1)) / 2
          : _boundaryX(ann.startTimeIndex);
      final double movedCenterX = commentRect.center.dx;
      final bool movedInX = (movedCenterX - originalCommentCenterX).abs() > 1.0;
      if (movedInX) {
        final double dashedX = originalCommentCenterX;
        // 水平ON時はコメントボックス中心Yへ完全追従（チャート外でも追従）
        // 水平OFF時は既存仕様（arrowTipY なければ boundaryEndY）
        final bool useHorizontal = ann.arrowHorizontal != false;
        final double anchorY =
            useHorizontal
                ? commentRect.center.dy
                : (ann.arrowTipY ?? boundaryEndY);
        final Offset end = Offset(dashedX, anchorY);

        final Offset start =
            useHorizontal
                ? Offset(commentRect.right, anchorY)
                : commentRect.topCenter;

        drawArrowLine(canvas, start, end, color: arrowColor, strokeWidth: 2.0);
      }
    }

    // --- 全アノテーションの破線・矢印を描画し終えた後でコメントボックスを前面に描画 ---
    for (final data in _commentBoxDrawData) {
      drawCommentBox(
        canvas,
        data.rect,
        data.painter,
        data.annId,
        selectedAnnotationId,
      );
    }
  }

  // 指定した境界 index の画面X座標（非等間隔対応）
  double _boundaryX(int boundaryIndex) {
    if (!timeUnitIsMs) {
      return labelWidth + boundaryIndex * cellWidth;
    }
    double steps = 0.0;
    for (int t = 0; t < boundaryIndex; t++) {
      final durSteps = (t < stepDurationsMs.length && msPerStep > 0)
          ? stepDurationsMs[t] / msPerStep
          : 1.0;
      steps += durSteps;
    }
    return labelWidth + steps * cellWidth;
  }

  /// アノテーションのソート
  List<TimingChartAnnotation> _sortAnnotations() {
    final sortedAnnotations = [...annotations];
    sortedAnnotations.sort((a, b) {
      // 並び順の優先度:
      // 1) 範囲コメント (endTimeIndex != null)
      // 2) 単一セルコメント (endTimeIndex == null)

      final bool aIsRange = a.endTimeIndex != null;
      final bool bIsRange = b.endTimeIndex != null;

      if (aIsRange && !bIsRange) {
        return -1; // a が範囲, b が単一 → a を先に
      } else if (!aIsRange && bIsRange) {
        return 1; // b が範囲 → b を先に
      }

      // 同タイプ同士
      if (aIsRange) {
        // 両方とも範囲コメント
        // endTimeIndex → startTimeIndex の順で比較
        final cmpEnd = a.endTimeIndex!.compareTo(b.endTimeIndex!);
        return cmpEnd != 0
            ? cmpEnd
            : a.startTimeIndex.compareTo(b.startTimeIndex);
      } else {
        // 単一セルコメント
        return a.startTimeIndex.compareTo(b.startTimeIndex);
      }
    });
    return sortedAnnotations;
  }

  /// 矢印とコメントボックスの衝突検出
  bool isArrowOverlappingCommentBoxes(Rect arrowRect, List<Rect> commentBoxes) {
    for (final boxRect in commentBoxes) {
      // エッジが接しているだけの場合は重なりと見なさない（厳密判定）
      final bool horizontalOverlap =
          (arrowRect.right > boxRect.left) && (arrowRect.left < boxRect.right);
      final bool verticalOverlap =
          (arrowRect.bottom > boxRect.top) && (arrowRect.top < boxRect.bottom);
      if (horizontalOverlap && verticalOverlap) {
        return true;
      }
    }
    return false;
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
              ..color = Colors.blue.withAlpha((0.7 * 255).round())
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
              ..color = Colors.white.withAlpha((0.8 * 255).round())
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
              ..color = Colors.blue.withAlpha((0.7 * 255).round())
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
              ..color = Colors.white.withAlpha((0.8 * 255).round())
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

  @override
  bool shouldRepaint(covariant ChartAnnotationsPainter oldDelegate) {
    return annotations != oldDelegate.annotations ||
        mapper != oldDelegate.mapper;
  }
}
