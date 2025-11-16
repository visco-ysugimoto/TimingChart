import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Text(
        dialogTitle,
        style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ) ?? const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // バージョン情報セクション
            Text(
              versionLabel,
              style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ) ?? const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              versionText,
              style: textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ) ?? const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 20),
            // バージョン情報と変更点の間の区切り線
            Divider(
              thickness: 1.5,
              height: 1,
              color: theme.dividerColor,
            ),
            const SizedBox(height: 20),
            // 変更点セクション
            Text(
              changesLabel,
              style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ) ?? const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: MarkdownBody(
                  data: changelogText,
                  styleSheet: MarkdownStyleSheet(
                    p: textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                        ) ?? const TextStyle(fontSize: 14),
                    h1: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ) ?? const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                    h2: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ) ?? const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                    h3: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ) ?? const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                    listBullet: textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                        ) ?? const TextStyle(fontSize: 14),
                    code: textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                        ) ?? TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                        ),
                    codeblockDecoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  selectable: true,
                ),
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
