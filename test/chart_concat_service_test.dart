import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/backup/app_config.dart';
import 'package:flutter_application_1/models/chart/signal_data.dart';
import 'package:flutter_application_1/models/chart/signal_type.dart';
import 'package:flutter_application_1/models/chart/timing_chart_annotation.dart';
import 'package:flutter_application_1/models/form/camera_table_types.dart';
import 'package:flutter_application_1/models/form/form_state.dart';
import 'package:flutter_application_1/services/chart_concat_service.dart';

void main() {
  group('ChartConcatService', () {
    int idSeq = 0;
    String nextId() => 'id_${idSeq++}';

    setUp(() {
      idSeq = 0;
    });

    test('同名信号を時間方向に連結しコメントと省略位置をずらす', () {
      final current = [
        const SignalData(
          name: 'TRIGGER',
          signalType: SignalType.input,
          values: [0, 1, 0],
        ),
        const SignalData(
          name: 'BUSY',
          signalType: SignalType.output,
          values: [1, 1, 0],
        ),
      ];
      const currentAnn = TimingChartAnnotation(
        id: 'a1',
        startTimeIndex: 1,
        endTimeIndex: 1,
        text: 'task A',
      );
      final incoming = _config(
        signals: const [
          SignalData(
            name: 'TRIGGER',
            signalType: SignalType.input,
            values: [1, 0],
          ),
          SignalData(
            name: 'BUSY',
            signalType: SignalType.output,
            values: [1, 1],
          ),
        ],
        annotations: const [
          TimingChartAnnotation(
            id: 'b1',
            startTimeIndex: 0,
            endTimeIndex: 1,
            text: 'task B',
          ),
        ],
        omissionIndices: const [1],
      );

      final result = ChartConcatService.concat(
        currentSignals: current,
        currentAnnotations: const [currentAnn],
        currentOmissions: const [0],
        currentStepDurationsMs: const [],
        currentMsPerStep: 1,
        currentTimeUnitIsMs: false,
        incoming: incoming,
        unmatchedPolicy: UnmatchedIncomingPolicy.padAndAdd,
        joinLabel: 'taskB.json',
        newId: nextId,
      );

      expect(result.signals[0].values, [0, 1, 0, 1, 0]);
      expect(result.signals[1].values, [1, 1, 0, 1, 1]);
      expect(result.omissionIndices, [0, 4]);
      expect(result.annotations[0].text, 'task A');
      expect(result.annotations[1].startTimeIndex, 3);
      expect(result.annotations[1].endTimeIndex, 4);
      expect(result.annotations[1].text, 'task B');
      expect(result.annotations.last.text, 'taskB.json');
      expect(result.annotations.last.startTimeIndex, 3);
      expect(result.annotations.last.endTimeIndex, 4);
      expect(result.annotations.last.placement, 'top');
      expect(result.joinStartIndex, 3);
      expect(result.joinEndIndex, 4);
      expect(result.segments, hasLength(2));
      expect(result.segments[0].startTimeIndex, 0);
      expect(result.segments[0].endTimeIndex, 3);
      expect(result.segments[1].label, 'taskB.json');
      expect(result.segments[1].startTimeIndex, 3);
      expect(result.segments[1].endTimeIndex, 5);
    });

    test('不一致信号は 0 埋めして行追加できる', () {
      final current = [
        const SignalData(
          name: 'IN1',
          signalType: SignalType.input,
          values: [1, 1],
        ),
      ];
      final incoming = _config(
        signals: const [
          SignalData(
            name: 'IN1',
            signalType: SignalType.input,
            values: [0],
          ),
          SignalData(
            name: 'OUT1',
            signalType: SignalType.output,
            values: [1],
          ),
        ],
      );

      final preview = ChartConcatService.preview(
        currentSignals: current,
        incomingSignals: incoming.signals,
        currentTimeUnitIsMs: false,
        incomingTimeUnitIsMs: false,
      );
      expect(preview.incomingOnlyNames, ['OUT1']);

      final added = ChartConcatService.concat(
        currentSignals: current,
        currentAnnotations: const [],
        currentOmissions: const [],
        currentStepDurationsMs: const [],
        currentMsPerStep: 1,
        currentTimeUnitIsMs: false,
        incoming: incoming,
        unmatchedPolicy: UnmatchedIncomingPolicy.padAndAdd,
        joinLabel: 'B',
        newId: nextId,
      );
      expect(added.signals.map((s) => s.name), ['IN1', 'OUT1']);
      expect(added.signals[1].values, [0, 0, 1]);
      expect(added.signals[1].signalType, SignalType.output);

      final dropped = ChartConcatService.concat(
        currentSignals: current,
        currentAnnotations: const [],
        currentOmissions: const [],
        currentStepDurationsMs: const [],
        currentMsPerStep: 1,
        currentTimeUnitIsMs: false,
        incoming: incoming,
        unmatchedPolicy: UnmatchedIncomingPolicy.drop,
        joinLabel: 'B',
        newId: nextId,
      );
      expect(dropped.signals.map((s) => s.name), ['IN1']);
      expect(dropped.signals.first.values, [1, 1, 0]);
    });

    test('名前リスト上の Output は誤った Input 種別でも Output として追加する', () {
      final current = [
        const SignalData(
          name: 'TRIGGER',
          signalType: SignalType.input,
          values: [1, 0],
        ),
      ];
      final incoming = _config(
        signals: const [
          SignalData(
            name: 'TRIGGER',
            signalType: SignalType.input,
            values: [0, 1],
          ),
          SignalData(
            name: 'CAMERA_2_IMAGE_EXPOSURE',
            signalType: SignalType.input,
            values: [1, 1],
          ),
          SignalData(
            name: 'CAMERA_2_IMAGE_ACQUISITION',
            signalType: SignalType.input,
            values: [1, 0],
          ),
        ],
        outputNames: const [
          'CAMERA_2_IMAGE_EXPOSURE',
          'CAMERA_2_IMAGE_ACQUISITION',
        ],
      );

      final result = ChartConcatService.concat(
        currentSignals: current,
        currentAnnotations: const [],
        currentOmissions: const [],
        currentStepDurationsMs: const [],
        currentMsPerStep: 1,
        currentTimeUnitIsMs: false,
        incoming: incoming,
        unmatchedPolicy: UnmatchedIncomingPolicy.padAndAdd,
        joinLabel: 'cam2',
        newId: nextId,
      );

      expect(result.signals[1].name, 'CAMERA_2_IMAGE_EXPOSURE');
      expect(result.signals[1].signalType, SignalType.output);
      expect(result.signals[2].name, 'CAMERA_2_IMAGE_ACQUISITION');
      expect(result.signals[2].signalType, SignalType.output);
    });

    test('現在チャートが空なら結合コメントを付けず incoming を採用する', () {
      final incoming = _config(
        signals: const [
          SignalData(
            name: 'IN1',
            signalType: SignalType.input,
            values: [1, 0, 1],
          ),
        ],
      );

      final result = ChartConcatService.concat(
        currentSignals: const [],
        currentAnnotations: const [],
        currentOmissions: const [],
        currentStepDurationsMs: const [],
        currentMsPerStep: 1,
        currentTimeUnitIsMs: false,
        incoming: incoming,
        unmatchedPolicy: UnmatchedIncomingPolicy.padAndAdd,
        joinLabel: 'first',
        newId: nextId,
      );

      expect(result.signals.single.values, [1, 0, 1]);
      expect(result.annotations, isEmpty);
      expect(result.joinStartIndex, 0);
      expect(result.joinEndIndex, 2);
    });

    test('ms モードでは stepDurationsMs も連結する', () {
      final current = [
        const SignalData(
          name: 'IN1',
          signalType: SignalType.input,
          values: [1, 0],
        ),
      ];
      final incoming = _config(
        signals: const [
          SignalData(
            name: 'IN1',
            signalType: SignalType.input,
            values: [1],
          ),
        ],
        timeUnitIsMs: true,
        msPerStep: 5,
        stepDurationsMs: const [5],
      );

      final result = ChartConcatService.concat(
        currentSignals: current,
        currentAnnotations: const [],
        currentOmissions: const [],
        currentStepDurationsMs: const [2, 3],
        currentMsPerStep: 2,
        currentTimeUnitIsMs: true,
        incoming: incoming,
        unmatchedPolicy: UnmatchedIncomingPolicy.padAndAdd,
        joinLabel: 'B',
        newId: nextId,
      );

      expect(result.stepDurationsMs, [2, 3, 5]);
    });

    test('時間単位の不一致を preview で検出する', () {
      final preview = ChartConcatService.preview(
        currentSignals: const [
          SignalData(
            name: 'IN1',
            signalType: SignalType.input,
            values: [1],
          ),
        ],
        incomingSignals: const [
          SignalData(
            name: 'IN1',
            signalType: SignalType.input,
            values: [0],
          ),
        ],
        currentTimeUnitIsMs: true,
        incomingTimeUnitIsMs: false,
      );
      expect(preview.timeUnitMismatch, isTrue);
    });

    test('結合コメントのIDは重複しない', () {
      final current = [
        const SignalData(
          name: 'IN1',
          signalType: SignalType.input,
          values: [1],
        ),
      ];
      final incoming = _config(
        signals: const [
          SignalData(
            name: 'IN1',
            signalType: SignalType.input,
            values: [0],
          ),
        ],
        annotations: const [
          TimingChartAnnotation(
            id: '',
            startTimeIndex: 0,
            endTimeIndex: 0,
            text: 'てすと',
          ),
          TimingChartAnnotation(
            id: '',
            startTimeIndex: 0,
            endTimeIndex: 0,
            text: 'another',
          ),
        ],
      );

      final result = ChartConcatService.concat(
        currentSignals: current,
        currentAnnotations: const [],
        currentOmissions: const [],
        currentStepDurationsMs: const [],
        currentMsPerStep: 1,
        currentTimeUnitIsMs: false,
        incoming: incoming,
        unmatchedPolicy: UnmatchedIncomingPolicy.padAndAdd,
        joinLabel: 'join',
      );

      final ids = result.annotations.map((a) => a.id).toList();
      expect(ids.length, 3);
      expect(ids.toSet().length, ids.length);
      expect(ids.every((id) => id.isNotEmpty), isTrue);
    });

    test('名前が空で全て0の行は結合しない', () {
      final current = [
        const SignalData(
          name: 'IN1',
          signalType: SignalType.input,
          values: [1, 0],
        ),
      ];
      final incoming = _config(
        signals: const [
          SignalData(
            name: 'IN1',
            signalType: SignalType.input,
            values: [1],
          ),
          SignalData(
            name: '',
            signalType: SignalType.output,
            values: [0, 0, 0],
          ),
        ],
      );

      final preview = ChartConcatService.preview(
        currentSignals: current,
        incomingSignals: incoming.signals,
        currentTimeUnitIsMs: false,
        incomingTimeUnitIsMs: false,
      );
      expect(preview.incomingOnlyNames, isEmpty);

      final result = ChartConcatService.concat(
        currentSignals: current,
        currentAnnotations: const [],
        currentOmissions: const [],
        currentStepDurationsMs: const [],
        currentMsPerStep: 1,
        currentTimeUnitIsMs: false,
        incoming: incoming,
        unmatchedPolicy: UnmatchedIncomingPolicy.padAndAdd,
        joinLabel: 'B',
        newId: nextId,
      );
      expect(result.signals.map((s) => s.name), ['IN1']);
    });

    test('名前が空でも波形がある行は Unnamed として残す', () {
      final current = [
        const SignalData(
          name: 'IN1',
          signalType: SignalType.input,
          values: [1],
        ),
      ];
      final incoming = _config(
        signals: const [
          SignalData(
            name: '',
            signalType: SignalType.output,
            values: [0, 1, 0],
          ),
        ],
      );

      final result = ChartConcatService.concat(
        currentSignals: current,
        currentAnnotations: const [],
        currentOmissions: const [],
        currentStepDurationsMs: const [],
        currentMsPerStep: 1,
        currentTimeUnitIsMs: false,
        incoming: incoming,
        unmatchedPolicy: UnmatchedIncomingPolicy.padAndAdd,
        joinLabel: 'B',
        newId: nextId,
      );
      expect(result.signals.map((s) => s.name), ['IN1', 'Unnamed 1']);
      expect(result.signals.last.values, [0, 0, 1, 0]);
    });

    test('IOプレフィックス付きの同名信号は同一行に結合する', () {
      final current = [
        const SignalData(
          name: 'BUSY',
          signalType: SignalType.output,
          values: [1, 0],
        ),
      ];
      final incoming = _config(
        signals: const [
          SignalData(
            name: 'Output3: BUSY',
            signalType: SignalType.output,
            values: [1],
          ),
        ],
      );

      final preview = ChartConcatService.preview(
        currentSignals: current,
        incomingSignals: incoming.signals,
        currentTimeUnitIsMs: false,
        incomingTimeUnitIsMs: false,
      );
      expect(preview.incomingOnlyNames, isEmpty);

      final result = ChartConcatService.concat(
        currentSignals: current,
        currentAnnotations: const [],
        currentOmissions: const [],
        currentStepDurationsMs: const [],
        currentMsPerStep: 1,
        currentTimeUnitIsMs: false,
        incoming: incoming,
        unmatchedPolicy: UnmatchedIncomingPolicy.padAndAdd,
        joinLabel: 'B',
        newId: nextId,
      );
      expect(result.signals, hasLength(1));
      expect(result.signals.single.name, 'BUSY');
      expect(result.signals.single.values, [1, 0, 1]);
    });

    test('カメラ取込表を結合順に積み、列数は多い方に揃える', () {
      final current = [
        const SignalData(
          name: 'TRIGGER',
          signalType: SignalType.input,
          values: [0, 1],
        ),
      ];
      final incoming = _config(
        signals: const [
          SignalData(
            name: 'TRIGGER',
            signalType: SignalType.input,
            values: [1, 0],
          ),
        ],
        camera: 2,
        tableData: const [
          [CellMode.mode2, CellMode.mode1],
          [CellMode.none, CellMode.none],
        ],
        rowModes: const ['simultaneous', 'none'],
      );

      final result = ChartConcatService.concat(
        currentSignals: current,
        currentAnnotations: const [],
        currentOmissions: const [],
        currentStepDurationsMs: const [],
        currentMsPerStep: 1,
        currentTimeUnitIsMs: false,
        incoming: incoming,
        unmatchedPolicy: UnmatchedIncomingPolicy.padAndAdd,
        joinLabel: 'taskB.json',
        currentTable: const [
          [CellMode.mode1],
          [CellMode.none],
        ],
        currentRowModes: const ['none', 'none'],
        currentCameraCount: 1,
        newId: nextId,
      );

      expect(result.cameraCount, 2);
      expect(result.tableData, [
        [CellMode.mode1, CellMode.none],
        [CellMode.mode2, CellMode.mode1],
      ]);
      expect(result.rowModes, ['none', 'simultaneous']);
      expect(result.segments[0].cameraTable, [
        [CellMode.mode1],
      ]);
      expect(result.segments[1].cameraTable, [
        [CellMode.mode2, CellMode.mode1],
      ]);
    });
  });
}

AppConfig _config({
  required List<SignalData> signals,
  List<TimingChartAnnotation> annotations = const [],
  List<int> omissionIndices = const [],
  bool timeUnitIsMs = false,
  double msPerStep = 1,
  List<double> stepDurationsMs = const [],
  List<String> outputNames = const [],
  int camera = 1,
  List<List<CellMode>> tableData = const [],
  List<String> rowModes = const [],
}) {
  return AppConfig(
    formState: TimingFormState(
      triggerOption: 'Single Trigger',
      ioPort: 32,
      hwPort: 0,
      camera: camera,
      inputCount: 32,
      outputCount: 32,
    ),
    signals: signals,
    tableData: tableData,
    inputNames: const [],
    outputNames: outputNames,
    hwTriggerNames: const [],
    inputVisibility: const [],
    outputVisibility: const [],
    hwTriggerVisibility: const [],
    rowModes: rowModes,
    annotations: annotations,
    omissionIndices: omissionIndices,
    timeUnitIsMs: timeUnitIsMs,
    msPerStep: msPerStep,
    stepDurationsMs: stepDurationsMs,
  );
}
