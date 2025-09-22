import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../generated/l10n.dart';
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

  final _navDestinations = const [];

  @override
  void initState() {
    super.initState();
    _showIoNumbers = widget.showIoNumbers;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.settings_title, style: GoogleFonts.notoSansJp()),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.settings),
                label: Text(s.settings_nav_general),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.bar_chart),
                label: Text(s.settings_nav_chart),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.import_export),
                label: Text(s.settings_nav_io),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.color_lens),
                label: Text(s.settings_nav_appearance),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.language),
                label: Text(s.settings_nav_language),
              ),
            ],
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
    final s = S.of(context);
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
      builder:
          (_) => AlertDialog(
            title: Text(s.color_picker_title),
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
                child: Text(s.common_cancel),
              ),
            ],
          ),
    );
  }

  // カテゴリごとの設定項目を返す
  Widget _buildPanel() {
    final settings = context.watch<SettingsNotifier>();
    final s = S.of(context);

    switch (_selectedIndex) {
      // ─────────── 一般設定 ───────────
      case 0:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.tag),
              title: Text(s.show_io_numbers),
              value: _showIoNumbers,
              onChanged: (val) {
                setState(() => _showIoNumbers = val);
                widget.onShowIoNumbersChanged(val);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(s.default_camera_count),
              subtitle: Text('${settings.defaultCameraCount}'),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final selected = await showDialog<int>(
                  context: context,
                  builder:
                      (_) => _CameraCountDialog(
                        initial: settings.defaultCameraCount,
                      ),
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
        Color _effective(Color c) =>
            isDark && c == Colors.black ? Colors.white : c;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.grid_on),
              title: Text(s.show_grid_lines),
              value: settings.showGridLines,
              onChanged: (val) => settings.showGridLines = val,
            ),
            ListTile(
              leading: const Icon(Icons.timeline),
              title: Text(s.default_chart_length),
              subtitle: Text('${settings.defaultChartLength}'),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final controller = TextEditingController(
                  text: '${settings.defaultChartLength}',
                );
                final updated = await showDialog<int>(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        title: Text(s.default_chart_length),
                        content: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '50'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(s.common_cancel),
                          ),
                          TextButton(
                            onPressed:
                                () => Navigator.of(
                                  context,
                                ).pop(int.tryParse(controller.text)),
                            child: Text(s.common_ok),
                          ),
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
              leading: Container(
                width: 24,
                height: 24,
                color: settings.signalColors[SignalType.input],
              ),
              title: Text(s.input_signal_color),
              onTap: () async {
                final c = await _pickColor(
                  context,
                  settings.signalColors[SignalType.input]!,
                );
                if (c != null) settings.setSignalColor(SignalType.input, c);
              },
            ),
            ListTile(
              leading: Container(
                width: 24,
                height: 24,
                color: settings.signalColors[SignalType.output],
              ),
              title: Text(s.output_signal_color),
              onTap: () async {
                final c = await _pickColor(
                  context,
                  settings.signalColors[SignalType.output]!,
                );
                if (c != null) settings.setSignalColor(SignalType.output, c);
              },
            ),
            ListTile(
              leading: Container(
                width: 24,
                height: 24,
                color: settings.signalColors[SignalType.hwTrigger],
              ),
              title: Text(s.hw_trigger_signal_color),
              onTap: () async {
                final c = await _pickColor(
                  context,
                  settings.signalColors[SignalType.hwTrigger]!,
                );
                if (c != null) settings.setSignalColor(SignalType.hwTrigger, c);
              },
            ),
            TextButton(
              onPressed: settings.resetSignalColors,
              child: Text(s.reset_default_colors),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                width: 24,
                height: 24,
                color: _effective(settings.commentDashedColor),
              ),
              title: Text(s.comment_dashed_color),
              onTap: () async {
                final c = await _pickColor(
                  context,
                  settings.commentDashedColor,
                );
                if (c != null) settings.commentDashedColor = c;
              },
            ),
            ListTile(
              leading: Container(
                width: 24,
                height: 24,
                color: _effective(settings.commentArrowColor),
              ),
              title: Text(s.comment_arrow_color),
              onTap: () async {
                final c = await _pickColor(context, settings.commentArrowColor);
                if (c != null) settings.commentArrowColor = c;
              },
            ),
            ListTile(
              leading: Container(
                width: 24,
                height: 24,
                color: _effective(settings.omissionLineColor),
              ),
              title: Text(s.omission_line_color),
              onTap: () async {
                final c = await _pickColor(context, settings.omissionLineColor);
                if (c != null) settings.omissionLineColor = c;
              },
            ),
            TextButton(
              onPressed: settings.resetCommentColors,
              child: Text(s.reset_default_colors),
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
              title: Text(s.default_export_folder),
              subtitle: Text(settings.exportFolder),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final controller = TextEditingController(
                  text: settings.exportFolder,
                );
                final updated = await showDialog<String>(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        title: Text(s.default_export_folder),
                        content: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: s.hint_export_folder,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(s.common_cancel),
                          ),
                          TextButton(
                            onPressed:
                                () => Navigator.of(
                                  context,
                                ).pop(controller.text.trim()),
                            child: Text(s.common_ok),
                          ),
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
              title: Text(s.file_name_prefix),
              subtitle: Text(settings.fileNamePrefix),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final controller = TextEditingController(
                  text: settings.fileNamePrefix,
                );
                final updated = await showDialog<String>(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        title: Text(s.file_name_prefix),
                        content: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: s.hint_filename_prefix,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(s.common_cancel),
                          ),
                          TextButton(
                            onPressed:
                                () => Navigator.of(
                                  context,
                                ).pop(controller.text.trim()),
                            child: Text(s.common_ok),
                          ),
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
              title: Text(s.dark_mode),
              value: settings.darkMode,
              onChanged: (val) => settings.darkMode = val,
            ),
            ListTile(
              leading: Container(
                width: 24,
                height: 24,
                color: settings.accentColor,
              ),
              title: Text(s.accent_color),
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
              title: Text(s.language_japanese),
              onChanged: (locale) {
                context.read<LocaleNotifier>().setLocale(locale!);
                setSuggestionLanguage(SuggestionLanguage.ja);
              },
            ),
            RadioListTile<Locale>(
              value: const Locale('en'),
              groupValue: context.watch<LocaleNotifier>().locale,
              title: Text(s.language_english),
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
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.default_camera_count),
      content: DropdownButton<int>(
        value: _selected,
        items: [
          for (int i = 1; i <= 8; i++)
            DropdownMenuItem<int>(value: i, child: Text('$i')),
        ],
        onChanged: (v) => setState(() => _selected = v!),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.common_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(s.common_ok),
        ),
      ],
    );
  }
}
