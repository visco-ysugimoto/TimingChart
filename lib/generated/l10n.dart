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
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[Locale.fromSubtags(languageCode: 'en')];
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
