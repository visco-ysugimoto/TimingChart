import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/backup/app_config.dart';
import 'package:flutter_application_1/models/form/camera_table_types.dart';
import 'package:flutter_application_1/models/form/form_state.dart';
import 'package:flutter_application_1/models/chart/signal_data.dart';
import 'package:flutter_application_1/models/chart/signal_type.dart';
import 'package:flutter_application_1/models/chart/chart_segment.dart';

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

    test('auxiliaryNames の往復と旧JSONの欠落フィールドを扱える', () {
      const formState = TimingFormState(
        triggerOption: 'Single Trigger',
        ioPort: 1,
        hwPort: 0,
        camera: 1,
        inputCount: 1,
        outputCount: 0,
      );

      const aux = SignalData(
        name: 'NOTE',
        signalType: SignalType.auxiliary,
        values: [1, 0],
        showIoNumber: false,
        colorArgb: 0xFF00BCD4,
      );

      final original = AppConfig(
        formState: formState,
        signals: const [aux],
        tableData: const [],
        inputNames: const ['input1'],
        outputNames: const [],
        hwTriggerNames: const [],
        auxiliaryNames: const ['NOTE'],
        inputVisibility: const [true],
        outputVisibility: const [],
        hwTriggerVisibility: const [],
        auxiliaryVisibility: const [true],
        rowModes: const [],
      );

      final decoded = AppConfig.fromJsonString(original.toJsonString());
      expect(decoded.auxiliaryNames, ['NOTE']);
      expect(decoded.auxiliaryVisibility, [true]);
      expect(decoded.signals.first.signalType, SignalType.auxiliary);
      expect(decoded.signals.first.showIoNumber, isFalse);
      expect(decoded.signals.first.colorArgb, 0xFF00BCD4);

      final legacy = AppConfig.fromJson({
        'formState': {
          'triggerOption': 'Single Trigger',
          'ioPort': 1,
          'hwPort': 0,
          'camera': 1,
          'inputCount': 1,
          'outputCount': 0,
        },
        'signals': [
          {
            'name': 'input1',
            'signalType': SignalType.input.index,
            'values': [0, 1],
            'isVisible': true,
          },
        ],
        'tableData': [],
        'inputNames': ['input1'],
        'outputNames': [],
        'hwTriggerNames': [],
        'inputVisibility': [true],
        'outputVisibility': [],
        'hwTriggerVisibility': [],
        'rowModes': [],
      });
      expect(legacy.auxiliaryNames, isEmpty);
      expect(legacy.auxiliaryVisibility, isEmpty);
    });

    test('segments の往復と旧JSONの欠落を扱える', () {
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
      const segment = ChartSegment(
        id: 's1',
        label: 'taskA',
        startTimeIndex: 0,
        endTimeIndex: 4,
        cameraTable: [
          [CellMode.mode1],
        ],
        rowModes: ['none'],
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
        segments: const [segment],
      );

      final decoded = AppConfig.fromJsonString(original.toJsonString());
      expect(decoded.segments, hasLength(1));
      expect(decoded.segments.single.id, 's1');
      expect(decoded.segments.single.label, 'taskA');
      expect(decoded.segments.single.endTimeIndex, 4);
      expect(decoded.segments.single.cameraTable, [
        [CellMode.mode1],
      ]);
      expect(decoded.segments.single.rowModes, ['none']);

      final withScanOrder = AppConfig(
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
        captureScanOrder: 'row',
      );
      final decodedScan = AppConfig.fromJsonString(withScanOrder.toJsonString());
      expect(decodedScan.captureScanOrder, 'row');

      final legacy = AppConfig.fromJson({
        'formState': {
          'triggerOption': 'Single Trigger',
          'ioPort': 1,
          'hwPort': 0,
          'camera': 1,
          'inputCount': 1,
          'outputCount': 0,
        },
        'signals': [
          {
            'name': 'input1',
            'signalType': SignalType.input.index,
            'values': [0, 1],
            'isVisible': true,
          },
        ],
        'tableData': [],
        'inputNames': ['input1'],
        'outputNames': [],
        'hwTriggerNames': [],
        'inputVisibility': [true],
        'outputVisibility': [],
        'hwTriggerVisibility': [],
        'rowModes': [],
      });
      expect(legacy.segments, isEmpty);
      expect(legacy.captureScanOrder, 'column');
    });
  });
}
