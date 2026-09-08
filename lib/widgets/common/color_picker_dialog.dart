import 'package:flutter/material.dart';

import '../../generated/l10n.dart';

/// プリセットから色を選び、OK で確定するダイアログ。
class ColorPickerDialog {
  ColorPickerDialog._();

  static const List<Color> _basePresets = [
    Colors.white,
    Colors.black,
    Color(0xFF9E9E9E),
    Color(0xFF616161),
    Colors.red,
    Colors.redAccent,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.blueGrey,
  ];

  static Future<Color?> show(
    BuildContext context, {
    String? title,
    required Color initial,
    bool allowTransparent = false,
    bool includeWhite = true,
    List<Color> extraPresets = const [],
  }) {
    return showDialog<Color>(
      context: context,
      builder: (ctx) => _ColorPickerDialogBody(
        title: title ?? S.of(context).color_picker_title,
        initial: initial,
        allowTransparent: allowTransparent,
        includeWhite: includeWhite,
        extraPresets: extraPresets,
      ),
    );
  }
}

class _ColorPickerDialogBody extends StatefulWidget {
  final String title;
  final Color initial;
  final bool allowTransparent;
  final bool includeWhite;
  final List<Color> extraPresets;

  const _ColorPickerDialogBody({
    required this.title,
    required this.initial,
    required this.allowTransparent,
    required this.includeWhite,
    required this.extraPresets,
  });

  @override
  State<_ColorPickerDialogBody> createState() => _ColorPickerDialogBodyState();
}

class _ColorPickerDialogBodyState extends State<_ColorPickerDialogBody> {
  late Color _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  List<Color> get _presets {
    final seen = <int>{};
    final list = <Color>[];
    void add(Color c) {
      final key = c.toARGB32();
      if (seen.add(key)) list.add(c);
    }

    if (widget.allowTransparent) add(Colors.transparent);
    for (final c in ColorPickerDialog._basePresets) {
      if (!widget.includeWhite && c.toARGB32() == Colors.white.toARGB32()) {
        continue;
      }
      add(c);
    }
    for (final c in widget.extraPresets) {
      add(c);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final c in _presets) _swatch(c, scheme)],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('${s.color_picker_selected} '),
                _preview(_selected),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selected.a == 0
                        ? s.color_picker_transparent
                        : '#${_selected.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(s.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(s.common_ok),
        ),
      ],
    );
  }

  Widget _swatch(Color color, ColorScheme scheme) {
    final isTransparent = color.a == 0;
    final isSelected = color.toARGB32() == _selected.toARGB32();
    final checkColor = isTransparent || color.computeLuminance() > 0.55
        ? Colors.black
        : Colors.white;

    return Tooltip(
      message: isTransparent
          ? S.of(context).color_picker_transparent
          : '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
      child: InkWell(
        onTap: () => setState(() => _selected = color),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isTransparent ? Colors.grey.shade200 : color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? scheme.primary : scheme.outlineVariant,
              width: isSelected ? 3 : 1,
            ),
          ),
          child: isTransparent
              ? Text(
                  '∅',
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? scheme.primary : Colors.black54,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                )
              : isSelected
              ? Icon(Icons.check, size: 18, color: checkColor)
              : null,
        ),
      ),
    );
  }

  Widget _preview(Color color) {
    if (color.a == 0) {
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '∅',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
