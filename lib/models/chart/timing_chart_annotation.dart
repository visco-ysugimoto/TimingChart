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
  // コメントボックスから水平に矢印を引くかどうか（trueで水平、null/falseで通常）
  final bool? arrowHorizontal;

  const TimingChartAnnotation({
    required this.id,
    required this.startTimeIndex,
    required this.endTimeIndex,
    required this.text,
    this.offsetX,
    this.offsetY,
    this.arrowTipY,
    this.arrowHorizontal,
  });

  TimingChartAnnotation copyWith({
    String? id,
    int? startTimeIndex,
    int? endTimeIndex,
    String? text,
    double? offsetX,
    double? offsetY,
    double? arrowTipY,
    bool? arrowHorizontal,
  }) {
    return TimingChartAnnotation(
      id: id ?? this.id,
      startTimeIndex: startTimeIndex ?? this.startTimeIndex,
      endTimeIndex: endTimeIndex ?? this.endTimeIndex,
      text: text ?? this.text,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      arrowTipY: arrowTipY ?? this.arrowTipY,
      arrowHorizontal: arrowHorizontal ?? this.arrowHorizontal,
    );
  }
}
