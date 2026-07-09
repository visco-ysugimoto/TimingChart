import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/form/form_tab_signal_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FormTabSignalMapper.applyExternalValuesToPortCache', () {
    test('外部波形で portKey キャッシュを上書きする', () {
      final prevPortValues = <String, List<int>>{
        FormTabSignalMapper.dioInputKey(0): List.filled(10, 1),
        FormTabSignalMapper.dioOutputKey(0): List.filled(10, 1),
      };

      final inputControllers = [TextEditingController(text: 'Input1')];
      final outputControllers = [TextEditingController(text: 'Output1')];

      FormTabSignalMapper.applyExternalValuesToPortCache(
        prevPortValues: prevPortValues,
        externalValues: {
          'Input1': [1, 0, 1],
          'Output1': [0, 1],
        },
        inputControllers: inputControllers,
        plcEipInputControllers: const [],
        hwTriggerControllers: const [],
        outputControllers: outputControllers,
        plcEipOutputControllers: const [],
      );

      expect(prevPortValues[FormTabSignalMapper.dioInputKey(0)], [1, 0, 1]);
      expect(prevPortValues[FormTabSignalMapper.dioOutputKey(0)], [0, 1]);
    });
  });
}
