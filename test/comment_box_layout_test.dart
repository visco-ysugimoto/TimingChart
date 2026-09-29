import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/chart/timing_chart_annotation.dart';
import 'package:flutter_application_1/utils/comment_box_layout.dart';

void main() {
  const labelColumn = Rect.fromLTWH(0, 0, 200, 400);

  test('ラベル列と重ならなければそのまま', () {
    const rect = Rect.fromLTWH(220, 410, 80, 30);
    expect(
      shiftCommentOutOfLabelColumn(
        commentRect: rect,
        labelColumn: labelColumn,
        placementTop: false,
      ),
      rect,
    );
  });

  test('下部コメントが最終行＋ラベル列に食い込んだらチャート下へ退避する', () {
    const rect = Rect.fromLTWH(20, 385, 160, 40);
    final shifted = shiftCommentOutOfLabelColumn(
      commentRect: rect,
      labelColumn: labelColumn,
      placementTop: false,
    );
    expect(shifted.top, 400);
    expect(shifted.left, 20);
    expect(shifted.overlaps(labelColumn), isFalse);
  });

  test('チャート行内でラベル列と重なったら右へ退避する', () {
    const rect = Rect.fromLTWH(40, 80, 120, 30);
    final shifted = shiftCommentOutOfLabelColumn(
      commentRect: rect,
      labelColumn: labelColumn,
      placementTop: false,
    );
    expect(shifted.left, 200);
    expect(shifted.top, 80);
    expect(shifted.overlaps(labelColumn), isFalse);
  });

  test('上部コメントがラベル列と重なったらチャート上へ退避する', () {
    const rect = Rect.fromLTWH(10, -10, 100, 30);
    final shifted = shiftCommentOutOfLabelColumn(
      commentRect: rect,
      labelColumn: labelColumn,
      placementTop: true,
    );
    expect(shifted.bottom, 0);
    expect(shifted.overlaps(labelColumn), isFalse);
  });

  test('中心がチャート本体内のときだけ行位置を返す', () {
    expect(
      commentBoxCenterRow(
        boxTop: 180,
        boxHeight: 40,
        chartBottomY: 400,
        cellHeight: 40,
      ),
      5,
    );
    expect(
      commentBoxCenterRow(
        boxTop: 420,
        boxHeight: 40,
        chartBottomY: 400,
        cellHeight: 40,
      ),
      isNull,
    );
  });

  test('チャート内の中心行は縦圧縮後も同じ行に残る', () {
    final placed = placeCommentBox(
      baseRect: const Rect.fromLTWH(10, 420, 80, 40),
      offsetX: 5,
      offsetY: -300,
      boxCenterRow: 5,
      cellHeight: 40,
    );
    expect(placed.left, 15);
    expect(placed.center.dy, 200);

    final compressed = placeCommentBox(
      baseRect: const Rect.fromLTWH(10, 220, 80, 40),
      offsetX: 5,
      offsetY: null,
      boxCenterRow: 5,
      cellHeight: 20,
    );
    expect(compressed.center.dy / 20, 5);
    expect(compressed.center.dy / 200, placed.center.dy / 400);
  });

  test('チャート下の余白はピクセルオフセットのまま', () {
    final placed = placeCommentBox(
      baseRect: const Rect.fromLTWH(10, 420, 80, 40),
      offsetX: 0,
      offsetY: -10,
      boxCenterRow: null,
      cellHeight: 40,
    );
    expect(placed.top, 410);
  });

  test('行高さが変わるとチャート内コメントだけ中心行を確定する', () {
    const inside = TimingChartAnnotation(
      id: 'in',
      startTimeIndex: 1,
      endTimeIndex: null,
      text: 'inside',
      offsetY: -220,
    );
    const below = TimingChartAnnotation(
      id: 'below',
      startTimeIndex: 2,
      endTimeIndex: null,
      text: 'below',
      offsetY: 12,
    );
    final updated = anchorCommentsInsideChart(
      annotations: const [inside, below],
      paintedRects: {
        'in': const Rect.fromLTWH(20, 180, 80, 40),
        'below': const Rect.fromLTWH(40, 430, 80, 40),
      },
      oldCellHeight: 40,
      newCellHeight: 20,
      rowCount: 10,
    );
    expect(updated, isNotNull);
    expect(updated!.first.boxCenterRow, 5);
    expect(updated.first.offsetY, isNull);
    expect(updated.last.boxCenterRow, isNull);
    expect(updated.last.offsetY, 12);
  });
}
