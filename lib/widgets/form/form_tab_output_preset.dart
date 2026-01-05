/// `FormTab` の出力割当プリセットと選択ロジックをまとめたヘルパー
///
/// 目的:
/// - `form_tab.dart` から「出力ポートの配置ルール」を切り出して見通しを良くする
/// - ルールを一箇所にまとめ、将来的な変更点を局所化する
class FormTabOutputPreset {
  const FormTabOutputPreset._();

  /// 出力ポート数ごとの「信号ID -> 出力インデックス(0-based)」のプリセット
  ///
  /// NOTE:
  /// - ここで返す index は `TextEditingController` 配列に対する 0-based index 想定です。
  static const Map<int, Map<String, int>> presetMap = {
    6: {
      'AUTO_MODE': 1,
      'BUSY': 2, // Output1
      'ENABLE_RESULT_SIGNAL': 3, // Output2
      'TOTAL_RESULT_OK': 4, // Output3
      'TOTAL_RESULT_NG': 5, // Output4
    },
    16: {
      'AUTO_MODE': 1,
      'BUSY': 2, // Output9
      'ENABLE_RESULT_SIGNAL': 6, // Output10
      'TOTAL_RESULT_OK': 9, // Output11
      'TOTAL_RESULT_NG': 10, // Output12
    },
    32: {
      'AUTO_MODE': 1, // Output2
      'BUSY': 2, // Output3
      'RECOVERY': 26, // Output27
      'BATCH_EXPOSURE': 27, // Output28
      'ENABLE_RESULT_SIGNAL': 28, // Output29
      'ERROR': 29, // Output30
      'ACQ_TRIGGER_WAITING': 30, // Output31
      'PC_CONTROL': 31, // Output32
    },
  };

  static int selectOutputIndex(
    String signalId,
    int totalOutputs,
    int totalCameras,
  ) {
    // 優先ルール:
    // 1) 32ポート構成では Camera信号を予約領域に詰める（従来仕様）
    // 2) それ以外は presetMap に基づいて割当
    // 従来仕様：32 ポート構成で CAM_EXPOSURE / ACQUISITION を配置
    if (totalOutputs == 32) {
      final expReg = RegExp(r'^CAMERA_(\d+)_IMAGE_EXPOSURE');
      final acqReg = RegExp(r'^CAMERA_(\d+)_IMAGE_ACQUISITION');

      RegExpMatch? m = expReg.firstMatch(signalId);
      if (m != null) {
        final cam = int.parse(m.group(1)!);
        if (cam >= 1 && cam <= totalCameras) {
          return 3 + (cam - 1);
        }
      }

      m = acqReg.firstMatch(signalId);
      if (m != null) {
        final cam = int.parse(m.group(1)!);
        if (cam >= 1 && cam <= totalCameras) {
          return 3 + totalCameras + (cam - 1);
        }
      }

      if (signalId == 'TOTAL_RESULT_OK') {
        return 3 + totalCameras * 2 + 1;
      }
      if (signalId == 'TOTAL_RESULT_NG') {
        return 3 + totalCameras * 2 + 2;
      }
    }

    final preset = presetMap[totalOutputs];
    if (preset == null) return -1;
    return preset[signalId] ?? -1;
  }
}
