import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/chart/signal_data.dart';
import 'package:flutter_application_1/models/chart/signal_type.dart';
import 'package:flutter_application_1/models/form/form_state.dart';
import 'package:flutter_application_1/widgets/form/form_tab_constants.dart';
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

  group('FormTabSignalMapper.buildAuxiliarySignalMap', () {
    test('空ラベルは除外し、aux:n キーで波形を引き継ぐ', () {
      final controllers = [
        TextEditingController(text: 'Helper'),
        TextEditingController(text: ''),
        TextEditingController(text: 'Helper2'),
      ];
      final map = FormTabSignalMapper.buildAuxiliarySignalMap(
        auxiliaryControllers: controllers,
        auxiliaryVisibility: const [true, true, false],
        occupiedNames: const {},
        prevPortValues: {
          FormTabSignalMapper.auxKey(0): [1, 0, 1],
        },
        prevValueMap: const {},
        defaultWaveLength: 4,
      );

      expect(map.keys, [0, 2]);
      expect(map[0]!.name, 'Helper');
      expect(map[0]!.signalType, SignalType.auxiliary);
      expect(map[0]!.showIoNumber, isFalse);
      expect(map[0]!.values, [1, 0, 1]);
      expect(map[2]!.name, 'Helper2');
      expect(map[2]!.isVisible, isFalse);
      expect(map[2]!.values, [0, 0, 0, 0]);
    });

    test('個別色を名前とインデックスから引き継ぐ', () {
      final map = FormTabSignalMapper.buildAuxiliarySignalMap(
        auxiliaryControllers: [
          TextEditingController(text: 'Renamed'),
          TextEditingController(text: 'Keep'),
        ],
        auxiliaryVisibility: const [true, true],
        occupiedNames: const {},
        prevPortValues: const {},
        prevValueMap: const {},
        defaultWaveLength: 2,
        prevColorByName: const {'Keep': 0xFF2196F3},
        auxiliaryColors: const [0xFFFF5722, null],
      );

      expect(map[0]!.colorArgb, 0xFFFF5722);
      expect(map[1]!.colorArgb, 0xFF2196F3);
    });

    test('IO 名と衝突する補助信号は採用しない', () {
      final map = FormTabSignalMapper.buildAuxiliarySignalMap(
        auxiliaryControllers: [TextEditingController(text: 'BUSY')],
        auxiliaryVisibility: const [true],
        occupiedNames: {'BUSY'},
        prevPortValues: const {},
        prevValueMap: const {},
        defaultWaveLength: 2,
      );
      expect(map, isEmpty);
    });
  });

  group('FormTabSignalMapper.populateSignalDataList', () {
    test('補助信号は末尾に連結される', () {
      const formState = TimingFormState(
        triggerOption: 'Single Trigger',
        ioPort: 1,
        hwPort: 0,
        camera: 1,
        inputCount: 1,
        outputCount: 1,
      );
      final list = FormTabSignalMapper.populateSignalDataList(
        formState: formState,
        plcEipOption: PlcEipOptions.none,
        inputSignalMap: {
          0: const SignalData(
            name: 'IN',
            signalType: SignalType.input,
            values: [0],
          ),
        },
        outputSignalMap: {
          0: const SignalData(
            name: 'OUT',
            signalType: SignalType.output,
            values: [0],
          ),
        },
        hwTriggerSignalMap: const {},
        auxiliarySignalMap: {
          0: const SignalData(
            name: 'NOTE',
            signalType: SignalType.auxiliary,
            values: [1],
            showIoNumber: false,
          ),
        },
        prevOrder: const [],
      );

      expect(list.map((s) => s.name), ['IN', 'OUT', 'NOTE']);
    });
  });
}
