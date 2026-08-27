import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/backup/app_config.dart';
import 'package:flutter_application_1/models/form/form_state.dart';
import 'package:flutter_application_1/models/chart/signal_data.dart';
import 'package:flutter_application_1/models/chart/signal_type.dart';
import 'package:flutter_application_1/models/chart/timing_chart_annotation.dart';
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

    test('チャート上部に置いたコメントの placement が往復後も維持される', () {
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

      const topComment = TimingChartAnnotation(
        id: 'ann-top',
        startTimeIndex: 1,
        endTimeIndex: 2,
        text: 'upper comment',
        offsetX: 8,
        offsetY: -12,
        placement: 'top',
        fontSize: 14,
        isBold: true,
        maxWidth: 160,
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
        annotations: const [topComment],
      );

      final jsonStr = WaveDromConverter.toWaveDromJson(
        config,
        annotations: const [topComment],
      );
      expect(jsonStr.contains('"placement": "top"'), isTrue);

      final restored = WaveDromConverter.fromWaveDromJson(jsonStr);
      expect(restored, isNotNull);
      expect(restored!.annotations, hasLength(1));

      final restoredAnn = restored.annotations.first;
      expect(restoredAnn.placement, 'top');
      expect(restoredAnn.offsetX, 8);
      expect(restoredAnn.offsetY, -12);
      expect(restoredAnn.fontSize, 14);
      expect(restoredAnn.isBold, isTrue);
      expect(restoredAnn.maxWidth, 160);
      expect(restoredAnn.text, 'upper comment');
    });
  });
}
