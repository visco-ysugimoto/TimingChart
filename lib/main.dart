import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' as io;

import 'generated/l10n.dart';
import 'models/form/form_state.dart';
import 'models/chart/signal_data.dart';
import 'models/chart/timing_chart_annotation.dart';
import 'utils/desktop_file_reveal.dart';
import 'utils/file_utils.dart';
import 'widgets/form/form_tab.dart';
import 'widgets/chart/timing_chart.dart';
import 'widgets/settings/settings_window.dart';
import 'widgets/help/help_dialog.dart';
import 'utils/vxvismgr_parser.dart';
import 'utils/vxvismgr_mapping_loader.dart';
import 'utils/csv_io_log_parser.dart';
import 'models/chart/signal_type.dart';
import 'models/chart/io_channel_source.dart';

import 'providers/form_state_notifier.dart';
import 'providers/form_controllers_notifier.dart';
import 'providers/locale_notifier.dart';
import 'providers/settings_notifier.dart';
import 'suggestion_loader.dart';
import 'providers/timing_chart_controller.dart';
import 'dart:math' as math;
import 'widgets/common/version_info_dialog.dart';
import 'services/ziq_import_service.dart';
import 'services/chart_update_service.dart';
import 'services/export_service.dart';
import 'services/chart_concat_service.dart';
import 'widgets/chart/chart_concat_dialogs.dart';
import 'widgets/form/form_tab_controller_mapper.dart';
import 'widgets/form/form_tab_rules.dart';

/// ZIQインポートテストモードの有効/無効を制御する環境変数
const bool kZiqImportTest = bool.fromEnvironment(
  'ZIQ_IMPORT_TEST',
  defaultValue: false,
);

/// ZIQファイルのパスを指定する環境変数
const String kZiqPath = String.fromEnvironment('ZIQ_PATH', defaultValue: '');

/// アプリケーションのエントリーポイント
///
/// テストモードが有効な場合はZIQインポートテストを実行し、
/// 通常モードの場合はProviderで状態管理を初期化してアプリを起動します。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kZiqImportTest) {
    await _runZiqImportTestMode();
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FormStateNotifier()),
        ChangeNotifierProvider(create: (_) => FormControllersNotifier()),
        ChangeNotifierProvider(create: (_) => LocaleNotifier()),
        ChangeNotifierProvider(create: (_) => SettingsNotifier()),
      ],
      child: const TimingChartGeneratorApp(),
    ),
  );
}

void _printZiqFilesStatus({
  required String ziqLabel,
  required String? ini,
  required String? dio,
  required String? plc,
  required String? fnl,
}) {
  debugPrint('ZIQ_IMPORT_TEST: $ziqLabel');
  debugPrint(' - vxVisMgr.ini: ${ini != null ? 'OK' : 'MISSING'}');
  debugPrint(' - DioMonitorLog.csv: ${dio != null ? 'OK' : 'MISSING'}');
  debugPrint(' - Plc_DioMonitorLog.csv: ${plc != null ? 'OK' : 'MISSING'}');
  debugPrint(' - FNL_DioMonitorLog.csv: ${fnl != null ? 'OK' : 'MISSING'}');
}

List<MapEntry<String, String>> _collectCsvPairs({
  required String? dio,
  required String? plc,
  required String? fnl,
}) {
  final csvPairs = <MapEntry<String, String>>[];
  if (dio != null && dio.isNotEmpty) csvPairs.add(MapEntry('DIO', dio));
  if (plc != null && plc.isNotEmpty) csvPairs.add(MapEntry('PLC', plc));
  if (fnl != null && fnl.isNotEmpty) csvPairs.add(MapEntry('EIP', fnl));
  return csvPairs;
}

Future<void> _runZiqImportTestFromContents({
  required String? ini,
  required String? dio,
  required String? plc,
  required String? fnl,
}) async {
  if (ini != null) {
    final ioActive = VxVisMgrParser.parseIOActive(ini);
    final ioSetting = VxVisMgrParser.parseIOSetting(ini);
    final enabled =
        VxVisMgrParser.parseStatusSignalSettings(
          ini,
        ).where((s) => s.enabled).toList();

    if (ioActive != null) {
      debugPrint(
        ' IOActive: pinPorts=${ioActive.pinPorts}, poutPorts=${ioActive.poutPorts}',
      );
    }
    if (ioSetting != null) {
      final trigger =
          (ioSetting.plcCommandEnabled || ioSetting.ethernetIpCommandEnabled)
              ? 'Command Trigger'
              : (ioSetting.triggerMode == 0
                  ? 'Code Trigger'
                  : 'Single Trigger');
      final plcEip =
          ioSetting.plcLinkEnabled
              ? 'PLC'
              : (ioSetting.ethernetIpEnabled ? 'EIP' : 'None');
      debugPrint(' IOSetting: trigger=$trigger, PLC/EIP=$plcEip');
    }
    debugPrint(' Enabled signals: ${enabled.length}');
  }

  final csvPairs = _collectCsvPairs(dio: dio, plc: plc, fnl: fnl);
  if (csvPairs.isEmpty) return;

  final timeline = CsvIoLogParser.parseTimelineMulti(csvPairs);
  final active = ActivePortDetector.detectActivePorts(csvPairs);
  final activeIn = ActivePortDetector.detectActiveInputPorts(csvPairs);
  final activePrintable = <String, List<int>>{
    for (final e in active.entries) e.key: (e.value.toList()..sort()),
  };
  debugPrint(
    ' Timeline: rows=${timeline.entries.length} (信号データが存在します), inPorts=${timeline.inPortCount}, outPorts=${timeline.outPortCount}',
  );
  debugPrint(' Active output ports: $activePrintable');
  final activeInPrintable = <String, List<int>>{
    for (final e in activeIn.entries) e.key: (e.value.toList()..sort()),
  };
  debugPrint(' Active input ports: $activeInPrintable');

  if (ini == null) return;

  final mapping = await VxVisMgrMappingLoader.loadMapping();
  final enabled =
      VxVisMgrParser.parseStatusSignalSettings(
        ini,
      ).where((s) => s.enabled).toList();

  String plcEipOption = 'None';
  final ioSetting2 = VxVisMgrParser.parseIOSetting(ini);
  if (ioSetting2 != null) {
    if (ioSetting2.plcLinkEnabled) {
      plcEipOption = 'PLC';
    } else if (ioSetting2.ethernetIpEnabled) {
      plcEipOption = 'EIP';
    }
  }

  final namesBySourcePort = <String, Map<int, String>>{
    'DIO': <int, String>{},
    'PLC': <int, String>{},
    'EIP': <int, String>{},
  };
  for (final s in enabled) {
    if (!s.portNoByIndex.containsKey(0)) continue;
    final n0 = s.portNoByIndex[0]! + 1;
    final type = s.portTypeByIndex[0];
    final label = mapping[s.name] ?? s.name;
    if (type != null && type != 0) {
      final src = plcEipOption == 'PLC' ? 'PLC' : 'EIP';
      namesBySourcePort[src]![n0] = label;
    } else {
      namesBySourcePort['DIO']![n0] = label;
    }
  }

  String fallbackName(String source, int port) {
    if (source == 'DIO') return 'Output$port';
    if (source == 'PLC') return 'PLO$port';
    if (source == 'EIP') return 'ESO$port';
    return 'Port$port';
  }

  debugPrint(' ActivePort Names:');
  for (final source in ['DIO', 'PLC', 'EIP']) {
    final ports = active[source];
    if (ports == null || ports.isEmpty) continue;
    final sorted = ports.toList()..sort();
    for (final p in sorted) {
      final name = namesBySourcePort[source]?[p] ?? fallbackName(source, p);
      debugPrint('  - $source:$p -> $name');
    }
  }

  debugPrint(' Enabled (INI) Signals:');
  for (final source in ['DIO', 'PLC', 'EIP']) {
    final map = namesBySourcePort[source]!;
    if (map.isEmpty) continue;
    final keys = map.keys.toList()..sort();
    for (final p in keys) {
      debugPrint('  - $source:$p -> ${map[p]}');
    }
  }

  final definedPorts = <String, Set<int>>{
    'DIO': namesBySourcePort['DIO']!.keys.toSet(),
    'PLC': namesBySourcePort['PLC']!.keys.toSet(),
    'EIP': namesBySourcePort['EIP']!.keys.toSet(),
  };
  final undefinedActivePorts = <String, List<int>>{};
  for (final source in ['DIO', 'PLC', 'EIP']) {
    final act = active[source] ?? <int>{};
    final def = definedPorts[source] ?? <int>{};
    final diff = act.difference(def).toList()..sort();
    if (diff.isNotEmpty) {
      undefinedActivePorts[source] = diff;
    }
  }
  if (undefinedActivePorts.isEmpty) {
    debugPrint(' Undefined ActivePorts: none');
  } else {
    debugPrint(' Undefined ActivePorts: $undefinedActivePorts');
  }
}

