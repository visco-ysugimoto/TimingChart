import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/chart/timing_chart_annotation.dart';

/// 範囲を本文長にクリップし、重なりを解消して同じ色の隣接範囲を結合する。
List<CommentColorSpan> normalizeCommentColorSpans(
  Iterable<CommentColorSpan> spans, {
  required int textLength,
}) {
  if (textLength <= 0) return const [];

  final List<CommentColorSpan> clipped = [];
  for (final span in spans) {
    final int start = span.start.clamp(0, textLength);
    final int end = span.end.clamp(0, textLength);
    if (end > start) {
      clipped.add(
        CommentColorSpan(start: start, end: end, colorValue: span.colorValue),
      );
    }
  }
  if (clipped.isEmpty) return const [];

  clipped.sort((a, b) {
    final int byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : a.end.compareTo(b.end);
  });

  final List<CommentColorSpan> resolved = [];
  for (final span in clipped) {
    if (resolved.isEmpty) {
      resolved.add(span);
      continue;
    }
    final CommentColorSpan last = resolved.last;
    if (span.start >= last.end) {
      resolved.add(span);
      continue;
    }
    if (span.colorValue == last.colorValue) {
      resolved[resolved.length - 1] = CommentColorSpan(
        start: last.start,
        end: math.max(last.end, span.end),
        colorValue: last.colorValue,
      );
      continue;
    }
    if (span.start > last.start) {
      resolved[resolved.length - 1] = CommentColorSpan(
        start: last.start,
        end: span.start,
        colorValue: last.colorValue,
      );
      resolved.add(span);
      if (last.end > span.end) {
        resolved.add(
          CommentColorSpan(
            start: span.end,
            end: last.end,
            colorValue: last.colorValue,
          ),
        );
      }
    } else {
      resolved.removeLast();
      resolved.add(span);
      if (last.end > span.end) {
        resolved.add(
          CommentColorSpan(
            start: span.end,
            end: last.end,
            colorValue: last.colorValue,
          ),
        );
      }
    }
  }

  if (resolved.isEmpty) return const [];
  final List<CommentColorSpan> merged = [resolved.first];
  for (int i = 1; i < resolved.length; i++) {
    final CommentColorSpan prev = merged.last;
    final CommentColorSpan current = resolved[i];
    if (current.start <= prev.end && current.colorValue == prev.colorValue) {
      merged[merged.length - 1] = CommentColorSpan(
        start: prev.start,
        end: math.max(prev.end, current.end),
        colorValue: prev.colorValue,
      );
    } else {
      merged.add(current);
    }
  }
  return merged;
}

List<CommentColorSpan> subtractCommentColorRange(
  Iterable<CommentColorSpan> spans, {
  required int start,
  required int end,
}) {
  if (end <= start) return List<CommentColorSpan>.from(spans);
  final List<CommentColorSpan> result = [];
  for (final span in spans) {
    if (span.end <= start || span.start >= end) {
      result.add(span);
      continue;
    }
    if (span.start < start) {
      result.add(
        CommentColorSpan(
          start: span.start,
          end: start,
          colorValue: span.colorValue,
        ),
      );
    }
    if (span.end > end) {
      result.add(
        CommentColorSpan(
          start: end,
          end: span.end,
          colorValue: span.colorValue,
        ),
      );
    }
  }
  return result;
}

List<CommentColorSpan> applyCommentColor(
  Iterable<CommentColorSpan> spans, {
  required int start,
  required int end,
  required int colorValue,
  required int textLength,
}) {
  if (end <= start) {
    return normalizeCommentColorSpans(spans, textLength: textLength);
  }
  return normalizeCommentColorSpans(
    [
      ...subtractCommentColorRange(spans, start: start, end: end),
      CommentColorSpan(start: start, end: end, colorValue: colorValue),
    ],
    textLength: textLength,
  );
}

List<CommentColorSpan> clearCommentColorRange(
  Iterable<CommentColorSpan> spans, {
  required int start,
  required int end,
  required int textLength,
}) {
  return normalizeCommentColorSpans(
    subtractCommentColorRange(spans, start: start, end: end),
    textLength: textLength,
  );
}

List<CommentColorSpan> remapCommentColorSpans({
  required Iterable<CommentColorSpan> spans,
  required String oldText,
  required String newText,
}) {
  if (oldText == newText) {
    return normalizeCommentColorSpans(spans, textLength: newText.length);
  }

  final int prefix = _commonPrefixLength(oldText, newText);
  final int suffix = _commonSuffixLength(oldText, newText, prefix);
  final int oldReplaceStart = prefix;
  final int oldReplaceEnd = oldText.length - suffix;
  final int delta = newText.length - oldText.length;
  final List<CommentColorSpan> result = [];

  for (final span in spans) {
    if (span.end <= oldReplaceStart) {
      result.add(span);
      continue;
    }
    if (span.start >= oldReplaceEnd) {
      result.add(
        CommentColorSpan(
          start: span.start + delta,
          end: span.end + delta,
          colorValue: span.colorValue,
        ),
      );
      continue;
    }
    if (span.start <= oldReplaceStart && span.end >= oldReplaceEnd) {
      result.add(
        CommentColorSpan(
          start: span.start,
          end: span.end + delta,
          colorValue: span.colorValue,
        ),
      );
      continue;
    }
    if (span.start < oldReplaceStart) {
      result.add(
        CommentColorSpan(
          start: span.start,
          end: oldReplaceStart,
          colorValue: span.colorValue,
        ),
      );
    }
    if (span.end > oldReplaceEnd) {
      result.add(
        CommentColorSpan(
          start: oldReplaceEnd + delta,
          end: span.end + delta,
          colorValue: span.colorValue,
        ),
      );
    }
  }

  return normalizeCommentColorSpans(result, textLength: newText.length);
}

