class TimingChartAnnotation {
  final String id;
  final int startTimeIndex;
  final int? endTimeIndex;
  final String text;
  // ユーザーがコメントボックスを任意移動できるようにするためのオフセット（px）
  final double? offsetX;
  final double? offsetY;
  // 矢印先端のY座標（チャートローカル座標, marginTop基準）。nullならデフォルト（上端）
  final double? arrowTipY;
  // 矢印先端を「どの行に向けるか」（表示行インデックス）。cellHeight変動に強い。
  // arrowTipY よりこちらを優先して描画する（後方互換のため arrowTipY も残す）。
  final int? arrowTipRowIndex;
  // コメントボックスから水平に矢印を引くかどうか（trueで水平、null/falseで通常）
  final bool? arrowHorizontal;
  // --- コメントボックスの見た目（個別設定） ---
  // フォントサイズ（px相当）。nullの場合は描画側のデフォルト値を使う。
  final double? fontSize;
  // 太字にするかどうか。nullの場合はfalse扱い（通常）。
  final bool? isBold;
  // 罫線（枠線）の色（ARGB int）。nullの場合は描画側のデフォルト値を使う。
  // alpha が 0 の場合は枠線を描画しない。
  final int? borderColorValue;
  // コメントボックスの背景色（ARGB int）。nullの場合は描画側のデフォルト値を使う。
  // alpha が 0 の場合は背景を描画しない。
  final int? backgroundColorValue;
  // コメントテキストの色（ARGB int）。nullの場合は描画側のデフォルト値を使う。
  final int? textColorValue;
  // 時刻を指す破線（境界線）の色（ARGB int）。nullの場合は描画側のデフォルト値を使う。
  final int? dashedLineColorValue;
  // 矢印の色（ARGB int）。nullの場合は描画側のデフォルト値を使う。
  final int? arrowColorValue;
  // テキストの折り返し幅（px）。nullの場合は描画側のデフォルト値（120）を使う。
  final double? maxWidth;
  // テキストの最大行数。nullまたは0以下の場合は無制限扱い。
  final int? maxLines;
  // 行数制限時に省略記号（...）を表示するか。nullの場合はtrue扱い。
  final bool? ellipsisEnabled;
  // コメントボックスの配置位置。'top'=チャート上部、null/'bottom'=チャート下部（既定）。
  final String? placement;

  const TimingChartAnnotation({
    required this.id,
    required this.startTimeIndex,
    required this.endTimeIndex,
    required this.text,
    this.offsetX,
    this.offsetY,
    this.arrowTipY,
    this.arrowTipRowIndex,
    this.arrowHorizontal,
    this.fontSize,
    this.isBold,
    this.borderColorValue,
    this.backgroundColorValue,
    this.textColorValue,
    this.dashedLineColorValue,
    this.arrowColorValue,
    this.maxWidth,
    this.maxLines,
    this.ellipsisEnabled,
    this.placement,
  });

  TimingChartAnnotation copyWith({
    String? id,
    int? startTimeIndex,
    int? endTimeIndex,
    String? text,
    double? offsetX,
    double? offsetY,
    double? arrowTipY,
    int? arrowTipRowIndex,
    bool? arrowHorizontal,
    double? fontSize,
    bool? isBold,
    int? borderColorValue,
    int? backgroundColorValue,
    int? textColorValue,
    int? dashedLineColorValue,
    int? arrowColorValue,
    double? maxWidth,
    int? maxLines,
    bool? ellipsisEnabled,
    String? placement,
  }) {
    return TimingChartAnnotation(
      id: id ?? this.id,
      startTimeIndex: startTimeIndex ?? this.startTimeIndex,
      endTimeIndex: endTimeIndex ?? this.endTimeIndex,
      text: text ?? this.text,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      arrowTipY: arrowTipY ?? this.arrowTipY,
      arrowTipRowIndex: arrowTipRowIndex ?? this.arrowTipRowIndex,
      arrowHorizontal: arrowHorizontal ?? this.arrowHorizontal,
      fontSize: fontSize ?? this.fontSize,
      isBold: isBold ?? this.isBold,
      borderColorValue: borderColorValue ?? this.borderColorValue,
      backgroundColorValue:
          backgroundColorValue ?? this.backgroundColorValue,
      textColorValue: textColorValue ?? this.textColorValue,
      dashedLineColorValue: dashedLineColorValue ?? this.dashedLineColorValue,
      arrowColorValue: arrowColorValue ?? this.arrowColorValue,
      maxWidth: maxWidth ?? this.maxWidth,
      maxLines: maxLines ?? this.maxLines,
      ellipsisEnabled: ellipsisEnabled ?? this.ellipsisEnabled,
      placement: placement ?? this.placement,
    );
  }
}
