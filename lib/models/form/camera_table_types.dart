import 'package:flutter/foundation.dart';

/// カメラ設定テーブルで使用するセル種別
///
/// NOTE:
/// - UI（widgets）から models 層へ切り出し、AppConfig 等が widgets に依存しないようにするための型定義。
/// - `mode1..3` の意味は FormTab の UI 表示（順次取込/接点入力/HWトリガ）と対応します。
enum CellMode { none, mode1, mode2, mode3, mode4, mode5 }

/// 行モード（none / 同時取込）
///
/// - `simultaneous`: 同一行の複数カメラを同時に取込扱いにするモード
enum RowMode { none, simultaneous }

/// `RowMode` を永続化する際の文字列
///
/// NOTE: json 保存/復元では enum.name を使う実装もあるため、将来の互換性のために残しています。
@visibleForTesting
const String kRowModeNone = 'none';

@visibleForTesting
const String kRowModeSimultaneous = 'simultaneous';


