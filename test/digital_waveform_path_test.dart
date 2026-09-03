import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/chart/chart_drawing_util.dart';

void main() {
  group('buildDigitalWaveformPath', () {
    test('立ち上がり・立ち下がりを1本のパスにまとめる', () {
      const stepPositions = [0.0, 1.0, 2.0, 3.0];
      final path = buildDigitalWaveformPath(
        values: const [0, 1, 0],
        stepPositions: stepPositions,
        xOrigin: 100,
        cellWidth: 40,
        yHigh: 20,
        yLow: 30,
      );

      final metrics = path.computeMetrics().toList();
      expect(metrics, hasLength(1));
      expect(metrics.first.length, greaterThan(0));
    });
  });

  group('buildDigitalWaveformSvgPathD', () {
    test('SVG path d を生成する', () {
      const stepPositions = [0.0, 1.0, 2.0];
      final d = buildDigitalWaveformSvgPathD(
        values: const [0, 1],
        stepPositions: stepPositions,
        xOrigin: 0,
        cellWidth: 10,
        yHigh: 5,
        yLow: 15,
        formatCoord: (value) => value.toStringAsFixed(0),
      );

      expect(d, startsWith('M '));
      expect(d, contains(' L '));
      expect(d.split(' L ').length, greaterThan(2));
    });
  });
}
