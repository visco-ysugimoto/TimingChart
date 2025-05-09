import 'package:flutter/material.dart';
import 'signal_type.dart';

class SignalData {
  final String name;
  final SignalType signalType;
  final List<int> values;

  const SignalData({
    required this.name,
    required this.signalType,
    required this.values,
  });

  SignalData copyWith({
    String? name,
    SignalType? signalType,
    List<int>? values,
  }) {
    return SignalData(
      name: name ?? this.name,
      signalType: signalType ?? this.signalType,
      values: values ?? this.values,
    );
  }
}
