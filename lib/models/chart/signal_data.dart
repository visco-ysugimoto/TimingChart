import 'signal_type.dart';

class SignalData {
  final String name;
  final SignalType signalType;
  final List<int> values;
  final bool isVisible;
  /// チャート左ラベルに IO 番号プレフィックスを表示するか（グローバル設定が ON のときのみ反映）
  final bool showIoNumber;

  const SignalData({
    required this.name,
    required this.signalType,
    required this.values,
    this.isVisible = true,
    this.showIoNumber = true,
  });

  SignalData copyWith({
    String? name,
    SignalType? signalType,
    List<int>? values,
    bool? isVisible,
    bool? showIoNumber,
  }) {
    return SignalData(
      name: name ?? this.name,
      signalType: signalType ?? this.signalType,
      values: values ?? this.values,
      isVisible: isVisible ?? this.isVisible,
      showIoNumber: showIoNumber ?? this.showIoNumber,
    );
  }

  SignalData toggleVisibility() {
    return copyWith(isVisible: !isVisible);
  }
}
