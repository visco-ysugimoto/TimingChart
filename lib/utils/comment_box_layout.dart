import 'package:flutter/material.dart';

import '../models/chart/timing_chart_annotation.dart';

/// 信号ラベル列（チャート行の左側）とコメントボックスが重ならないよう退避する。
///
/// 範囲コメントを矢印中央に置くと、ボックス上半分が最終行＋ラベル列に食い込み、
/// ラベル overlay / clip で消えて見える。HTML ではラベルの上に描画される。
Rect shiftCommentOutOfLabelColumn({
  required Rect commentRect,
  required Rect labelColumn,
  required bool placementTop,
}) {
  if (commentRect.isEmpty || labelColumn.isEmpty) return commentRect;
  if (!commentRect.overlaps(labelColumn)) return commentRect;

  final bool mostlyAbove = commentRect.center.dy <= labelColumn.top;
  final bool mostlyBelow = commentRect.center.dy >= labelColumn.bottom;

  if (placementTop || mostlyAbove) {
    return commentRect.translate(0, labelColumn.top - commentRect.bottom);
  }
  if (mostlyBelow) {
    return commentRect.translate(0, labelColumn.bottom - commentRect.top);
  }
  return commentRect.translate(labelColumn.right - commentRect.left, 0);
}

/// コメントボックスの中心がチャート本体（0 .. [chartBottomY]）にあるとき、
/// その中心を行高さ単位で返す。上下の余白にある場合は null。
///
/// 余白のコメントはチャート下端（または上端）からのピクセル距離を保ち、
/// チャート内のコメントは行の圧縮に合わせて同じ行へ追従する。
double? commentBoxCenterRow({
  required double boxTop,
  required double boxHeight,
  required double chartBottomY,
  required double cellHeight,
}) {
  if (!(cellHeight > 0) || !(chartBottomY > 0) || !boxTop.isFinite) {
    return null;
  }
  if (!boxHeight.isFinite || boxHeight < 0) return null;
  final double center = boxTop + boxHeight / 2;
  if (center < 0 || center >= chartBottomY) return null;
  return center / cellHeight;
}

/// 既定配置 [baseRect] にユーザー移動を反映する。
///
/// [boxCenterRow] があるときは縦位置を行単位で置き換える。
/// 横位置は [offsetX]（px）を足す。チャート外では [offsetY]（px）を使う。
Rect placeCommentBox({
  required Rect baseRect,
  required double? offsetX,
  required double? offsetY,
  required double? boxCenterRow,
  required double cellHeight,
  double chartTopY = 0,
}) {
  if (boxCenterRow != null && cellHeight > 0 && boxCenterRow.isFinite) {
    final double top =
        chartTopY + boxCenterRow * cellHeight - baseRect.height / 2;
    return Rect.fromLTWH(
      baseRect.left + (offsetX ?? 0),
      top,
      baseRect.width,
      baseRect.height,
    );
  }
  if (offsetX != null || offsetY != null) {
    return baseRect.shift(Offset(offsetX ?? 0, offsetY ?? 0));
  }
  return baseRect;
}

/// 行高さが変わる直前の描画矩形から、チャート内コメントの中心行を確定する。
///
/// 変化がなければ null。戻り値は置き換え後のリスト。
List<TimingChartAnnotation>? anchorCommentsInsideChart({
  required List<TimingChartAnnotation> annotations,
  required Map<String, Rect> paintedRects,
  required double oldCellHeight,
  required double newCellHeight,
  required int rowCount,
  String? draggingAnnotationId,
}) {
  if (rowCount <= 0 || !(oldCellHeight > 0)) return null;
  if (!newCellHeight.isFinite || (oldCellHeight - newCellHeight).abs() < 0.01) {
    return null;
  }
  final double chartBottomY = rowCount * oldCellHeight;
  var changed = false;
  final List<TimingChartAnnotation> next = [];
  for (final ann in annotations) {
    if (ann.boxCenterRow != null || ann.id == draggingAnnotationId) {
      next.add(ann);
      continue;
    }
    final Rect? rect = paintedRects[ann.id];
    if (rect == null) {
      next.add(ann);
      continue;
    }
    final double? row = commentBoxCenterRow(
      boxTop: rect.top,
      boxHeight: rect.height,
      chartBottomY: chartBottomY,
      cellHeight: oldCellHeight,
    );
    if (row == null) {
      next.add(ann);
      continue;
    }
    changed = true;
    next.add(
      ann.copyWith(
        boxCenterRow: row,
        clearOffsetY: true,
      ),
    );
  }
  return changed ? next : null;
}
