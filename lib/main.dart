import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' as io;

import 'generated/l10n.dart';
import 'models/form/form_state.dart';
import 'models/chart/signal_data.dart';
import 'models/chart/timing_chart_annotation.dart';
import 'models/backup/app_config.dart';
import 'utils/file_utils.dart';
import 'widgets/form/form_tab.dart';
import 'widgets/chart/timing_chart.dart';
import 'widgets/settings/settings_window.dart';
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

const bool kZiqImportTest = bool.fromEnvironment(
  'ZIQ_IMPORT_TEST',
  defaultValue: false,
);
const String kZiqPath = String.fromEnvironment('ZIQ_PATH', defaultValue: '');

Future<void> main() async {
  if (kZiqImportTest) {
    WidgetsFlutterBinding.ensureInitialized();
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
      child: const MyApp(),
    ),
  );
}

Future<void> _runZiqImportTestMode() async {
  try {
    final String path =
        kZiqPath.isNotEmpty
            ? kZiqPath
            : (await FileUtils.pickZiqAndConvertToZipPath() ?? '');
    if (path.isEmpty) {
      debugPrint('ZIQ_IMPORT_TEST: ziqファイルが選択されていません');
      io.exit(2);
    }

    final files = await FileUtils.readRequiredFilesFromZip(path);
    final ini = files['vxVisMgr.ini'];
    final dio = files['DioMonitorLog.csv'];
    final plc = files['Plc_DioMonitorLog.csv'];
    final fnl = files['FNL_DioMonitorLog.csv'];

    print('ZIQ_IMPORT_TEST: "$path" ziqファイルパス');
    print(' - vxVisMgr.ini: ${ini != null ? 'OK' : 'MISSING'}');
    print(' - DioMonitorLog.csv: ${dio != null ? 'OK' : 'MISSING'}');
    print(' - Plc_DioMonitorLog.csv: ${plc != null ? 'OK' : 'MISSING'}');
    print(' - FNL_DioMonitorLog.csv: ${fnl != null ? 'OK' : 'MISSING'}');

    if (ini != null) {
      final ioActive = VxVisMgrParser.parseIOActive(ini);
      final ioSetting = VxVisMgrParser.parseIOSetting(ini);
      final enabled =
          VxVisMgrParser.parseStatusSignalSettings(
            ini,
          ).where((s) => s.enabled).toList();

      if (ioActive != null) {
        print(
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
        print(' IOSetting: trigger=$trigger, PLC/EIP=$plcEip');
      }
      print(' Enabled signals: ${enabled.length}');
    }

    final csvPairs = <MapEntry<String, String>>[];
    if (dio != null && dio.isNotEmpty) csvPairs.add(MapEntry('DIO', dio));
    if (plc != null && plc.isNotEmpty) csvPairs.add(MapEntry('PLC', plc));
    if (fnl != null && fnl.isNotEmpty) csvPairs.add(MapEntry('EIP', fnl));
    if (csvPairs.isNotEmpty) {
      final timeline = CsvIoLogParser.parseTimelineMulti(csvPairs);
      final active = ActivePortDetector.detectActivePorts(csvPairs);
      final activeIn = ActivePortDetector.detectActiveInputPorts(csvPairs);
      final activePrintable = <String, List<int>>{
        for (final e in active.entries) e.key: (e.value.toList()..sort()),
      };
      print(
        ' Timeline: rows=${timeline.entries.length} (信号データが存在します), inPorts=${timeline.inPortCount}, outPorts=${timeline.outPortCount}',
      );
      print(' ActivePorts: $activePrintable');
      final activeInPrintable = <String, List<int>>{
        for (final e in activeIn.entries) e.key: (e.value.toList()..sort()),
      };
      print(' ActiveInputPorts: $activeInPrintable');

      if (ini != null) {
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

        String _fallbackName(String source, int port) {
          if (source == 'DIO') return 'Output$port';
          if (source == 'PLC') return 'PLO$port';
          if (source == 'EIP') return 'ESO$port';
          return 'Port$port';
        }

        print(' ActivePort Names:');
        for (final source in ['DIO', 'PLC', 'EIP']) {
          final ports = active[source];
          if (ports == null || ports.isEmpty) continue;
          final sorted = ports.toList()..sort();
          for (final p in sorted) {
            final name =
                namesBySourcePort[source]?[p] ?? _fallbackName(source, p);
            print('  - $source:$p -> $name');
          }
        }

        print(' Enabled (INI) Signals:');
        for (final source in ['DIO', 'PLC', 'EIP']) {
          final map = namesBySourcePort[source]!;
          if (map.isEmpty) continue;
          final keys = map.keys.toList()..sort();
          for (final p in keys) {
            print('  - $source:$p -> ${map[p]}');
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
          print(' Undefined ActivePorts: none');
        } else {
          print(' Undefined ActivePorts: $undefinedActivePorts');
        }
      }
    }

    io.exit(0);
  } catch (e, st) {
    debugPrint('ZIQ_IMPORT_TEST: 信号データが存在しません: $e\n$st');
    io.exit(1);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

          home: const MyHomePage(),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _showIoNumbers = true;

  late FormControllersNotifier _controllersNotifier;

  List<SignalData> _chartSignals = [];
  List<int> _chartPortNumbers = [];
  List<IoChannelSource> _chartIoSources = [];
  List<TimingChartAnnotation> _chartAnnotations = [];
  late final TimingChartController _chartController;

  String? _vxVisMgrIniContent;
  String? _dioMonitorLogCsvContent;
  String? _plcDioMonitorLogCsvContent;
  String? _fnlDioMonitorLogCsvContent;

  List<String> _enabledStatusSignals = [];

  List<StatusSignalSetting> _enabledSignalStructures = [];

  Map<String, String> _vxvisNameToSuggestionId = {};

  List<_OutputAssignment> _dioOutputAssignments = [];
  List<_OutputAssignment> _plcEipOutputAssignments = [];
  String _plcEipOption = 'None';

  bool _isImportingZiq = false;

  Future<void> _applyOutputAssignments() async {
    int maxIndex = 0;
    for (final a in _dioOutputAssignments) {
      if (a.outputIndex1Based > maxIndex) maxIndex = a.outputIndex1Based;
    }
    if (maxIndex > _formState.outputCount) {
      _updateOutputCount(maxIndex);

      await SchedulerBinding.instance.endOfFrame;
    }

    setState(() {
      for (final a in _dioOutputAssignments) {
        if (a.suggestionId.isEmpty) continue;
        final idx = a.outputIndex1Based - 1;
        if (idx >= 0 && idx < _outputControllers.length) {
          _controllersNotifier.setOutputText(idx, a.suggestionId);
        }
      }

      if (_plcEipOption != 'None') {
        for (final a in _plcEipOutputAssignments) {
          if (a.suggestionId.isEmpty) continue;
          final idx = a.outputIndex1Based - 1;
          if (idx >= 0 && idx < _plcEipOutputControllers.length) {
            _controllersNotifier.setPlcEipOutputText(idx, a.suggestionId);
          }
        }
      } else {
        _clearPlcEipControllersIfDisabled();
      }
    });
  }

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

  Future<void> _transferInputs(
    List<TextEditingController> dioControllers,
    List<TextEditingController> plcControllers,
  ) async {
    final form = _formTabKey.currentState;
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

    form?.registerExternalSignalValues(nameToValues);

    if (chart != null) {
      chart.updateSignalNames(updatedSignals.map((e) => e.name).toList());
      chart.updateSignals(updatedSignals.map((e) => e.values).toList());
    }
  }

  Future<void> _transferOutputs(
    List<TextEditingController> dioControllers,
    List<TextEditingController> plcControllers,
  ) async {
    final form = _formTabKey.currentState;
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

    form?.registerExternalSignalValues(nameToValues);

    if (chart != null) {
      chart.updateSignalNames(updatedSignals.map((e) => e.name).toList());
      chart.updateSignals(updatedSignals.map((e) => e.values).toList());
    }
  }

  void _handleChartSignalsChanged(
    List<String> names,
    List<List<int>> values,
    List<SignalType> types,
  ) {
    if (names.length != values.length) {
      return;
    }

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
      final currentByName = {
        for (final signal in _chartSignals) signal.name: signal,
      };
      final List<SignalData> updatedSignals = [];
      for (int i = 0; i < names.length; i++) {
        final existing = currentByName[names[i]];
        final copiedValues = List<int>.from(values[i]);
        if (existing != null) {
          final signalType = types.length > i ? types[i] : existing.signalType;
          updatedSignals.add(
            existing.copyWith(signalType: signalType, values: copiedValues),
          );
        } else {
          final signalType = types.length > i ? types[i] : SignalType.input;
          updatedSignals.add(
            SignalData(
              name: names[i],
              signalType: signalType,
              values: copiedValues,
            ),
          );
        }
      }
      _chartSignals = updatedSignals;
    });
  }

  String _defaultPlcInputName(String? option, int index) {
    if (option == 'PLC') {
      return 'PLI${index + 1}';
    }
    if (option == 'EIP') {
      return 'ESI${index + 1}';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final initial = const TimingFormState(
      triggerOption: 'Single Trigger',
      ioPort: 32,
      hwPort: 0,
      camera: 1,
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
  }

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

  void _updateInputCount(int inputPorts) {
    _scheduleFormUpdate((n) {
      n.update(ioPort: inputPorts, inputCount: inputPorts);
    });
    _controllersNotifier.setInputCount(inputPorts);
  }

  void _updateOutputCount(int outputPorts) {
    _scheduleFormUpdate((n) {
      n.update(outputCount: outputPorts);
    });
    _controllersNotifier.setOutputCount(outputPorts);
  }

  void _updateHwTriggerControllers([int? desiredCount]) {
    final target = desiredCount ?? _formState.hwPort;
    _controllersNotifier.setHwTriggerCount(target);
  }

  void _clearAllTextFields() {
    _controllersNotifier.clearAllTexts();

    setState(() {
      _chartSignals.clear();
      _chartPortNumbers.clear();
      _chartIoSources.clear();
      _chartAnnotations.clear();
    });

    if (_timingChartKey.currentState != null) {
      _timingChartKey.currentState!.updateSignalNames([]);
      _timingChartKey.currentState!.updateSignals([]);

      _timingChartKey.currentState!.updateAnnotations([]);
    }

    _scheduleFormUpdate((n) {
      n.replace(
        const TimingFormState(
          triggerOption: 'Single Trigger',
          ioPort: 32,
          hwPort: 0,
          camera: 1,
          inputCount: 32,
          outputCount: 32,
        ),
      );
    });

    _controllersNotifier.setInputCount(32);
    _controllersNotifier.setOutputCount(32);
    _controllersNotifier.setHwTriggerCount(0);
  }

  IoChannelSource _resolvePlcEipSource({bool allowUnknown = false}) {
    if (_plcEipOption == 'PLC') return IoChannelSource.plc;
    if (_plcEipOption == 'EIP') return IoChannelSource.eip;
    return allowUnknown ? IoChannelSource.unknown : IoChannelSource.dio;
  }

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

  IoChannelSource _mapOutSourceTag(String tag) {
    switch (tag) {
      case 'PLC':
        return IoChannelSource.plc;
      case 'EIP':
        return IoChannelSource.eip;
      case 'PLC/EIP':
        return IoChannelSource.plcEip;
      case 'DIO':
        return IoChannelSource.dio;
      default:
        return IoChannelSource.unknown;
    }
  }

  Future<AppConfig> _createAppConfig() async {
    debugPrint("\n===== _createAppConfig (Chart first) =====");

    _chartAnnotations = List.from(_chartController.annotations);

    List<SignalData> signalData = [];
    List<List<CellMode>> tableData = [];
    List<bool> inputVisibility = [];
    List<bool> outputVisibility = [];
    List<bool> hwTriggerVisibility = [];
    List<String> rowModes = [];

    if (_formTabKey.currentState != null) {
      signalData = _formTabKey.currentState!.getSignalDataList();
      tableData = _formTabKey.currentState!.getTableData();
      inputVisibility = _formTabKey.currentState!.getInputVisibility();
      outputVisibility = _formTabKey.currentState!.getOutputVisibility();
      hwTriggerVisibility = _formTabKey.currentState!.getHwTriggerVisibility();
      rowModes = _formTabKey.currentState!.getRowModes();
    }

    if (_timingChartKey.currentState != null) {
      final orderedNames = _chartController.signalNames;
      final mapByName = {for (var s in _chartSignals) s.name: s};
      signalData = orderedNames.map((n) => mapByName[n]!).toList();
    } else {
      signalData = List<SignalData>.from(_chartSignals);
    }

    debugPrint("信号データが存在します: ${signalData.length}");
    if (signalData.isNotEmpty) {
      debugPrint(
        "信号データが存在します: ${signalData.any((signal) => signal.values.any((val) => val != 0))}",
      );
    }
    debugPrint("===== _createAppConfig _====\n");

    return AppConfig.fromCurrentState(
      formState: _formState,
      signals: signalData,
      tableData: tableData,
      inputControllers: _inputControllers,
      outputControllers: _outputControllers,
      hwTriggerControllers: _hwTriggerControllers,
      inputVisibility: inputVisibility,
      outputVisibility: outputVisibility,
      hwTriggerVisibility: hwTriggerVisibility,
      rowModes: rowModes,
      annotations: _chartAnnotations,
      omissionIndices:
          _timingChartKey.currentState?.getOmissionTimeIndices() ?? const [],

      timeUnitIsMs:
          Provider.of<SettingsNotifier>(context, listen: false).timeUnitIsMs,
      msPerStep:
          Provider.of<SettingsNotifier>(context, listen: false).msPerStep,
      stepDurationsMs:
          Provider.of<SettingsNotifier>(context, listen: false).stepDurationsMs,
    );
  }

  Future<bool> _confirmExport() async {
    debugPrint("===== _confirmExport =====");
    debugPrint("信号データが見つかりません: ${_tabController.index}");

    if (_tabController.index == 1 && _timingChartKey.currentState != null) {
      List<List<int>> chartData = _chartController.signals;
      debugPrint("信号データが存在します: ${chartData.length}");
      if (chartData.isNotEmpty) {
        debugPrint("信号データ: ${chartData[0].take(10)}...");
        final hasNonZero = chartData.any(
          (row) => row.any((value) => value != 0),
        );
        debugPrint("信号データに0が含まれているか: $hasNonZero");

        if (hasNonZero) {
          return true;
        }
      }
    }

    List<SignalData> signalData = [];

    if (_formTabKey.currentState != null) {
      signalData = _formTabKey.currentState!.getSignalDataList();
    }

    if (signalData.isEmpty ||
        !signalData.any((signal) => signal.values.any((value) => value != 0))) {
      final shouldUpdate =
          await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('信号データが見つかりません'),
                  content: const Text(
                    'エクスポートする前に「Update Chart」ボタンをクリックして信号データを更新することをお勧めします。\n\n'
                    'このまま進めますか？',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('このまま進める'),
                    ),
                  ],
                ),
          ) ??
          false;

      return shouldUpdate;
    }

    return true;
  }

  Future<void> _exportConfig() async {
    if (_timingChartKey.currentState != null &&
        _formTabKey.currentState != null) {
      final chartData = _chartController.signals;
      _formTabKey.currentState!.setChartDataOnly(chartData);
    }

    await SchedulerBinding.instance.endOfFrame;

    final shouldContinue = await _confirmExport();
    if (!shouldContinue) return;

    if (_tabController.index == 1 && _timingChartKey.currentState != null) {
      final chartData = _chartController.signals;
      if (_formTabKey.currentState != null) {
        _formTabKey.currentState!.setChartDataOnly(chartData);
      }
    }

    await SchedulerBinding.instance.endOfFrame;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final config = await _createAppConfig();
      final success = await FileUtils.exportWaveDrom(
        config,
        annotations: _chartAnnotations,
        omissionIndices: _timingChartKey.currentState?.getOmissionTimeIndices(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'JSONが正常にエクスポートされました' : 'JSONのエクスポートに失敗しました'),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  Future<void> _importConfig() async {
    final config = await FileUtils.importAppConfig();

    if (config == null) {
      return;
    }

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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('JPEGが正常にエクスポートされました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportChartImageJpeg() async {
    await SchedulerBinding.instance.endOfFrame;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final bytes = await _timingChartKey.currentState?.captureChartJpeg(
      backgroundColor: bg,
      quality: 90,
    );
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('JPEGのエクスポートに失敗しました')));
      return;
    }

    final ok = await FileUtils.exportJpegBytes(bytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'JPEGが正常にエクスポートされました' : 'JPEGのエクスポートに失敗しました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportXlsx() async {
    try {
      if (_timingChartKey.currentState != null &&
          _formTabKey.currentState != null) {
        final chartData = _chartController.signals;
        _formTabKey.currentState!.setChartDataOnly(chartData);
      }

      await SchedulerBinding.instance.endOfFrame;

      debugPrint('=== IO Information: ID to Label conversion ===');

      List<String> inputNames = [];
      for (int i = 0; i < _inputControllers.length; i++) {
        final inputText = _inputControllers[i].text.trim();
        if (inputText.isNotEmpty) {
          final labelName = await labelOfId(inputText);
          debugPrint('Converting Input[$i]: $inputText -> $labelName');
          inputNames.add(labelName);
        } else {
          inputNames.add('');
        }
      }

      List<String> outputNames = [];
      for (int i = 0; i < _outputControllers.length; i++) {
        final outputText = _outputControllers[i].text.trim();
        if (outputText.isNotEmpty) {
          final labelName = await labelOfId(outputText);
          debugPrint('Converting Output[$i]: $outputText -> $labelName');
          outputNames.add(labelName);
        } else {
          outputNames.add('');
        }
      }

      List<String> hwTriggerNames = [];
      for (int i = 0; i < _hwTriggerControllers.length; i++) {
        final hwText = _hwTriggerControllers[i].text.trim();
        if (hwText.isNotEmpty) {
          final labelName = await labelOfId(hwText);
          debugPrint('Converting HW Trigger[$i]: $hwText -> $labelName');
          hwTriggerNames.add(labelName);
        } else {
          hwTriggerNames.add('');
        }
      }

      debugPrint('=== End IO conversion ===');

      List<SignalData> signalData = [];

      if (_timingChartKey.currentState != null) {
        final orderedNames = _chartController.signalNames;
        final mapByName = {for (var s in _chartSignals) s.name: s};

        debugPrint('=== XLSX Export: ID to Label conversion ===');
        debugPrint('Ordered signal IDs: $orderedNames');

        for (String signalId in orderedNames) {
          if (mapByName.containsKey(signalId)) {
            final originalSignal = mapByName[signalId]!;

            final labelName = await labelOfId(signalId);
            debugPrint('Converting: $signalId -> $labelName');
            final modifiedSignal = originalSignal.copyWith(name: labelName);
            signalData.add(modifiedSignal);
          }
        }

        for (var signal in _chartSignals) {
          if (!orderedNames.contains(signal.name)) {
            final labelName = await labelOfId(signal.name);
            debugPrint(
              'Converting additional signal: ${signal.name} -> $labelName',
            );
            final modifiedSignal = signal.copyWith(name: labelName);
            signalData.add(modifiedSignal);
          }
        }

        debugPrint(
          'Final signal names for XLSX: ${signalData.map((s) => s.name).toList()}',
        );
        debugPrint('=== End conversion ===');
      } else {
        for (var signal in _chartSignals) {
          final labelName = await labelOfId(signal.name);
          debugPrint(
            'Converting from _chartSignals: ${signal.name} -> $labelName',
          );
          final modifiedSignal = signal.copyWith(name: labelName);
          signalData.add(modifiedSignal);
        }
      }

      final success = await FileUtils.exportXlsx(
        inputNames: inputNames,
        outputNames: outputNames,
        hwTriggerNames: hwTriggerNames,
        chartSignals: signalData,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'XLSXが正常にエクスポートされました' : 'XLSXのエクスポートに失敗しました'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('XLSXのエクスポートに失敗しました: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(s.appTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.language, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    Provider.of<LocaleNotifier>(context).locale.languageCode ==
                            'ja'
                        ? 'JP'
                        : Provider.of<LocaleNotifier>(
                          context,
                        ).locale.languageCode.toUpperCase(),
                    style: GoogleFonts.notoSansJp(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

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
              leading: Icon(Icons.archive_outlined),
              title: Text(s.drawer_import_ziq),
              onTap: () async {
                Navigator.pop(context);
                final zipPath = await FileUtils.pickZiqAndConvertToZipPath();
                if (!mounted) return;
                if (zipPath == null) {
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
                  final files = await FileUtils.readRequiredFilesFromZip(
                    zipPath,
                  );
                  if (!mounted) return;

                  final mapping = await VxVisMgrMappingLoader.loadMapping();

                  setState(() {
                    _vxVisMgrIniContent = files['vxVisMgr.ini'];
                    _dioMonitorLogCsvContent = files['DioMonitorLog.csv'];
                    _plcDioMonitorLogCsvContent =
                        files['Plc_DioMonitorLog.csv'];
                    _vxvisNameToSuggestionId = mapping;
                    _fnlDioMonitorLogCsvContent =
                        files['FNL_DioMonitorLog.csv'];

                    if (_vxVisMgrIniContent == null) {
                      _enabledStatusSignals = [];
                      _enabledSignalStructures = [];
                      _dioOutputAssignments = [];
                      _plcEipOutputAssignments = [];
                      _plcEipOption = 'None';
                      _clearPlcEipControllersIfDisabled();
                    } else {
                      final ioActive = VxVisMgrParser.parseIOActive(
                        _vxVisMgrIniContent!,
                      );
                      if (ioActive != null) {
                        if (ioActive.pinPorts > 0 &&
                            ioActive.pinPorts != _formState.inputCount) {
                          _updateInputCount(ioActive.pinPorts);
                        }
                        if (ioActive.poutPorts > 0 &&
                            ioActive.poutPorts != _formState.outputCount) {
                          _updateOutputCount(ioActive.poutPorts);
                        }
                      }

                      final all = VxVisMgrParser.parseStatusSignalSettings(
                        _vxVisMgrIniContent!,
                      );
                      _enabledSignalStructures =
                          all.where((s) => s.enabled).toList();
                      _enabledStatusSignals =
                          _enabledSignalStructures.map((e) => e.name).toList();

                      final ioSetting = VxVisMgrParser.parseIOSetting(
                        _vxVisMgrIniContent!,
                      );

                      String triggerOption = _formState.triggerOption;
                      _plcEipOption = 'None';
                      if (ioSetting != null) {
                        if (ioSetting.plcLinkEnabled) {
                          _plcEipOption = 'PLC';
                        } else if (ioSetting.ethernetIpEnabled) {
                          _plcEipOption = 'EIP';
                        } else if (ioSetting.useVirtualIoOnTrigger == 1) {
                          if (ioSetting.plcLinkEnabled) {
                            _plcEipOption = 'PLC';
                          } else if (ioSetting.ethernetIpEnabled) {
                            _plcEipOption = 'EIP';
                          }
                        }

                        final bool isPlcCommand =
                            ioSetting.plcLinkEnabled &&
                            ioSetting.plcCommandEnabled;
                        final bool isEipCommand =
                            ioSetting.ethernetIpEnabled &&
                            ioSetting.ethernetIpCommandEnabled;
                        if (isPlcCommand || isEipCommand) {
                          triggerOption = 'Command Trigger';
                        } else {
                          triggerOption =
                              ioSetting.triggerMode == 0
                                  ? 'Code Trigger'
                                  : 'Single Trigger';
                        }
                      }

                      _dioOutputAssignments = [];
                      _plcEipOutputAssignments = [];

                      final assignedSignalNames = <String>{};

                      for (final s in _enabledSignalStructures) {
                        if (!s.portNoByIndex.containsKey(0)) continue;
                        final n0 = s.portNoByIndex[0]!;
                        final type = s.portTypeByIndex[0];
                        final suggestionId =
                            _vxvisNameToSuggestionId[s.name] ?? '';

                        final signalName =
                            suggestionId.isNotEmpty ? suggestionId : s.name;

                        debugPrint(
                          'INI信号名: ${s.name} -> Port.No=${n0 + 1}, Type=$type, SignalName=$signalName',
                        );

                        if (assignedSignalNames.contains(signalName)) {
                          debugPrint('INI信号名が重複しています: $signalName (${s.name})');
                          continue;
                        }
                        assignedSignalNames.add(signalName);
                        debugPrint(
                          'INI信号名: $signalName (${s.name}) -> Port.No=${n0 + 1}, Type=$type',
                        );

                        final assignment = _OutputAssignment(
                          name: s.name,
                          suggestionId: suggestionId,
                          portNo0: n0 + 1,
                          outputIndex1Based: n0 + 1,
                        );

                        if (type != null && type != 0) {
                          _plcEipOutputAssignments.add(assignment);
                        } else {
                          _dioOutputAssignments.add(assignment);
                        }
                      }

                      debugPrint('=== DIO信号名 ===');
                      for (final a in _dioOutputAssignments) {
                        debugPrint(
                          'DIO: ${a.name} -> Port.No=${a.portNo0}, SuggestionId=${a.suggestionId}',
                        );
                      }
                      debugPrint('=== PLC/EIP信号名 ===');
                      for (final a in _plcEipOutputAssignments) {
                        debugPrint(
                          'PLC/EIP: ${a.name} -> Port.No=${a.portNo0}, SuggestionId=${a.suggestionId}',
                        );
                      }

                      for (final a in _dioOutputAssignments) {
                        final idx = a.outputIndex1Based - 1;
                        if (idx >= 0 && idx < _outputControllers.length) {
                          final signalName =
                              a.suggestionId.isNotEmpty
                                  ? a.suggestionId
                                  : a.name;
                          _outputControllers[idx].text = signalName;
                          debugPrint('DIO信号名: $signalName -> DIO[$idx]');
                        }
                      }

                      for (final a in _plcEipOutputAssignments) {
                        final idx = a.outputIndex1Based - 1;
                        if (idx >= 0 && idx < _plcEipOutputControllers.length) {
                          final signalName =
                              a.suggestionId.isNotEmpty
                                  ? a.suggestionId
                                  : a.name;
                          _plcEipOutputControllers[idx].text = signalName;
                          debugPrint(
                            'PLC/EIP信号名: $signalName -> PLC/EIP[$idx]',
                          );
                        }
                      }

                      if (_formTabKey.currentState != null) {
                        _formTabKey.currentState!.setPlcEipOption(
                          _plcEipOption,
                        );
                      }

                      _scheduleFormUpdate(
                        (n) => n.update(triggerOption: triggerOption),
                      );
                      _clearPlcEipControllersIfDisabled();

                      final csvPairs = <MapEntry<String, String>>[];
                      if (_dioMonitorLogCsvContent != null &&
                          _dioMonitorLogCsvContent!.isNotEmpty) {
                        csvPairs.add(
                          MapEntry('DIO', _dioMonitorLogCsvContent!),
                        );
                      }
                      if (_plcDioMonitorLogCsvContent != null &&
                          _plcDioMonitorLogCsvContent!.isNotEmpty) {
                        csvPairs.add(
                          MapEntry('PLC', _plcDioMonitorLogCsvContent!),
                        );
                      }
                      if (_fnlDioMonitorLogCsvContent != null &&
                          _fnlDioMonitorLogCsvContent!.isNotEmpty) {
                        csvPairs.add(
                          MapEntry('EIP', _fnlDioMonitorLogCsvContent!),
                        );
                      }
                      if (csvPairs.isNotEmpty) {
                        final activePorts =
                            ActivePortDetector.detectActivePorts(csvPairs);

                        final definedPorts = <String, Set<int>>{};
                        for (final a in _dioOutputAssignments) {
                          definedPorts
                              .putIfAbsent('DIO', () => <int>{})
                              .add(a.portNo0);
                        }
                        for (final a in _plcEipOutputAssignments) {
                          final source = _plcEipOption == 'PLC' ? 'PLC' : 'EIP';
                          definedPorts
                              .putIfAbsent(source, () => <int>{})
                              .add(a.portNo0);
                        }

                        final undefinedActivePorts = <String, Set<int>>{};
                        for (final source in activePorts.keys) {
                          final defined = definedPorts[source] ?? <int>{};
                          final active = activePorts[source]!;
                          final undefined = active.difference(defined);
                          if (undefined.isNotEmpty) {
                            undefinedActivePorts[source] = undefined;
                          }
                        }

                        final assignedNames = <String>{};
                        for (final a in _dioOutputAssignments) {
                          if (a.suggestionId.isNotEmpty) {
                            assignedNames.add(a.suggestionId);
                          } else {
                            assignedNames.add(a.name);
                          }
                        }
                        for (final a in _plcEipOutputAssignments) {
                          if (a.suggestionId.isNotEmpty) {
                            assignedNames.add(a.suggestionId);
                          } else {
                            assignedNames.add(a.name);
                          }
                        }

                        for (final source in undefinedActivePorts.keys) {
                          final ports = undefinedActivePorts[source]!;
                          for (final port in ports) {
                            String signalName;
                            if (source == 'DIO') {
                              signalName = 'Output$port';
                            } else if (source == 'PLC') {
                              signalName = 'PLO$port';
                            } else if (source == 'EIP') {
                              signalName = 'ESO$port';
                            } else {
                              continue;
                            }

                            if (assignedNames.contains(signalName)) {
                              debugPrint(
                                'CSV信号名が重複しています: $signalName ($source:$port)',
                              );
                              continue;
                            }

                            if (source == 'DIO' &&
                                port <= _outputControllers.length) {
                              if (_outputControllers[port - 1].text.isEmpty) {
                                _outputControllers[port - 1].text = signalName;
                                debugPrint('CSV信号名: $signalName -> DIO:$port');
                              }
                            } else if ((source == 'PLC' || source == 'EIP') &&
                                port <= _plcEipOutputControllers.length) {
                              if (_plcEipOutputControllers[port - 1]
                                  .text
                                  .isEmpty) {
                                _plcEipOutputControllers[port - 1].text =
                                    signalName;
                                debugPrint(
                                  'CSV信号名: $signalName -> $source:$port',
                                );
                              }
                            }
                          }
                        }

                        final activeInputPorts =
                            ActivePortDetector.detectActiveInputPorts(csvPairs);
                        for (final entry in activeInputPorts.entries) {
                          final source = entry.key;
                          final ports = entry.value.toList()..sort();
                          for (final port in ports) {
                            if (source == 'DIO') {
                              if (port >= 1 &&
                                  port <= _inputControllers.length) {
                                if (_inputControllers[port - 1].text.isEmpty) {
                                  _inputControllers[port - 1].text =
                                      'Input$port';
                                  debugPrint('CSV信号名: Input$port -> DIO:$port');
                                }
                              }
                            } else if (source == 'PLC' || source == 'EIP') {
                              if (port >= 1 &&
                                  port <= _plcEipInputControllers.length) {
                                if (_plcEipInputControllers[port - 1]
                                    .text
                                    .isEmpty) {
                                  final prefix =
                                      (source == 'PLC') ? 'PLI' : 'ESI';
                                  final name = '$prefix$port';
                                  _plcEipInputControllers[port - 1].text = name;
                                  debugPrint('CSV信号名: $name -> $source:$port');
                                }
                              }
                            }
                          }
                        }

                        final timeline = CsvIoLogParser.parseTimelineMulti(
                          csvPairs,
                        );

                        final stepDurationsMs =
                            CsvIoLogParserTimestamps.inferStepDurationsMsFromTimeline(
                              timeline,
                            );
                        if (stepDurationsMs.isNotEmpty) {
                          final settings = Provider.of<SettingsNotifier>(
                            context,
                            listen: false,
                          );

                          final double sumMs = stepDurationsMs
                              .where((e) => e.isFinite && e > 0)
                              .fold<double>(0.0, (a, b) => a + b);
                          final double avgMs = sumMs / stepDurationsMs.length;
                          if (avgMs.isFinite && avgMs > 0) {
                            settings.msPerStep = avgMs;
                          }

                          final int maxLen = timeline.entries.length;
                          if (stepDurationsMs.length != maxLen) {
                            final List<double> fixed = List<double>.from(
                              stepDurationsMs,
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
                            settings.setStepDurationsMs(stepDurationsMs);
                            _chartController.setStepDurationsMs(
                              stepDurationsMs,
                            );
                          }
                        }

                        Provider.of<SettingsNotifier>(context, listen: false)
                            .timeUnitIsMs = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _chartController.requestGridRecompute();
                            setState(() {});
                          }
                        });

                        final int timeLength = timeline.entries.length;

                        final outSource = <String, String>{};
                        final outNamesDio = <String>[];
                        final outTypesDio = <SignalType>[];
                        final outPortsDio = <int>[];
                        final outValuesDio = <List<int>>[];
                        final outNamesPlc = <String>[];
                        final outTypesPlc = <SignalType>[];
                        final outPortsPlc = <int>[];
                        final outValuesPlc = <List<int>>[];
                        if (timeLength > 0) {
                          int dioOutputs = _formState.outputCount;
                          for (final a in _dioOutputAssignments) {
                            if (a.outputIndex1Based > dioOutputs)
                              dioOutputs = a.outputIndex1Based;
                          }

                          for (final source in undefinedActivePorts.keys) {
                            if (source == 'DIO') {
                              final ports = undefinedActivePorts[source]!;
                              for (final port in ports) {
                                if (port > dioOutputs) dioOutputs = port;
                              }
                            }
                          }
                          List<List<int>> outChartRowsDio = List.generate(
                            dioOutputs,
                            (_) => List.filled(timeLength, 0),
                          );

                          for (final a in _dioOutputAssignments) {
                            final outIdx = a.outputIndex1Based - 1;
                            final portK = a.portNo0;
                            if (outIdx < 0 || outIdx >= dioOutputs) continue;
                            int last = 0;
                            for (int t = 0; t < timeLength; t++) {
                              final e = timeline.entries[t];
                              if (e.type == 'OUT' &&
                                  (e.source == null || e.source == 'DIO')) {
                                final row = e.bits;
                                final colIdx = row.length - portK;
                                final v =
                                    (colIdx >= 0 &&
                                            colIdx < row.length &&
                                            row[colIdx] != 0)
                                        ? 1
                                        : 0;
                                last = v;
                                outChartRowsDio[outIdx][t] = v;
                              } else {
                                outChartRowsDio[outIdx][t] = last;
                              }
                            }
                          }

                          for (final source in undefinedActivePorts.keys) {
                            if (source == 'DIO') {
                              final ports = undefinedActivePorts[source]!;
                              for (final port in ports) {
                                final outIdx = port - 1;
                                if (outIdx < 0 || outIdx >= dioOutputs)
                                  continue;
                                int last = 0;
                                for (int t = 0; t < timeLength; t++) {
                                  final e = timeline.entries[t];
                                  if (e.type == 'OUT' &&
                                      (e.source == null || e.source == 'DIO')) {
                                    final row = e.bits;
                                    final colIdx = row.length - port;
                                    final v =
                                        (colIdx >= 0 &&
                                                colIdx < row.length &&
                                                row[colIdx] != 0)
                                            ? 1
                                            : 0;
                                    last = v;
                                    outChartRowsDio[outIdx][t] = v;
                                  } else {
                                    outChartRowsDio[outIdx][t] = last;
                                  }
                                }
                              }
                            }
                          }
                          for (int i = 0; i < dioOutputs; i++) {
                            if (i >= _outputControllers.length) continue;
                            final name = _outputControllers[i].text.trim();
                            if (name.isEmpty) continue;
                            outNamesDio.add(name);
                            outTypesDio.add(SignalType.output);
                            outPortsDio.add(i + 1);
                            outValuesDio.add(outChartRowsDio[i]);

                            final s = outSource[name];
                            if (s == null) {
                              outSource[name] = 'DIO';
                            } else if (s == 'PLC' ||
                                s == 'EIP' ||
                                s == 'PLC/EIP') {
                              outSource[name] = 'PLC/EIP';
                            }
                          }

                          if (_plcEipOption != 'None') {
                            int plcOutputs = _formState.outputCount;
                            for (final a in _plcEipOutputAssignments) {
                              if (a.outputIndex1Based > plcOutputs)
                                plcOutputs = a.outputIndex1Based;
                            }

                            for (final source in undefinedActivePorts.keys) {
                              if (source == 'PLC' || source == 'EIP') {
                                final ports = undefinedActivePorts[source]!;
                                for (final port in ports) {
                                  if (port > plcOutputs) plcOutputs = port;
                                }
                              }
                            }
                            List<List<int>> outChartRowsPlc = List.generate(
                              plcOutputs,
                              (_) => List.filled(timeLength, 0),
                            );
                            bool seenPlc = false;
                            bool seenEip = false;

                            for (final a in _plcEipOutputAssignments) {
                              final outIdx = a.outputIndex1Based - 1;
                              final portK = a.portNo0;
                              if (outIdx < 0 || outIdx >= plcOutputs) continue;
                              int last = 0;
                              for (int t = 0; t < timeLength; t++) {
                                final e = timeline.entries[t];
                                if (e.type == 'OUT' &&
                                    (e.source == 'PLC' || e.source == 'EIP')) {
                                  final row = e.bits;
                                  final colIdx = row.length - portK;
                                  final v =
                                      (colIdx >= 0 &&
                                              colIdx < row.length &&
                                              row[colIdx] != 0)
                                          ? 1
                                          : 0;
                                  last = v;
                                  outChartRowsPlc[outIdx][t] = v;
                                  if (e.source == 'PLC')
                                    seenPlc = true;
                                  else if (e.source == 'EIP')
                                    seenEip = true;
                                } else {
                                  outChartRowsPlc[outIdx][t] = last;
                                }
                              }
                            }

                            for (final source in undefinedActivePorts.keys) {
                              if (source == 'PLC' || source == 'EIP') {
                                final ports = undefinedActivePorts[source]!;
                                for (final port in ports) {
                                  final outIdx = port - 1;
                                  if (outIdx < 0 || outIdx >= plcOutputs)
                                    continue;
                                  int last = 0;
                                  for (int t = 0; t < timeLength; t++) {
                                    final e = timeline.entries[t];
                                    if (e.type == 'OUT' && e.source == source) {
                                      final row = e.bits;
                                      final colIdx = row.length - port;
                                      final v =
                                          (colIdx >= 0 &&
                                                  colIdx < row.length &&
                                                  row[colIdx] != 0)
                                              ? 1
                                              : 0;
                                      last = v;
                                      outChartRowsPlc[outIdx][t] = v;
                                      if (e.source == 'PLC')
                                        seenPlc = true;
                                      else if (e.source == 'EIP')
                                        seenEip = true;
                                    } else {
                                      outChartRowsPlc[outIdx][t] = last;
                                    }
                                  }
                                }
                              }
                            }
                            for (int i = 0; i < plcOutputs; i++) {
                              if (i >= _plcEipOutputControllers.length)
                                continue;
                              final name =
                                  _plcEipOutputControllers[i].text.trim();
                              if (name.isEmpty) continue;
                              outNamesPlc.add(name);
                              outTypesPlc.add(SignalType.output);
                              outPortsPlc.add(i + 1);
                              outValuesPlc.add(outChartRowsPlc[i]);

                              final src =
                                  (seenPlc && seenEip)
                                      ? 'PLC/EIP'
                                      : (seenPlc ? 'PLC' : 'EIP');
                              final s = outSource[name];
                              if (s == null) {
                                outSource[name] = src;
                              } else if (s != src) {
                                outSource[name] = 'PLC/EIP';
                              }
                            }
                          }
                        }

                        final int inTime = timeline.entries.length;
                        if (inTime > 0 && _formTabKey.currentState != null) {
                          final int inputs = _formState.inputCount;

                          if (triggerOption == 'Code Trigger' &&
                              _inputControllers.isNotEmpty) {
                            _controllersNotifier.setInputText(0, 'TRIGGER');
                          }

                          List<List<int>> inChart = [];
                          List<String> inNames = [];
                          List<SignalType> inTypes = [];

                          for (int idx0 = 0; idx0 < inputs; idx0++) {
                            if (idx0 >= _inputControllers.length) continue;
                            final name = _inputControllers[idx0].text.trim();
                            if (name.isEmpty) continue;
                            List<int> series = List.filled(inTime, 0);
                            for (int t = 0; t < inTime; t++) {
                              final e = timeline.entries[t];
                              if (e.type == 'IN' && e.source == 'DIO') {
                                final row = e.bits;

                                final col = row.length - (idx0 + 1);
                                if (col >= 0 && col < row.length) {
                                  series[t] = row[col] != 0 ? 1 : 0;
                                }
                              } else if (e.type != 'IN') {
                                series[t] = 0;
                              }
                            }
                            inChart.add(series);
                            inNames.add(name);
                            inTypes.add(SignalType.input);
                          }

                          for (int idx0 = 0; idx0 < inputs; idx0++) {
                            if (idx0 >= _plcEipInputControllers.length)
                              continue;
                            final name =
                                _plcEipInputControllers[idx0].text.trim();
                            if (name.isEmpty) continue;

                            bool allowPlc;
                            bool allowEip;
                            if (name.startsWith('PLI')) {
                              allowPlc = true;
                              allowEip = false;
                            } else if (name.startsWith('ESI')) {
                              allowPlc = false;
                              allowEip = true;
                            } else {
                              if (_plcEipOption == 'PLC') {
                                allowPlc = true;
                                allowEip = false;
                              } else if (_plcEipOption == 'EIP') {
                                allowPlc = false;
                                allowEip = true;
                              } else {
                                allowPlc = true;
                                allowEip = true;
                              }
                            }
                            List<int> series = List.filled(inTime, 0);
                            for (int t = 0; t < inTime; t++) {
                              final e = timeline.entries[t];
                              if (e.type == 'IN') {
                                final isPlc = e.source == 'PLC';
                                final isEip = e.source == 'EIP';
                                if ((isPlc && allowPlc) ||
                                    (isEip && allowEip)) {
                                  final row = e.bits;
                                  final col = row.length - (idx0 + 1);
                                  if (col >= 0 && col < row.length) {
                                    series[t] = row[col] != 0 ? 1 : 0;
                                  }
                                }
                              } else if (e.type != 'IN') {
                                series[t] = 0;
                              }
                            }
                            inChart.add(series);
                            inNames.add(name);
                            inTypes.add(SignalType.input);
                          }

                          final combinedValues = <List<int>>[];
                          final combinedNames = <String>[];
                          final combinedTypes = <SignalType>[];

                          int idxCode = inNames.indexOf('CODE_OPTION');
                          if (idxCode != -1) {
                            combinedNames.add(inNames[idxCode]);
                            combinedTypes.add(inTypes[idxCode]);
                            combinedValues.add(inChart[idxCode]);
                          } else {
                            if (triggerOption == 'Code Trigger') {
                              combinedNames.add('CODE_OPTION');
                              combinedTypes.add(SignalType.input);
                              combinedValues.add(
                                List<int>.filled(timeLength, 0),
                              );
                            }
                          }

                          int idxCmd = inNames.indexOf('Command Option');
                          if (idxCmd != -1) {
                            combinedNames.add(inNames[idxCmd]);
                            combinedTypes.add(inTypes[idxCmd]);
                            combinedValues.add(inChart[idxCmd]);
                          }

                          for (int i = 0; i < inNames.length; i++) {
                            if (i == idxCode || i == idxCmd) continue;
                            combinedNames.add(inNames[i]);
                            combinedTypes.add(inTypes[i]);
                            combinedValues.add(inChart[i]);
                          }

                          if (_formState.hwPort > 0) {
                            for (int j = 0; j < _formState.hwPort; j++) {
                              final hwName =
                                  (j < _hwTriggerControllers.length)
                                      ? _hwTriggerControllers[j].text.trim()
                                      : '';
                              if (hwName.isEmpty) continue;
                              combinedNames.add(hwName);
                              combinedTypes.add(SignalType.hwTrigger);
                              combinedValues.add(
                                List<int>.filled(timeLength, 0),
                              );
                            }
                          }

                          if (timeLength > 0) {
                            final dioMap = <String, List<int>>{};
                            for (int i = 0; i < outNamesDio.length; i++) {
                              dioMap[outNamesDio[i]] = outValuesDio[i];
                            }
                            final plcMap = <String, List<int>>{};
                            for (int i = 0; i < outNamesPlc.length; i++) {
                              plcMap[outNamesPlc[i]] = outValuesPlc[i];
                            }

                            final orderedOutputNames = <String>[];
                            for (final n in outNamesDio) {
                              if (!orderedOutputNames.contains(n))
                                orderedOutputNames.add(n);
                            }
                            for (final n in outNamesPlc) {
                              if (!orderedOutputNames.contains(n))
                                orderedOutputNames.add(n);
                            }

                            final mergedValuesByName = <String, List<int>>{};
                            for (final n in orderedOutputNames) {
                              final dio = dioMap[n];
                              final plc = plcMap[n];
                              if (dio == null && plc != null) {
                                mergedValuesByName[n] = plc;
                              } else if (dio != null && plc == null) {
                                mergedValuesByName[n] = dio;
                              } else if (dio != null && plc != null) {
                                final len = math.min(dio.length, plc.length);
                                final merged = List<int>.from(dio);
                                for (int t = 0; t < len; t++) {
                                  if (plc[t] != 0) merged[t] = plc[t];
                                }
                                mergedValuesByName[n] = merged;
                              }
                            }

                            for (final n in orderedOutputNames) {
                              final v = mergedValuesByName[n];
                              if (v == null) continue;
                              combinedNames.add(n);
                              combinedTypes.add(SignalType.output);
                              combinedValues.add(v);
                            }
                          }

                          if (combinedNames.isNotEmpty) {
                            debugPrint(
                              '[COMBINED] names=${combinedNames.length}, valuesRows=${combinedValues.length}, anyNonZero=${combinedValues.any((r) => r.any((v) => v != 0))}',
                            );

                            if (_formTabKey.currentState != null) {
                              _formTabKey.currentState!.setChartDataOnly(
                                combinedValues,
                              );
                            }

                            setState(() {
                              final syncedSignals = <SignalData>[];
                              final syncedPorts = <int>[];
                              final syncedSources = <IoChannelSource>[];

                              final inputNameToPort = <String, int>{
                                for (int i = 0; i < inNames.length; i++)
                                  inNames[i]: i + 1,
                              };

                              final outputNameToPort = <String, int>{};
                              for (int i = 0; i < outNamesDio.length; i++) {
                                outputNameToPort.putIfAbsent(
                                  outNamesDio[i],
                                  () => outPortsDio[i],
                                );
                              }
                              for (int i = 0; i < outNamesPlc.length; i++) {
                                outputNameToPort.putIfAbsent(
                                  outNamesPlc[i],
                                  () => outPortsPlc[i],
                                );
                              }
                              final hwNameToPort = <String, int>{
                                for (int i = 0; i < _formState.hwPort; i++)
                                  if (i < _hwTriggerControllers.length &&
                                      _hwTriggerControllers[i].text
                                          .trim()
                                          .isNotEmpty)
                                    _hwTriggerControllers[i].text.trim(): i + 1,
                              };

                              for (int i = 0; i < combinedNames.length; i++) {
                                final name = combinedNames[i];
                                final type = combinedTypes[i];
                                final vals = combinedValues[i];
                                syncedSignals.add(
                                  SignalData(
                                    name: name,
                                    signalType: type,
                                    values: vals,
                                    isVisible: true,
                                  ),
                                );

                                int portNum = 0;
                                switch (type) {
                                  case SignalType.output:
                                    portNum = outputNameToPort[name] ?? 0;
                                    break;
                                  case SignalType.input:
                                    if (name != 'CODE_OPTION' &&
                                        name != 'Command Option') {
                                      portNum = inputNameToPort[name] ?? 0;
                                    }
                                    break;
                                  case SignalType.hwTrigger:
                                    portNum = hwNameToPort[name] ?? 0;
                                    break;
                                  default:
                                    portNum = 0;
                                }
                                syncedPorts.add(portNum);
                                IoChannelSource source;
                                if (type == SignalType.output) {
                                  source = _mapOutSourceTag(
                                    outSource[name] ?? 'DIO',
                                  );
                                  if (source == IoChannelSource.plcEip) {
                                    final resolved = _resolvePlcEipSource(
                                      allowUnknown: true,
                                    );
                                    if (resolved != IoChannelSource.unknown) {
                                      source = resolved;
                                    }
                                  }
                                } else if (type == SignalType.input) {
                                  source = _detectIoSourceFor(name, type);
                                } else {
                                  source = IoChannelSource.unknown;
                                }
                                syncedSources.add(source);
                              }
                              _chartSignals = syncedSignals;
                              _chartPortNumbers = syncedPorts;
                              _chartIoSources = syncedSources;
                            });
                            _formTabKey.currentState!
                                .updateSignalDataFromChartData(
                                  combinedValues,
                                  combinedNames,
                                  combinedTypes,
                                );

                            _formTabKey.currentState!.refreshSignalDataList();

                            if (_timingChartKey.currentState != null) {
                              final Map<String, int> nameToPortForLabel = {};
                              for (int i = 0; i < outNamesDio.length; i++) {
                                nameToPortForLabel.putIfAbsent(
                                  outNamesDio[i],
                                  () => outPortsDio[i],
                                );
                              }
                              for (int i = 0; i < outNamesPlc.length; i++) {
                                nameToPortForLabel.putIfAbsent(
                                  outNamesPlc[i],
                                  () => outPortsPlc[i],
                                );
                              }

                              final List<String> displayNames = List.generate(
                                combinedNames.length,
                                (i) {
                                  final name = combinedNames[i];
                                  final type = combinedTypes[i];
                                  if (type != SignalType.output) {
                                    return name;
                                  }
                                  final port = nameToPortForLabel[name] ?? 0;
                                  final src = outSource[name] ?? 'DIO';
                                  String prefix;
                                  if (src == 'PLC' ||
                                      (src == 'PLC/EIP' &&
                                          _plcEipOption == 'PLC')) {
                                    prefix = 'PLO';
                                  } else if (src == 'EIP' ||
                                      (src == 'PLC/EIP' &&
                                          _plcEipOption == 'EIP')) {
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
                              _timingChartKey.currentState!.updateSignals(
                                combinedValues,
                              );
                            }

                            if (_timingChartKey.currentState != null) {
                              final Map<String, int> nameToPortForLabel = {};
                              for (int i = 0; i < outNamesDio.length; i++) {
                                nameToPortForLabel.putIfAbsent(
                                  outNamesDio[i],
                                  () => outPortsDio[i],
                                );
                              }
                              for (int i = 0; i < outNamesPlc.length; i++) {
                                nameToPortForLabel.putIfAbsent(
                                  outNamesPlc[i],
                                  () => outPortsPlc[i],
                                );
                              }
                              final controllerDisplayNames = List.generate(
                                combinedNames.length,
                                (i) {
                                  final name = combinedNames[i];
                                  final type = combinedTypes[i];
                                  if (type != SignalType.output) return name;
                                  if (_showIoNumbers) {
                                    return name;
                                  }
                                  final port = nameToPortForLabel[name] ?? 0;
                                  final src = outSource[name] ?? 'DIO';
                                  String prefix;
                                  if (src == 'PLC' ||
                                      (src == 'PLC/EIP' &&
                                          _plcEipOption == 'PLC')) {
                                    prefix = 'PLO';
                                  } else if (src == 'EIP' ||
                                      (src == 'PLC/EIP' &&
                                          _plcEipOption == 'EIP')) {
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
                              _chartController.setSignalNames(
                                controllerDisplayNames,
                              );
                              _chartController.setSignals(combinedValues);
                            }
                          }
                        }
                      }
                    }
                  });

                  final foundIni =
                      _vxVisMgrIniContent != null
                          ? 'OK'
                          : 'vxVisMgr.iniが見つかりません';
                  final foundDio =
                      _dioMonitorLogCsvContent != null
                          ? 'OK'
                          : 'DioMonitorLog.csvが見つかりません';
                  final foundPlc =
                      _plcDioMonitorLogCsvContent != null
                          ? 'OK'
                          : 'Plc_DioMonitorLog.csvが見つかりません';
                  final foundFnl =
                      _fnlDioMonitorLogCsvContent != null
                          ? 'OK'
                          : 'FNL_DioMonitorLog.csvが見つかりません';

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'ZIPファイルが正常にインポートされました: vxVisMgr.ini:$foundIni  DioMonitorLog.csv:$foundDio  Plc_DioMonitorLog.csv:$foundPlc  FNL_DioMonitorLog.csv:$foundFnl  EnabledSignals:${_enabledStatusSignals.length}  DioMap:${_dioOutputAssignments.length}  PlcEipMap:${_plcEipOutputAssignments.length}',
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );

                  await _applyOutputAssignments();
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
              },
            ),
            ListTile(
              leading: Icon(Icons.info),
              title: Text(s.menu_item_about),
              onTap: () {
                Navigator.pop(context);
                debugPrint('About');
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
                  setState(() {
                    Map<String, List<int>> existingValuesMap = {};
                    if (_timingChartKey.currentState != null) {
                      final currentChartValues = _chartController.signals;

                      for (
                        int i = 0;
                        i < _chartSignals.length &&
                            i < currentChartValues.length;
                        i++
                      ) {
                        existingValuesMap[_chartSignals[i].name] =
                            currentChartValues[i];
                      }
                    } else {
                      for (var signal in _chartSignals) {
                        existingValuesMap[signal.name] = signal.values;
                      }
                    }

                    List<SignalData> newChartSignals = [];
                    List<IoChannelSource> newChartSources = [];

                    for (int i = 0; i < signalNames.length; i++) {
                      List<int> signalValues;

                      if (overrideFlag) {
                        if (i < chartData.length) {
                          signalValues = List<int>.from(chartData[i]);
                        } else {
                          signalValues = List.filled(32, 0);
                        }
                      } else {
                        if (existingValuesMap.containsKey(signalNames[i])) {
                          signalValues = List<int>.from(
                            existingValuesMap[signalNames[i]]!,
                          );

                          if (i < chartData.length &&
                              signalValues.length != chartData[i].length) {
                            if (signalValues.length < chartData[i].length) {
                              signalValues.addAll(
                                List.filled(
                                  chartData[i].length - signalValues.length,
                                  0,
                                ),
                              );
                            } else if (signalValues.length >
                                chartData[i].length) {}
                          }
                        } else if (i < chartData.length) {
                          signalValues = List<int>.from(chartData[i]);
                        } else {
                          signalValues = List.filled(32, 0);
                        }
                      }

                      newChartSignals.add(
                        SignalData(
                          name: signalNames[i],
                          signalType: signalTypes[i],
                          values: signalValues,
                          isVisible: true,
                        ),
                      );
                      newChartSources.add(
                        _detectIoSourceFor(signalNames[i], signalTypes[i]),
                      );
                    }

                    _chartSignals = newChartSignals;

                    var effectiveSources = List<IoChannelSource>.from(
                      ioSources,
                    );

                    if (!overrideFlag && _timingChartKey.currentState != null) {
                      final currentOrder = _chartController.signalNames;

                      if (currentOrder.isNotEmpty) {
                        final mapByName = {
                          for (final s in _chartSignals) s.name: s,
                        };
                        final sourceByName = <String, List<IoChannelSource>>{};
                        for (int i = 0; i < _chartSignals.length; i++) {
                          final key = _chartSignals[i].name;
                          sourceByName
                              .putIfAbsent(key, () => [])
                              .add(effectiveSources[i]);
                        }

                        final reordered = <SignalData>[];
                        final reorderedSources = <IoChannelSource>[];
                        for (final name in currentOrder) {
                          final signal = mapByName[name];
                          if (signal != null) {
                            reordered.add(signal);
                            final list = sourceByName[name];
                            if (list != null && list.isNotEmpty) {
                              reorderedSources.add(list.removeAt(0));
                            } else {
                              reorderedSources.add(IoChannelSource.unknown);
                            }
                            mapByName.remove(name);
                          }
                        }
                        for (final entry in mapByName.entries) {
                          reordered.add(entry.value);
                          final list = sourceByName[entry.key];
                          if (list != null && list.isNotEmpty) {
                            reorderedSources.add(list.removeAt(0));
                          } else {
                            reorderedSources.add(IoChannelSource.unknown);
                          }
                        }

                        _chartSignals = reordered;
                        effectiveSources = reorderedSources;
                      }
                    }

                    final nameToPort = <String, int>{};
                    for (
                      int i = 0;
                      i < signalNames.length && i < portNumbers.length;
                      i++
                    ) {
                      nameToPort[signalNames[i]] = portNumbers[i];
                    }

                    _chartPortNumbers =
                        _chartSignals
                            .map((s) => nameToPort[s.name] ?? 0)
                            .toList();
                    _chartIoSources = effectiveSources;

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
              ),
            ],
          ),
          if (_isImportingZiq)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha((0.35 * 255).round()),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
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
            ),
        ],
      ),
    );
  }
}

class _OutputAssignment {
  final String name;
  final String suggestionId;
  final int portNo0;
  final int outputIndex1Based;

  const _OutputAssignment({
    required this.name,
    required this.suggestionId,
    required this.portNo0,
    required this.outputIndex1Based,
  });
}
