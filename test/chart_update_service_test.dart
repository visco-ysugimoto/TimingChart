import 'package:flutter_test/flutter_test.dart';
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
}
