import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/chart/signal_type.dart';
import 'package:flutter_application_1/models/chart/timing_chart_annotation.dart';
import 'package:flutter_application_1/services/chart_svg_builder.dart';
import 'package:flutter_application_1/services/chart_svg_export_data.dart';

void main() {
  group('ChartSvgBuilder', () {
    test('波形とラベルを含む SVG を生成する', () {
      const data = ChartSvgExportData(
        signals: [
          [0, 1, 1, 0],
          [1, 1, 0, 0],
        ],
        signalNames: ['TRIGGER', 'BUSY'],
        signalTypes: [SignalType.input, SignalType.output],
        annotations: const [],
        cellWidth: 40,
        cellHeight: 40,
        labelWidth: 200,
        commentAreaHeight: 40,
        topCommentAreaHeight: 0,
        chartMarginLeft: 16,
        chartMarginTop: 16,
        totalWidth: 336,
        totalHeight: 136,
        labelColor: Colors.black,
        backgroundColor: Colors.white,
        dashedColor: Colors.black,
        omissionColor: Colors.black,
        omissionFillColor: Colors.white,
        arrowColor: Colors.black,
        signalColors: {
          SignalType.input: Colors.blue,
          SignalType.output: Colors.red,
        },
      );

      final svg = ChartSvgBuilder.build(data);
      expect(svg, startsWith('<svg'));
      expect(svg, contains('</svg>'));
      expect(svg, contains('<path'));
      expect(svg, contains('stroke-linejoin="miter"'));
      expect(svg, contains('TRIGGER'));
      expect(svg, contains('BUSY'));
      expect(svg, contains('<line'));
    });

    test('アノテーションを SVG に含める', () {
      const data = ChartSvgExportData(
        signals: [
          [0, 1, 1],
        ],
        signalNames: ['TRIGGER'],
        signalTypes: [SignalType.input],
        annotations: [
          TimingChartAnnotation(
            id: 'c1',
            startTimeIndex: 1,
            endTimeIndex: 2,
            text: '立ち上がり',
          ),
        ],
        cellWidth: 40,
        cellHeight: 40,
        labelWidth: 200,
        commentAreaHeight: 120,
        topCommentAreaHeight: 0,
        chartMarginLeft: 16,
        chartMarginTop: 16,
        totalWidth: 296,
        totalHeight: 216,
        labelColor: Colors.black,
        backgroundColor: Colors.white,
        dashedColor: Colors.black,
        omissionColor: Colors.black,
        omissionFillColor: Colors.white,
        arrowColor: Colors.black,
        signalColors: {SignalType.input: Colors.blue},
      );

      final svg = ChartSvgBuilder.build(data);
      expect(svg, contains('立ち上がり'));
      expect(svg, contains('stroke-dasharray'));
    });

    test('上部配置コメントの接続矢印をコメント位置に合わせて描画する', () {
      const data = ChartSvgExportData(
        signals: [
          [0, 1, 1, 1],
        ],
        signalNames: ['TRIGGER'],
        signalTypes: [SignalType.input],
        annotations: [
          TimingChartAnnotation(
            id: 'top1',
            startTimeIndex: 2,
            endTimeIndex: null,
            text: 'eeeeeeeee',
            placement: 'top',
            offsetX: 80,
          ),
        ],
        cellWidth: 40,
        cellHeight: 40,
        labelWidth: 200,
        commentAreaHeight: 40,
        topCommentAreaHeight: 60,
        chartMarginLeft: 16,
        chartMarginTop: 16,
        totalWidth: 376,
        totalHeight: 196,
        labelColor: Colors.black,
        backgroundColor: Colors.white,
        dashedColor: Colors.black,
        omissionColor: Colors.black,
        omissionFillColor: Colors.white,
        arrowColor: Colors.black,
        signalColors: {SignalType.input: Colors.blue},
      );

      final svg = ChartSvgBuilder.build(data);
      expect(svg, contains('eeeeeeeee'));
      // 接続矢印（水平線 + 矢印先端）
      expect(svg.split('stroke-width="2"').length, greaterThan(2));
    });
  });
}
