import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/backup/app_config.dart';
import 'package:flutter_application_1/models/form/form_state.dart';
import 'package:flutter_application_1/models/chart/signal_data.dart';
import 'package:flutter_application_1/models/chart/signal_type.dart';
import 'package:flutter_application_1/utils/wavedrom_converter.dart';

void main() {
  group('WaveDromConverter', () {
    test('toWaveDromJsonで生成したJSONをfromWaveDromJsonで復元できる', () {
      const formState = TimingFormState(
        triggerOption: 'Single Trigger',
        ioPort: 1,
        hwPort: 0,
        camera: 1,
        inputCount: 1,
        outputCount: 0,
      );

      const signal = SignalData(
        name: 'input1',
        signalType: SignalType.input,
        values: [1, 0, 1, 1],
      );

      final config = AppConfig(
        formState: formState,
        signals: const [signal],
        tableData: const [],
        inputNames: const ['input1'],
        outputNames: const [],
        hwTriggerNames: const [],
        inputVisibility: const [true],
        outputVisibility: const [],
        hwTriggerVisibility: const [],
        rowModes: const [],
      );

      final jsonStr = WaveDromConverter.toWaveDromJson(config);
      expect(jsonStr.contains('"signal"'), isTrue);

      final restored = WaveDromConverter.fromWaveDromJson(jsonStr);
      expect(restored, isNotNull);
      expect(restored!.inputNames.first, 'input1');
      expect(restored.signals.first.values.length, signal.values.length);
    });
  });
}
