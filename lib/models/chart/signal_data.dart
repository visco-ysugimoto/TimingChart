import 'signal_type.dart';

class SignalData {
  final String name;
  final SignalType signalType;
  final List<int> values;
  final bool isVisible;

  const SignalData({
    required this.name,
    required this.signalType,
    required this.values,
    this.isVisible = true,
  });

  SignalData copyWith({
    String? name,
    SignalType? signalType,
    List<int>? values,
    bool? isVisible,
  }) {
    return SignalData(
      name: name ?? this.name,
      signalType: signalType ?? this.signalType,
      values: values ?? this.values,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  SignalData toggleVisibility() {
    return copyWith(isVisible: !isVisible);
  }
}
