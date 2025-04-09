import 'package:flutter/material.dart';
import '../../suggestion_loader.dart';

class SuggestionTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final Future<List<String>> Function() loadSuggestions;

  const SuggestionTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.loadSuggestions,
  });

  @override
  State<SuggestionTextField> createState() => _SuggestionTextFieldState();
}

class _SuggestionTextFieldState extends State<SuggestionTextField> {
  Future<List<String>>? _suggestionsFuture;
  late TextEditingController _internalController;

  @override
  void initState() {
    super.initState();
    _suggestionsFuture = widget.loadSuggestions();
    _internalController = TextEditingController(text: widget.controller.text);
    widget.controller.addListener(_onExternalControllerChanged);
  }

  void _updateSuggestions() {
    if (!mounted) return;
    setState(() {
      _suggestionsFuture = widget.loadSuggestions();
    });
  }

  void _onExternalControllerChanged() {
    if (widget.controller.text.isEmpty && _internalController.text.isNotEmpty) {
      _internalController.text = '';
      setState(() {});
    } else if (widget.controller.text != _internalController.text) {
      _internalController.text = widget.controller.text;
      setState(() {});
    }
  }

  @override
  void dispose() {
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

        return Autocomplete<String>(
          key: ValueKey(widget.controller.hashCode),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return suggestions;
            }
            return suggestions.where((String option) {
              return option.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              );
            });
          },
          onSelected: (String selection) {
            widget.controller.text = selection;
            widget.controller.selection = TextSelection.fromPosition(
              TextPosition(offset: widget.controller.text.length),
            );
          },
          initialValue: TextEditingValue(text: widget.controller.text),
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController fieldTextEditingController,
            FocusNode fieldFocusNode,
            VoidCallback onFieldSubmitted,
          ) {
            if (!fieldFocusNode.hasListeners) {
              fieldFocusNode.addListener(() {
                if (fieldFocusNode.hasFocus) {
                  _updateSuggestions();
                }
              });
            }

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
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    decoration: InputDecoration(
                      labelText: widget.label,
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.transparent,
                    ),
                    onSubmitted: (_) => onFieldSubmitted(),
                    onChanged: (text) {
                      if (widget.controller.text != text) {
                        final previousSelection = widget.controller.selection;
                        widget.controller.text = text;
                        try {
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
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 400,
                    maxHeight: 200,
                  ),
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
