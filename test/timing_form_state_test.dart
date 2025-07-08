import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/form/form_state.dart';

void main() {
  test('copyWith で指定したフィールドのみ更新される', () {
    const original = TimingFormState(
      triggerOption: 'Single',
      ioPort: 1,
      hwPort: 2,
      camera: 0,
      inputCount: 3,
      outputCount: 4,
    );

    final modified = original.copyWith(ioPort: 99);

    expect(modified.ioPort, 99);
    expect(modified.hwPort, original.hwPort);
    expect(modified.triggerOption, original.triggerOption);
    expect(modified.outputCount, original.outputCount);
  });
}