/// ZIQインポートテストモードを実行します
///
/// ZIQファイルから必要なファイルを読み込み、解析結果をコンソールに出力します。
/// テスト用の関数で、通常のアプリ実行時には呼び出されません。
Future<void> _runZiqImportTestMode() async {
  try {
    if (kZiqPath.isNotEmpty) {
      final files = await FileUtils.readRequiredFilesFromZip(kZiqPath);
      final ini = files['vxVisMgr.ini'];
      final dio = files['DioMonitorLog.csv'];
      final plc = files['Plc_DioMonitorLog.csv'];
      final fnl = files['FNL_DioMonitorLog.csv'];
      _printZiqFilesStatus(
        ziqLabel: '"$kZiqPath" ziqファイルパス',
        ini: ini,
        dio: dio,
        plc: plc,
        fnl: fnl,
      );
      await _runZiqImportTestFromContents(
        ini: ini,
        dio: dio,
        plc: plc,
        fnl: fnl,
      );
      io.exit(0);
    }

    final pickedFiles = await FileUtils.pickZiqAndReadRequiredFiles();
    if (pickedFiles == null) {
      debugPrint('ZIQ_IMPORT_TEST: ziqファイルが選択されていません');
      io.exit(2);
    }

    final ini = pickedFiles['vxVisMgr.ini'];
    final dio = pickedFiles['DioMonitorLog.csv'];
    final plc = pickedFiles['Plc_DioMonitorLog.csv'];
    final fnl = pickedFiles['FNL_DioMonitorLog.csv'];
    _printZiqFilesStatus(
      ziqLabel: 'ziqファイル選択',
      ini: ini,
      dio: dio,
      plc: plc,
      fnl: fnl,
    );
    await _runZiqImportTestFromContents(ini: ini, dio: dio, plc: plc, fnl: fnl);

    io.exit(0);
  } catch (e, st) {
    debugPrint('ZIQ_IMPORT_TEST: 信号データが存在しません: $e\n$st');
    io.exit(1);
  }
}

/// アプリケーションのルートウィジェット
///
/// テーマ設定、ローカライゼーション、言語設定を管理し、
/// MaterialAppを構築してアプリ全体の設定を行います。
class TimingChartGeneratorApp extends StatelessWidget {
  const TimingChartGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocaleNotifier, SettingsNotifier>(
      builder: (context, localeNotifier, settings, child) {
        final brightness =
            settings.darkMode ? Brightness.dark : Brightness.light;
        final baseTheme = ThemeData(brightness: brightness);
        return MaterialApp(
          title: 'Timing Chart Generator',
          theme: baseTheme.copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: settings.accentColor,
              brightness: brightness,
            ),
            scaffoldBackgroundColor: baseTheme.colorScheme.surface,
            textTheme: GoogleFonts.notoSansJpTextTheme(baseTheme.textTheme),
            appBarTheme: baseTheme.appBarTheme.copyWith(
              backgroundColor: settings.accentColor,
              titleTextStyle: GoogleFonts.notoSansJp(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
              filled: true,
              fillColor:
                  brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.white,
            ),
            dropdownMenuTheme: baseTheme.dropdownMenuTheme.copyWith(
              menuStyle: MenuStyle(
                backgroundColor: WidgetStateProperty.all(
                  brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.white,
                ),
              ),
            ),
          ),

          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          locale: localeNotifier.locale,

          home: const TimingChartGeneratorHomePage(),
        );
      },
    );
  }
}

class TimingChartGeneratorHomePage extends StatefulWidget {
  const TimingChartGeneratorHomePage({super.key});

  @override
  State<TimingChartGeneratorHomePage> createState() =>
      _TimingChartGeneratorHomePageState();
}

