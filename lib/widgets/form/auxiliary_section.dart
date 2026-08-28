import 'package:flutter/material.dart';

class AuxiliarySection extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<bool> visibilityList;
  final List<TextEditingController> excludeControllers;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onVisibilityChanged;

  const AuxiliarySection({
    super.key,
    required this.controllers,
    required this.visibilityList,
    required this.excludeControllers,
    required this.onAdd,
    required this.onRemove,
    required this.onVisibilityChanged,
  });

  bool _isDuplicate(int index) {
    final name = controllers[index].text.trim();
    if (name.isEmpty) return false;
    for (int i = 0; i < controllers.length; i++) {
      if (i == index) continue;
      if (controllers[i].text.trim() == name) return true;
    }
    for (final other in excludeControllers) {
      if (other.text.trim() == name) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...List.generate(controllers.length, (index) {
          final isDuplicate = _isDuplicate(index);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controllers[index],
                    decoration: InputDecoration(
                      labelText: 'Auxiliary ${index + 1}',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      errorText: isDuplicate ? 'Duplicate name' : null,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Checkbox(
                  value: index < visibilityList.length
                      ? visibilityList[index]
                      : true,
                  onChanged: (_) => onVisibilityChanged(index),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => onRemove(index),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  iconSize: 20,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ),
      ],
    );
  }
}
