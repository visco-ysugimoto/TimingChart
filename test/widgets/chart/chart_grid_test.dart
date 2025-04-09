import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/chart/chart_grid.dart';

void main() {
  group('ChartGrid', () {
    testWidgets('信号数が0の場合は空のウィジェットを返す', (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ChartGrid(
            timeSteps: 10,
            cellWidth: 50.0,
            cellHeight: 30.0,
            signalCount: 0,
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('正常なパラメータで描画される', (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ChartGrid(
            timeSteps: 10,
            cellWidth: 50.0,
            cellHeight: 30.0,
            signalCount: 5,
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    test('不正なパラメータでエラーが発生する', () {
      expect(
        () => ChartGrid(
          timeSteps: 0,
          cellWidth: 50.0,
          cellHeight: 30.0,
          signalCount: 5,
        ),
        throwsAssertionError,
      );

      expect(
        () => ChartGrid(
          timeSteps: 10,
          cellWidth: 0,
          cellHeight: 30.0,
          signalCount: 5,
        ),
        throwsAssertionError,
      );

      expect(
        () => ChartGrid(
          timeSteps: 10,
          cellWidth: 50.0,
          cellHeight: 0,
          signalCount: 5,
        ),
        throwsAssertionError,
      );

      expect(
        () => ChartGrid(
          timeSteps: 10,
          cellWidth: 50.0,
          cellHeight: 30.0,
          signalCount: -1,
        ),
        throwsAssertionError,
      );
    });
  });
}
