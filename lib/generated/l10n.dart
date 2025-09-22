// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name =
        (locale.countryCode?.isEmpty ?? false)
            ? locale.languageCode
            : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Timing Chart Generator`
  String get appTitle {
    return Intl.message(
      'Timing Chart Generator',
      name: 'appTitle',
      desc: 'The main title of the application',
      args: [],
    );
  }

  /// `Input Form`
  String get formTabTitle {
    return Intl.message(
      'Input Form',
      name: 'formTabTitle',
      desc: 'Title for the tab containing the input form',
      args: [],
    );
  }

  /// `Timing Chart`
  String get chartTabTitle {
    return Intl.message(
      'Timing Chart',
      name: 'chartTabTitle',
      desc: 'Title for the tab displaying the timing chart',
      args: [],
    );
  }

  /// `File`
  String get menu_file {
    return Intl.message(
      'File',
      name: 'menu_file',
      desc: 'Label for the File menu',
      args: [],
    );
  }

  /// `New`
  String get menu_item_new {
    return Intl.message(
      'New',
      name: 'menu_item_new',
      desc: 'Menu item to create a new file',
      args: [],
    );
  }

  /// `Open...`
  String get menu_item_open {
    return Intl.message(
      'Open...',
      name: 'menu_item_open',
      desc: 'Menu item to open an existing file',
      args: [],
    );
  }

  /// `Save`
  String get menu_item_save {
    return Intl.message(
      'Save',
      name: 'menu_item_save',
      desc: 'Menu item to save the current file',
      args: [],
    );
  }

  /// `Save As...`
  String get menu_item_save_as {
    return Intl.message(
      'Save As...',
      name: 'menu_item_save_as',
      desc: 'Menu item to save the current file with a new name',
      args: [],
    );
  }

  /// `Edit`
  String get menu_edit {
    return Intl.message(
      'Edit',
      name: 'menu_edit',
      desc: 'Label for the Edit menu',
      args: [],
    );
  }

  /// `Cut`
  String get menu_item_cut {
    return Intl.message(
      'Cut',
      name: 'menu_item_cut',
      desc: 'Menu item to cut selected content',
      args: [],
    );
  }

  /// `Copy`
  String get menu_item_copy {
    return Intl.message(
      'Copy',
      name: 'menu_item_copy',
      desc: 'Menu item to copy selected content',
      args: [],
    );
  }

  /// `Paste`
  String get menu_item_paste {
    return Intl.message(
      'Paste',
      name: 'menu_item_paste',
      desc: 'Menu item to paste content from clipboard',
      args: [],
    );
  }

  /// `Help`
  String get menu_help {
    return Intl.message(
      'Help',
      name: 'menu_help',
      desc: 'Label for the Help menu',
      args: [],
    );
  }

  /// `About`
  String get menu_item_about {
    return Intl.message(
      'About',
      name: 'menu_item_about',
      desc: 'Menu item to show information about the application',
      args: [],
    );
  }

  /// `Chart Name`
  String get chartNameLabel {
    return Intl.message(
      'Chart Name',
      name: 'chartNameLabel',
      desc: 'Label for the chart name input field',
      args: [],
    );
  }

  /// `Trigger Option`
  String get triggerOptionLabel {
    return Intl.message(
      'Trigger Option',
      name: 'triggerOptionLabel',
      desc: 'Label for the trigger option dropdown',
      args: [],
    );
  }

  /// `Total I/O Port`
  String get ioPortLabel {
    return Intl.message(
      'Total I/O Port',
      name: 'ioPortLabel',
      desc: 'Label for the total I/O port selection dropdown',
      args: [],
    );
  }

  /// `Total HW Port`
  String get hwPortLabel {
    return Intl.message(
      'Total HW Port',
      name: 'hwPortLabel',
      desc: 'Label for the total hardware trigger port selection dropdown',
      args: [],
    );
  }

  /// `Total Camera`
  String get cameraLabel {
    return Intl.message(
      'Total Camera',
      name: 'cameraLabel',
      desc: 'Label for the total camera selection dropdown',
      args: [],
    );
  }

  /// `Input Signals`
  String get inputSignalSectionTitle {
    return Intl.message(
      'Input Signals',
      name: 'inputSignalSectionTitle',
      desc: 'Title for the input signal name entry section',
      args: [],
    );
  }

  /// `Input`
  String get inputSignalPrefix {
    return Intl.message(
      'Input',
      name: 'inputSignalPrefix',
      desc: 'Prefix used for input signal labels (e.g., Input 1, Input 2)',
      args: [],
    );
  }

  /// `Output Signals`
  String get outputSignalSectionTitle {
    return Intl.message(
      'Output Signals',
      name: 'outputSignalSectionTitle',
      desc: 'Title for the output signal name entry section',
      args: [],
    );
  }

  /// `Output`
  String get outputSignalPrefix {
    return Intl.message(
      'Output',
      name: 'outputSignalPrefix',
      desc: 'Prefix used for output signal labels (e.g., Output 1, Output 2)',
      args: [],
    );
  }

  /// `HW Trigger Signals`
  String get hwTriggerSectionTitle {
    return Intl.message(
      'HW Trigger Signals',
      name: 'hwTriggerSectionTitle',
      desc: 'Title for the hardware trigger signal name entry section',
      args: [],
    );
  }

  /// `HW Trigger`
  String get hwTriggerPrefix {
    return Intl.message(
      'HW Trigger',
      name: 'hwTriggerPrefix',
      desc:
          'Prefix used for hardware trigger signal labels (e.g., HW Trigger 1)',
      args: [],
    );
  }

  /// `Create Template`
  String get createTemplateButton {
    return Intl.message(
      'Create Template',
      name: 'createTemplateButton',
      desc: 'Text for the button to create a template (might be replaced)',
      args: [],
    );
  }

  /// `Update Chart`
  String get updateChartButton {
    return Intl.message(
      'Update Chart',
      name: 'updateChartButton',
      desc:
          'Text for the button that updates the timing chart based on form input',
      args: [],
    );
  }

  /// `Import`
  String get drawer_import {
    return Intl.message(
      'Import',
      name: 'drawer_import',
      desc: 'Drawer item: Import',
      args: [],
    );
  }

  /// `Import (.ziq)`
  String get drawer_import_ziq {
    return Intl.message(
      'Import (.ziq)',
      name: 'drawer_import_ziq',
      desc: 'Drawer item: Import .ziq archive',
      args: [],
    );
  }

  /// `.ziq selection was cancelled`
  String get drawer_import_ziq_cancelled {
    return Intl.message(
      '.ziq selection was cancelled',
      name: 'drawer_import_ziq_cancelled',
      desc: 'SnackBar when .ziq selection is cancelled',
      args: [],
    );
  }

  /// `Export`
  String get drawer_export {
    return Intl.message(
      'Export',
      name: 'drawer_export',
      desc: 'Drawer item: Export',
      args: [],
    );
  }

  /// `Export chart image (JPEG)`
  String get drawer_export_chart_jpeg {
    return Intl.message(
      'Export chart image (JPEG)',
      name: 'drawer_export_chart_jpeg',
      desc: 'Drawer item: Export chart image as JPEG',
      args: [],
    );
  }

  /// `Export as XLSX`
  String get drawer_export_xlsx {
    return Intl.message(
      'Export as XLSX',
      name: 'drawer_export_xlsx',
      desc: 'Drawer item: Export XLSX',
      args: [],
    );
  }

  /// `Preferences`
  String get drawer_preferences {
    return Intl.message(
      'Preferences',
      name: 'drawer_preferences',
      desc: 'Drawer item: Preferences',
      args: [],
    );
  }

  /// `Japanese`
  String get language_japanese {
    return Intl.message(
      'Japanese',
      name: 'language_japanese',
      desc: 'Label: Japanese language',
      args: [],
    );
  }

  /// `English`
  String get language_english {
    return Intl.message(
      'English',
      name: 'language_english',
      desc: 'Label: English language',
      args: [],
    );
  }

  /// `Preferences`
  String get settings_title {
    return Intl.message(
      'Preferences',
      name: 'settings_title',
      desc: 'Settings window title',
      args: [],
    );
  }

  /// `General`
  String get settings_nav_general {
    return Intl.message(
      'General',
      name: 'settings_nav_general',
      desc: 'Settings nav: General',
      args: [],
    );
  }

  /// `Chart`
  String get settings_nav_chart {
    return Intl.message(
      'Chart',
      name: 'settings_nav_chart',
      desc: 'Settings nav: Chart',
      args: [],
    );
  }

  /// `I/O`
  String get settings_nav_io {
    return Intl.message(
      'I/O',
      name: 'settings_nav_io',
      desc: 'Settings nav: I/O',
      args: [],
    );
  }

  /// `Appearance`
  String get settings_nav_appearance {
    return Intl.message(
      'Appearance',
      name: 'settings_nav_appearance',
      desc: 'Settings nav: Appearance',
      args: [],
    );
  }

  /// `Language`
  String get settings_nav_language {
    return Intl.message(
      'Language',
      name: 'settings_nav_language',
      desc: 'Settings nav: Language',
      args: [],
    );
  }

  /// `Select Color`
  String get color_picker_title {
    return Intl.message(
      'Select Color',
      name: 'color_picker_title',
      desc: 'Title for color picker dialog',
      args: [],
    );
  }

  /// `Cancel`
  String get common_cancel {
    return Intl.message(
      'Cancel',
      name: 'common_cancel',
      desc: 'Common button: Cancel',
      args: [],
    );
  }

  /// `OK`
  String get common_ok {
    return Intl.message(
      'OK',
      name: 'common_ok',
      desc: 'Common button: OK',
      args: [],
    );
  }

  /// `Show IO numbers`
  String get show_io_numbers {
    return Intl.message(
      'Show IO numbers',
      name: 'show_io_numbers',
      desc: 'Toggle to show IO number suffixes',
      args: [],
    );
  }

  /// `Default camera count`
  String get default_camera_count {
    return Intl.message(
      'Default camera count',
      name: 'default_camera_count',
      desc: 'Label for default camera count',
      args: [],
    );
  }

  /// `Show grid lines`
  String get show_grid_lines {
    return Intl.message(
      'Show grid lines',
      name: 'show_grid_lines',
      desc: 'Toggle to show grid lines',
      args: [],
    );
  }

  /// `Default chart length`
  String get default_chart_length {
    return Intl.message(
      'Default chart length',
      name: 'default_chart_length',
      desc: 'Label for default chart length',
      args: [],
    );
  }

  /// `Input signal color`
  String get input_signal_color {
    return Intl.message(
      'Input signal color',
      name: 'input_signal_color',
      desc: 'Label for input signal color',
      args: [],
    );
  }

  /// `Output signal color`
  String get output_signal_color {
    return Intl.message(
      'Output signal color',
      name: 'output_signal_color',
      desc: 'Label for output signal color',
      args: [],
    );
  }

  /// `HW Trigger signal color`
  String get hw_trigger_signal_color {
    return Intl.message(
      'HW Trigger signal color',
      name: 'hw_trigger_signal_color',
      desc: 'Label for hw trigger signal color',
      args: [],
    );
  }

  /// `Reset to default colors`
  String get reset_default_colors {
    return Intl.message(
      'Reset to default colors',
      name: 'reset_default_colors',
      desc: 'Button to reset colors to default',
      args: [],
    );
  }

  /// `Comment dashed color`
  String get comment_dashed_color {
    return Intl.message(
      'Comment dashed color',
      name: 'comment_dashed_color',
      desc: 'Label for dashed line color',
      args: [],
    );
  }

  /// `Comment arrow color`
  String get comment_arrow_color {
    return Intl.message(
      'Comment arrow color',
      name: 'comment_arrow_color',
      desc: 'Label for arrow color',
      args: [],
    );
  }

  /// `Omission mark color`
  String get omission_line_color {
    return Intl.message(
      'Omission mark color',
      name: 'omission_line_color',
      desc: 'Label for omission mark color',
      args: [],
    );
  }

  /// `Default export folder`
  String get default_export_folder {
    return Intl.message(
      'Default export folder',
      name: 'default_export_folder',
      desc: 'Label for default export folder',
      args: [],
    );
  }

  /// `File name prefix`
  String get file_name_prefix {
    return Intl.message(
      'File name prefix',
      name: 'file_name_prefix',
      desc: 'Label for file name prefix',
      args: [],
    );
  }

  /// `Export Chart`
  String get hint_export_folder {
    return Intl.message(
      'Export Chart',
      name: 'hint_export_folder',
      desc: 'Hint text for export folder',
      args: [],
    );
  }

  /// `prefix_`
  String get hint_filename_prefix {
    return Intl.message(
      'prefix_',
      name: 'hint_filename_prefix',
      desc: 'Hint for file name prefix',
      args: [],
    );
  }

  /// `Dark mode`
  String get dark_mode {
    return Intl.message(
      'Dark mode',
      name: 'dark_mode',
      desc: 'Toggle for dark mode',
      args: [],
    );
  }

  /// `Accent color`
  String get accent_color {
    return Intl.message(
      'Accent color',
      name: 'accent_color',
      desc: 'Label for accent color',
      args: [],
    );
  }

  /// `Importing... Please wait`
  String get importing_wait {
    return Intl.message(
      'Importing... Please wait',
      name: 'importing_wait',
      desc: 'Overlay text while importing',
      args: [],
    );
  }

  /// `Edit comment`
  String get ctx_edit_comment {
    return Intl.message(
      'Edit comment',
      name: 'ctx_edit_comment',
      desc: 'Context menu: edit comment',
      args: [],
    );
  }

  /// `Delete comment`
  String get ctx_delete_comment {
    return Intl.message(
      'Delete comment',
      name: 'ctx_delete_comment',
      desc: 'Context menu: delete comment',
      args: [],
    );
  }

  /// `Draw arrow horizontally: ON → OFF`
  String get ctx_arrow_horizontal_on_to_off {
    return Intl.message(
      'Draw arrow horizontally: ON → OFF',
      name: 'ctx_arrow_horizontal_on_to_off',
      desc: 'Toggle arrow horizontal on->off',
      args: [],
    );
  }

  /// `Draw arrow horizontally: OFF → ON`
  String get ctx_arrow_horizontal_off_to_on {
    return Intl.message(
      'Draw arrow horizontally: OFF → ON',
      name: 'ctx_arrow_horizontal_off_to_on',
      desc: 'Toggle arrow horizontal off->on',
      args: [],
    );
  }

  /// `Set arrow tip to this signal`
  String get ctx_set_arrow_tip_to_row {
    return Intl.message(
      'Set arrow tip to this signal',
      name: 'ctx_set_arrow_tip_to_row',
      desc: 'Set arrow tip to clicked row',
      args: [],
    );
  }

  /// `Insert 0 into selection`
  String get ctx_insert_zeros {
    return Intl.message(
      'Insert 0 into selection',
      name: 'ctx_insert_zeros',
      desc: 'Insert zeros into selected range',
      args: [],
    );
  }

  /// `Duplicate selection to tail`
  String get ctx_duplicate_to_tail {
    return Intl.message(
      'Duplicate selection to tail',
      name: 'ctx_duplicate_to_tail',
      desc: 'Duplicate selection to the end',
      args: [],
    );
  }

  /// `Select all signals`
  String get ctx_select_all_signals {
    return Intl.message(
      'Select all signals',
      name: 'ctx_select_all_signals',
      desc: 'Select all signals',
      args: [],
    );
  }

  /// `Delete selection`
  String get ctx_delete_selection {
    return Intl.message(
      'Delete selection',
      name: 'ctx_delete_selection',
      desc: 'Delete selected range',
      args: [],
    );
  }

  /// `Add comment`
  String get ctx_add_comment {
    return Intl.message(
      'Add comment',
      name: 'ctx_add_comment',
      desc: 'Add comment on selection or position',
      args: [],
    );
  }

  /// `Draw omission signal`
  String get ctx_draw_omission {
    return Intl.message(
      'Draw omission signal',
      name: 'ctx_draw_omission',
      desc: 'Draw omission for the range',
      args: [],
    );
  }

  /// `Add comment`
  String get comment_add_title {
    return Intl.message(
      'Add comment',
      name: 'comment_add_title',
      desc: 'Dialog title: add single comment',
      args: [],
    );
  }

  /// `Add comment to selection`
  String get comment_add_range_title {
    return Intl.message(
      'Add comment to selection',
      name: 'comment_add_range_title',
      desc: 'Dialog title: add comment to selected range',
      args: [],
    );
  }

  /// `Enter comment`
  String get comment_input_hint {
    return Intl.message(
      'Enter comment',
      name: 'comment_input_hint',
      desc: 'Hint text for comment input',
      args: [],
    );
  }

  /// `Edit comment`
  String get comment_edit_title {
    return Intl.message(
      'Edit comment',
      name: 'comment_edit_title',
      desc: 'Dialog title: edit comment',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'ja'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
