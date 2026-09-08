import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/report/html_report_sections.dart';

void main() {
  group('HtmlReportSectionSet', () {
    test('未保存・空・未知 ID は全選択にする', () {
      expect(HtmlReportSectionSet.fromPrefIds(null), HtmlReportSectionSet.all);
      expect(
        HtmlReportSectionSet.fromPrefIds(const []),
        HtmlReportSectionSet.all,
      );
      expect(
        HtmlReportSectionSet.fromPrefIds(const ['unknown']),
        HtmlReportSectionSet.all,
      );
    });

    test('保存 ID から選択状態を復元する', () {
      const selected = HtmlReportSectionSet(
        composition: true,
        trigger: false,
        signals: true,
        camera: false,
        chart: true,
      );
      expect(HtmlReportSectionSet.fromPrefIds(selected.toPrefIds()), selected);
      expect(selected.toPrefIds(), ['composition', 'signals', 'chart']);
      expect(selected.hasAny, isTrue);
      expect(selected.includes(HtmlReportSection.trigger), isFalse);
    });

    test('withSection は指定項目だけ切り替える', () {
      const start = HtmlReportSectionSet.all;
      final withoutChart = start.withSection(HtmlReportSection.chart, false);
      expect(withoutChart.chart, isFalse);
      expect(withoutChart.signals, isTrue);
      expect(withoutChart.hasAny, isTrue);
    });
  });
}
