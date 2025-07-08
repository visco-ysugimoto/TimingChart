import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/chart/signal_data.dart';
import 'package:flutter_application_1/models/chart/signal_type.dart';

void main() {
  test('SignalData.toggleVisibilityが表示状態を反転する', () {
    const original = SignalData(
      name: 'test',
      signalType: SignalType.input,
      values: [0, 1],
      isVisible: true,
    );

    final toggled = original.toggleVisibility();

    expect(toggled.isVisible, isFalse);
    // 元のオブジェクトは不変であることも確認
    expect(original.isVisible, isTrue);
  });
}
