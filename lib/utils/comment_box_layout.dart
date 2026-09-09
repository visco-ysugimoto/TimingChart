import 'package:flutter/material.dart';

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
