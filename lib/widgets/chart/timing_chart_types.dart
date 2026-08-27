part of 'timing_chart.dart';

/// `TimingChart` の内部用型/計算ユーティリティをまとめた `part` ファイル。
///
/// - **目的**: `timing_chart.dart` 本体の肥大化を抑え、責務（UI/ジェスチャー/編集/描画/補助型）を分離する。
/// - **方針**: `part of` を使うことで、`TimingChartState` の private メンバー（`_...`）を含め同一ライブラリ内で共有する。
/// - **内容**: レイアウト計算結果（`_ChartLayoutData`）や、時間位置計算（`_TimePositionCalculator`）、
///   自動コメント生成で使う小さな内部イベント型（`_HwTriggerEdge` / `_OutputEdge`）など。
///
/// 自動コメント生成で使用する HWトリガ立ち上がりイベント（内部専用）
class _HwTriggerEdge {
  final int rowIndex;
  final int timeIndex;
  final String name;

  const _HwTriggerEdge({
    required this.rowIndex,
    required this.timeIndex,
    required this.name,
  });
}

/// 自動コメント生成で使用する 出力信号立ち上がりイベント（内部専用）
class _OutputEdge {
  final int rowIndex;
  final int timeIndex;
  final String name;

  const _OutputEdge({
    required this.rowIndex,
    required this.timeIndex,
    required this.name,
  });
}

/// タイミングチャートのレンダリングに必要なレイアウト計算データ構造
///
/// このクラスは、タイミングチャートをレンダリングするために必要なすべての計算済みレイアウト値を保持します。
/// セルの寸法、ズーム係数、表示可能な信号インデックスなどが含まれます。
/// これらの値はレイアウトパスごとに一度計算され、レンダリング全体で再利用されます。
class _ChartLayoutData {
  /// 信号タイプでフィルタリング後の表示可能な信号行インデックスのリスト
  final List<int> visibleIndexes;

  /// 時間ステップの総数（ミリ秒単位を使用する場合は小数になる可能性がある）
  final double totalSteps;

  /// ズームが適用される前の基本セル幅
  final double baseCellWidth;

  /// ビューポート内のすべてのコンテンツを表示するために必要な最小セル幅
  final double minCellWidthForFullView;

  /// ズーム制約に基づく最大許可セル幅
  final double maxCellWidthAllowed;

  /// 現在のビューで許可される最小ズーム係数
  final double minZoomFactorForView;

  /// 現在のビューで許可される最大ズーム係数
  final double maxZoomFactorForView;

  /// 最小/最大境界にクランプされた後の実効ズーム係数
  final double effectiveZoomFactor;

  /// レンダリングに使用される実際のセル幅（baseCellWidth * effectiveZoomFactor）
  final double cellWidth;

  /// 各信号行セルの高さ
  final double cellHeight;

  /// チャートコンテンツ領域の総幅
  final double totalWidth;

  /// コメント領域を含むチャートコンテンツ領域の総高さ
  final double totalHeight;

  /// 下部に予約されているアノテーションコメント領域の高さ
  final double commentAreaHeight;

  /// 上部に予約されているアノテーションコメント領域の高さ
  final double topCommentAreaHeight;

  /// すべての信号配列の最大長（最長の信号）
  final int maxLen;

  /// コメント領域込みの高さがビューポートを超え、縦スクロールが必要か
  final bool needsVerticalScroll;

  _ChartLayoutData({
    required this.visibleIndexes,
    required this.totalSteps,
    required this.baseCellWidth,
    required this.minCellWidthForFullView,
    required this.maxCellWidthAllowed,
    required this.minZoomFactorForView,
    required this.maxZoomFactorForView,
    required this.effectiveZoomFactor,
    required this.cellWidth,
    required this.cellHeight,
    required this.totalWidth,
    required this.totalHeight,
    required this.commentAreaHeight,
    required this.topCommentAreaHeight,
    required this.maxLen,
    required this.needsVerticalScroll,
  });
}

/// コメント増加時の行高さと縦スクロール要否
class _VerticalLayout {
  final double cellHeight;
  final double totalHeight;
  final bool needsVerticalScroll;

  const _VerticalLayout({
    required this.cellHeight,
    required this.totalHeight,
    required this.needsVerticalScroll,
  });

