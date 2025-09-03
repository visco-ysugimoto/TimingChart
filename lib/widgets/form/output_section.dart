import 'package:flutter/material.dart';
import '../common/suggestion_text_field.dart';
import '../../suggestion_loader.dart';

class OutputSection extends StatelessWidget {
  final List<TextEditingController> controllers;
  final int count;
  final List<bool> visibilityList;
  final Function(int) onVisibilityChanged;

  const OutputSection({
    super.key,
    required this.controllers,
    required this.count,
    required this.visibilityList,
    required this.onVisibilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(
        count,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Row(
            children: [
              Expanded(
                child: SuggestionTextField(
                  label: 'Output ${index + 1}',
                  controller: controllers[index],
                  loadSuggestions: loadOutputSuggestions,
                  excludeControllers: controllers,
                  enableDuplicateCheck: true,
                ),
              ),
              const SizedBox(width: 6),
              Checkbox(
                value: visibilityList[index],
                onChanged: (value) {
                  onVisibilityChanged(index);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
