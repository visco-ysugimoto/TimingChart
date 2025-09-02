import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_notifier.dart';
import '../../providers/locale_notifier.dart';
import '../../models/chart/signal_type.dart';
import '../../suggestion_loader.dart';

// ────────────────────────────────────────────────────────────
//  環境設定ウインドウ
//  Google Chrome の設定画面のように、左側にカテゴリ（NavigationRail）
//  右側に選択中カテゴリの設定項目を表示するレイアウト。
//  実際の機能はまだ実装しないため、各項目はプレースホルダーとして
//  ListTile / SwitchListTile を配置している。
// ────────────────────────────────────────────────────────────

class SettingsWindow extends StatefulWidget {
  final bool showIoNumbers;
  final ValueChanged<bool> onShowIoNumbersChanged;

  const SettingsWindow({
    Key? key,
    required this.showIoNumbers,
    required this.onShowIoNumbersChanged,
  }) : super(key: key);

  @override
  State<SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> {
  late bool _showIoNumbers;
  int _selectedIndex = 0;

  final _navDestinations = const [
    NavigationRailDestination(
      icon: Icon(Icons.settings),
      label: Text('一般'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.bar_chart),
      label: Text('チャート'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.import_export),
      label: Text('入出力'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.color_lens),
      label: Text('外観'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.language),
      label: Text('言語'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _showIoNumbers = widget.showIoNumbers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('環境設定', style: GoogleFonts.notoSansJp()),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: _navDestinations,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // ───────────── 右側パネル ─────────────
          Expanded(child: _buildPanel()),
        ],
      ),
    );
  }

