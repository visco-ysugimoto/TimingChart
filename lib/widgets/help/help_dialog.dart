import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import '../../generated/l10n.dart';
import '../../providers/locale_notifier.dart';

/// アプリ共通のヘルプダイアログ。
///
/// - 本文は assets の Markdown を読み込みます（言語別）。
/// - 画像は Markdown の `![alt](assets/...)` を `Image.asset` で表示します。
/// - 動画は将来対応の拡張記法（`:::video <path>`）を検出し、現状はプレースホルダを表示します。
class GlobalHelpDialog extends StatefulWidget {
  final int initialTabIndex;

  const GlobalHelpDialog({super.key, required this.initialTabIndex});

  @override
  State<GlobalHelpDialog> createState() => _GlobalHelpDialogState();
}

class _GlobalHelpDialogState extends State<GlobalHelpDialog> {
  bool _isMaximized = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final size = MediaQuery.of(context).size;
    // デスクトップでも十分大きく表示できるように、画面サイズに追従させる
    // （最大値は過度に大きくならないようにクランプ）
    final double dialogW = _isMaximized ? size.width : size.width * 0.98;
    final double dialogH = _isMaximized ? size.height : size.height * 0.90;

    return AlertDialog(
      insetPadding: _isMaximized ? EdgeInsets.zero : const EdgeInsets.all(12),
      titlePadding:
          _isMaximized
              ? const EdgeInsets.fromLTRB(16, 12, 8, 0)
              : null,
      contentPadding:
          _isMaximized
              ? const EdgeInsets.fromLTRB(16, 0, 16, 12)
              : null,
      title: Row(
        children: [
          Expanded(child: Text(s.menu_help)),
          IconButton(
            tooltip: _isMaximized ? '元に戻す' : '最大化',
            icon: Icon(_isMaximized ? Icons.fullscreen_exit : Icons.fullscreen),
            onPressed: () => setState(() => _isMaximized = !_isMaximized),
          ),
          IconButton(
            tooltip: '閉じる',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: _isMaximized ? dialogW : dialogW.clamp(320, 1100),
        height: _isMaximized ? dialogH : dialogH.clamp(280, 900),
        child: DefaultTabController(
          length: 2,
          initialIndex: widget.initialTabIndex.clamp(0, 1),
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: s.formTabTitle),
                  Tab(text: s.chartTabTitle),
                ],
              ),
              const SizedBox(height: 8),
              const Expanded(
                child: TabBarView(
                  children: [
                    _HelpMarkdownTab(kind: _HelpKind.form),
                    _HelpMarkdownTab(kind: _HelpKind.chart),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(S.of(context).common_ok),
        ),
      ],
    );
  }
}

enum _HelpKind { form, chart }

class _HelpMarkdownTab extends StatefulWidget {
  final _HelpKind kind;

  const _HelpMarkdownTab({required this.kind});

  @override
  State<_HelpMarkdownTab> createState() => _HelpMarkdownTabState();
}

class _HelpMarkdownTabState extends State<_HelpMarkdownTab> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 言語変更に追従するため、依存関係が変わったら再ロード
    _future = _load();
  }

  Future<String> _load() async {
    final locale = Provider.of<LocaleNotifier>(context, listen: false).locale;
    final lang = locale.languageCode.toLowerCase();

    final String fileName = widget.kind == _HelpKind.form ? 'form.md' : 'chart.md';
    final String primaryPath = 'assets/help/$lang/$fileName';
    final String fallbackPath = 'assets/help/en/$fileName';

    try {
      return await rootBundle.loadString(primaryPath);
    } catch (_) {
      return await rootBundle.loadString(fallbackPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Help load error: ${snapshot.error}'),
          );
        }
        final raw = snapshot.data ?? '';
        final blocks = _parseHelpBlocks(raw);

        final markdownStyle = _helpMarkdownStyle(context);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          itemCount: blocks.length,
          itemBuilder: (context, i) {
            final b = blocks[i];
            switch (b) {
              case _MarkdownBlock():
                return MarkdownBody(
                  data: b.markdown,
                  selectable: true,
                  styleSheet: markdownStyle,
                  imageBuilder: (uri, title, alt) {
                    final s = uri.toString();
                    if (s.startsWith('assets/')) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Image.asset(s),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Image.network(s),
                    );
                  },
                  onTapLink: (text, href, title) {
                    if (href == null) return;
                    // ここは将来拡張用（例: video: スキーム等）
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(href)),
                    );
                  },
                );
              case _VideoBlock():
                return _HelpVideoPlaceholder(assetPath: b.assetPath);
            }
          },
        );
      },
    );
  }
}

MarkdownStyleSheet _helpMarkdownStyle(BuildContext context) {
  final theme = Theme.of(context);
  final base = MarkdownStyleSheet.fromTheme(theme);
  final borderColor = theme.dividerColor;
  return base.copyWith(
    tablePadding: const EdgeInsets.only(bottom: 16),
    tableBorder: TableBorder.all(color: borderColor),
    tableHeadAlign: TextAlign.left,
    tableHeadCellsPadding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    tableHeadCellsDecoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
    ),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    tableCellsDecoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.5))),
    ),
  );
}

sealed class _HelpBlock {}

class _MarkdownBlock extends _HelpBlock {
  final String markdown;
  _MarkdownBlock(this.markdown);
}

class _VideoBlock extends _HelpBlock {
  final String assetPath;
  _VideoBlock(this.assetPath);
}

/// `:::video <path>` の行を検出してブロック分割します。
///
/// 将来 `video_player` 等を導入した際に、`_HelpVideoPlaceholder` を
/// 実再生ウィジェットへ差し替えるだけで対応できるようにしています。
List<_HelpBlock> _parseHelpBlocks(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').split('\n');
  final blocks = <_HelpBlock>[];
  final buf = StringBuffer();

  void flushMarkdown() {
    final text = buf.toString().trimRight();
    if (text.isNotEmpty) blocks.add(_MarkdownBlock(text));
    buf.clear();
  }

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith(':::video')) {
      flushMarkdown();
      final path = trimmed.substring(':::video'.length).trim();
      if (path.isNotEmpty) {
        blocks.add(_VideoBlock(path));
      }
      continue;
    }
    buf.writeln(line);
  }
  flushMarkdown();
  return blocks;
}

class _HelpVideoPlaceholder extends StatelessWidget {
  final String assetPath;

  const _HelpVideoPlaceholder({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.play_circle_outline),
          title: const Text('動画（将来対応）'),
          subtitle: Text(assetPath),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('動画再生は準備中です'),
                content: const Text(
                  '将来的に video_player などを導入して、ヘルプ内で動画を直接再生できるようにする想定です。',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(S.of(ctx).common_ok),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}


