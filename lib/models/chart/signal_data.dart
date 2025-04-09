import 'package:flutter/material.dart';

class SignalData {
  final String name;
  final Color color;
  final List<int> values;

  const SignalData({
    required this.name,
    required this.color,
    required this.values,
  });

  SignalData copyWith({String? name, Color? color, List<int>? values}) {
    return SignalData(
      name: name ?? this.name,
      color: color ?? this.color,
      values: values ?? this.values,
    );
  }
}
