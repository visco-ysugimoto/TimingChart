import 'package:flutter/material.dart';
import '../../models/chart/signal_type.dart';
import '../common/suggestion_text_field.dart';
import '../../suggestion_loader.dart';

class InputSection extends StatelessWidget {
  final List<TextEditingController> controllers;
  final int count;
  final List<bool> visibilityList;
  final Function(int) onVisibilityChanged;
  final String triggerOption;
  // Inputポート数（総数）
  // これまでは ioPort で保持していたが、Input/Output 分割に伴い count を直接使用
  // final int ioPort; // 削除

  const InputSection({
    super.key,
    required this.controllers,
    required this.count,
    required this.visibilityList,
    required this.onVisibilityChanged,
    required this.triggerOption,
  });

  // SignalTypeを取得する関数
  SignalType _getSignalType(int index) {
    final totalInputs = count;

    if (triggerOption == 'Code Trigger') {
      if (totalInputs >= 32) {
        if (index >= 1 && index <= 8) {
          // Input2~9
          return SignalType.control;
        } else if (index >= 9 && index <= 14) {
          // Input10~15
          return SignalType.group;
        } else if (index >= 15 && index <= 20) {
          // Input16~21
          return SignalType.task;
        }
      } else if (totalInputs == 16) {
        if (index >= 1 && index <= 4) {
          // Input2~5
          return SignalType.control;
        } else if (index >= 5 && index <= 7) {
          // Input6~8
          return SignalType.group;
        } else if (index >= 8 && index <= 13) {
          // Input9~14
          return SignalType.task;
        }
      }
    }
    return SignalType.input;
  }

  // Control信号の名前を取得する関数
  String _getControlSignalName(int index) {
    final totalInputs = count;

    if (triggerOption == 'Code Trigger') {
      if (totalInputs >= 32) {
        if (index >= 1 && index <= 8) {
          // Input2~9 を Control Code1~8 に変換
          return 'Control Code${index}(bit)';
        }
      } else if (totalInputs == 16) {
        if (index >= 1 && index <= 4) {
          // Input2~5 を Control Code1~4 に変換
          return 'Control Code${index}(bit)';
        }
      }
    }
    return 'Input ${index + 1}';
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
