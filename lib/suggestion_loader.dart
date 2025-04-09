import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

Future<List<String>> loadInputSuggestions() async {
  final jsonString = await rootBundle.loadString(
    'assets/input_suggestions.json',
  );
  final Map<String, dynamic> jsonMap = json.decode(jsonString);
  return List<String>.from(jsonMap['suggestions']);
}

Future<List<String>> loadOutputSuggestions() async {
  final jsonString = await rootBundle.loadString(
    'assets/output_suggestions.json',
  );
  final Map<String, dynamic> jsonMap = json.decode(jsonString);
  return List<String>.from(jsonMap['suggestions']);
}
