import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/chart/signal_data.dart';
import 'package:flutter_application_1/widgets/chart/chart_signals.dart';

void main() {
  group('ChartSignals', () {
    testWidgets('空の信号リストの場合は空のウィジェットを返す', (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ChartSignals(
            signals: [],
            cellWidth: 50.0,
            cellHeight: 30.0,
            timeSteps: 10,
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('正常な信号データで描画される', (WidgetTester tester) async {
      final signals = [
        SignalData(
          name: 'Test Signal 1',
          color: Colors.blue,
          values: List.filled(10, 0),
        ),
        SignalData(
          name: 'Test Signal 2',
          color: Colors.red,
          values: List.filled(10, 1),
        ),
      ];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ChartSignals(
            signals: signals,
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
        () => ChartSignals(
          signals: [],
          cellWidth: 0,
          cellHeight: 30.0,
          timeSteps: 10,
        ),
        throwsAssertionError,
      );

      expect(
        () => ChartSignals(
          signals: [],
          cellWidth: 50.0,
          cellHeight: 0,
          timeSteps: 10,
        ),
        throwsAssertionError,
      );

      expect(
        () => ChartSignals(
          signals: [],
          cellWidth: 50.0,
          cellHeight: 30.0,
          timeSteps: 0,
        ),
        throwsAssertionError,
      );
    });
  });
}
