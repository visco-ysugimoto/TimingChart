import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/chart/io_channel_source.dart';
import 'package:flutter_application_1/models/chart/signal_data.dart';
import 'package:flutter_application_1/models/chart/signal_type.dart';
import 'package:flutter_application_1/providers/timing_chart_controller.dart';
import 'package:flutter_application_1/services/chart_update_service.dart';

void main() {
  group('ChartUpdateService.mergeExistingWithFormLength', () {
    test('チャート非表示時は短い既存波形を0埋めする', () {
      final merged = ChartUpdateService.mergeExistingWithFormLength(
        existingValues: [1, 0, 1],
        formLength: 5,
        chartLengthIsAuthoritative: false,
      );

      expect(merged, [1, 0, 1, 0, 0]);
    });

    test('チャート表示中は短い既存波形を0埋めしない', () {
      final merged = ChartUpdateService.mergeExistingWithFormLength(
        existingValues: [1, 0, 1],
        formLength: 5,
        chartLengthIsAuthoritative: true,
      );

      expect(merged, [1, 0, 1]);
    });

    test('既存波形が長い場合は切り詰めない', () {
      final merged = ChartUpdateService.mergeExistingWithFormLength(
        existingValues: [1, 0, 1, 0, 0],
        formLength: 3,
        chartLengthIsAuthoritative: false,
      );

      expect(merged, [1, 0, 1, 0, 0]);
    });
  });

  group('ChartUpdateService.updateChart color', () {
    test('同名の補助信号の個別色を維持する', () {
      final controller = TimingChartController.fromInitial(
        ['NOTE'],
        [
          [1, 0],
        ],
        const [],
      );
      final result = ChartUpdateService.updateChart(
        signalNames: const ['NOTE'],
        chartData: const [
          [1, 0],
        ],
        signalTypes: const [SignalType.auxiliary],
        portNumbers: const [0],
        ioSources: const [IoChannelSource.unknown],
        overrideFlag: false,
        existingSignals: const [
          SignalData(
            name: 'NOTE',
            signalType: SignalType.auxiliary,
            values: [1, 0],
            showIoNumber: false,
            colorArgb: 0xFF9C27B0,
          ),
        ],
        chartController: controller,
      );

      expect(result.signals.single.colorArgb, 0xFF9C27B0);
    });

    test('フォームで改名しても補助信号の順序で色を引き継ぐ', () {
      final controller = TimingChartController.fromInitial(
        ['OLD'],
        [
          [0, 1],
        ],
        const [],
      );
      final result = ChartUpdateService.updateChart(
        signalNames: const ['NEW'],
        chartData: const [
          [0, 1],
        ],
        signalTypes: const [SignalType.auxiliary],
        portNumbers: const [0],
        ioSources: const [IoChannelSource.unknown],
        overrideFlag: false,
        existingSignals: const [
          SignalData(
            name: 'OLD',
            signalType: SignalType.auxiliary,
            values: [0, 1],
            showIoNumber: false,
            colorArgb: 0xFF4CAF50,
          ),
        ],
        chartController: controller,
      );

      expect(result.signals.single.name, 'NEW');
      expect(result.signals.single.colorArgb, 0xFF4CAF50);
    });
  });
}
