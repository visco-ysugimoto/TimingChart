import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/form/camera_capture_scheduler.dart';
import 'package:flutter_application_1/models/form/camera_table_types.dart';

void main() {
  group('CameraCaptureScheduler', () {
    /// 添付例:
    /// Cam1: 行1,2,5,6 / Cam2: 行7,8 / Cam3: 行3,4
    List<List<CellMode>> exampleTable() {
      final none = CellMode.none;
      final seq = CellMode.mode1;
      return [
        [seq, none, none], // 1
        [seq, none, none], // 2
        [none, none, seq], // 3
        [none, none, seq], // 4
        [seq, none, none], // 5
        [seq, none, none], // 6
        [none, seq, none], // 7
        [none, seq, none], // 8
        [none, none, none], // 9
      ];
    }

    List<RowMode> noneRowModes(int rows) =>
        List<RowMode>.filled(rows, RowMode.none);

    test('列順はカメラ列ごとに上から並べる (1,1,1,1,2,2,3,3)', () {
      final schedule = CameraCaptureScheduler.build(
        tableData: exampleTable(),
        rowModes: noneRowModes(9),
        cameraCount: 3,
        scanOrder: CaptureScanOrder.column,
      );

      expect(
        schedule.orderedCameraSequence(),
        [1, 1, 1, 1, 2, 2, 3, 3],
      );
    });

    test('行順は表の上の行から左へ並べる (1,1,3,3,1,1,2,2)', () {
      final schedule = CameraCaptureScheduler.build(
        tableData: exampleTable(),
        rowModes: noneRowModes(9),
        cameraCount: 3,
        scanOrder: CaptureScanOrder.row,
      );

      expect(
        schedule.orderedCameraSequence(),
        [1, 1, 3, 3, 1, 1, 2, 2],
      );
    });

    test('同時取込がある場合は走査順に関わらず行単位のまま', () {
      final table = [
        [CellMode.mode1, CellMode.mode1, CellMode.none],
        [CellMode.mode1, CellMode.none, CellMode.none],
        [CellMode.none, CellMode.none, CellMode.mode1],
      ];
      final rowModes = [
        RowMode.simultaneous,
        RowMode.none,
        RowMode.none,
      ];

      final column = CameraCaptureScheduler.build(
        tableData: table,
        rowModes: rowModes,
        cameraCount: 3,
        scanOrder: CaptureScanOrder.column,
      );
      final row = CameraCaptureScheduler.build(
        tableData: table,
        rowModes: rowModes,
        cameraCount: 3,
        scanOrder: CaptureScanOrder.row,
      );

      // 行1は Cam1+Cam2 同時、その後 行2 Cam1、行3 Cam3
      expect(column.orderedCameraSequence(), [1, 2, 1, 3]);
      expect(row.orderedCameraSequence(), column.orderedCameraSequence());
      expect(column.exposureTimes[1]![0], column.exposureTimes[2]![0]);
    });

    test('接点入力とHWトリガの時刻をカメラへ紐づける', () {
      final table = [
        [CellMode.mode2, CellMode.none],
        [CellMode.none, CellMode.mode3],
      ];
      final schedule = CameraCaptureScheduler.build(
        tableData: table,
        rowModes: noneRowModes(2),
        cameraCount: 2,
        scanOrder: CaptureScanOrder.row,
      );

      expect(schedule.contactWaitTimes[1], isNotEmpty);
      expect(schedule.hwTriggerTimes[2], isNotEmpty);
      expect(schedule.contactWaitTimes[1], schedule.exposureTimes[1]);
      expect(schedule.hwTriggerTimes[2], schedule.exposureTimes[2]);
    });
  });

  group('CaptureScanOrder', () {
    test('不明な名前は列順にフォールバックする', () {
      expect(CaptureScanOrder.fromName(null), CaptureScanOrder.column);
      expect(CaptureScanOrder.fromName('unknown'), CaptureScanOrder.column);
      expect(CaptureScanOrder.fromName('row'), CaptureScanOrder.row);
    });
  });
}
