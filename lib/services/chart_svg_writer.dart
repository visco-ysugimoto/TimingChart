import 'package:flutter/material.dart';

/// SVG 要素を組み立てるユーティリティ。
class ChartSvgWriter {
  final StringBuffer _elements = StringBuffer();
  int _clipId = 0;

  void raw(String svg) => _elements.write(svg);

  void group(void Function() draw, {String? id, String? clipPath}) {
    _elements.write('<g');
    if (id != null) _elements.write(' id="${_escapeAttr(id)}"');
    if (clipPath != null) {
      _elements.write(' clip-path="url(#${_escapeAttr(clipPath)})"');
    }
    _elements.write('>');
    draw();
    _elements.write('</g>');
  }

  String defineClipPath(void Function(ChartSvgWriter w) draw) {
    final id = 'clip-${_clipId++}';
    _elements.write('<clipPath id="${_escapeAttr(id)}">');
    draw(this);
    _elements.write('</clipPath>');
    return id;
  }

  void rect({
    required double x,
    required double y,
    required double width,
    required double height,
    String? fill,
    String? stroke,
    double strokeWidth = 1,
    double? rx,
    double? opacity,
  }) {
    _elements.write('<rect x="${_n(x)}" y="${_n(y)}" width="${_n(width)}" height="${_n(height)}"');
    if (fill != null) _elements.write(' fill="$fill"');
    if (stroke != null) _elements.write(' stroke="$stroke"');
    if (strokeWidth != 1) _elements.write(' stroke-width="${_n(strokeWidth)}"');
    if (rx != null) _elements.write(' rx="${_n(rx)}"');
    if (opacity != null) _elements.write(' opacity="${_n(opacity)}"');
    _elements.write('/>');
  }

  void line({
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required String stroke,
    double strokeWidth = 1,
    double? opacity,
    String? strokeDasharray,
  }) {
    _elements.write(
      '<line x1="${_n(x1)}" y1="${_n(y1)}" x2="${_n(x2)}" y2="${_n(y2)}" '
      'stroke="$stroke" stroke-width="${_n(strokeWidth)}"',
    );
    if (opacity != null) _elements.write(' opacity="${_n(opacity)}"');
    if (strokeDasharray != null) {
      _elements.write(' stroke-dasharray="$strokeDasharray"');
    }
    _elements.write('/>');
  }

  void path({
    required String d,
    String? fill,
    String? stroke,
    double strokeWidth = 1,
    double? opacity,
    String? strokeLinejoin,
    String? strokeLinecap,
  }) {
    _elements.write('<path d="$d"');
    if (fill != null) _elements.write(' fill="$fill"');
    if (stroke != null) _elements.write(' stroke="$stroke"');
    if (strokeWidth != 1) _elements.write(' stroke-width="${_n(strokeWidth)}"');
    if (strokeLinejoin != null) {
      _elements.write(' stroke-linejoin="$strokeLinejoin"');
    }
    if (strokeLinecap != null) {
      _elements.write(' stroke-linecap="$strokeLinecap"');
    }
    if (opacity != null) _elements.write(' opacity="${_n(opacity)}"');
    _elements.write('/>');
  }

  void text({
    required double x,
    required double y,
    required String text,
    String fill = '#000000',
    double fontSize = 14,
    String fontWeight = 'normal',
    String textAnchor = 'start',
    String dominantBaseline = 'auto',
  }) {
    _elements.write(
      '<text x="${_n(x)}" y="${_n(y)}" fill="$fill" font-size="${_n(fontSize)}" '
      'font-weight="$fontWeight" text-anchor="$textAnchor" '
      'dominant-baseline="$dominantBaseline" '
      'font-family="Segoe UI, Yu Gothic UI, Hiragino Sans, sans-serif">'
      '${_escapeText(text)}</text>',
    );
  }

  void tspanGroup({
    required double x,
    required double y,
    required List<({String text, String fill, String fontWeight})> spans,
    double fontSize = 14,
    String textAnchor = 'start',
  }) {
    _elements.write(
      '<text x="${_n(x)}" y="${_n(y)}" font-size="${_n(fontSize)}" '
      'text-anchor="$textAnchor" '
      'font-family="Segoe UI, Yu Gothic UI, Hiragino Sans, sans-serif">',
    );
    for (final span in spans) {
      _elements.write(
        '<tspan fill="${span.fill}" font-weight="${span.fontWeight}">'
        '${_escapeText(span.text)}</tspan>',
      );
    }
    _elements.write('</text>');
  }

  String build({
    required double width,
    required double height,
    required String background,
    required String defs,
  }) {
    return '<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="0 0 ${_n(width)} ${_n(height)}" '
        'width="${_n(width)}" height="${_n(height)}" '
        'role="img" aria-label="Timing chart">'
        '<defs>$defs</defs>'
        '<rect width="100%" height="100%" fill="$background"/>'
        '$_elements'
        '</svg>';
  }

  static String color(Color color, {double? opacity}) {
    final a = opacity != null
        ? (opacity.clamp(0.0, 1.0) * 255).round()
        : (color.a * 255).round();
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    if (a >= 255) {
      return '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}';
    }
    return 'rgba($r,$g,$b,${(a / 255).toStringAsFixed(3)})';
  }

  static String formatCoord(double value) => _n(value);

  static String _n(double value) {
    final rounded = (value * 100).round() / 100;
    if (rounded == rounded.roundToDouble()) {
      return rounded.toStringAsFixed(0);
    }
    return rounded.toStringAsFixed(2);
  }

  static String _escapeText(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  static String _escapeAttr(String text) {
    return _escapeText(text).replaceAll('"', '&quot;');
  }
}
