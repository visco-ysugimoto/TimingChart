import 'package:flutter/material.dart';
import 'dart:math' as math;

/// チャートの座標変換を担当するクラス
///
/// このクラスは論理座標（時間、信号インデックスなど）を
/// キャンバス上の物理座標（ピクセル）に変換する機能を提供します。
class ChartCoordinateMapper {
  /// キャンバスの全体サイズ
  final Size canvasSize;

  /// 表示する合計時間
  final double totalTime;

  /// 信号の数
  final int signalCount;

  /// 各信号の高さ
  final double signalHeight;

  /// 信号間の垂直パディング
  final double verticalPadding;

  /// 上部パディング
  final double topPadding;

  /// 下部パディング
  final double bottomPadding;

  /// 左側パディング
  final double leftPadding;

  /// 右側パディング
  final double rightPadding;

  /// コンストラクタ
  ///
  /// [canvasSize] キャンバスの全体サイズ
  /// [totalTime] 表示する合計時間
  /// [signalCount] 信号の数
  /// [signalHeight] 各信号の高さ
  /// [verticalPadding] 信号間の垂直パディング
  /// [topPadding] 上部パディング
  /// [bottomPadding] 下部パディング
  /// [leftPadding] 左側パディング
  /// [rightPadding] 右側パディング
  ///
  /// 例外:
  /// - [ArgumentError] パラメータが不正な場合
  ChartCoordinateMapper({
    required this.canvasSize,
    required this.totalTime,
    required this.signalCount,
    required this.signalHeight,
    required this.verticalPadding,
    required this.topPadding,
    required this.bottomPadding,
    required this.leftPadding,
    required this.rightPadding,
  }) : assert(totalTime > 0, '合計時間は0より大きい必要があります'),
       assert(signalCount >= 0, '信号数は0以上である必要があります'),
       assert(signalHeight > 0, '信号の高さは0より大きい必要があります'),
       assert(verticalPadding >= 0, '垂直パディングは0以上である必要があります'),
       assert(topPadding >= 0, '上部パディングは0以上である必要があります'),
       assert(bottomPadding >= 0, '下部パディングは0以上である必要があります'),
       assert(leftPadding >= 0, '左側パディングは0以上である必要があります'),
       assert(rightPadding >= 0, '右側パディングは0以上である必要があります');

  /// チャート領域の幅（パディングを除く）
  double get chartAreaWidth => canvasSize.width - leftPadding - rightPadding;

  /// チャート領域の高さ（パディングを除く）
  double get chartAreaHeight => canvasSize.height - topPadding - bottomPadding;

  /// 信号1つ分の合計高さ（信号の高さ + パディング）
  double get signalTotalHeight => signalHeight + verticalPadding;

  /// 時間をX座標に変換
  ///
  /// [time] 変換する時間
  /// 戻り値: X座標（ピクセル）
  double mapTimeToX(double time) {
    // 時間が負の場合は左端にクリップ
    if (time < 0) return leftPadding;

    // 時間が合計時間を超える場合は右端にクリップ
    if (time > totalTime) return leftPadding + chartAreaWidth;

    // 時間を0〜1の範囲に正規化し、チャート領域の幅に比例させる
    return leftPadding + (time / totalTime) * chartAreaWidth;
  }

  /// X座標を時間に変換
  ///
  /// [x] 変換するX座標（ピクセル）
  /// 戻り値: 時間
  double mapXToTime(double x) {
    // 左パディングより左の場合は0にクリップ
    if (x < leftPadding) return 0;

    // 右端より右の場合は合計時間にクリップ
    if (x > leftPadding + chartAreaWidth) return totalTime;

    // X座標をチャート領域内での相対位置（0〜1）に変換し、合計時間に比例させる
    return ((x - leftPadding) / chartAreaWidth) * totalTime;
  }

