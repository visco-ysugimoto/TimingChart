import 'package:flutter/material.dart';
import '../../suggestion_loader.dart';

class SuggestionTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final Future<List<SuggestionItem>> Function() loadSuggestions;
  final List<TextEditingController>? excludeControllers; // 重複チェック用
  final bool enableDuplicateCheck; // 重複チェックを有効にするかどうか

  const SuggestionTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.loadSuggestions,
    this.excludeControllers,
    this.enableDuplicateCheck = false,
  });

  @override
  State<SuggestionTextField> createState() => _SuggestionTextFieldState();
}

class _SuggestionTextFieldState extends State<SuggestionTextField> {
  Future<List<SuggestionItem>>? _suggestionsFuture;
  late TextEditingController _internalController;
  TextEditingController? _fieldController;
  VoidCallback? _syncListener;
  List<SuggestionItem> _latestItems = [];
  late final VoidCallback _langListener;
  FocusNode? _attachedFocusNode;

  @override
  void initState() {
    super.initState();
    _updateSuggestions(translateCurrent: true);
    _internalController = TextEditingController(
      text: _idToLabel(widget.controller.text),
    );
    widget.controller.addListener(_onExternalControllerChanged);

    // 他のコントローラーの変更を監視
    if (widget.enableDuplicateCheck && widget.excludeControllers != null) {
      for (var controller in widget.excludeControllers!) {
        if (controller != widget.controller) {
          controller.addListener(_onOtherControllerChanged);
        }
      }
    }

    // 言語変更時に候補を更新
    _langListener = () {
      _updateSuggestions(translateCurrent: true);
    };
    suggestionLanguageVersion.addListener(_langListener);
  }

  void _onOtherControllerChanged() {
    if (mounted) {
      setState(() {
        // 他のコントローラーが変更されたときに重複チェックを更新
      });
    }
  }

  void _updateSuggestions({bool translateCurrent = false}) {
    if (!mounted) return;
    setState(() {
      _suggestionsFuture = widget.loadSuggestions();
    });

    if (translateCurrent) {
      // After future completes, translate current text
      _suggestionsFuture?.then((items) {
        if (!mounted) return;
        _latestItems = items;
        final newLabel = _idToLabel(widget.controller.text);
        if (_internalController.text != newLabel) {
          setState(() {
            _internalController.text = newLabel;
            _fieldController?.text = newLabel;
          });
        }
      });
    }
  }

  void _onExternalControllerChanged() {
    final newLabel = _idToLabel(widget.controller.text);
    if (widget.controller.text.isEmpty && _internalController.text.isNotEmpty) {
      _internalController.text = '';
    } else if (_internalController.text != newLabel) {
      _internalController.text = newLabel;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalControllerChanged);

    // 他のコントローラーのリスナーを削除
    if (widget.enableDuplicateCheck && widget.excludeControllers != null) {
      for (var controller in widget.excludeControllers!) {
        if (controller != widget.controller) {
          controller.removeListener(_onOtherControllerChanged);
        }
      }
    }

    _detachSyncListener();
    if (_attachedFocusNode != null) {
      _attachedFocusNode!.removeListener(_onFocusChange);
      _attachedFocusNode = null;
    }
    _internalController.dispose();
    suggestionLanguageVersion.removeListener(_langListener);
    super.dispose();
  }

  // 同じ種類のコントローラーで使用されている値を取得
  Set<String> _getUsedValues() {
    if (!widget.enableDuplicateCheck || widget.excludeControllers == null) {
      return <String>{};
    }

    Set<String> usedValues = {};
    for (var controller in widget.excludeControllers!) {
      if (controller != widget.controller && controller.text.isNotEmpty) {
        usedValues.add(controller.text);
      }
    }

    // デバッグログ
    print('重複チェック - 使用済み値: $usedValues');
    return usedValues;
  }

  // 候補リストから使用済みの値を除外
  List<SuggestionItem> _filterSuggestions(List<SuggestionItem> suggestions) {
    if (!widget.enableDuplicateCheck) {
      return suggestions;
    }

    final usedValues = _getUsedValues();
    final filtered =
        suggestions.where((item) => !usedValues.contains(item.id)).toList();

    // デバッグログ
    print(
      '候補フィルタリング - 元の候補数: ${suggestions.length}, フィルタ後: ${filtered.length}',
    );
    print(
      '除外された候補: ${suggestions.where((item) => usedValues.contains(item.id)).map((e) => e.label).toList()}',
    );

    return filtered;
  }

  // 重複チェック（labelをidに変換してから比較）
  bool _isDuplicate(String labelValue) {
    if (!widget.enableDuplicateCheck || labelValue.isEmpty) {
      return false;
    }

    // 入力されたlabelをidに変換
    final inputId = _labelToId(labelValue);
    final usedValues = _getUsedValues();
    final isDuplicate = usedValues.contains(inputId);

    // デバッグログ
    print('重複チェック - 入力: "$labelValue", ID: "$inputId", 重複: $isDuplicate');

    return isDuplicate;
  }

  // labelからidを取得するヘルパーメソッド
  String _labelToId(String label) {
    final hit = _latestItems.firstWhere(
      (e) => e.label == label,
      orElse: () => SuggestionItem(label, label),
    );
    return hit.id;
  }

