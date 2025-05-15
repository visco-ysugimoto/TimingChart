import 'package:flutter/material.dart';

class HwTriggerSection extends StatelessWidget {
  final List<TextEditingController> controllers;
  final int count;
  final List<bool> visibilityList;
  final Function(int) onVisibilityChanged;

  const HwTriggerSection({
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
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controllers[index],
                  decoration: InputDecoration(
                    labelText: 'HW Trigger ${index + 1}',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 10.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
