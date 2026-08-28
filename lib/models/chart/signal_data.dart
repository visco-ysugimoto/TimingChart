import 'signal_type.dart';

class SignalData {
  final String name;
  final SignalType signalType;
  final List<int> values;
  final bool isVisible;
  /// チャート左ラベルに IO 番号プレフィックスを表示するか（グローバル設定が ON のときのみ反映）
  final bool showIoNumber;
  /// 波形・ラベルの個別色（ARGB）。null のときは SignalType の既定色を使う
  final int? colorArgb;

  const SignalData({
    required this.name,
    required this.signalType,
    required this.values,
    this.isVisible = true,
    this.showIoNumber = true,
    this.colorArgb,
  });

  SignalData copyWith({
    String? name,
    SignalType? signalType,
    List<int>? values,
    bool? isVisible,
    bool? showIoNumber,
    int? colorArgb,
    bool clearColorArgb = false,
  }) {
    return SignalData(
      name: name ?? this.name,
      signalType: signalType ?? this.signalType,
      values: values ?? this.values,
      isVisible: isVisible ?? this.isVisible,
      showIoNumber: showIoNumber ?? this.showIoNumber,
      colorArgb: clearColorArgb ? null : (colorArgb ?? this.colorArgb),
    );
  }

  SignalData toggleVisibility() {
    return copyWith(isVisible: !isVisible);
  }
}
