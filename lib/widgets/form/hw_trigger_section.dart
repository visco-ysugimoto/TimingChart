import 'package:flutter/material.dart';
import '../common/suggestion_text_field.dart';
import '../../suggestion_loader.dart';

class HwTriggerSection extends StatelessWidget {
  final List<TextEditingController> controllers;
  final int count;

  const HwTriggerSection({
    super.key,
    required this.controllers,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /*const Text(
          'HW Trigger Signals',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),*/
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SuggestionTextField(
                label: 'HW Trigger ${index + 1}',
                controller: controllers[index],
                loadSuggestions: loadInputSuggestions, // または専用のサジェストを用意
              ),
            );
          },
        ),
      ],
    );
  }
}
