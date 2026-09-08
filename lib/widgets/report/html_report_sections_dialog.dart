import 'package:flutter/material.dart';

import '../../generated/l10n.dart';
import '../../models/report/html_report_sections.dart';
import 'html_report_sections_picker.dart';

/// HTML レポート書き出し時の出力項目選択。
class HtmlReportSectionsDialog {
  HtmlReportSectionsDialog._();

  static Future<HtmlReportSectionSet?> show(
    BuildContext context, {
    required HtmlReportSectionSet initial,
  }) {
    return showDialog<HtmlReportSectionSet>(
      context: context,
      builder: (_) => _HtmlReportSectionsDialog(initial: initial),
    );
  }
}

class _HtmlReportSectionsDialog extends StatefulWidget {
  final HtmlReportSectionSet initial;

  const _HtmlReportSectionsDialog({required this.initial});

  @override
  State<_HtmlReportSectionsDialog> createState() =>
      _HtmlReportSectionsDialogState();
}

class _HtmlReportSectionsDialogState extends State<_HtmlReportSectionsDialog> {
  late HtmlReportSectionSet _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial.hasAny
        ? widget.initial
        : HtmlReportSectionSet.all;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.html_export_sections_title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.html_export_sections_subtitle),
            const SizedBox(height: 8),
            HtmlReportSectionsPicker(
              value: _selected,
              onChanged: (next) => setState(() => _selected = next),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.common_cancel),
        ),
        FilledButton(
          onPressed: _selected.hasAny
              ? () => Navigator.of(context).pop(_selected)
              : null,
          child: Text(s.html_export_sections_export),
        ),
      ],
    );
  }
}
