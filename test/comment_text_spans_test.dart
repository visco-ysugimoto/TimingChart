import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/chart/timing_chart_annotation.dart';
import 'package:flutter_application_1/utils/comment_text_spans.dart';

void main() {
  group('comment color spans', () {
    test('JSONの往復で部分色が維持される', () {
      const original = TimingChartAnnotation(
        id: 'a1',
        startTimeIndex: 0,
        endTimeIndex: 2,
        text: 'Hello World',
        colorSpans: [
          CommentColorSpan(start: 0, end: 5, colorValue: 0xFFFF0000),
          CommentColorSpan(start: 6, end: 11, colorValue: 0xFF0000FF),
        ],
      );

      final decoded = TimingChartAnnotation.fromJson(original.toJson());
      expect(decoded.text, 'Hello World');
      expect(decoded.colorSpans, original.colorSpans);
    });

    test('colorSpans が無い既存JSONは null のまま読める', () {
      final decoded = TimingChartAnnotation.fromJson({
        'id': 'a1',
        'start': 0,
        'end': null,
        'text': 'plain',
      });
      expect(decoded.colorSpans, isNull);
    });

    test('挿入すると後ろの範囲がずれる', () {
      const spans = [
        CommentColorSpan(start: 0, end: 5, colorValue: 0xFFFF0000),
        CommentColorSpan(start: 6, end: 11, colorValue: 0xFF0000FF),
      ];
      final remapped = remapCommentColorSpans(
        spans: spans,
        oldText: 'Hello World',
        newText: 'Hello, World',
      );
      expect(
        remapped,
        const [
          CommentColorSpan(start: 0, end: 5, colorValue: 0xFFFF0000),
          CommentColorSpan(start: 7, end: 12, colorValue: 0xFF0000FF),
        ],
      );
    });

    test('範囲の内側に挿入した文字は同じ色を引き継ぐ', () {
      const spans = [
        CommentColorSpan(start: 0, end: 11, colorValue: 0xFFFF0000),
      ];
      final remapped = remapCommentColorSpans(
        spans: spans,
        oldText: 'Hello World',
        newText: 'Hello, World',
      );
      expect(
        remapped,
        const [CommentColorSpan(start: 0, end: 12, colorValue: 0xFFFF0000)],
      );
    });

    test('削除した範囲に重なる色は切り詰められる', () {
      const spans = [
        CommentColorSpan(start: 0, end: 11, colorValue: 0xFFFF0000),
      ];
      final remapped = remapCommentColorSpans(
        spans: spans,
        oldText: 'Hello World',
        newText: 'Hello',
      );
      expect(
        remapped,
        const [CommentColorSpan(start: 0, end: 5, colorValue: 0xFFFF0000)],
      );
    });

    test('重なる範囲に色を付けると分割・上書きされる', () {
      const existing = [
        CommentColorSpan(start: 0, end: 11, colorValue: 0xFFFF0000),
      ];
      final applied = applyCommentColor(
        existing,
        start: 6,
        end: 11,
        colorValue: 0xFF0000FF,
        textLength: 11,
      );
      expect(
        applied,
        const [
          CommentColorSpan(start: 0, end: 6, colorValue: 0xFFFF0000),
          CommentColorSpan(start: 6, end: 11, colorValue: 0xFF0000FF),
        ],
      );
    });

    test('同じ色の隣接範囲は結合される', () {
      final applied = applyCommentColor(
        const [CommentColorSpan(start: 0, end: 5, colorValue: 0xFFFF0000)],
        start: 5,
        end: 11,
        colorValue: 0xFFFF0000,
        textLength: 11,
      );
      expect(
        applied,
        const [CommentColorSpan(start: 0, end: 11, colorValue: 0xFFFF0000)],
      );
    });

    test('TextSpan の子が色範囲どおりに分かれる', () {
      const text = 'Hello World';
      final span = buildCommentTextSpan(
        text: text,
        baseStyle: const TextStyle(color: Colors.black, fontSize: 14),
        spans: const [
          CommentColorSpan(start: 0, end: 5, colorValue: 0xFFFF0000),
          CommentColorSpan(start: 6, end: 11, colorValue: 0xFF0000FF),
        ],
      );

      expect(span.children, isNotNull);
      expect(span.children, hasLength(3));
      expect((span.children![0] as TextSpan).text, 'Hello');
      expect((span.children![0] as TextSpan).style?.color, const Color(0xFFFF0000));
      expect((span.children![1] as TextSpan).text, ' ');
      expect((span.children![1] as TextSpan).style?.color, isNull);
      expect((span.children![2] as TextSpan).text, 'World');
      expect((span.children![2] as TextSpan).style?.color, const Color(0xFF0000FF));
    });

    test('色範囲が無い場合は単一の TextSpan になる', () {
      final span = buildCommentTextSpan(
        text: 'Hello',
        baseStyle: const TextStyle(color: Colors.black),
      );
      expect(span.text, 'Hello');
      expect(span.children, isNull);
    });
  });
}
