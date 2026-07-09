import 'package:flutter/material.dart';
import '../../models/chart/signal_type.dart';
import '../common/suggestion_text_field.dart';
import '../../suggestion_loader.dart';
import 'form_tab_rules.dart';

class InputSection extends StatelessWidget {
  final List<TextEditingController> controllers;
  final int count;
  final List<bool> visibilityList;
  final Function(int) onVisibilityChanged;
  final String triggerOption;
  final bool codeTriggerOnPlcEip;
  final bool isPlcEipChannel;

  const InputSection({
    super.key,
    required this.controllers,
    required this.count,
    required this.visibilityList,
    required this.onVisibilityChanged,
    required this.triggerOption,
    this.codeTriggerOnPlcEip = false,
    this.isPlcEipChannel = false,
  });

  // SignalTypeを取得する関数
  SignalType _getSignalType(int index) {
    return FormTabRules.inferInputSignalType(
      triggerOption: triggerOption,
      inputCount: count,
      index: index,
      codeTriggerOnPlcEip: codeTriggerOnPlcEip,
      isPlcEipChannel: isPlcEipChannel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(count, (index) {
        final signalType = _getSignalType(index);
        final isLocked =
            signalType == SignalType.control ||
            signalType == SignalType.group ||
            signalType == SignalType.task;

        // Control信号の自動命名は外部で行うため、ここでは書き換えない

        return Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Row(
            children: [
              Expanded(
                child:
                    isLocked
                        ? (index < controllers.length
                            ? TextField(
                              controller: controllers[index],
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: 'Input ${index + 1}',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10.0,
                                  vertical: 8.0,
                                ),
                                filled: true,
                                fillColor:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade200,
                                hintText: 'Locked',
                              ),
                            )
                            : const SizedBox.shrink())
                        : (index < controllers.length
                            ? SuggestionTextField(
                              controller: controllers[index],
                              label: 'Input ${index + 1}',
                              loadSuggestions: loadInputSuggestions,
                              excludeControllers: controllers,
                              enableDuplicateCheck: true,
                            )
                            : const SizedBox.shrink()),
              ),
              const SizedBox(width: 6),
              if (!isLocked) // ロックされていない場合のみチェックボックスを表示
                Checkbox(
                  value:
                      index < visibilityList.length
                          ? visibilityList[index]
                          : true,
                  onChanged: (value) {
                    onVisibilityChanged(index);
                  },
                ),
            ],
          ),
        );
      }),
    );
  }
}
