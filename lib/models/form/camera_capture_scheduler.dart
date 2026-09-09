import 'camera_table_types.dart';

/// Camera Configuration Table から算出した露光タイミング
class CameraCaptureSchedule {
  /// カメラ番号 (1-based) → 露光開始インデックス
  final Map<int, List<int>> exposureTimes;

  /// カメラ番号 (1-based) → 接点入力待ちの時刻
  final Map<int, List<int>> contactWaitTimes;

  /// カメラ番号 (1-based) → HWトリガの時刻
  final Map<int, List<int>> hwTriggerTimes;

  const CameraCaptureSchedule({
    required this.exposureTimes,
    required this.contactWaitTimes,
    required this.hwTriggerTimes,
  });

  /// 時刻順のカメラ番号列。同時刻はカメラ番号の昇順。
  List<int> orderedCameraSequence() {
    final events = <({int time, int camera})>[];
    exposureTimes.forEach((camera, times) {
      for (final time in times) {
        events.add((time: time, camera: camera));
      }
    });
    events.sort((a, b) {
      final byTime = a.time.compareTo(b.time);
      if (byTime != 0) return byTime;
      return a.camera.compareTo(b.camera);
    });
    return [for (final e in events) e.camera];
  }
}

/// Camera Configuration Table を走査して露光タイミングを決める
///
/// Template 生成時の「列順 / 行順」をここに集約する。
/// 同時取込がある場合は従来どおり行単位で処理し、[scanOrder] は使わない。
class CameraCaptureScheduler {
  static const int defaultMinGap = 4;
  static const int defaultStartTime = 6;

  const CameraCaptureScheduler._();

  static CameraCaptureSchedule build({
    required List<List<CellMode>> tableData,
    required List<RowMode> rowModes,
    required int cameraCount,
    CaptureScanOrder scanOrder = CaptureScanOrder.column,
    int minGap = defaultMinGap,
    int startTime = defaultStartTime,
  }) {
    final cameras = cameraCount > 0 ? cameraCount : 1;
    final exposureTimes = <int, List<int>>{
      for (int c = 1; c <= cameras; c++) c: <int>[],
    };
    final contactWaitTimes = <int, List<int>>{
      for (int c = 1; c <= cameras; c++) c: <int>[],
    };
    final hwTriggerTimes = <int, List<int>>{
      for (int c = 1; c <= cameras; c++) c: <int>[],
    };

    var currentTime = startTime;
    final step = minGap + 1;
    final hasSimultaneous =
        canUseSimultaneousCapture(cameras) &&
        rowModes.any((mode) => mode == RowMode.simultaneous);

    void captureAt(int row, int cam, int time) {
      if (row < 0 || row >= tableData.length) return;
      if (cam < 0 || cam >= tableData[row].length || cam >= cameras) return;
      final mode = tableData[row][cam];
      if (!isCaptureCellMode(mode)) return;
      exposureTimes[cam + 1]!.add(time);
      if (mode == CellMode.mode2) {
        contactWaitTimes[cam + 1]!.add(time);
      } else if (mode == CellMode.mode3) {
        hwTriggerTimes[cam + 1]!.add(time);
      }
    }

    if (hasSimultaneous) {
      for (int row = 0; row < tableData.length; row++) {
        final isSimul =
            row < rowModes.length && rowModes[row] == RowMode.simultaneous;
        if (isSimul) {
          var any = false;
          for (int cam = 0; cam < cameras; cam++) {
            if (row < tableData.length &&
                cam < tableData[row].length &&
                isCaptureCellMode(tableData[row][cam])) {
              captureAt(row, cam, currentTime);
              any = true;
            }
          }
          if (any) currentTime += step;
        } else {
          for (int cam = 0; cam < cameras; cam++) {
            if (row < tableData.length &&
                cam < tableData[row].length &&
                isCaptureCellMode(tableData[row][cam])) {
              captureAt(row, cam, currentTime);
              currentTime += step;
            }
          }
        }
      }
    } else if (scanOrder == CaptureScanOrder.row) {
      for (int row = 0; row < tableData.length; row++) {
        for (int cam = 0; cam < cameras; cam++) {
          if (row < tableData.length &&
              cam < tableData[row].length &&
              isCaptureCellMode(tableData[row][cam])) {
            captureAt(row, cam, currentTime);
            currentTime += step;
          }
        }
      }
    } else {
      for (int cam = 0; cam < cameras; cam++) {
        for (int row = 0; row < tableData.length; row++) {
          if (cam < tableData[row].length &&
              isCaptureCellMode(tableData[row][cam])) {
            captureAt(row, cam, currentTime);
            currentTime += step;
          }
        }
      }
    }

    return CameraCaptureSchedule(
      exposureTimes: exposureTimes,
      contactWaitTimes: contactWaitTimes,
      hwTriggerTimes: hwTriggerTimes,
    );
  }
}
