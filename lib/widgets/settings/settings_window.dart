import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../generated/l10n.dart';
import '../../providers/settings_notifier.dart';
import '../../providers/locale_notifier.dart';
import '../../models/chart/signal_type.dart';
import '../../suggestion_loader.dart';
import '../common/color_picker_dialog.dart';
import '../form/form_tab_constants.dart';
import '../form/form_tab_rules.dart';
import '../report/html_report_sections_picker.dart';

// ────────────────────────────────────────────────────────────
//  環境設定ウインドウ
//  Google Chrome の設定画面のように、左側にカテゴリ（NavigationRail）
//  右側に選択中カテゴリの設定項目を表示するレイアウト。
// ────────────────────────────────────────────────────────────

class SettingsWindow extends StatefulWidget {
  const SettingsWindow({super.key});

  @override
  State<SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> {
  int _selectedIndex = 0;

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

  Future<Color?> _pickColor(BuildContext context, Color currentColor) {
    return ColorPickerDialog.show(context, initial: currentColor);
  }

  Future<void> _confirmResetAll(
    BuildContext context,
    SettingsNotifier settings,
  ) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.settings_reset_all_confirm_title),
        content: Text(s.settings_reset_all_confirm_message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.settings_reset_all),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await settings.resetAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.settings_reset_all_done)));
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
              value: settings.showIoNumbers,
              onChanged: (val) => settings.showIoNumbers = val,
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(s.default_camera_count),
              subtitle: Text('${settings.defaultCameraCount}'),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final selected = await showDialog<int>(
                  context: context,
                  builder: (_) =>
                      _CameraCountDialog(initial: settings.defaultCameraCount),
                );
                if (selected != null) {
                  settings.defaultCameraCount = selected;
                }
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                s.settings_form_defaults_section,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bolt_outlined),
              title: Text(s.default_trigger_option),
              trailing: DropdownButton<String>(
                value:
                    FormTabRules.triggerOptionsForInputCount(
                      settings.defaultInputPort,
                    ).contains(settings.defaultTriggerOption)
                    ? settings.defaultTriggerOption
                    : TriggerOptions.single,
                items: [
                  for (final option in FormTabRules.triggerOptionsForInputCount(
                    settings.defaultInputPort,
                  ))
                    DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: (v) {
                  if (v != null) settings.defaultTriggerOption = v;
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(s.default_input_port),
              trailing: DropdownButton<int>(
                value: settings.defaultInputPort,
                items: [
                  for (final n in FormTabRules.portOptions)
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
                onChanged: (v) {
                  if (v != null) settings.defaultInputPort = v;
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(s.default_output_port),
              trailing: DropdownButton<int>(
                value: settings.defaultOutputPort,
                items: [
                  for (final n in FormTabRules.portOptions)
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
                onChanged: (v) {
                  if (v != null) settings.defaultOutputPort = v;
                },
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.memory_outlined),
              title: Text(s.default_hw_trigger_enabled),
              subtitle: Text(s.default_hw_trigger_enabled_help),
              value: settings.defaultHwTriggerEnabled,
              onChanged: (v) => settings.defaultHwTriggerEnabled = v,
            ),
            ListTile(
              leading: const Icon(Icons.device_hub_outlined),
              title: Text(s.default_plc_eip_option),
              trailing: DropdownButton<String>(
                value: settings.defaultPlcEipOption,
                items: const [
                  DropdownMenuItem(
                    value: PlcEipOptions.none,
                    child: Text(PlcEipOptions.none),
                  ),
                  DropdownMenuItem(
                    value: PlcEipOptions.plc,
                    child: Text(PlcEipOptions.plc),
                  ),
                  DropdownMenuItem(
                    value: PlcEipOptions.eip,
                    child: Text(PlcEipOptions.eip),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) settings.defaultPlcEipOption = v;
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                s.settings_reset_all,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(s.settings_reset_all_help),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: OutlinedButton.icon(
                  onPressed: () => _confirmResetAll(context, settings),
                  icon: const Icon(Icons.restore),
                  label: Text(s.settings_reset_all),
                ),
              ),
            ),
          ],
        );

      // ─────────── チャート設定 ───────────
      case 1:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        Color effective(Color c) =>
            isDark && c == Colors.black ? Colors.white : c;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.timer_outlined),
              title: Text(s.default_time_unit_ms),
              subtitle: Text(s.default_time_unit_ms_help),
              value: settings.defaultTimeUnitIsMs,
              onChanged: (val) => settings.defaultTimeUnitIsMs = val,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.straighten),
              title: Text(s.show_bottom_unit_labels),
              value: settings.showBottomUnitLabels,
              onChanged: (val) => settings.showBottomUnitLabels = val,
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
            ListTile(
              leading: Container(
                width: 24,
                height: 24,
                color: settings.signalColors[SignalType.auxiliary],
              ),
              title: Text(s.auxiliary_signal_color),
              onTap: () async {
                final c = await _pickColor(
                  context,
                  settings.signalColors[SignalType.auxiliary]!,
                );
                if (c != null) {
                  settings.setSignalColor(SignalType.auxiliary, c);
                }
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
                color: effective(settings.commentDashedColor),
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
                color: effective(settings.commentArrowColor),
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
                color: effective(settings.omissionLineColor),
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
              leading: const Icon(Icons.folder),
              title: Text(s.settings_export_base_directory),
              subtitle: Text(
                settings.lastExportDirectory ??
                    s.settings_export_base_directory_not_set,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (settings.lastExportDirectory != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: s.common_clear,
                      onPressed: () => settings.lastExportDirectory = null,
                    ),
                  const Icon(Icons.edit),
                ],
              ),
              onTap: () async {
                final path = await FilePicker.getDirectoryPath(
                  dialogTitle: s.settings_pick_export_directory,
                  initialDirectory: settings.lastExportDirectory,
                );
                if (path != null && path.isNotEmpty) {
                  settings.lastExportDirectory = path;
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(s.default_export_folder),
              subtitle: Text(
                '${settings.exportFolder}\n${s.settings_export_subfolder_help}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final controller = TextEditingController(
                  text: settings.exportFolder,
                );
                final updated = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(s.default_export_folder),
                    content: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: s.hint_export_folder,
                        helperText: s.settings_export_subfolder_help,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(s.common_cancel),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop(controller.text.trim()),
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
              subtitle: Text(
                settings.fileNamePrefix.isEmpty
                    ? s.file_name_prefix_none
                    : settings.fileNamePrefix,
              ),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final controller = TextEditingController(
                  text: settings.fileNamePrefix,
                );
                final updated = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
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
                        onPressed: () =>
                            Navigator.of(context).pop(controller.text.trim()),
                        child: Text(s.common_ok),
                      ),
                    ],
                  ),
                );
                if (updated != null) {
                  settings.fileNamePrefix = updated;
                }
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.flash_on),
              title: Text(s.settings_quick_export),
              value: settings.quickExportEnabled,
              onChanged: (v) => settings.quickExportEnabled = v,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.html),
              title: Text(s.settings_html_export_sections),
              subtitle: Text(s.settings_html_export_sections_help),
            ),
            HtmlReportSectionsPicker(
              value: settings.htmlReportSections,
              onChanged: (next) => settings.htmlReportSections = next,
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
            RadioGroup<Locale>(
              groupValue: context.watch<LocaleNotifier>().locale,
              onChanged: (locale) {
                if (locale == null) return;
                context.read<LocaleNotifier>().setLocale(locale);
                setSuggestionLanguage(
                  locale.languageCode == 'ja'
                      ? SuggestionLanguage.ja
                      : SuggestionLanguage.en,
                );
              },
              child: Column(
                children: [
                  RadioListTile<Locale>(
                    value: const Locale('ja'),
                    title: Text(s.language_japanese),
                  ),
                  RadioListTile<Locale>(
                    value: const Locale('en'),
                    title: Text(s.language_english),
                  ),
                ],
              ),
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
  const _CameraCountDialog({required this.initial});

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
