import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/chart/timing_chart_annotation.dart';
import 'package:flutter_application_1/widgets/chart/chart_annotations.dart';

void main() {
  group('ChartAnnotations', () {
    testWidgets('空のアノテーションリストの場合は空のウィジェットを返す', (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ChartAnnotations(
            annotations: [],
            cellWidth: 50.0,
            cellHeight: 30.0,
            timeSteps: 10,
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('正常なアノテーションデータで描画される', (WidgetTester tester) async {
      final annotations = [
        TimingChartAnnotation(
          timeStep: 5,
          text: 'Test Annotation',
          yPosition: 0,
        ),
        TimingChartAnnotation(
          timeStep: 8,
          text: 'Another Annotation',
          yPosition: 0,
        ),
      ];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ChartAnnotations(
            annotations: annotations,
            cellWidth: 50.0,
            cellHeight: 30.0,
            timeSteps: 10,
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    test('不正なパラメータでエラーが発生する', () {
      expect(
        () => ChartAnnotations(
          annotations: [],
          cellWidth: 0,
          cellHeight: 30.0,
          timeSteps: 10,
        ),
        throwsAssertionError,
      );

      expect(
        () => ChartAnnotations(
          annotations: [],
          cellWidth: 50.0,
          cellHeight: 0,
          timeSteps: 10,
        ),
        throwsAssertionError,
      );

      expect(
        () => ChartAnnotations(
          annotations: [],
          cellWidth: 50.0,
          cellHeight: 30.0,
          timeSteps: 0,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('範囲外のタイムステップのアノテーションはスキップされる', (WidgetTester tester) async {
      final annotations = [
        TimingChartAnnotation(
          timeStep: -1, // 範囲外
          text: 'Invalid Annotation',
          yPosition: 0,
        ),
        TimingChartAnnotation(
          timeStep: 10, // 範囲外
          text: 'Another Invalid Annotation',
          yPosition: 0,
        ),
        TimingChartAnnotation(
          timeStep: 5, // 有効
          text: 'Valid Annotation',
          yPosition: 0,
        ),
      ];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ChartAnnotations(
            annotations: annotations,
            cellWidth: 50.0,
            cellHeight: 30.0,
            timeSteps: 10,
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });
  });
}
