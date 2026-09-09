import 'package:flutter/foundation.dart';

/// カメラ設定テーブルで使用するセル種別
///
/// NOTE:
/// - UI（widgets）から models 層へ切り出し、AppConfig 等が widgets に依存しないようにするための型定義。
/// - `mode1..3` の意味は FormTab の UI 表示（順次取込/接点入力/HWトリガ）と対応します。
enum CellMode { none, mode1, mode2, mode3, mode4, mode5 }

/// セルがチャート上の取込（露光）対象かどうか
///
/// `mode1`=順次取込 / `mode2`=接点入力 / `mode3`=HWトリガ
bool isCaptureCellMode(CellMode mode) =>
    mode == CellMode.mode1 ||
    mode == CellMode.mode2 ||
    mode == CellMode.mode3;

/// 行モード（none / 同時取込）
///
/// - `simultaneous`: 同一行の複数カメラを同時に取込扱いにするモード
enum RowMode { none, simultaneous }

/// Camera Configuration Table から波形を組み立てるときの走査順
///
/// - `column`: カメラ列ごと（従来どおり。Cam1 の行を上から、次に Cam2、…）
/// - `row`: 行ごと（1行目を左から右、次に 2行目、…）
///
/// 同時取込行が1つでもある場合は、この指定に関わらず従来どおり行単位で処理する。
enum CaptureScanOrder {
  column,
  row;

  static const CaptureScanOrder defaultOrder = column;

  static CaptureScanOrder fromName(String? name) {
    return CaptureScanOrder.values.firstWhere(
      (e) => e.name == name,
      orElse: () => defaultOrder,
    );
  }
}

/// 同時取込は「同じタイミングで複数カメラを撮る」設定のため、カメラが2台以上のときだけ使える。
bool canUseSimultaneousCapture(int cameraCount) => cameraCount > 1;

/// `RowMode` を永続化する際の文字列
///
/// NOTE: json 保存/復元では enum.name を使う実装もあるため、将来の互換性のために残しています。
@visibleForTesting
const String kRowModeNone = 'none';

@visibleForTesting
const String kRowModeSimultaneous = 'simultaneous';