  void _attachSyncListener(TextEditingController fieldCtrl) {
    if (_fieldController == fieldCtrl) return;

    _detachSyncListener();

    _fieldController = fieldCtrl;
    _syncListener = () {
      if (!mounted) return;
      final newLabel = _idToLabel(widget.controller.text);
      if (_fieldController!.text != newLabel) {
        _fieldController!.text = newLabel;
      }
    };

    widget.controller.addListener(_syncListener!);
  }

  void _detachSyncListener() {
    if (_fieldController != null && _syncListener != null) {
      widget.controller.removeListener(_syncListener!);
      _syncListener = null;
      _fieldController = null;
    }
  }

  void _onFocusChange() {
    if (_attachedFocusNode != null && _attachedFocusNode!.hasFocus) {
      _updateSuggestions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SuggestionItem>>(
      future: _suggestionsFuture,
      builder: (context, snapshot) {
        List<SuggestionItem> suggestions = snapshot.data ?? [];
        _latestItems = suggestions;

        // 重複チェックが有効な場合は候補をフィルタリング
        List<SuggestionItem> filteredSuggestions = _filterSuggestions(
          suggestions,
        );

        return Autocomplete<SuggestionItem>(
          key: ValueKey(
            '${widget.controller.hashCode}-${suggestionLanguageVersion.value}',
          ),
          displayStringForOption: (item) => item.label,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return filteredSuggestions;
            }
            return filteredSuggestions.where(
              (item) => item.label.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              ),
            );
          },
          onSelected: (SuggestionItem selection) {
            widget.controller.text = selection.id;
            widget.controller.selection = TextSelection.fromPosition(
              TextPosition(offset: widget.controller.text.length),
            );
            _internalController.text = selection.label;
          },
          initialValue: TextEditingValue(
            text: _idToLabel(widget.controller.text),
          ),
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController fieldTextEditingController,
            FocusNode fieldFocusNode,
            VoidCallback onFieldSubmitted,
          ) {
            if (_attachedFocusNode != fieldFocusNode) {
              if (_attachedFocusNode != null) {
                _attachedFocusNode!.removeListener(_onFocusChange);
              }
              _attachedFocusNode = fieldFocusNode;
              _attachedFocusNode!.addListener(_onFocusChange);
            }

            _attachSyncListener(fieldTextEditingController);

            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: fieldTextEditingController,
              builder: (context, value, child) {
                // 重複チェック
                bool isDuplicate = _isDuplicate(value.text);

                final bool isDark =
                    Theme.of(context).brightness == Brightness.dark;

                // デフォルトの塗りつぶし色（テーマ優先）
                final defaultFill =
                    Theme.of(context).inputDecorationTheme.fillColor ??
                    (isDark ? Colors.grey.shade800 : Colors.white);

                // 値が入力されている／重複している場合のハイライト色を決定
                Color backgroundColor;
                if (isDuplicate) {
                  backgroundColor =
                      isDark
                          ? Colors.red.withOpacity(0.35)
                          : Colors.red.withOpacity(0.2);
                } else if (value.text.isNotEmpty) {
                  // アクセントカラーを利用して入力済みをハイライト
                  final accent = Theme.of(context).colorScheme.secondary;
                  backgroundColor = accent.withOpacity(isDark ? 0.35 : 0.2);
                } else {
                  backgroundColor = defaultFill;
                }

                return Container(
                  color: backgroundColor,
                  child: TextField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    decoration: InputDecoration(
                      labelText: widget.label,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 8.0,
                      ),
                      filled: true,
                      // テキストフィールド本体の塗りつぶし色にも同じ色を適用
                      fillColor: backgroundColor,
                      errorText: isDuplicate ? '重複した値です' : null,
                    ),
                    onSubmitted: (_) => onFieldSubmitted(),
                    onChanged: (text) {
                      if (widget.controller.text == text) return;

                      // 重複チェック
                      if (widget.enableDuplicateCheck && _isDuplicate(text)) {
                        // 重複している場合は元の候補から検索（フィルタリング前）
                        final matched = _latestItems.firstWhere(
                          (e) => e.label == text,
                          orElse: () => SuggestionItem(text, text),
                        );
                        widget.controller.text = matched.id;
                        return;
                      }

                      // 入力が候補の label と一致する場合は id を保存
                      final matched = _latestItems.firstWhere(
                        (e) => e.label == text,
                        orElse: () => SuggestionItem(text, text),
                      );
                      widget.controller.text = matched.id;
                    },
                  ),
                );
              },
            );
          },
          optionsViewBuilder: (
            BuildContext context,
            AutocompleteOnSelected<SuggestionItem> onSelected,
            Iterable<SuggestionItem> options,
          ) {
            const double itemExtent = 36.0; // 候補1件あたりの高さ（コンパクト）
            final double maxHeight = itemExtent * 5; // 5件表示分の高さ
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 400,
                    maxHeight: maxHeight,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemExtent: itemExtent,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final SuggestionItem option = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                        },
                        child: Builder(
                          builder: (BuildContext context) {
                            final bool highlight =
                                AutocompleteHighlightedOption.of(context) ==
                                index;
                            return Container(
                              color:
                                  highlight
                                      ? Theme.of(context).focusColor
                                      : null,
                              padding: const EdgeInsets.symmetric(
                                vertical: 6.0,
                                horizontal: 12.0,
                              ),
                              child: Text(option.label),
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

  String _idToLabel(String id) {
    // 元の候補リストから検索（フィルタリング前）
    final hit = _latestItems.firstWhere(
      (e) => e.id == id,
      orElse: () => SuggestionItem(id, id),
    );
    return hit.label;
  }
}
