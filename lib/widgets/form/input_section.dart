import 'package:flutter/material.dart';
import '../common/suggestion_text_field.dart';
import '../../suggestion_loader.dart';

class InputSection extends StatefulWidget {
  final List<TextEditingController> controllers;
  final int count;

  const InputSection({
    super.key,
    required this.controllers,
    required this.count,
  });

  @override
  State<InputSection> createState() => _InputSectionState();
}

class _InputSectionState extends State<InputSection> {
  @override
  Widget build(BuildContext context) {
    // 入力項目が0のときはエラーになるのを防ぐ
    if (widget.count <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /*const Text(
          'Input Signals',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),*/
        const SizedBox(height: 8),
        // 具体的な高さを持つContainerで囲むことで、ReorderableListViewのサイズを制限
        SizedBox(
          height: widget.count * 56.0, // 各アイテムの高さ (48) + パディング (8) × アイテム数
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false, // ドラッグハンドルを明示的に制御
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.count,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < 0 ||
                  newIndex < 0 ||
                  oldIndex >= widget.controllers.length ||
                  newIndex >= widget.controllers.length) {
                return; // インデックスが範囲外なら何もしない
              }

              setState(() {
                // Flutterの挙動に合わせてインデックスを調整
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }

                // テキストの値を一時変数に保存
                final String tempValue = widget.controllers[oldIndex].text;

                // 移動元のテキストを移動先のテキストで上書き（値だけを交換）
                widget.controllers[oldIndex].text =
                    widget.controllers[newIndex].text;
                widget.controllers[newIndex].text = tempValue;
              });
            },
            itemBuilder: (context, index) {
              if (index < 0 || index >= widget.controllers.length) {
                return const SizedBox.shrink(); // 安全チェック
              }

              return Padding(
                key: ValueKey('input_$index'),
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    // ドラッグハンドル
                    ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_handle,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // テキストフィールド
                    Expanded(
                      child: SuggestionTextField(
                        label: 'Input ${index + 1}',
                        controller: widget.controllers[index],
                        loadSuggestions: loadInputSuggestions,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
