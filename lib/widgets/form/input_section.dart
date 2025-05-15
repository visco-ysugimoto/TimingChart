import 'package:flutter/material.dart';
import '../../models/chart/signal_type.dart';

class InputSection extends StatelessWidget {
  final List<TextEditingController> controllers;
  final int count;
  final List<bool> visibilityList;
  final Function(int) onVisibilityChanged;
  final String triggerOption;
  final int ioPort;

  const InputSection({
    super.key,
    required this.controllers,
    required this.count,
    required this.visibilityList,
    required this.onVisibilityChanged,
    required this.triggerOption,
    required this.ioPort,
  });

  // SignalTypeを取得する関数
  SignalType _getSignalType(int index) {
    if (triggerOption == 'Code Trigger') {
      if (ioPort >= 32) {
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
      } else if (ioPort == 16) {
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
    if (triggerOption == 'Code Trigger') {
      if (ioPort >= 32) {
        if (index >= 1 && index <= 8) {
          // Input2~9 を Control Code1~8 に変換
          return 'Control Code${index}(bit)';
        }
      } else if (ioPort == 16) {
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

        // Control信号の場合は自動的に名前を設定
        if (signalType == SignalType.control) {
          controllers[index].text = _getControlSignalName(index);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controllers[index],
                  enabled: !isLocked,
                  decoration: InputDecoration(
                    labelText: 'Input ${index + 1}',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 10.0,
                    ),
                    filled: isLocked,
                    fillColor: isLocked ? Colors.grey.shade200 : null,
                    hintText: isLocked ? 'Locked' : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!isLocked) // ロックされていない場合のみチェックボックスを表示
                Checkbox(
                  value: visibilityList[index],
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
