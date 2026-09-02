import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/chart/signal_type.dart';
import 'package:flutter_application_1/utils/code_trigger_helpers.dart';
import 'package:flutter_application_1/widgets/form/form_tab_constants.dart';
import 'package:flutter_application_1/widgets/form/form_tab_rules.dart';

void main() {
  group('FormTabRules Code Trigger 可視性', () {
    test('DIO の Control/Group/Task ビットは非表示', () {
      for (final index in CodeTriggerHelpers.codeBitIndices(32)) {
        expect(
          FormTabRules.inferInputVisibility(
            triggerOption: TriggerOptions.code,
            inputCount: 32,
            index: index,
          ),
          isFalse,
          reason: 'index $index',
        );
      }
      expect(
        FormTabRules.inferInputVisibility(
          triggerOption: TriggerOptions.code,
          inputCount: 32,
          index: 0,
        ),
        isTrue,
      );
    });

    test('CODE_OPTION 構成ビットはチャートに出さない', () {
      expect(
        FormTabRules.shouldIncludeOnChart(
          isVisible: true,
          signalType: SignalType.input,
          name: 'Control Code1(bit)',
          triggerOption: TriggerOptions.code,
          inputCount: 32,
        ),
        isFalse,
      );
      expect(
        FormTabRules.shouldIncludeOnChart(
          isVisible: true,
          signalType: SignalType.control,
          name: 'Control Code1(bit)',
          triggerOption: TriggerOptions.code,
          inputCount: 32,
        ),
        isFalse,
      );
      expect(
        FormTabRules.shouldIncludeOnChart(
          isVisible: true,
          signalType: SignalType.input,
          name: 'TRIGGER',
          triggerOption: TriggerOptions.code,
          inputCount: 32,
        ),
        isTrue,
      );
      expect(
        FormTabRules.shouldIncludeOnChart(
          isVisible: true,
          signalType: SignalType.input,
          name: SignalNames.codeOption,
          triggerOption: TriggerOptions.code,
          inputCount: 32,
        ),
        isTrue,
      );
    });
  });

  group('CodeTriggerHelpers.containsCodeBitName', () {
    test('Control/Group/Task 名を検出する', () {
      expect(
        CodeTriggerHelpers.containsCodeBitName(
          const ['TRIGGER', 'Control Code1(bit)'],
          32,
        ),
        isTrue,
      );
      expect(
        CodeTriggerHelpers.containsCodeBitName(const ['TRIGGER', 'BUSY'], 32),
        isFalse,
      );
    });
  });
}
