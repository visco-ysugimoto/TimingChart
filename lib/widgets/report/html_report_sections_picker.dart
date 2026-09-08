import 'package:flutter/material.dart';

import '../../generated/l10n.dart';
import '../../models/report/html_report_sections.dart';

/// HTML レポートの出力項目チェックリスト。
class HtmlReportSectionsPicker extends StatelessWidget {
  final HtmlReportSectionSet value;
  final ValueChanged<HtmlReportSectionSet> onChanged;

  const HtmlReportSectionsPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final section in HtmlReportSection.values)
          CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(_labelOf(s, section)),
            value: value.includes(section),
            onChanged: (checked) {
              if (checked == null) return;
              final next = value.withSection(section, checked);
              if (!next.hasAny) return;
              onChanged(next);
            },
          ),
      ],
    );
  }

  static String _labelOf(S s, HtmlReportSection section) {
    switch (section) {
      case HtmlReportSection.composition:
        return s.html_export_section_composition;
      case HtmlReportSection.trigger:
        return s.html_export_section_trigger;
      case HtmlReportSection.signals:
        return s.html_export_section_signals;
      case HtmlReportSection.camera:
        return s.html_export_section_camera;
      case HtmlReportSection.chart:
        return s.html_export_section_chart;
    }
  }
}