  /// 画面フィット時はコメントなしの行高さを基準に、[minVerticalFitScale] 未満へは圧縮しない。
  /// 溢れた分は [needsVerticalScroll] で縦スクロールへ回す。
  static _VerticalLayout calculate({
    required bool fitToScreen,
    required double viewportHeight,
    required double chartMarginTop,
    required double topCommentAreaHeight,
    required double commentAreaHeight,
    required double noCommentBottomMargin,
    required int visibleRowCount,
    required double minVerticalFitScale,
    required double minCellHeight,
    required double defaultCellHeight,
  }) {
    final double safeViewport = viewportHeight.isFinite && viewportHeight > 0
        ? viewportHeight
        : 0.0;

    double cellHeight;
    if (!fitToScreen || visibleRowCount <= 0) {
      cellHeight = defaultCellHeight;
    } else {
      final double naturalAvailable = math.max(
        0.0,
        safeViewport - chartMarginTop - noCommentBottomMargin,
      );
      final double naturalCellHeight = math.max(
        naturalAvailable / visibleRowCount,
        minCellHeight,
      );
      final double fittedAvailable =
          safeViewport -
          chartMarginTop -
          topCommentAreaHeight -
          commentAreaHeight;
      final double fittedCellHeight = fittedAvailable / visibleRowCount;
      final double minByRatio = naturalCellHeight * minVerticalFitScale;
      cellHeight = math.max(
        math.max(fittedCellHeight, minByRatio),
        minCellHeight,
      );
    }

    final double totalHeight =
        chartMarginTop +
        topCommentAreaHeight +
        visibleRowCount * cellHeight +
        commentAreaHeight;

    return _VerticalLayout(
      cellHeight: cellHeight,
      totalHeight: totalHeight,
      needsVerticalScroll: totalHeight > safeViewport + 0.5,
    );
  }
}

/// タイミングチャートでの時間位置計算用のヘルパークラス
///
/// ピクセル位置と時間ステップインデックス間の変換を行う静的ユーティリティメソッドを提供します。
/// ステップベースとミリ秒ベースの両方の時間単位を処理します。
class _TimePositionCalculator {
  /// 時間単位変換用の累積ステップ位置配列を計算します
  ///
  /// ミリ秒単位を使用する場合、各ステップの継続時間が異なる可能性があります。
  /// このメソッドは、正規化されたステップ単位（1.0 = 1つの基本ステップ継続時間）で
  /// 各ステップ境界の累積位置を計算します。
  ///
  /// 長さmaxLen + 1の配列を返します。pos[i]はステップiの開始時の累積位置で、
  /// pos[maxLen]は総位置です。
  ///
  /// [settings] - msPerStepと時間単位設定を含む設定
  /// [maxLen] - 時間ステップの最大数
  /// [stepDurationsMs] - 各ステップの継続時間（ミリ秒）の配列
  /// 累積ステップ位置の配列を返します
  static List<double> calculateStepPositions(
    SettingsNotifier settings,
    int maxLen,
    List<double> stepDurationsMs,
  ) {
    final List<double> pos = List<double>.filled(maxLen + 1, 0.0);
    for (int i = 0; i < maxLen; i++) {
      final durSteps = (i < stepDurationsMs.length && settings.msPerStep > 0)
          ? stepDurationsMs[i] / settings.msPerStep
          : 1.0;
      pos[i + 1] = pos[i] + durSteps;
    }
    return pos;
  }

  /// ピクセル単位の相対X位置から時間ステップインデックスを取得します
  ///
  /// ピクセル位置（波形領域の開始位置からの相対位置）を対応する時間ステップインデックスに変換します。
  /// ステップベースとミリ秒ベースの両方の時間単位を正しく処理します。
  ///
  /// [relX] - 波形領域の開始位置からの相対X位置（ピクセル）
  /// [cellWidth] - 1つのセルの幅（ピクセル）
  /// [settings] - 時間単位設定を含む設定
  /// [maxLen] - 時間ステップの最大数
  /// [stepDurationsMs] - 各ステップの継続時間（ミリ秒）の配列
  /// 時間ステップインデックスを返します。無効な場合は-1を返します
  static int getTimeIndexFromPosition(
    double relX,
    double cellWidth,
    SettingsNotifier settings,
    int maxLen,
    List<double> stepDurationsMs,
  ) {
    if (settings.timeUnitIsMs && maxLen > 0) {
      final pos = calculateStepPositions(settings, maxLen, stepDurationsMs);
      for (int i = 0; i < maxLen; i++) {
        final double leftPx = pos[i] * cellWidth;
        final double rightPx = pos[i + 1] * cellWidth;
        if (relX >= leftPx && relX < rightPx) {
          return i;
        }
      }
      return maxLen - 1;
    }
    return (relX / cellWidth).floor();
  }
}