TextSpan buildCommentTextSpan({
  required String text,
  required TextStyle baseStyle,
  List<CommentColorSpan>? spans,
  TextRange? composing,
}) {
  final List<CommentColorSpan> normalized = normalizeCommentColorSpans(
    spans ?? const [],
    textLength: text.length,
  );
  final bool hasComposing =
      composing != null &&
      composing.isValid &&
      composing.start >= 0 &&
      composing.end <= text.length &&
      composing.end > composing.start;

  if (text.isEmpty) {
    return TextSpan(text: '', style: baseStyle);
  }
  if (normalized.isEmpty && !hasComposing) {
    return TextSpan(text: text, style: baseStyle);
  }

  final Set<int> cuts = {0, text.length};
  for (final span in normalized) {
    cuts.add(span.start);
    cuts.add(span.end);
  }
  if (hasComposing) {
    cuts.add(composing.start);
    cuts.add(composing.end);
  }
  final List<int> points = cuts.toList()..sort();

  Color? colorAt(int index) {
    for (final span in normalized) {
      if (index >= span.start && index < span.end) {
        return Color(span.colorValue);
      }
    }
    return null;
  }

  final List<TextSpan> children = [];
  for (int i = 0; i < points.length - 1; i++) {
    final int start = points[i];
    final int end = points[i + 1];
    if (end <= start) continue;
    final bool inComposing =
        hasComposing && start >= composing.start && end <= composing.end;
    children.add(
      TextSpan(
        text: text.substring(start, end),
        style: TextStyle(
          color: colorAt(start),
          decoration: inComposing ? TextDecoration.underline : null,
        ),
      ),
    );
  }

  return TextSpan(style: baseStyle, children: children);
}

class ColoredCommentTextEditingController extends TextEditingController {
  ColoredCommentTextEditingController({
    super.text,
    List<CommentColorSpan>? colorSpans,
    this.baseColor = Colors.black,
  }) : colorSpans = normalizeCommentColorSpans(
         colorSpans ?? const [],
         textLength: text?.length ?? 0,
       ),
       _lastText = text ?? '';

  List<CommentColorSpan> colorSpans;
  Color baseColor;
  String _lastText;

  bool get hasSelection =>
      selection.isValid && !selection.isCollapsed && text.isNotEmpty;

  @override
  set value(TextEditingValue newValue) {
    if (newValue.text != _lastText) {
      colorSpans = remapCommentColorSpans(
        spans: colorSpans,
        oldText: _lastText,
        newText: newValue.text,
      );
      _lastText = newValue.text;
    }
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final TextStyle base = (style ?? const TextStyle()).copyWith(
      color: baseColor,
    );
    final TextRange? composing =
        withComposing && value.isComposingRangeValid ? value.composing : null;
    return buildCommentTextSpan(
      text: text,
      baseStyle: base,
      spans: colorSpans,
      composing: composing,
    );
  }

  void applyColorToSelection(int colorValue) {
    if (!hasSelection) return;
    final int start = math.min(selection.start, selection.end);
    final int end = math.max(selection.start, selection.end);
    colorSpans = applyCommentColor(
      colorSpans,
      start: start,
      end: end,
      colorValue: colorValue,
      textLength: text.length,
    );
    notifyListeners();
  }

  void clearColorFromSelection() {
    if (!hasSelection) return;
    final int start = math.min(selection.start, selection.end);
    final int end = math.max(selection.start, selection.end);
    colorSpans = clearCommentColorRange(
      colorSpans,
      start: start,
      end: end,
      textLength: text.length,
    );
    notifyListeners();
  }
}

int _commonPrefixLength(String a, String b) {
  final int maxLen = math.min(a.length, b.length);
  int i = 0;
  while (i < maxLen && a.codeUnitAt(i) == b.codeUnitAt(i)) {
    i++;
  }
  return i;
}

int _commonSuffixLength(String a, String b, int prefix) {
  final int maxLen = math.min(a.length - prefix, b.length - prefix);
  int i = 0;
  while (i < maxLen &&
      a.codeUnitAt(a.length - 1 - i) == b.codeUnitAt(b.length - 1 - i)) {
    i++;
  }
  return i;
}
