import 'package:flutter/material.dart';

import '../../generated/l10n.dart';
import '../../utils/code_trigger_helpers.dart';

/// 制御コード / グループ / タスクから CODE_OPTION コメント本文を組み立てる。
Future<String?> showCodeOptionCommentDialog({
  required BuildContext context,
  required int inputCount,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _CodeOptionCommentDialog(inputCount: inputCount),
  );
}

class _CodeOptionCommentDialog extends StatefulWidget {
  final int inputCount;

  const _CodeOptionCommentDialog({required this.inputCount});

  @override
  State<_CodeOptionCommentDialog> createState() =>
      _CodeOptionCommentDialogState();
}

class _CodeOptionCommentDialogState extends State<_CodeOptionCommentDialog> {
  late final List<int> _controlCodes;
  late int _controlCode;
  int _group = 0;
  int _task = 0;
  late final TextEditingController _textController;
  late final int _maxGroup;
  late final int _maxTask;

  @override
  void initState() {
    super.initState();
    _controlCodes = CodeTriggerHelpers.availableControlCodes(widget.inputCount);
    _controlCode = _controlCodes.isNotEmpty ? _controlCodes.first : 0;
    _maxGroup = CodeTriggerHelpers.maxGroupNumber(widget.inputCount);
    _maxTask = CodeTriggerHelpers.maxTaskNumber(widget.inputCount);
    _textController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_textController.text.isEmpty) {
      _textController.text = _composeText();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _commandName(S s, int code) {
    switch (code) {
      case 1:
        return s.code_cmd_execute_task;
      case 2:
        return s.code_cmd_execute_system;
      case 3:
        return s.code_cmd_switch_active_task;
      case 4:
        return s.code_cmd_load_task;
      case 5:
        return s.code_cmd_unload_task;
      case 9:
        return s.code_cmd_execute_active_task;
      case 10:
        return s.code_cmd_clear_judgment_counter;
      case 12:
        return s.code_cmd_unload_all_tasks;
      case 34:
        return s.code_cmd_start_lot;
      case 35:
        return s.code_cmd_end_lot;
      case 37:
        return s.code_cmd_start_image_save;
      case 38:
        return s.code_cmd_end_image_save;
      case 39:
        return s.code_cmd_save_image_file;
      case 40:
        return s.code_cmd_edit_lot_settings;
      case 42:
        return s.code_cmd_system_shutdown;
      case 43:
        return s.code_cmd_save_screen_file;
      case 44:
        return s.code_cmd_start_screen_save;
      case 45:
        return s.code_cmd_end_screen_save;
      case 48:
        return s.code_cmd_start_distributed;
      case 49:
        return s.code_cmd_end_distributed;
      default:
        return code.toString();
    }
  }

  String _composeText() {
    final s = S.of(context);
    return CodeTriggerHelpers.formatCodeOptionComment(
      commandName: _commandName(s, _controlCode),
      controlCode: _controlCode,
      group: _group,
      task: _task,
      inputCount: widget.inputCount,
    );
  }

  void _syncTextFromPickers() {
    _textController.text = _composeText();
  }

  CodeControlCommand get _spec =>
      CodeTriggerHelpers.commandSpec(_controlCode);

  bool get _canSubmit {
    final spec = _spec;
    if (spec.requiresGroup && _group <= 0) return false;
    if (spec.requiresTask && _task <= 0) return false;
    return _textController.text.trim().isNotEmpty;
  }

  String? _requirementHint(S s) {
    final spec = _spec;
    final bool missingGroup = spec.requiresGroup && _group <= 0;
    final bool missingTask = spec.requiresTask && _task <= 0;
    if (missingGroup && missingTask) {
      return s.code_comment_group_task_required;
    }
    if (missingGroup) return s.code_comment_group_required;
    if (missingTask) return s.code_comment_task_required;
    return null;
  }

  List<DropdownMenuItem<int>> _numberItems(int max) {
    return [
      for (int n = 1; n <= max; n++)
        DropdownMenuItem<int>(value: n, child: Text('$n')),
    ];
  }

  Widget _numberDropdown({
    required String label,
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      key: ValueKey('$label-$max'),
      initialValue: value > 0 ? value : null,
      isExpanded: true,
      menuMaxHeight: 320,
      hint: Text(S.of(context).code_comment_select),
      items: _numberItems(max),
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.code_comment_title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _controlCode,
                isExpanded: true,
                items: [
                  for (final code in _controlCodes)
                    DropdownMenuItem<int>(
                      value: code,
                      child: Text('${_commandName(s, code)} ($code)'),
                    ),
                ],
                onChanged: _controlCodes.isEmpty
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() {
                          _controlCode = v;
                          final spec = CodeTriggerHelpers.commandSpec(v);
                          if (!spec.requiresGroup) _group = 0;
                          if (!spec.requiresTask) _task = 0;
                          _syncTextFromPickers();
                        });
                      },
                decoration: InputDecoration(
                  labelText: s.code_comment_control,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_spec.requiresGroup) ...[
                _numberDropdown(
                  label: s.code_comment_group,
                  value: _group,
                  max: _maxGroup,
                  onChanged: (v) {
                    setState(() {
                      _group = v;
                      _syncTextFromPickers();
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (_spec.requiresTask) ...[
                _numberDropdown(
                  label: s.code_comment_task,
                  value: _task,
                  max: _maxTask,
                  onChanged: (v) {
                    setState(() {
                      _task = v;
                      _syncTextFromPickers();
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (_requirementHint(s) != null) ...[
                Text(
                  _requirementHint(s)!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                '${s.code_comment_preview}: ${_composeText()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                maxLines: null,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: s.code_comment_body,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.common_cancel),
        ),
        TextButton(
          onPressed: _canSubmit
              ? () {
                  final text = _textController.text.trim();
                  Navigator.pop(context, text);
                }
              : null,
          child: Text(s.common_ok),
        ),
      ],
    );
  }
}
