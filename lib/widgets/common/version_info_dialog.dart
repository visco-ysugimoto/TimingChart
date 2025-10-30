import 'package:flutter/material.dart';

class VersionInfoDialog extends StatelessWidget {
  const VersionInfoDialog({
    super.key,
    this.title,
    this.version,
    this.changelog,
  });

  final String? title;
  final String? version;
  final String? changelog;

  @override
  Widget build(BuildContext context) {
    final String dialogTitle = title ?? 'バージョン情報';
    final String versionLabel = 'バージョン';
    final String changesLabel = '変更点';
    final String versionText = version ?? 'vX.Y.Z';
    final String changelogText = changelog ?? 'ここに変更点の概要を記述します。';

    return AlertDialog(
      title: Text(dialogTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(versionLabel, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            SelectableText(versionText),
            const SizedBox(height: 16),
            Text(changesLabel, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: SelectableText(changelogText, textAlign: TextAlign.left),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
