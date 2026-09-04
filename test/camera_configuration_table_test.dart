import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/form/camera_table_types.dart';
import 'package:flutter_application_1/widgets/form/camera_configuration_table.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('canUseSimultaneousCapture', () {
    test('カメラ1台では使えない', () {
      expect(canUseSimultaneousCapture(1), isFalse);
      expect(canUseSimultaneousCapture(0), isFalse);
    });

    test('カメラ2台以上では使える', () {
      expect(canUseSimultaneousCapture(2), isTrue);
      expect(canUseSimultaneousCapture(4), isTrue);
    });
  });

  group('CameraConfigurationTable', () {
    testWidgets('カメラ1台では行番号タップで同時取込にならない', (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        _wrap(
          CameraConfigurationTable(
            cameraCount: 1,
            rowCount: 1,
            tableData: const [
              [CellMode.none],
            ],
            rowModes: const [RowMode.none],
            columnModes: const [CellMode.none],
            canSelectHwTrigger: false,
            onToggleRowMode: (_) => toggled = true,
            onChangeCellMode: (_, __, ___) {},
            onChangeColumnMode: (_, __) {},
          ),
        ),
      );

      await tester.tap(find.text('1'));
      await tester.pump();
      expect(toggled, isFalse);
      expect(find.text('同時取込'), findsNothing);
      expect(find.text('Simultaneous'), findsNothing);
    });

    testWidgets('カメラ2台では行番号タップで同時取込を切り替えられる', (tester) async {
      var toggledRow = -1;
      await tester.pumpWidget(
        _wrap(
          CameraConfigurationTable(
            cameraCount: 2,
            rowCount: 1,
            tableData: const [
              [CellMode.none, CellMode.none],
            ],
            rowModes: const [RowMode.none],
            columnModes: const [CellMode.none, CellMode.none],
            canSelectHwTrigger: false,
            onToggleRowMode: (row) => toggledRow = row,
            onChangeCellMode: (_, __, ___) {},
            onChangeColumnMode: (_, __) {},
          ),
        ),
      );

      await tester.tap(find.text('1'));
      await tester.pump();
      expect(toggledRow, 0);
    });

    testWidgets('カメラ1台では同時取込ラベルを出さない', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CameraConfigurationTable(
            cameraCount: 1,
            rowCount: 1,
            tableData: const [
              [CellMode.mode1],
            ],
            rowModes: const [RowMode.simultaneous],
            columnModes: const [CellMode.none],
            canSelectHwTrigger: false,
            onToggleRowMode: (_) {},
            onChangeCellMode: (_, __, ___) {},
            onChangeColumnMode: (_, __) {},
          ),
        ),
      );

      expect(find.text('同時取込'), findsNothing);
      expect(find.text('Simultaneous'), findsNothing);
    });
  });
}