  /// 信号インデックスから中央のY座標を取得
  ///
  /// [signalIndex] 信号インデックス
  /// 戻り値: 中央のY座標（ピクセル）
  /// 例外:
  /// - [ArgumentError] 信号インデックスが範囲外の場合
  double getSignalCenterY(int signalIndex) {
    if (signalIndex < 0 || signalIndex >= signalCount) {
      throw ArgumentError('信号インデックスが範囲外です: $signalIndex');
    }

    return topPadding + signalIndex * signalTotalHeight + signalHeight / 2;
  }

  /// 信号インデックスからHighレベルのY座標を取得
  ///
  /// [signalIndex] 信号インデックス
  /// 戻り値: HighレベルのY座標（ピクセル）
  double getSignalHighY(int signalIndex) {
    return getSignalCenterY(signalIndex) - signalHeight / 3;
  }

  /// 信号インデックスからLowレベルのY座標を取得
  ///
  /// [signalIndex] 信号インデックス
  /// 戻り値: LowレベルのY座標（ピクセル）
  double getSignalLowY(int signalIndex) {
    return getSignalCenterY(signalIndex);
  }

  /// 信号インデックスから信号の上端Y座標を取得
  ///
  /// [signalIndex] 信号インデックス
  /// 戻り値: 上端のY座標（ピクセル）
  /// 例外:
  /// - [ArgumentError] 信号インデックスが範囲外の場合
  double getSignalTopY(int signalIndex) {
    if (signalIndex < 0 || signalIndex >= signalCount) {
      throw ArgumentError('信号インデックスが範囲外です: $signalIndex');
    }

    return topPadding + signalIndex * signalTotalHeight;
  }

  /// 信号インデックスから信号の下端Y座標を取得
  ///
  /// [signalIndex] 信号インデックス
  /// 戻り値: 下端のY座標（ピクセル）
  double getSignalBottomY(int signalIndex) {
    return getSignalTopY(signalIndex) + signalHeight;
  }

  /// 時間間隔からグリッド間隔を計算
  ///
  /// [minSpacingPx] 最小のグリッド間隔（ピクセル）
  /// 戻り値: 適切な時間間隔
  double calculateTimeGridInterval(double minSpacingPx) {
    if (minSpacingPx <= 0) {
      throw ArgumentError('最小グリッド間隔は0より大きい必要があります');
    }

    // チャート領域の幅をminSpacingPxで割って、必要なグリッド線の最大数を計算
    final maxGridLines = chartAreaWidth / minSpacingPx;

    // 合計時間をグリッド線の最大数で割って、最小の時間間隔を計算
    final minInterval = totalTime / maxGridLines;

    // 読みやすい間隔に調整（1, 2, 5, 10, 20, 50, ...のいずれか）
    final magnitude = pow10(minInterval);

    if (minInterval < 1 * magnitude) return 1 * magnitude;
    if (minInterval < 2 * magnitude) return 2 * magnitude;
    if (minInterval < 5 * magnitude) return 5 * magnitude;
    return 10 * magnitude;
  }

  /// 10の累乗を計算
  ///
  /// [value] 計算する値
  /// 戻り値: 10の累乗
  double pow10(double value) {
    if (value == 0) return 1;

    // 10の累乗の指数部分を計算
    final exponent =
        (value.abs() < 1) ? (log10(value).floor() - 1) : log10(value).floor();

    return math.pow(10, exponent).toDouble();
  }

  /// 10を底とする対数を計算
  ///
  /// [value] 計算する値
  /// 戻り値: 10を底とする対数
  double log10(double value) {
    return math.log(value) / math.ln10;
  }

  /// Y座標から最も近い信号インデックスを取得
  ///
  /// [y] Y座標（ピクセル）
  /// 戻り値: 最も近い信号インデックス
  int getNearestSignalIndex(double y) {
    if (y < topPadding) return 0;
    if (y > topPadding + signalCount * signalTotalHeight)
      return signalCount - 1;

    return ((y - topPadding) / signalTotalHeight).floor();
  }
}
