import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/chart/chart_data_generator.dart';
import 'package:flutter_application_1/models/form/form_state.dart';
import 'package:flutter_application_1/models/chart/signal_type.dart';

void main() {
  // TextEditingController を使用するために初期化
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChartDataGenerator', () {
    test('generateSignalNames と generateSignalTypes が正しい順序・型を返す', () {
      // 各 TextEditingController に名前を設定
      final inputControllers = [TextEditingController(text: 'CLK')];
      final outputControllers = [TextEditingController(text: 'DATA')];
      final hwTriggerControllers = [TextEditingController(text: 'TRIGGER')];

      const formState = TimingFormState(
        triggerOption: 'Single',
        ioPort: 1,
        hwPort: 1,
        camera: 0,
        inputCount: 1,
        outputCount: 1,
      );

      final names = ChartDataGenerator.generateSignalNames(
        inputControllers: inputControllers,
        outputControllers: outputControllers,
        hwTriggerControllers: hwTriggerControllers,
        formState: formState,
      );

      expect(names, equals(['CLK', 'TRIGGER', 'DATA']));

      final types = ChartDataGenerator.generateSignalTypes(
        inputControllers: inputControllers,
        outputControllers: outputControllers,
        hwTriggerControllers: hwTriggerControllers,
        formState: formState,
      );

      expect(
        types,
        equals([SignalType.input, SignalType.hwTrigger, SignalType.output]),
      );
    });
  });
}
