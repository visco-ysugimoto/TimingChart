import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/providers/settings_notifier.dart';
import 'package:flutter_application_1/models/report/html_report_sections.dart';
import 'package:flutter_application_1/models/chart/signal_type.dart';
import 'package:flutter_application_1/widgets/form/form_tab_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // 各テスト前に SharedPreferences の内容をクリア
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('SettingsNotifier は設定値を保存し、再生成時に復元できる', () async {
    final first = SettingsNotifier();
    await first.initialized;

    // デフォルト値を確認
    expect(first.defaultCameraCount, 1);
    expect(first.darkMode, false);

    // 値を変更
    first.defaultCameraCount = 4;
    first.darkMode = true;
    first.exportFolder = 'MyFolder';

    // SharedPreferences に保存されていることを確認
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('defaultCameraCount'), 4);
    expect(prefs.getBool('darkMode'), true);
    expect(prefs.getString('exportFolder'), 'MyFolder');

    // 新しいインスタンスを生成して、保存済みの値が復元されることを確認
    final second = SettingsNotifier();
    await second.initialized;

    expect(second.defaultCameraCount, 4);
    expect(second.darkMode, true);
    expect(second.exportFolder, 'MyFolder');
  });

  test('フォーム初期値は保存し、再生成時に復元できる', () async {
    final first = SettingsNotifier();
    await first.initialized;

    expect(first.defaultTriggerOption, TriggerOptions.single);
    expect(first.defaultInputPort, 32);
    expect(first.defaultOutputPort, 32);
    expect(first.defaultHwTriggerEnabled, isFalse);
    expect(first.defaultPlcEipOption, PlcEipOptions.none);

    first.defaultCameraCount = 3;
    first.defaultTriggerOption = TriggerOptions.code;
    first.defaultInputPort = 16;
    first.defaultOutputPort = 64;
    first.defaultHwTriggerEnabled = true;
    first.defaultPlcEipOption = PlcEipOptions.plc;

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('defaultTriggerOption'), TriggerOptions.code);
    expect(prefs.getInt('defaultInputPort'), 16);
    expect(prefs.getInt('defaultOutputPort'), 64);
    expect(prefs.getBool('defaultHwTriggerEnabled'), isTrue);
    expect(prefs.getString('defaultPlcEipOption'), PlcEipOptions.plc);

    final second = SettingsNotifier();
    await second.initialized;
    expect(second.defaultCameraCount, 3);
    expect(second.defaultTriggerOption, TriggerOptions.code);
    expect(second.defaultInputPort, 16);
    expect(second.defaultOutputPort, 64);
    expect(second.defaultHwTriggerEnabled, isTrue);
    expect(second.defaultPlcEipOption, PlcEipOptions.plc);
    expect(second.defaultFormState.hwPort, 3);
    expect(second.defaultFormState.inputCount, 16);
  });

  test('入力ポートが 6 のとき Code Trigger は Single に正規化される', () async {
    final settings = SettingsNotifier();
    await settings.initialized;

    settings.defaultTriggerOption = TriggerOptions.code;
    settings.defaultInputPort = 6;

    expect(settings.defaultTriggerOption, TriggerOptions.single);
    expect(settings.defaultFormState.triggerOption, TriggerOptions.single);
  });

  test('htmlReportSections は保存し、再生成時に復元できる', () async {
    final first = SettingsNotifier();
    await first.initialized;

    expect(first.htmlReportSections, HtmlReportSectionSet.all);

    const selected = HtmlReportSectionSet(
      composition: true,
      trigger: false,
      signals: true,
      camera: false,
      chart: true,
    );
    first.htmlReportSections = selected;

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('htmlReportSections'), [
      'composition',
      'signals',
      'chart',
    ]);

    final second = SettingsNotifier();
    await second.initialized;
    expect(second.htmlReportSections, selected);
  });

  test('htmlReportSections は空の選択を保存しない', () async {
    final settings = SettingsNotifier();
    await settings.initialized;

    settings.htmlReportSections = const HtmlReportSectionSet(
      composition: false,
      trigger: false,
      signals: false,
      camera: false,
      chart: false,
    );

    expect(settings.htmlReportSections, HtmlReportSectionSet.all);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('htmlReportSections'), isFalse);
  });

  test('msPerStep は永続化せず、起動時は 1.0 になる', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'msPerStep': 10.0});

    final settings = SettingsNotifier();
    await settings.initialized;

    expect(settings.msPerStep, 1.0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('msPerStep'), isFalse);

    settings.msPerStep = 5.0;
    expect(settings.msPerStep, 5.0);
    expect(prefs.containsKey('msPerStep'), isFalse);

    final restarted = SettingsNotifier();
    await restarted.initialized;
    expect(restarted.msPerStep, 1.0);
  });

  test('showIoNumbers は保存し、再生成時に復元できる', () async {
    final first = SettingsNotifier();
    await first.initialized;
    expect(first.showIoNumbers, isTrue);

    first.showIoNumbers = false;
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('showIoNumbers'), isFalse);

    final second = SettingsNotifier();
    await second.initialized;
    expect(second.showIoNumbers, isFalse);
  });

  test('fileNamePrefix は空文字を保存できる', () async {
    final first = SettingsNotifier();
    await first.initialized;
    first.fileNamePrefix = 'pre_';
    first.fileNamePrefix = '';

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fileNamePrefix'), '');

    final second = SettingsNotifier();
    await second.initialized;
    expect(second.fileNamePrefix, '');
  });

  test('表示中の timeUnitIsMs は永続化せず、既定値だけ保存する', () async {
    final first = SettingsNotifier();
    await first.initialized;
    expect(first.defaultTimeUnitIsMs, isFalse);
    expect(first.timeUnitIsMs, isFalse);

    first.defaultTimeUnitIsMs = true;
    first.timeUnitIsMs = false;

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('defaultTimeUnitIsMs'), isTrue);
    expect(prefs.containsKey('timeUnitIsMs'), isFalse);

    final second = SettingsNotifier();
    await second.initialized;
    expect(second.defaultTimeUnitIsMs, isTrue);
    expect(second.timeUnitIsMs, isTrue);

    second.timeUnitIsMs = false;
    expect(second.timeUnitIsMs, isFalse);
    expect(prefs.containsKey('timeUnitIsMs'), isFalse);
  });

  test('旧 timeUnitIsMs キーは既定の時間単位へ移行する', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'timeUnitIsMs': true,
    });

    final settings = SettingsNotifier();
    await settings.initialized;

    expect(settings.defaultTimeUnitIsMs, isTrue);
    expect(settings.timeUnitIsMs, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('timeUnitIsMs'), isFalse);
    expect(prefs.getBool('defaultTimeUnitIsMs'), isTrue);
  });

  test('resetAll は言語以外の設定を初期化し、保存キーを消す', () async {
    final settings = SettingsNotifier();
    await settings.initialized;

    settings.darkMode = true;
    settings.defaultCameraCount = 4;
    settings.exportFolder = 'MyFolder';
    settings.defaultTimeUnitIsMs = true;
    settings.showIoNumbers = false;
    settings.accentColor = Colors.red;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('localeCode', 'en');

    await settings.resetAll();

    expect(settings.darkMode, isFalse);
    expect(settings.defaultCameraCount, 1);
    expect(settings.exportFolder, 'Export Chart');
    expect(settings.defaultTimeUnitIsMs, isFalse);
    expect(settings.timeUnitIsMs, isFalse);
    expect(settings.showIoNumbers, isTrue);
    expect(settings.accentColor, Colors.blue);
    expect(settings.signalColors[SignalType.input], Colors.blue);

    expect(prefs.containsKey('darkMode'), isFalse);
    expect(prefs.containsKey('defaultCameraCount'), isFalse);
    expect(prefs.containsKey('exportFolder'), isFalse);
    expect(prefs.getString('localeCode'), 'en');
  });
}