class _TimingChartGeneratorHomePageState
    extends State<TimingChartGeneratorHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _showIoNumbers = true;
  SharedPreferences? _prefs;

  late FormControllersNotifier _controllersNotifier;

  List<SignalData> _chartSignals = [];
  List<int> _chartPortNumbers = [];
  List<bool> _chartShowIoNumbers = [];
  List<IoChannelSource> _chartIoSources = [];
  List<TimingChartAnnotation> _chartAnnotations = [];
  late final TimingChartController _chartController;
  String _plcEipOption = 'None';

  bool _isImportingZiq = false;

  /// PLC/EIPオプションが無効な場合、関連するコントローラーをクリアします
  void _clearPlcEipControllersIfDisabled() {
    if (_plcEipOption == 'None') {
      for (final controller in _plcEipOutputControllers) {
        controller.clear();
      }
    }
  }

  final GlobalKey<TimingChartState> _timingChartKey =
      GlobalKey<TimingChartState>();

  final GlobalKey<FormTabState> _formTabKey = GlobalKey<FormTabState>();

  FormStateNotifier get _formNotifier =>
      Provider.of<FormStateNotifier>(context, listen: false);

  TimingFormState get _formState =>
      Provider.of<FormStateNotifier>(context, listen: false).state;

  /// フォーム状態の更新を次のフレーム後にスケジュールします
  ///
  /// ウィジェットのビルド中に状態を更新するのを避けるため、
  /// フレーム終了後に実行されるようにスケジュールします。
  void _scheduleFormUpdate(void Function(FormStateNotifier) edit) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) edit(_formNotifier);
    });
  }

  List<TextEditingController> get _inputControllers =>
      _controllersNotifier.inputControllers;
  List<TextEditingController> get _plcEipInputControllers =>
      _controllersNotifier.plcEipInputControllers;
  List<TextEditingController> get _outputControllers =>
      _controllersNotifier.outputControllers;
  List<TextEditingController> get _plcEipOutputControllers =>
      _controllersNotifier.plcEipOutputControllers;
  List<TextEditingController> get _hwTriggerControllers =>
      _controllersNotifier.hwTriggerControllers;

  Map<String, List<int>> _snapshotNameToValues() {
    final chart = _timingChartKey.currentState;
    final currentNames =
        chart?.getSignalIdNames() ?? _chartSignals.map((s) => s.name).toList();
    final currentValues =
        chart != null
            ? chart.getChartData()
            : _chartSignals.map((s) => s.values).toList();

    final nameToValues = <String, List<int>>{};
    for (int i = 0; i < currentNames.length; i++) {
      nameToValues[currentNames[i]] = List<int>.from(currentValues[i]);
    }
    return nameToValues;
  }

  void _commitNameToValues(Map<String, List<int>> nameToValues) {
    final updatedSignals =
        _chartSignals.map((signal) {
          final stored = nameToValues[signal.name];
          if (stored != null) {
            return signal.copyWith(values: stored);
          }
          return signal;
        }).toList();

    setState(() {
      _chartSignals = updatedSignals;
    });

    final form = _formTabKey.currentState;
    form?.registerExternalSignalValues(nameToValues);

    final chart = _timingChartKey.currentState;
    if (chart != null) {
      chart.updateSignalNames(updatedSignals.map((e) => e.name).toList());
      chart.updateSignals(updatedSignals.map((e) => e.values).toList());
    }
  }

  /// DIO入力とPLC/EIP入力を交換します
  ///
  /// 入力フィールドの値を交換し、対応するチャート信号の値も更新します。
  /// チャートとフォームの両方の状態を同期させます。
  Future<void> _transferInputs(
    List<TextEditingController> dioControllers,
    List<TextEditingController> plcControllers,
  ) async {
    final form = _formTabKey.currentState;
    final nameToValues = _snapshotNameToValues();

    final int len = math.min(dioControllers.length, plcControllers.length);
    for (int i = 0; i < len; i++) {
      final oldDioName = dioControllers[i].text.trim();
      final oldPlcName = plcControllers[i].text.trim();

      final dioValues = oldDioName.isNotEmpty ? nameToValues[oldDioName] : null;
      final plcValues = oldPlcName.isNotEmpty ? nameToValues[oldPlcName] : null;

      final tmp = dioControllers[i].text;
      dioControllers[i].text = plcControllers[i].text;
      plcControllers[i].text = tmp;

      final newDioName = dioControllers[i].text.trim();
      final newPlcName = plcControllers[i].text.trim();

      final defaultPlcName = _defaultPlcInputName(form?.plcOption, i);
      final defaultDioName = 'Input${i + 1}';

      if (dioValues != null) {
        final targetName = newPlcName.isNotEmpty ? newPlcName : defaultPlcName;
        if (targetName.isNotEmpty) {
          nameToValues[targetName] = dioValues;
        }
      }

      if (plcValues != null) {
        final targetName = newDioName.isNotEmpty ? newDioName : defaultDioName;
        if (targetName.isNotEmpty) {
          nameToValues[targetName] = plcValues;
        }
      }
    }

    _commitNameToValues(nameToValues);
  }

  /// DIO出力とPLC/EIP出力を交換します
  ///
  /// 出力フィールドの値を交換し、対応するチャート信号の値も更新します。
  /// チャートとフォームの両方の状態を同期させます。
  Future<void> _transferOutputs(
    List<TextEditingController> dioControllers,
    List<TextEditingController> plcControllers,
  ) async {
    final form = _formTabKey.currentState;
    final nameToValues = _snapshotNameToValues();

    final int len = math.min(dioControllers.length, plcControllers.length);
    for (int i = 0; i < len; i++) {
      final dioName = dioControllers[i].text.trim();
      final plcUser = plcControllers[i].text.trim();
      final plcName = form?.formatPlcLabel(i, plcUser) ?? plcUser;

      if (dioName.isEmpty && plcName.isEmpty) {
        continue;
      }

      final dioValues = nameToValues[dioName];
      final plcValues = nameToValues[plcName];

      if (dioValues != null) {
        nameToValues[plcName] = dioValues;
      }
      if (plcValues != null) {
        nameToValues[dioName] = plcValues;
      }

      final tmp = dioControllers[i].text;
      dioControllers[i].text = plcControllers[i].text;
      plcControllers[i].text = tmp;
    }

    _commitNameToValues(nameToValues);
  }

  /// チャートの信号が変更された際の処理を行います
  ///
  /// チャートから信号名、値、タイプが変更された際に呼び出されます。
  /// 既存の信号データを更新し、フォームの状態も同期させます。
  void _handleChartSignalsChanged(
    List<String> names,
    List<List<int>> values,
    List<SignalType> types,
  ) {
    final updatedSignals = ChartUpdateService.handleChartSignalsChanged(
      names: names,
      values: values,
      types: types,
      existingSignals: _chartSignals,
    );

    final nameToValues = <String, List<int>>{};
    for (int i = 0; i < names.length; i++) {
      nameToValues[names[i]] = List<int>.from(values[i]);
    }

    final form = _formTabKey.currentState;
    if (form != null && form.mounted) {
      form.registerExternalSignalValues(nameToValues);
      form.refreshSignalDataList();
    }

    setState(() {
      _chartSignals = updatedSignals;
      _chartShowIoNumbers = updatedSignals.map((s) => s.showIoNumber).toList();
    });
  }

  void _handleSignalShowIoNumberChanged(int originalIndex, bool showIoNumber) {
    if (originalIndex < 0 || originalIndex >= _chartSignals.length) return;
    setState(() {
      _chartSignals[originalIndex] = _chartSignals[originalIndex].copyWith(
        showIoNumber: showIoNumber,
      );
      _chartShowIoNumbers =
          _chartSignals.map((signal) => signal.showIoNumber).toList();
    });
  }

  /// PLC/EIPオプションに基づいてデフォルトの入力名を生成します
  ///
  /// [option]が'PLC'の場合は'PLI{index+1}'、'EIP'の場合は'ESI{index+1}'を返します。
  /// それ以外の場合は空文字列を返します。
  String _defaultPlcInputName(String? option, int index) {
    if (option == 'PLC') {
      return 'PLI${index + 1}';
    }
    if (option == 'EIP') {
      return 'ESI${index + 1}';
    }
    return '';
  }

  /// ウィジェットの初期化処理を行います
  ///
  /// タブコントローラー、フォーム状態、チャートコントローラーを初期化し、
  /// 初期値を設定します。
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // SettingsNotifier からデフォルトカメラ数を取得
    final settings = Provider.of<SettingsNotifier>(context, listen: false);

    final initial = TimingFormState(
      triggerOption: 'Single Trigger',
      ioPort: 32,
      hwPort: 0,
      camera: settings.defaultCameraCount,
      inputCount: 32,
      outputCount: 32,
    );

    _scheduleFormUpdate((n) => n.replace(initial));

    _controllersNotifier = Provider.of<FormControllersNotifier>(
      context,
      listen: false,
    );
    _controllersNotifier.initialize(
      inputCount: initial.inputCount,
      outputCount: initial.outputCount,
      hwTriggerCount: initial.hwPort,
    );

    _chartAnnotations = [];

    _chartController = TimingChartController.fromInitial(
      _chartSignals.map((s) => s.name).toList(),
      _chartSignals.map((s) => s.values).toList(),
      _chartAnnotations,
    );

    _tabController.addListener(_handleTabChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _formNotifier.replace(_formState);
    });

    _initPrefs();

    // SharedPreferences から設定が読み込まれたあとで、フォームのカメラ数も更新
    settings.initialized.then((_) {
      if (!mounted) return;
      _scheduleFormUpdate((n) {
        n.update(camera: settings.defaultCameraCount);
      });
    });
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs?.getBool('showIoNumbers');
    if (saved != null) {
      setState(() {
        _showIoNumbers = saved;
      });
    }
  }

  /// タブが変更された際の処理を行います
  ///
  /// チャートタブからフォームタブに戻る際はアノテーションを保存し、
  /// フォームタブからチャートタブに移動する際は信号データを更新します。
  void _handleTabChange() {
    if (_tabController.previousIndex == 1 && _tabController.index == 0) {
      if (_timingChartKey.currentState != null) {
        _chartAnnotations = List.from(_chartController.annotations);
      }

      debugPrint("信号データが存在します");
    }

    if (_tabController.previousIndex == 0 && _tabController.index == 1) {
      if (_timingChartKey.currentState != null) {
        _timingChartKey.currentState!.updateAnnotations(_chartAnnotations);

        if (_chartSignals.isNotEmpty) {
          final signalNames = _chartSignals.map((s) => s.name).toList();
          final signalValues = _chartSignals.map((s) => s.values).toList();
          _chartController.setSignalNames(signalNames);
          _chartController.setSignals(signalValues);
          _timingChartKey.currentState!.updateSignalNames(signalNames);
          _timingChartKey.currentState!.updateSignals(signalValues);
          debugPrint('信号データが存在します: ${signalNames.length}');
        }
      }
    }
  }

  /// 入力ポート数を更新します
  ///
  /// フォーム状態とコントローラーの数を更新します。
  void _updateInputCount(int inputPorts) {
    _scheduleFormUpdate((n) {
      n.update(ioPort: inputPorts, inputCount: inputPorts);
    });
    _controllersNotifier.setInputCount(inputPorts);
  }

  /// 出力ポート数を更新します
  ///
  /// フォーム状態とコントローラーの数を更新します。
  void _updateOutputCount(int outputPorts) {
    _scheduleFormUpdate((n) {
      n.update(outputCount: outputPorts);
    });
    _controllersNotifier.setOutputCount(outputPorts);
  }

  /// ハードウェアトリガーコントローラーの数を更新します
  ///
  /// [desiredCount]が指定されていない場合は現在のフォーム状態の値を使用します。
  void _updateHwTriggerControllers([int? desiredCount]) {
    final target = desiredCount ?? _formState.hwPort;
    _controllersNotifier.setHwTriggerCount(target);
  }

  /// すべてのテキストフィールドとチャートデータをクリアします
  ///
  /// フォームの入力フィールド、チャート信号、アノテーションをすべて初期状態に戻します。
  void _clearAllTextFields() {
    _controllersNotifier.clearAllTexts();

    setState(() {
      _chartSignals.clear();
      _chartPortNumbers.clear();
      _chartShowIoNumbers.clear();
      _chartIoSources.clear();
      _chartAnnotations.clear();
    });

    if (_timingChartKey.currentState != null) {
      _timingChartKey.currentState!.updateSignalNames([]);
      _timingChartKey.currentState!.updateSignals([]);

      _timingChartKey.currentState!.updateAnnotations([]);
    }

    _scheduleFormUpdate((n) {
      final settings = Provider.of<SettingsNotifier>(context, listen: false);
      n.replace(
        TimingFormState(
          triggerOption: 'Single Trigger',
          ioPort: 32,
          hwPort: 0,
          camera: settings.defaultCameraCount,
          inputCount: 32,
          outputCount: 32,
        ),
      );
    });

    _controllersNotifier.setInputCount(32);
    _controllersNotifier.setOutputCount(32);
    _controllersNotifier.setHwTriggerCount(0);
  }

  /// PLC/EIPオプションに基づいてIOチャネルソースを解決します
  ///
  /// [allowUnknown]がtrueの場合、オプションが'None'のときはunknownを返します。
  /// falseの場合はdioを返します。
  IoChannelSource _resolvePlcEipSource({bool allowUnknown = false}) {
    if (_plcEipOption == 'PLC') return IoChannelSource.plc;
    if (_plcEipOption == 'EIP') return IoChannelSource.eip;
    return allowUnknown ? IoChannelSource.unknown : IoChannelSource.dio;
  }

  /// ラベルからプレフィックスを抽出します
  ///
  /// コロン(:)またはスペースで区切られた最初の部分を返します。
  /// 区切り文字がない場合はラベル全体を返します。
  String _extractLabelPrefix(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '';
    final colonIdx = trimmed.indexOf(':');
    if (colonIdx != -1) {
      return trimmed.substring(0, colonIdx);
    }
    final spaceIdx = trimmed.indexOf(' ');
    if (spaceIdx != -1) {
      return trimmed.substring(0, spaceIdx);
    }
    return trimmed;
  }

  /// ラベルに一致するコントローラーのインデックスを検索します
  ///
  /// 完全一致を最初に試し、コロン(:)で区切られた場合の後半部分でも検索します。
  /// 見つからない場合は-1を返します。
  int _findControllerIndexByLabel(
    String label,
    List<TextEditingController> controllers,
  ) {
    final target = label.trim();
    for (int i = 0; i < controllers.length; i++) {
      if (controllers[i].text.trim() == target) {
        return i;
      }
    }
    final colonIdx = target.indexOf(':');
    if (colonIdx != -1) {
      final suffix = target.substring(colonIdx + 1).trim();
      if (suffix.isNotEmpty) {
        for (int i = 0; i < controllers.length; i++) {
          if (controllers[i].text.trim() == suffix) {
            return i;
          }
        }
      }
    }
    return -1;
  }

  /// プレフィックス文字列からIOチャネルソースを判定します
  ///
  /// プレフィックスの先頭文字列（PLI/PLO/ESI/ESO/INPUT/OUTPUTなど）に基づいて
  /// 適切なIOチャネルソースを返します。
  IoChannelSource _sourceFromPrefix(String prefixUpper, SignalType type) {
    if (prefixUpper.startsWith('PLIN') ||
        prefixUpper.startsWith('PLI') ||
        prefixUpper.startsWith('PLON') ||
        prefixUpper.startsWith('PLO')) {
      return IoChannelSource.plc;
    }
    if (prefixUpper.startsWith('ESIN') ||
        prefixUpper.startsWith('ESI') ||
        prefixUpper.startsWith('ESON') ||
        prefixUpper.startsWith('ESO')) {
      return IoChannelSource.eip;
    }
    if (prefixUpper.startsWith('PLC/EIP')) {
      return IoChannelSource.plcEip;
    }
    if (prefixUpper.startsWith('INPUT') || prefixUpper.startsWith('OUTPUT')) {
      return IoChannelSource.dio;
    }
    return IoChannelSource.unknown;
  }

  /// ラベルと信号タイプからIOチャネルソースを検出します
  ///
  /// まずプレフィックスから判定を試み、それでも不明な場合は
  /// コントローラーのリストを検索して判定します。
  IoChannelSource _detectIoSourceFor(String label, SignalType type) {
    if (type != SignalType.input && type != SignalType.output) {
      return IoChannelSource.unknown;
    }

    final prefix = _extractLabelPrefix(label).toUpperCase();
    final prefSource = _sourceFromPrefix(prefix, type);
    if (prefSource != IoChannelSource.unknown) {
      if (prefSource == IoChannelSource.plcEip) {
        return _resolvePlcEipSource(allowUnknown: true);
      }
      return prefSource;
    }

    if (type == SignalType.input) {
      if (_findControllerIndexByLabel(label, _inputControllers) != -1) {
        return IoChannelSource.dio;
      }
      if (_findControllerIndexByLabel(label, _plcEipInputControllers) != -1) {
        return _resolvePlcEipSource(allowUnknown: true);
      }
    } else if (type == SignalType.output) {
      if (_findControllerIndexByLabel(label, _outputControllers) != -1) {
        return IoChannelSource.dio;
      }
      if (_findControllerIndexByLabel(label, _plcEipOutputControllers) != -1) {
        return _resolvePlcEipSource(allowUnknown: true);
      }
    }

    return IoChannelSource.unknown;
  }

  void _showExportResultSnackBar({
    required bool success,
    required String successMessage,
    required String failureMessage,
    String? savedPath,
  }) {
    if (!mounted) return;
    final s = S.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? successMessage : failureMessage),
        duration: const Duration(seconds: 3),
        persist: false,
        showCloseIcon: true,
        action:
            success && savedPath != null && !kIsWeb
                ? SnackBarAction(
                  label: s.export_open_folder,
                  onPressed: () => revealFileInFileManager(savedPath),
                )
                : null,
      ),
    );
  }

  /// アプリケーション設定をJSONファイルとしてエクスポートします
  ///
  /// フォーム状態、チャートデータ、アノテーションなどの設定を
  /// すべてJSON形式でファイルに保存します。
  Future<void> _exportConfig() async {
    // チャートアノテーションを更新
    _chartAnnotations = List.from(_chartController.annotations);

    String? savedPath;
    final success = await ExportService.exportConfig(
      context: context,
      tabIndex: _tabController.index,
      formState: _formState,
      chartSignals: _chartSignals,
      chartController: _chartController,
      chartAnnotations: _chartAnnotations,
      formTabState: _formTabKey.currentState,
      timingChartState: _timingChartKey.currentState,
      inputControllers: _inputControllers,
      outputControllers: _outputControllers,
      hwTriggerControllers: _hwTriggerControllers,
      timeUnitIsMs:
          Provider.of<SettingsNotifier>(context, listen: false).timeUnitIsMs,
      msPerStep:
          Provider.of<SettingsNotifier>(context, listen: false).msPerStep,
      stepDurationsMs:
          Provider.of<SettingsNotifier>(context, listen: false).stepDurationsMs,
      onExported: (path) => savedPath = path,
    );

    if (!mounted) return;
    final s = S.of(context);
    _showExportResultSnackBar(
      success: success,
      successMessage: s.export_success_json,
      failureMessage: s.export_failed_json,
      savedPath: savedPath,
    );
  }

  /// JSONファイルからアプリケーション設定をインポートします
  ///
  /// 保存された設定ファイルを読み込み、フォーム状態、チャートデータ、
  /// アノテーションなどを復元します。
  Future<void> _importConfig() async {
    final config = await FileUtils.importAppConfig();

    if (config == null) {
      return;
    }
    if (!mounted) return;

    final formState = _formTabKey.currentState;
    formState?.clearAllForImport();

    _scheduleFormUpdate((n) => n.replace(config.formState));

    _controllersNotifier.setInputCount(config.formState.inputCount);
    _controllersNotifier.setOutputCount(config.formState.outputCount);
    _updateHwTriggerControllers(config.formState.hwPort);

    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    settings.timeUnitIsMs = config.timeUnitIsMs;
    settings.msPerStep = config.msPerStep;
    if (config.stepDurationsMs.isNotEmpty) {
      settings.setStepDurationsMs(config.stepDurationsMs);
    }

    for (
      int i = 0;
      i < config.inputNames.length && i < _inputControllers.length;
      i++
    ) {
      _inputControllers[i].text = config.inputNames[i];
    }

    for (
      int i = 0;
      i < config.outputNames.length && i < _outputControllers.length;
      i++
    ) {
      _outputControllers[i].text = config.outputNames[i];
    }

    for (
      int i = 0;
      i < config.hwTriggerNames.length && i < _hwTriggerControllers.length;
      i++
    ) {
      _hwTriggerControllers[i].text = config.hwTriggerNames[i];
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final form = _formTabKey.currentState;
      if (form != null) {
        form.updateFromAppConfig(config);
      }

      _chartAnnotations = config.annotations;
      if ((config.annotations.isNotEmpty ||
              config.omissionIndices.isNotEmpty) &&
          _timingChartKey.currentState != null) {
        _timingChartKey.currentState!.updateAnnotations(_chartAnnotations);
        _timingChartKey.currentState!.setOmission(config.omissionIndices);
      }
    });

    if (!mounted) {
      return;
    }

    final s = S.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.import_success_config),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 別チャートの JSON を現在のチャート末尾へ結合します
  Future<void> _concatChartToTail() async {
    final s = S.of(context);
    final picked = await FileUtils.pickAppConfigFile();
    if (!mounted) return;
    if (picked == null) return;
    if (picked.config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.concat_failed_load)),
      );
      return;
    }

    final incoming = picked.config!;
    if (incoming.signals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.concat_failed_empty)),
      );
      return;
    }

    final nameToValues = _snapshotNameToValues();
    final currentSignals =
        _chartSignals.map((signal) {
          final stored = nameToValues[signal.name];
          return stored != null ? signal.copyWith(values: stored) : signal;
        }).toList();
    final currentAnnotations =
        _timingChartKey.currentState?.getAnnotations() ??
        List<TimingChartAnnotation>.from(_chartController.annotations);
    final currentOmissions =
        _timingChartKey.currentState?.getOmissionTimeIndices() ??
        List<int>.from(_chartController.omissionTimeIndices);
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    final currentDurations =
        (_chartController.stepDurationsMs.isNotEmpty)
            ? _chartController.stepDurationsMs
            : settings.stepDurationsMs;

    final preview = ChartConcatService.preview(
      currentSignals: currentSignals,
      incomingSignals: incoming.signals,
      currentTimeUnitIsMs: settings.timeUnitIsMs,
      incomingTimeUnitIsMs: incoming.timeUnitIsMs,
    );

    if (preview.timeUnitMismatch) {
      final proceed = await ChartConcatDialogs.confirmTimeUnitMismatch(context);
      if (!mounted || !proceed) return;
    }

    var policy = UnmatchedIncomingPolicy.padAndAdd;
    if (preview.currentLength > 0 && preview.incomingOnlyNames.isNotEmpty) {
      final chosen = await ChartConcatDialogs.chooseUnmatchedPolicy(
        context: context,
        incomingOnlyNames: preview.incomingOnlyNames,
      );
      if (!mounted || chosen == null) return;
      policy = chosen;
    }

    final joinLabel = _stripFileExtension(picked.fileName);
    final result = ChartConcatService.concat(
      currentSignals: currentSignals,
      currentAnnotations: currentAnnotations,
      currentOmissions: currentOmissions,
      currentStepDurationsMs: currentDurations,
      currentMsPerStep: settings.msPerStep,
      currentTimeUnitIsMs: settings.timeUnitIsMs,
      incoming: incoming,
      unmatchedPolicy: policy,
      joinLabel: joinLabel.isEmpty ? s.concat_join_default : joinLabel,
    );

    if (policy == UnmatchedIncomingPolicy.padAndAdd) {
      _expandFormSlotsForConcat(result.signals);
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
      _formTabKey.currentState?.mergeIncomingSignalNames(result.signals);
    }

    final form = _formTabKey.currentState;
    final valuesByName = <String, List<int>>{
      for (final signal in result.signals) signal.name: List<int>.from(signal.values),
    };
    form?.registerExternalSignalValues(valuesByName);
    form?.setChartDataOnly(
      result.signals.map((signal) => List<int>.from(signal.values)).toList(),
    );
    form?.refreshSignalDataList();

    final names = result.signals.map((signal) => signal.name).toList();
    final values = result.signals.map((signal) => List<int>.from(signal.values)).toList();
    final durationsToApply =
        settings.timeUnitIsMs
            ? result.stepDurationsMs
            : List<double>.from(_chartController.stepDurationsMs);

    _chartController.applyFullState(
      signals: values,
      signalNames: names,
      annotations: result.annotations,
      omissionTimeIndices: result.omissionIndices,
      stepDurationsMs: durationsToApply,
    );
    if (settings.timeUnitIsMs) {
      settings.setStepDurationsMs(result.stepDurationsMs);
    }

    setState(() {
      _chartSignals = result.signals;
      _chartPortNumbers = _portNumbersForSignals(result.signals);
      _chartShowIoNumbers =
          result.signals.map((signal) => signal.showIoNumber).toList();
      _chartIoSources =
          result.signals
              .map((signal) => _detectIoSourceFor(signal.name, signal.signalType))
              .toList();
      _chartAnnotations = result.annotations;
    });

    _chartController.requestGridRecompute();
    if (_tabController.index != 1) {
      _tabController.animateTo(1);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.concat_success)),
    );
  }

  String _stripFileExtension(String fileName) {
    final base = fileName.replaceAll('\\', '/').split('/').last.trim();
    if (base.isEmpty) return '';
    final dot = base.lastIndexOf('.');
    if (dot <= 0) return base;
    return base.substring(0, dot);
  }

  int _nextPortOption(int needed) {
    for (final option in FormTabRules.portOptions) {
      if (option >= needed) return option;
    }
    return FormTabRules.portOptions.last;
  }

  int _emptyControllerCount(List<TextEditingController> controllers) {
    return controllers.where((c) => c.text.trim().isEmpty).length;
  }

  void _expandFormSlotsForConcat(List<SignalData> mergedSignals) {
    final currentNames = _chartSignals.map((s) => s.name).toSet();
    currentNames.addAll(
      [
        ..._inputControllers,
        ..._plcEipInputControllers,
        ..._outputControllers,
        ..._plcEipOutputControllers,
        ..._hwTriggerControllers,
      ].map((c) => c.text).where((name) => name.trim().isNotEmpty),
    );

    bool isInputType(SignalData signal) =>
        signal.signalType == SignalType.input ||
        signal.signalType == SignalType.control ||
        signal.signalType == SignalType.group ||
        signal.signalType == SignalType.task;

    final unmatchedInputs =
        mergedSignals.where((signal) {
          if (currentNames.contains(signal.name)) return false;
          if (FormTabControllerMapper.shouldSkipChartToControllerAssignment(
            formState: _formState,
            name: signal.name,
          )) {
            return false;
          }
          return isInputType(signal);
        }).length;
    final unmatchedOutputs =
        mergedSignals.where((signal) {
          if (currentNames.contains(signal.name)) return false;
          return signal.signalType == SignalType.output;
        }).length;
    final unmatchedHw =
        mergedSignals.where((signal) {
          if (currentNames.contains(signal.name)) return false;
          return signal.signalType == SignalType.hwTrigger;
        }).length;

    final neededInput = _nextPortOption(
      _formState.inputCount +
          math.max(0, unmatchedInputs - _emptyControllerCount(_inputControllers)),
    );
    final neededOutput = _nextPortOption(
      _formState.outputCount +
          math.max(
            0,
            unmatchedOutputs - _emptyControllerCount(_outputControllers),
          ),
    );
    if (neededInput > _formState.inputCount) {
      _formNotifier.update(ioPort: neededInput, inputCount: neededInput);
      _controllersNotifier.setInputCount(neededInput);
    }
    if (neededOutput > _formState.outputCount) {
      _formNotifier.update(outputCount: neededOutput);
      _controllersNotifier.setOutputCount(neededOutput);
    }
    if (unmatchedHw > _emptyControllerCount(_hwTriggerControllers) &&
        _formState.hwPort == 0 &&
        _formState.camera > 0) {
      _formNotifier.update(hwPort: _formState.camera);
      _updateHwTriggerControllers(_formState.camera);
    }
  }

  List<int> _portNumbersForSignals(List<SignalData> signals) {
    final existingByName = <String, int>{};
    for (int i = 0; i < _chartSignals.length && i < _chartPortNumbers.length; i++) {
      existingByName[_chartSignals[i].name] = _chartPortNumbers[i];
    }

    final form = _formTabKey.currentState;
    final formByName = <String, int>{};
    if (form != null) {
      final names = form.generateSignalNames();
      final ports = form.generatePortNumbers();
      for (int i = 0; i < names.length && i < ports.length; i++) {
        formByName[names[i]] = ports[i];
      }
    }

    return signals
        .map((signal) => existingByName[signal.name] ?? formByName[signal.name] ?? 0)
        .toList();
  }

  /// チャートをJPEG画像としてエクスポートします
  ///
  /// 現在表示されているタイミングチャートを画像ファイルとして保存します。
  Future<void> _exportChartImageJpeg() async {
    String? savedPath;
    final success = await ExportService.exportChartImageJpeg(
      context: context,
      timingChartState: _timingChartKey.currentState,
      onExported: (path) => savedPath = path,
    );

    if (!mounted) return;
    final s = S.of(context);
    _showExportResultSnackBar(
      success: success,
      successMessage: s.export_success_jpeg,
      failureMessage: s.export_failed_jpeg,
      savedPath: savedPath,
    );
  }

  /// チャートデータをXLSX形式でエクスポートします
  ///
  /// 信号データ、アノテーション、省略情報などをExcel形式で保存します。
  Future<void> _exportXlsx() async {
    String? savedPath;
    final latestAnnotations =
        _timingChartKey.currentState?.getAnnotations() ??
        List<TimingChartAnnotation>.from(_chartController.annotations);
    _chartAnnotations = List<TimingChartAnnotation>.from(latestAnnotations);

    final success = await ExportService.exportXlsx(
      context: context,
      chartSignals: _chartSignals,
      chartPortNumbers: _chartPortNumbers,
      chartController: _chartController,
      inputControllers: _inputControllers,
      outputControllers: _outputControllers,
      hwTriggerControllers: _hwTriggerControllers,
      formTabState: _formTabKey.currentState,
      timingChartState: _timingChartKey.currentState,
      chartAnnotations: latestAnnotations,
      omissionIndices:
          _timingChartKey.currentState?.getOmissionTimeIndices() ?? [],
      onExported: (path) => savedPath = path,
    );

    if (!mounted) return;
    final s = S.of(context);
    _showExportResultSnackBar(
      success: success,
      successMessage: s.export_success_xlsx,
      failureMessage: s.export_failed_xlsx,
      savedPath: savedPath,
    );
  }

  /// バージョン情報を読み込みます
  ///
  /// assetsフォルダからVERSION.jsonファイルを読み込み、タイトルとバージョン番号を返します。
  /// 読み込みに失敗した場合はデフォルト値を返します。
  Future<Map<String, String>> _loadVersionInfo() async {
    try {
      final versionJson = await rootBundle.loadString('assets/VERSION.json');
      final versionData = json.decode(versionJson) as Map<String, dynamic>;
      return {
        'title': versionData['title'] as String? ?? 'バージョン情報',
        'version': versionData['version'] as String? ?? 'vX.Y.Z',
      };
    } catch (e) {
      debugPrint('VERSION.jsonファイルの読み込みに失敗しました: $e');
      return {'title': 'バージョン情報', 'version': 'vX.Y.Z'};
    }
  }

  /// CHANGELOGファイルを読み込みます
  ///
  /// assetsフォルダからCHANGELOG.mdファイルを読み込み、内容を返します。
  /// 読み込みに失敗した場合はデフォルトのメッセージを返します。
  Future<String> _loadChangelog() async {
    try {
      final changelog = await rootBundle.loadString('assets/CHANGELOG.md');
      return changelog;
    } catch (e) {
      debugPrint('CHANGELOGファイルの読み込みに失敗しました: $e');
      return '変更点の読み込みに失敗しました。';
    }
  }

  /// バージョン情報ダイアログを表示します
  ///
  /// VERSION.jsonとCHANGELOG.mdファイルを読み込んでからVersionInfoDialogを表示します。
  Future<void> _showVersionInfoDialog(BuildContext context) async {
    final versionInfo = await _loadVersionInfo();
    final changelog = await _loadChangelog();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder:
          (ctx) => VersionInfoDialog(
            title: versionInfo['title']!,
            version: versionInfo['version']!,
            changelog: changelog,
          ),
    );
  }

  void _showGlobalHelpDialog(BuildContext context) {
    final int initialTab = _tabController.index.clamp(0, 1);
    showDialog(
      context: context,
      builder: (_) => GlobalHelpDialog(initialTabIndex: initialTab),
    );
  }

  List<Widget> _buildAppBarActions(S s) {
    final locale = Provider.of<LocaleNotifier>(context).locale;
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                locale.languageCode == 'ja'
                    ? 'JP'
                    : locale.languageCode.toUpperCase(),
                style: GoogleFonts.notoSansJp(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: s.menu_help,
                icon: const Icon(Icons.help_outline),
                color: Colors.white,
                visualDensity: VisualDensity.compact,
                onPressed: () => _showGlobalHelpDialog(context),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildImportingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha((0.35 * 255).round()),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'ZIPファイルが正常にインポートされました...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ウィジェットの破棄処理を行います
  ///
  /// タブコントローラーとすべてのテキストコントローラーを破棄します。
  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    for (var controller in _inputControllers) {
      controller.dispose();
    }
    for (var controller in _outputControllers) {
      controller.dispose();
    }
    for (var controller in _hwTriggerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// ウィジェットツリーを構築します
  ///
  /// アプリバー、ドロワー、タブビューを含むメインUIを構築します。
  /// ZIQインポート中はローディングオーバーレイを表示します。
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(s.appTitle),
        actions: _buildAppBarActions(s),

        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.notoSansJp(fontSize: 20),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 6.0,
          tabs: [
            Tab(text: s.formTabTitle, icon: Icon(Icons.input)),
            Tab(text: s.chartTabTitle, icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                s.appTitle,
                style: GoogleFonts.notoSansJp(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            ListTile(
              leading: Icon(Icons.file_download),
              title: Text(s.drawer_import),
              onTap: () {
                Navigator.pop(context);
                _importConfig();
              },
            ),

            ListTile(
              leading: Icon(Icons.add_to_photos_outlined),
              title: Text(s.drawer_concat_chart),
              onTap: () {
                Navigator.pop(context);
                _concatChartToTail();
              },
            ),

            ListTile(
              leading: Icon(Icons.archive_outlined),
              title: Text(s.drawer_import_ziq),
              onTap: () async {
                Navigator.pop(context);
                final files = await FileUtils.pickZiqAndReadRequiredFiles();
                if (!context.mounted) return;
                if (files == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(s.drawer_import_ziq_cancelled),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                setState(() => _isImportingZiq = true);

                if (_formTabKey.currentState != null) {
                  _formTabKey.currentState!.clearAllForImport();
                }
                try {
                  // ZIQインポートサービスの使用
                  final result = await ZiqImportService.importZiq(
                    files: files,
                    currentFormState: _formState,
                    controllersNotifier: _controllersNotifier,
                    chartController: _chartController,
                    formTabState: _formTabKey.currentState,
                  );

                  if (!context.mounted) return;

                  // フォーム状態の更新
                  if (result.inputPorts != null &&
                      result.inputPorts! > 0 &&
                      result.inputPorts != _formState.inputCount) {
                    _updateInputCount(result.inputPorts!);
                  }
                  if (result.outputPorts != null &&
                      result.outputPorts! > 0 &&
                      result.outputPorts != _formState.outputCount) {
                    _updateOutputCount(result.outputPorts!);
                  }

                  // 状態の更新
                  setState(() {
                    _plcEipOption = result.plcEipOption;
                    _chartSignals = result.chartSignals;
                    _chartPortNumbers = result.chartPortNumbers;
                    _chartShowIoNumbers =
                        result.chartSignals.map((s) => s.showIoNumber).toList();
                    _chartIoSources = result.chartIoSources;
                  });

                  // トリガーオプション・VirtualIO フラグの更新（チャート反映前に同期適用）
                  _formNotifier.update(
                    triggerOption: result.triggerOption,
                    codeTriggerOnPlcEip: result.codeTriggerOnPlcEip,
                    useDioTriggerPortWithVirtualIo:
                        result.useDioTriggerPortWithVirtualIo,
                  );

                  // PLC/EIPオプションの設定
                  if (_formTabKey.currentState != null) {
                    _formTabKey.currentState!.setPlcEipOption(
                      result.plcEipOption,
                    );
                  }
                  _clearPlcEipControllersIfDisabled();

                  // ステップ継続時間の設定
                  if (result.stepDurationsMs.isNotEmpty) {
                    if (!context.mounted) return;
                    final settings = Provider.of<SettingsNotifier>(
                      context,
                      listen: false,
                    );

                    final double sumMs = result.stepDurationsMs
                        .where((e) => e.isFinite && e > 0)
                        .fold<double>(0.0, (a, b) => a + b);
                    final double avgMs = sumMs / result.stepDurationsMs.length;
                    if (avgMs.isFinite && avgMs > 0) {
                      settings.msPerStep = avgMs;
                    }

                    final int maxLen =
                        result.chartSignals.isNotEmpty
                            ? result.chartSignals[0].values.length
                            : 0;
                    if (result.stepDurationsMs.length != maxLen) {
                      final List<double> fixed = List<double>.from(
                        result.stepDurationsMs,
                      );
                      if (fixed.length < maxLen) {
                        fixed.addAll(
                          List<double>.filled(
                            maxLen - fixed.length,
                            settings.msPerStep,
                          ),
                        );
                      } else if (fixed.length > maxLen) {
                        fixed.removeRange(maxLen, fixed.length);
                      }
                      settings.setStepDurationsMs(fixed);
                      _chartController.setStepDurationsMs(fixed);
                    } else {
                      settings.setStepDurationsMs(result.stepDurationsMs);
                      _chartController.setStepDurationsMs(
                        result.stepDurationsMs,
                      );
                    }
                  }

                  // 時間単位の設定
                  if (!context.mounted) return;
                  Provider.of<SettingsNotifier>(context, listen: false)
                      .timeUnitIsMs = true;

                  // チャートデータの更新
                  if (result.chartSignals.isNotEmpty) {
                    final signalNames =
                        result.chartSignals.map((s) => s.name).toList();
                    final signalValues =
                        result.chartSignals.map((s) => s.values).toList();
                    final signalTypes =
                        result.chartSignals.map((s) => s.signalType).toList();

                    if (_formTabKey.currentState != null) {
                      _formTabKey.currentState!.setChartDataOnly(signalValues);
                      _formTabKey.currentState!.updateSignalDataFromChartData(
                        signalValues,
                        signalNames,
                        signalTypes,
                      );
                      _formTabKey.currentState!.refreshSignalDataList();
                    }

                    if (_timingChartKey.currentState != null) {
                      // 表示名の生成
                      final Map<String, int> nameToPortForLabel = {};
                      for (int i = 0; i < result.chartSignals.length; i++) {
                        final signal = result.chartSignals[i];
                        if (signal.signalType == SignalType.output &&
                            i < result.chartPortNumbers.length) {
                          nameToPortForLabel[signal.name] =
                              result.chartPortNumbers[i];
                        }
                      }

                      final List<String> displayNames = List.generate(
                        signalNames.length,
                        (i) {
                          final name = signalNames[i];
                          final type = signalTypes[i];
                          if (type != SignalType.output) {
                            return name;
                          }
                          final port = nameToPortForLabel[name] ?? 0;
                          final src = result.plcEipOption;
                          String prefix;
                          if (src == 'PLC') {
                            prefix = 'PLO';
                          } else if (src == 'EIP') {
                            prefix = 'ESO';
                          } else {
                            prefix = 'Output';
                          }
                          if (port > 0) {
                            return '$prefix$port: $name';
                          }
                          return name;
                        },
                      );

                      _timingChartKey.currentState!.updateSignalNames(
                        displayNames,
                      );
                      _timingChartKey.currentState!.updateSignals(signalValues);
                    }

                    _chartController.setSignalNames(signalNames);
                    _chartController.setSignals(signalValues);
                  }

                  // Code Trigger 個別ビット変化コメントを適用
                  _chartAnnotations =
                      List<TimingChartAnnotation>.from(result.chartAnnotations);
                  _chartController.setAnnotations(_chartAnnotations);
                  if (_timingChartKey.currentState != null) {
                    _timingChartKey.currentState!.updateAnnotations(
                      _chartAnnotations,
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _chartController.requestGridRecompute();
                      setState(() {});
                    }
                  });

                  // スナックバーの表示

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'ZIPファイルが正常にインポートされました: '
                        'vxVisMgr.ini:${result.vxVisMgrIniContent != null ? 'OK' : 'vxVisMgr.iniが見つかりません'}  '
                        'DioMonitorLog.csv:${result.dioMonitorLogCsvContent != null ? 'OK' : 'DioMonitorLog.csvが見つかりません'}  '
                        'Plc_DioMonitorLog.csv:${result.plcDioMonitorLogCsvContent != null ? 'OK' : 'Plc_DioMonitorLog.csvが見つかりません'}  '
                        'FNL_DioMonitorLog.csv:${result.fnlDioMonitorLogCsvContent != null ? 'OK' : 'FNL_DioMonitorLog.csvが見つかりません'}  '
                        'EnabledSignals:${result.enabledStatusSignals.length}  '
                        'DioMap:${result.dioOutputAssignments.length}  '
                        'PlcEipMap:${result.plcEipOutputAssignments.length}',
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );

                  // 出力数の更新が必要な場合
                  int maxIndex = 0;
                  for (final a in result.dioOutputAssignments) {
                    if (a.outputIndex1Based > maxIndex) {
                      maxIndex = a.outputIndex1Based;
                    }
                  }
                  if (maxIndex > _formState.outputCount) {
                    _updateOutputCount(maxIndex);
                    await SchedulerBinding.instance.endOfFrame;
                  }
                } finally {
                  if (mounted) setState(() => _isImportingZiq = false);
                }
              },
            ),

            ListTile(
              leading: Icon(Icons.file_upload),
              title: Text(s.drawer_export),
              onTap: () {
                Navigator.pop(context);
                _exportConfig();
              },
            ),

            ListTile(
              leading: Icon(Icons.image_outlined),
              title: Text(s.drawer_export_chart_jpeg),
              onTap: () {
                Navigator.pop(context);
                _exportChartImageJpeg();
              },
            ),

            ListTile(
              leading: Icon(Icons.table_chart),
              title: Text(s.drawer_export_xlsx),
              onTap: () {
                Navigator.pop(context);
                _exportXlsx();
              },
            ),
            Divider(),

            ListTile(
              leading: Icon(Icons.language),
              title: Text(s.language_english),
              onTap: () {
                setSuggestionLanguage(SuggestionLanguage.en);
                Provider.of<LocaleNotifier>(
                  context,
                  listen: false,
                ).setLocale(const Locale('en'));
                Navigator.pop(context);
                setState(() {});
              },
            ),
            ListTile(
              leading: Icon(Icons.language),
              title: Text(s.language_japanese),
              onTap: () {
                setSuggestionLanguage(SuggestionLanguage.ja);
                Provider.of<LocaleNotifier>(
                  context,
                  listen: false,
                ).setLocale(const Locale('ja'));
                Navigator.pop(context);
                setState(() {});
              },
            ),
            Divider(),

            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(s.drawer_preferences),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => SettingsWindow(
                          showIoNumbers: _showIoNumbers,
                          onShowIoNumbersChanged: (val) {
                            setState(() => _showIoNumbers = val);
                            _prefs?.setBool('showIoNumbers', val);
                          },
                        ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.help),
              title: Text(s.menu_help),
              onTap: () {
                Navigator.pop(context);
                _showGlobalHelpDialog(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.info),
              title: Text(s.menu_item_about),
              onTap: () async {
                Navigator.pop(context);
                await _showVersionInfoDialog(context);
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              FormTab(
                key: _formTabKey,
                hasChartBaseline: _chartSignals.isNotEmpty,
                inputControllers: _inputControllers,
                plcEipInputControllers: _plcEipInputControllers,
                outputControllers: _outputControllers,
                plcEipOutputControllers: _plcEipOutputControllers,
                hwTriggerControllers: _hwTriggerControllers,
                controllersNotifier: _controllersNotifier,
                onTriggerOptionChanged: (String? newValue) {
                  if (newValue != null) {
                    _scheduleFormUpdate(
                      (n) => n.update(triggerOption: newValue),
                    );
                  }
                },
                onPlcEipOptionChanged: (String? newValue) {
                  if (newValue == null) return;
                  setState(() => _plcEipOption = newValue);
                  _clearPlcEipControllersIfDisabled();
                },

                onInputPortChanged: (int? newValue) {
                  if (newValue != null && newValue != _formState.inputCount) {
                    _updateInputCount(newValue);
                  }
                },

                onOutputPortChanged: (int? newValue) {
                  if (newValue != null && newValue != _formState.outputCount) {
                    _updateOutputCount(newValue);
                  }
                },
                onHwPortChanged: (int? newValue) {
                  if (newValue != null && newValue != _formState.hwPort) {
                    _scheduleFormUpdate((n) {
                      n.update(hwPort: newValue);

                      setState(() => _updateHwTriggerControllers(newValue));
                    });
                  }
                },
                onCameraChanged: (int? newValue) {
                  if (newValue != null) {
                    _scheduleFormUpdate((n) => n.update(camera: newValue));
                  }
                },
                onTransferInputs: _transferInputs,
                onTransferOutputs: _transferOutputs,
                onUpdateChart: (
                  signalNames,
                  chartData,
                  signalTypes,
                  portNumbers,
                  ioSources,
                  bool overrideFlag,
                ) {
                  // チャート更新サービスの使用
                  final result = ChartUpdateService.updateChart(
                    signalNames: signalNames,
                    chartData: chartData,
                    signalTypes: signalTypes,
                    portNumbers: portNumbers,
                    ioSources: ioSources,
                    overrideFlag: overrideFlag,
                    existingSignals: _chartSignals,
                    chartController: _chartController,
                    timingChartState: _timingChartKey.currentState,
                    detectIoSource: _detectIoSourceFor,
                  );

                  setState(() {
                    _chartSignals = result.signals;
                    _chartPortNumbers = result.portNumbers;
                    _chartShowIoNumbers =
                        result.signals.map((s) => s.showIoNumber).toList();
                    _chartIoSources = result.ioSources;

                    if (_timingChartKey.currentState != null) {
                      final orderedNames =
                          _chartSignals.map((s) => s.name).toList();
                      _chartController.setSignalNames(orderedNames);
                      _chartController.setSignals(
                        _chartSignals.map((s) => s.values).toList(),
                      );
                    }
                  });
                },
                onClearFields: () {
                  _clearAllTextFields();
                  final settings = Provider.of<SettingsNotifier>(
                    context,
                    listen: false,
                  );
                  settings.setStepDurationsMs([]);
                  _chartController.setStepDurationsMs([]);
                  _chartController.requestGridRecompute();
                },
                showImportExportButtons: false,
              ),

              TimingChart(
                key: _timingChartKey,

                initialSignalNames: _chartSignals.map((s) => s.name).toList(),
                initialSignals: _chartSignals.map((s) => s.values).toList(),

                initialAnnotations: _chartAnnotations,

                signalTypes: _chartSignals.map((s) => s.signalType).toList(),
                controller: _chartController,
                fitToScreen: true,
                showAllSignalTypes: true,
                showIoNumbers: _showIoNumbers,
                portNumbers: _chartPortNumbers,
                ioSources: _chartIoSources,
                plcEipMode: _plcEipOption,
                onSignalsChanged: _handleChartSignalsChanged,
                onSignalShowIoNumberChanged: _handleSignalShowIoNumberChanged,
                onAnnotationsChanged: (anns) {
                  _chartAnnotations = List.from(anns);
                },
                showIoNumbersPerSignal: _chartShowIoNumbers,
              ),
            ],
          ),
          if (_isImportingZiq) _buildImportingOverlay(),
        ],
      ),
    );
  }
}
