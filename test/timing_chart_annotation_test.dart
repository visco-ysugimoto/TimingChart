import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/chart/timing_chart_annotation.dart';

void main() {
  group('TimingChartAnnotation line visibility', () {
    test('未設定の場合は枠線・破線・矢印を表示する', () {
      const ann = TimingChartAnnotation(
        id: 'a1',
        startTimeIndex: 0,
        endTimeIndex: 2,
        text: 'comment',
      );

      expect(ann.isBorderVisible, isTrue);
      expect(ann.isDashedLineVisible, isTrue);
      expect(ann.isArrowVisible, isTrue);
    });

    test('表示フラグをオフにすると非表示になる', () {
      const ann = TimingChartAnnotation(
        id: 'a1',
        startTimeIndex: 0,
        endTimeIndex: 2,
        text: 'comment',
        showBorder: false,
        showDashedLine: false,
        showArrow: false,
      );

      expect(ann.isBorderVisible, isFalse);
      expect(ann.isDashedLineVisible, isFalse);
      expect(ann.isArrowVisible, isFalse);
    });

    test('枠線色が透明の場合は枠線を非表示にする', () {
      const ann = TimingChartAnnotation(
        id: 'a1',
        startTimeIndex: 0,
        endTimeIndex: null,
        text: 'comment',
        borderColorValue: 0x00FFFFFF,
      );

      expect(ann.isBorderVisible, isFalse);
    });

    test('JSONの往復で表示フラグが維持される', () {
      const original = TimingChartAnnotation(
        id: 'a1',
        startTimeIndex: 1,
        endTimeIndex: 4,
        text: 'range',
        showBorder: false,
        showDashedLine: true,
        showArrow: false,
        borderColorValue: 0xFF616161,
      );

      final decoded = TimingChartAnnotation.fromJson(original.toJson());

      expect(decoded.showBorder, isFalse);
      expect(decoded.showDashedLine, isTrue);
      expect(decoded.showArrow, isFalse);
      expect(decoded.isBorderVisible, isFalse);
      expect(decoded.isDashedLineVisible, isTrue);
      expect(decoded.isArrowVisible, isFalse);
    });

    test('copyWithで表示フラグを更新できる', () {
      const original = TimingChartAnnotation(
        id: 'a1',
        startTimeIndex: 0,
        endTimeIndex: null,
        text: 'comment',
      );

      final updated = original.copyWith(
        showBorder: false,
        showDashedLine: false,
        showArrow: false,
        borderColorValue: Colors.red.toARGB32(),
      );

      expect(updated.showBorder, isFalse);
      expect(updated.showDashedLine, isFalse);
      expect(updated.showArrow, isFalse);
      expect(updated.borderColorValue, Colors.red.toARGB32());
    });
  });
}
