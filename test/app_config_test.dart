import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/backup/app_config.dart';
import 'package:flutter_application_1/models/form/form_state.dart';
import 'package:flutter_application_1/models/chart/signal_data.dart';
import 'package:flutter_application_1/models/chart/signal_type.dart';

void main() {
  group('AppConfig', () {
    test('toJsonStringとfromJsonStringの往復でデータが維持される', () {
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
        values: [0, 1, 0, 1],
      );

      final original = AppConfig(
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

      final jsonStr = original.toJsonString();
      final decoded = AppConfig.fromJsonString(jsonStr);

      expect(decoded.formState.triggerOption, original.formState.triggerOption);
      expect(decoded.signals.length, original.signals.length);
      expect(decoded.signals.first.name, original.signals.first.name);
      expect(decoded.signals.first.values, original.signals.first.values);
    });
  });
}