  // 色選択ダイアログ (簡易)
  Future<Color?> _pickColor(BuildContext context, Color currentColor) async {
    const preset = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.black,
      Colors.grey,
    ];
    Color? selected = currentColor;
    return showDialog<Color>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('色を選択'),
        content: SizedBox(
          width: 300,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in preset)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop(c);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(selected),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  // カテゴリごとの設定項目を返す
  Widget _buildPanel() {
    final settings = context.watch<SettingsNotifier>();

    switch (_selectedIndex) {
      // ─────────── 一般設定 ───────────
      case 0:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.tag),
              title: const Text('IO番号を表示'),
              value: _showIoNumbers,
              onChanged: (val) {
                setState(() => _showIoNumbers = val);
                widget.onShowIoNumbersChanged(val);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('デフォルトカメラ数'),
              subtitle: Text('${settings.defaultCameraCount}'),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final selected = await showDialog<int>(
                  context: context,
                  builder: (_) => _CameraCountDialog(initial: settings.defaultCameraCount),
                );
                if (selected != null) {
                  settings.defaultCameraCount = selected;
                }
              },
            ),
            // 自動保存間隔は未使用のため削除
          ],
        );

      // ─────────── チャート設定 ───────────
      case 1:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        Color _effective(Color c) => isDark && c == Colors.black ? Colors.white : c;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.grid_on),
              title: const Text('グリッド線を表示'),
              value: settings.showGridLines,
              onChanged: (val) => settings.showGridLines = val,
            ),
            ListTile(
              leading: const Icon(Icons.timeline),
              title: const Text('デフォルトチャート長'),
              subtitle: Text('${settings.defaultChartLength}'),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final controller = TextEditingController(text: '${settings.defaultChartLength}');
                final updated = await showDialog<int>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('デフォルトチャート長'),
                    content: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '50'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
                      TextButton(onPressed: () => Navigator.of(context).pop(int.tryParse(controller.text)), child: const Text('OK')),
                    ],
                  ),
                );
                if (updated != null && updated > 0) {
                  settings.defaultChartLength = updated;
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(width: 24, height: 24, color: settings.signalColors[SignalType.input]),
              title: const Text('Input 信号色'),
              onTap: () async {
                final c = await _pickColor(context, settings.signalColors[SignalType.input]!);
                if (c != null) settings.setSignalColor(SignalType.input, c);
              },
            ),
            ListTile(
              leading: Container(width: 24, height: 24, color: settings.signalColors[SignalType.output]),
              title: const Text('Output 信号色'),
              onTap: () async {
                final c = await _pickColor(context, settings.signalColors[SignalType.output]!);
                if (c != null) settings.setSignalColor(SignalType.output, c);
              },
            ),
            ListTile(
              leading: Container(width: 24, height: 24, color: settings.signalColors[SignalType.hwTrigger]),
              title: const Text('HW Trigger 信号色'),
              onTap: () async {
                final c = await _pickColor(context, settings.signalColors[SignalType.hwTrigger]!);
                if (c != null) settings.setSignalColor(SignalType.hwTrigger, c);
              },
            ),
            TextButton(
              onPressed: settings.resetSignalColors,
              child: const Text('デフォルト色に戻す'),
            ),
            const Divider(),
            ListTile(
              leading: Container(width: 24, height: 24, color: _effective(settings.commentDashedColor)),
              title: const Text('コメント破線色'),
              onTap: () async {
                final c = await _pickColor(context, settings.commentDashedColor);
                if (c != null) settings.commentDashedColor = c;
              },
            ),
            ListTile(
              leading: Container(width: 24, height: 24, color: _effective(settings.commentArrowColor)),
              title: const Text('コメント矢印色'),
              onTap: () async {
                final c = await _pickColor(context, settings.commentArrowColor);
                if (c != null) settings.commentArrowColor = c;
              },
            ),
            ListTile(
              leading: Container(width: 24, height: 24, color: _effective(settings.omissionLineColor)),
              title: const Text('省略記号色'),
              onTap: () async {
                final c = await _pickColor(context, settings.omissionLineColor);
                if (c != null) settings.omissionLineColor = c;
              },
            ),
            TextButton(
              onPressed: settings.resetCommentColors,
              child: const Text('デフォルト色に戻す'),
            ),
          ],
        );

      // ─────────── 入出力設定 ───────────
      case 2:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('デフォルト保存フォルダ'),
              subtitle: Text(settings.exportFolder),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final controller = TextEditingController(text: settings.exportFolder);
                final updated = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('デフォルト保存フォルダ'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(hintText: 'Export Chart'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
                      TextButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('OK')),
                    ],
                  ),
                );
                if (updated != null && updated.isNotEmpty) {
                  settings.exportFolder = updated;
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('ファイル名プレフィックス'),
              subtitle: Text(settings.fileNamePrefix),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final controller = TextEditingController(text: settings.fileNamePrefix);
                final updated = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('ファイル名プレフィックス'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(hintText: 'prefix_'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
                      TextButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('OK')),
                    ],
                  ),
                );
                if (updated != null && updated.isNotEmpty) {
                  settings.fileNamePrefix = updated;
                }
              },
            ),
          ],
        );

      // ─────────── 外観設定 ───────────
      case 3:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text('ダークモード'),
              value: settings.darkMode,
              onChanged: (val) => settings.darkMode = val,
            ),
            ListTile(
              leading: Container(width: 24, height: 24, color: settings.accentColor),
              title: const Text('アクセントカラー'),
              onTap: () async {
                final c = await _pickColor(context, settings.accentColor);
                if (c != null) {
                  settings.accentColor = c;
                }
              },
            ),
          ],
        );

      // ─────────── 言語設定 ───────────
      case 4:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            RadioListTile<Locale>(
              value: const Locale('ja'),
              groupValue: context.watch<LocaleNotifier>().locale,
              title: const Text('日本語'),
              onChanged: (locale) {
                context.read<LocaleNotifier>().setLocale(locale!);
                setSuggestionLanguage(SuggestionLanguage.ja);
              },
            ),
            RadioListTile<Locale>(
              value: const Locale('en'),
              groupValue: context.watch<LocaleNotifier>().locale,
              title: const Text('English'),
              onChanged: (locale) {
                context.read<LocaleNotifier>().setLocale(locale!);
                setSuggestionLanguage(SuggestionLanguage.en);
              },
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ────────────────────────────────────────────────────────────
//  デフォルトカメラ数 選択ダイアログ
// ────────────────────────────────────────────────────────────

class _CameraCountDialog extends StatefulWidget {
  final int initial;
  const _CameraCountDialog({Key? key, required this.initial}) : super(key: key);

  @override
  State<_CameraCountDialog> createState() => _CameraCountDialogState();
}

class _CameraCountDialogState extends State<_CameraCountDialog> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial.clamp(1, 8).toInt();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('デフォルトカメラ数'),
      content: DropdownButton<int>(
        value: _selected,
        items: [
          for (int i = 1; i <= 8; i++)
            DropdownMenuItem<int>(value: i, child: Text('$i')),
        ],
        onChanged: (v) => setState(() => _selected = v!),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
        TextButton(onPressed: () => Navigator.of(context).pop(_selected), child: const Text('OK')),
      ],
    );
  }
} 