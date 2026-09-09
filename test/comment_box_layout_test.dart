import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
