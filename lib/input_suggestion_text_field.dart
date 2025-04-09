import 'package:flutter/material.dart';
import 'suggestion_loader.dart'; // パスは環境に合わせてください

// ★ StatefulWidgetに変更する (内部状態やライフサイクル管理のため、必要に応じて)
class AsyncInputSuggestionTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller; // 親から渡されるコントローラー

  const AsyncInputSuggestionTextField({
    super.key,
    required this.label,
    required this.controller,
  });

  @override
  State<AsyncInputSuggestionTextField> createState() =>
      _AsyncInputSuggestionTextFieldState();
}

class _AsyncInputSuggestionTextFieldState
    extends State<AsyncInputSuggestionTextField> {
  Future<List<String>>? _suggestionsFuture;
  late TextEditingController _internalController;

  @override
  void initState() {
    super.initState();
    _suggestionsFuture = loadInputSuggestions();
    // 内部コントローラーを初期化
    _internalController = TextEditingController(text: widget.controller.text);

    // 外部コントローラーの変更を監視
    widget.controller.addListener(_onExternalControllerChanged);
  }

  @override
  void didUpdateWidget(AsyncInputSuggestionTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // コントローラーが変わった場合、リスナーを更新
    if (widget.controller != oldWidget.controller) {
      // 古いリスナーを削除
      oldWidget.controller.removeListener(_onExternalControllerChanged);

      // 新しいコントローラーの値で内部コントローラーを更新
      _internalController.text = widget.controller.text;

      // 新しいリスナーを追加
      widget.controller.addListener(_onExternalControllerChanged);
    }
  }

  // 外部コントローラーが変更されたときに内部のコントローラーも更新
  void _onExternalControllerChanged() {
    // 外部コントローラーのテキストが空になったら内部も空にする
    if (widget.controller.text.isEmpty && _internalController.text.isNotEmpty) {
      _internalController.text = '';
      // ここで強制的に更新して確実に変更が反映されるようにする
      setState(() {});
    }
    // 外部コントローラーの値が内部と異なる場合も同期
    else if (widget.controller.text != _internalController.text) {
      _internalController.text = widget.controller.text;
      // ここで強制的に更新して確実に変更が反映されるようにする
      setState(() {});
    }
  }

  // サジェストを更新するメソッドを追加
  void _updateSuggestions() {
    if (!mounted) return;
    setState(() {
      _suggestionsFuture = loadInputSuggestions();
    });
  }

  @override
  void dispose() {
    // リスナーを削除してメモリリークを防止
    widget.controller.removeListener(_onExternalControllerChanged);
    _internalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _suggestionsFuture,
      builder: (context, snapshot) {
        List<String> suggestions = [];
        if (snapshot.hasData) {
          suggestions = snapshot.data!;
        }
        // 必要ならローディングやエラー表示を追加

        return Autocomplete<String>(
          // ★ Keyを設定: コントローラーインスタンスのみをキーとして使用
          key: ValueKey(widget.controller.hashCode),

          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              // 空の場合は候補を空にするか、全て表示するか選択
              // return const Iterable<String>.empty();
              return suggestions; // 例: 空なら全候補表示
            }
            // 入力内容に基づいて候補をフィルタリング
            return suggestions.where((String option) {
              return option.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              );
            });
          },

          // ★ onSelected: 候補が選択されたときに外部コントローラーを更新
          onSelected: (String selection) {
            widget.controller.text = selection;
            // 必要ならカーソル位置なども調整
            widget.controller.selection = TextSelection.fromPosition(
              TextPosition(offset: widget.controller.text.length),
            );
          },

          // ★ initialValue: Autocompleteの内部コントローラーを外部コントローラーの現在の値で初期化
          initialValue: TextEditingValue(text: widget.controller.text),

          fieldViewBuilder: (
            BuildContext context,
            TextEditingController fieldTextEditingController,
            FocusNode fieldFocusNode,
            VoidCallback onFieldSubmitted,
          ) {
            // フォーカスノードにリスナーを追加（初回のみ）
            if (!fieldFocusNode.hasListeners) {
              fieldFocusNode.addListener(() {
                if (fieldFocusNode.hasFocus) {
                  _updateSuggestions();
                }
              });
            }

            // 外部コントローラーの変更を監視して内部コントローラーを更新
            widget.controller.addListener(() {
              if (fieldTextEditingController.text != widget.controller.text) {
                fieldTextEditingController.text = widget.controller.text;
              }
            });

            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: fieldTextEditingController,
              builder: (context, value, child) {
                return Container(
                  color:
                      value.text.isNotEmpty
                          ? Colors.lightBlueAccent.withOpacity(0.2)
                          : Colors.white,
                  child: TextField(
                    controller:
                        fieldTextEditingController, // ★ Autocompleteが提供するコントローラーを使用
                    focusNode: fieldFocusNode,
                    decoration: InputDecoration(
                      labelText: widget.label,
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.transparent,
                    ),
                    onSubmitted: (_) => onFieldSubmitted(),

                    // ★ onChanged: TextFieldの内容が変更されたときに外部コントローラーも更新
                    onChanged: (text) {
                      // onSelectedでの更新と重複してループしないように、値が変わった時だけ更新
                      if (widget.controller.text != text) {
                        // widget.controller.text = text; // 直接代入ではなく、カーソル位置を考慮するなら以下
                        // カーソル位置を保持しつつテキストを更新 (より安全)
                        final previousSelection = widget.controller.selection;
                        widget.controller.text = text;
                        try {
                          // カーソル位置がテキスト長を超える場合は末尾に設定
                          widget.controller.selection = previousSelection
                              .copyWith(
                                baseOffset: previousSelection.baseOffset.clamp(
                                  0,
                                  text.length,
                                ),
                                extentOffset: previousSelection.extentOffset
                                    .clamp(0, text.length),
                              );
                        } catch (e) {
                          // selection範囲がおかしくなった場合のエラーハンドリング (例: 末尾に設定)
                          widget
                              .controller
                              .selection = TextSelection.fromPosition(
                            TextPosition(offset: text.length),
                          );
                        }
                      }
                    },
                  ),
                );
              },
            );
          },

          optionsViewBuilder: (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            // サジェストリストのUIを構築 (元のコードと同様のはず)
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 400,
                    maxHeight: 200,
                  ), // 最大高さを制限
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                        },
                        child: Builder(
                          builder: (BuildContext context) {
                            final bool highlight =
                                AutocompleteHighlightedOption.of(context) ==
                                index;
                            if (highlight) {
                              // SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
                              //   Scrollable.ensureVisible(context, alignment: 0.5);
                              // });
                            }
                            return Container(
                              color:
                                  highlight
                                      ? Theme.of(context).focusColor
                                      : null,
                              padding: const EdgeInsets.all(16.0),
                              child: Text(option),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
