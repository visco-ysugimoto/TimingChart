import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chart/signal_type.dart';
import '../models/form/form_state.dart';
import '../models/report/html_report_sections.dart';
import '../widgets/form/form_tab_constants.dart';
import '../widgets/form/form_tab_rules.dart';

class SettingsNotifier extends ChangeNotifier {
  SharedPreferences? _prefs;
  late final Future<void> initialized;

  // 保存用キー
  static const _kDefaultCameraCount = 'defaultCameraCount';
  static const _kDefaultTriggerOption = 'defaultTriggerOption';
  static const _kDefaultInputPort = 'defaultInputPort';
  static const _kDefaultOutputPort = 'defaultOutputPort';
  static const _kDefaultHwTriggerEnabled = 'defaultHwTriggerEnabled';
  static const _kDefaultPlcEipOption = 'defaultPlcEipOption';
  static const _kShowIoNumbers = 'showIoNumbers';
  static const _kDefaultTimeUnitIsMs = 'defaultTimeUnitIsMs';
  static const _kTimeUnitIsMs = 'timeUnitIsMs';
  static const _kShowBottomUnitLabels = 'showBottomUnitLabels';
  static const _removedPrefKeys = <String>[
    'showGridLines',
    'defaultChartLength',
    'msPerStep',
    'stepDurationsMs',
  ];
  static const _kColorInput = 'color_input';
  static const _kColorOutput = 'color_output';
  static const _kColorHwTrigger = 'color_hwTrigger';
  static const _kColorAuxiliary = 'color_auxiliary';
  static const _kCommentDashedColor = 'commentDashedColor';
  static const _kCommentArrowColor = 'commentArrowColor';
  static const _kOmissionLineColor = 'omissionLineColor';
  static const _kExportFolder = 'exportFolder';
  static const _kFileNamePrefix = 'fileNamePrefix';
  static const _kLastExportDirectory = 'lastExportDirectory';
  static const _kQuickExportEnabled = 'quickExportEnabled';
  static const _kHtmlReportSections = 'htmlReportSections';
  static const _kDarkMode = 'darkMode';
  static const _kAccentColor = 'accentColor';

  static const _managedPrefKeys = <String>[
    _kDefaultCameraCount,
    _kDefaultTriggerOption,
    _kDefaultInputPort,
    _kDefaultOutputPort,
    _kDefaultHwTriggerEnabled,
    _kDefaultPlcEipOption,
    _kShowIoNumbers,
    _kDefaultTimeUnitIsMs,
    _kTimeUnitIsMs,
    _kShowBottomUnitLabels,
    _kColorInput,
    _kColorOutput,
    _kColorHwTrigger,
    _kColorAuxiliary,
    _kCommentDashedColor,
    _kCommentArrowColor,
    _kOmissionLineColor,
    _kExportFolder,
    _kFileNamePrefix,
    _kLastExportDirectory,
    _kQuickExportEnabled,
    _kHtmlReportSections,
    _kDarkMode,
    _kAccentColor,
  ];

  SettingsNotifier() {
    initialized = _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    final p = _prefs;
    if (p == null) return;

    for (final key in _removedPrefKeys) {
      p.remove(key);
    }

    // 一般
    _defaultCameraCount = p.getInt(_kDefaultCameraCount) ?? _defaultCameraCount;
    _defaultInputPort = _clampPort(
      p.getInt(_kDefaultInputPort) ?? _defaultInputPort,
    );
    _defaultOutputPort = _clampPort(
      p.getInt(_kDefaultOutputPort) ?? _defaultOutputPort,
    );
    _defaultTriggerOption = _normalizeTriggerOption(
      p.getString(_kDefaultTriggerOption) ?? _defaultTriggerOption,
      _defaultInputPort,
    );
    _defaultHwTriggerEnabled =
        p.getBool(_kDefaultHwTriggerEnabled) ?? _defaultHwTriggerEnabled;
    _defaultPlcEipOption = _normalizePlcEipOption(
      p.getString(_kDefaultPlcEipOption) ?? _defaultPlcEipOption,
    );
    _showIoNumbers = p.getBool(_kShowIoNumbers) ?? _showIoNumbers;

    // チャート
    // 旧キー timeUnitIsMs は「表示中チャートの単位」と混ざっていたため、
    // 既定値へ移行してから削除する。
    _defaultTimeUnitIsMs =
        p.getBool(_kDefaultTimeUnitIsMs) ??
        p.getBool(_kTimeUnitIsMs) ??
        _defaultTimeUnitIsMs;
    if (!p.containsKey(_kDefaultTimeUnitIsMs) &&
        p.containsKey(_kTimeUnitIsMs)) {
      p.setBool(_kDefaultTimeUnitIsMs, _defaultTimeUnitIsMs);
    }
    p.remove(_kTimeUnitIsMs);
    _timeUnitIsMs = _defaultTimeUnitIsMs;
    _msPerStep = 1.0;
    _stepDurationsMs = [];
    _showBottomUnitLabels =
        p.getBool(_kShowBottomUnitLabels) ?? _showBottomUnitLabels;

    final ci = p.getInt(_kColorInput);
    if (ci != null) _signalColors[SignalType.input] = Color(ci);
    final co = p.getInt(_kColorOutput);
    if (co != null) _signalColors[SignalType.output] = Color(co);
    final ch = p.getInt(_kColorHwTrigger);
    if (ch != null) _signalColors[SignalType.hwTrigger] = Color(ch);
    final ca = p.getInt(_kColorAuxiliary);
    if (ca != null) _signalColors[SignalType.auxiliary] = Color(ca);

    final cDash = p.getInt(_kCommentDashedColor);
    if (cDash != null) _commentDashedColor = Color(cDash);
    final cArrow = p.getInt(_kCommentArrowColor);
    if (cArrow != null) _commentArrowColor = Color(cArrow);
    final cOmit = p.getInt(_kOmissionLineColor);
    if (cOmit != null) _omissionLineColor = Color(cOmit);

    // 入出力
    _exportFolder = p.getString(_kExportFolder) ?? _exportFolder;
    _fileNamePrefix = p.getString(_kFileNamePrefix) ?? _fileNamePrefix;
    _lastExportDirectory = p.getString(_kLastExportDirectory);
    _quickExportEnabled =
        p.getBool(_kQuickExportEnabled) ?? _quickExportEnabled;
    _htmlReportSections = HtmlReportSectionSet.fromPrefIds(
      p.getStringList(_kHtmlReportSections),
    );

    // 外観
    _darkMode = p.getBool(_kDarkMode) ?? _darkMode;
    final acc = p.getInt(_kAccentColor);
    if (acc != null) _accentColor = Color(acc);

    notifyListeners();
  }

  // ───────── 一般 ─────────
  int _defaultCameraCount = 1;
  int get defaultCameraCount => _defaultCameraCount;
  set defaultCameraCount(int v) {
    // 許可範囲は 1 〜 8
    if (v < 1 || v > 8) return;
    if (v != _defaultCameraCount) {
      _defaultCameraCount = v;
      _prefs?.setInt(_kDefaultCameraCount, v);
      notifyListeners();
    }
  }

  String _defaultTriggerOption = TriggerOptions.single;
  String get defaultTriggerOption => _defaultTriggerOption;
  set defaultTriggerOption(String v) {
    final next = _normalizeTriggerOption(v, _defaultInputPort);
    if (next == _defaultTriggerOption) return;
    _defaultTriggerOption = next;
    _prefs?.setString(_kDefaultTriggerOption, next);
    notifyListeners();
  }

  int _defaultInputPort = 32;
  int get defaultInputPort => _defaultInputPort;
  set defaultInputPort(int v) {
    final next = _clampPort(v);
    if (next == _defaultInputPort) return;
    _defaultInputPort = next;
    _prefs?.setInt(_kDefaultInputPort, next);
    final trigger = _normalizeTriggerOption(_defaultTriggerOption, next);
    if (trigger != _defaultTriggerOption) {
      _defaultTriggerOption = trigger;
      _prefs?.setString(_kDefaultTriggerOption, trigger);
    }
    notifyListeners();
  }

  int _defaultOutputPort = 32;
  int get defaultOutputPort => _defaultOutputPort;
  set defaultOutputPort(int v) {
    final next = _clampPort(v);
    if (next == _defaultOutputPort) return;
    _defaultOutputPort = next;
    _prefs?.setInt(_kDefaultOutputPort, next);
    notifyListeners();
  }

  bool _defaultHwTriggerEnabled = false;
  bool get defaultHwTriggerEnabled => _defaultHwTriggerEnabled;
  set defaultHwTriggerEnabled(bool v) {
    if (v == _defaultHwTriggerEnabled) return;
    _defaultHwTriggerEnabled = v;
    _prefs?.setBool(_kDefaultHwTriggerEnabled, v);
    notifyListeners();
  }

  String _defaultPlcEipOption = PlcEipOptions.none;
  String get defaultPlcEipOption => _defaultPlcEipOption;
  set defaultPlcEipOption(String v) {
    final next = _normalizePlcEipOption(v);
    if (next == _defaultPlcEipOption) return;
    _defaultPlcEipOption = next;
    _prefs?.setString(_kDefaultPlcEipOption, next);
    notifyListeners();
  }

  /// 新規作成 / Clear 時に使うフォーム初期値
  TimingFormState get defaultFormState {
    return TimingFormState(
      triggerOption: _defaultTriggerOption,
      ioPort: _defaultInputPort,
      hwPort: _defaultHwTriggerEnabled ? _defaultCameraCount : 0,
      camera: _defaultCameraCount,
      inputCount: _defaultInputPort,
      outputCount: _defaultOutputPort,
    );
  }

  static int _clampPort(int v) {
    if (FormTabRules.portOptions.contains(v)) return v;
    return FormTabRules.portOptions.last;
  }

  static String _normalizeTriggerOption(String value, int inputPort) {
    final allowed = FormTabRules.triggerOptionsForInputCount(inputPort);
    if (allowed.contains(value)) return value;
    return TriggerOptions.single;
  }

  static String _normalizePlcEipOption(String value) {
    if (value == PlcEipOptions.plc || value == PlcEipOptions.eip) {
      return value;
    }
    return PlcEipOptions.none;
  }

  bool _showIoNumbers = true;
  bool get showIoNumbers => _showIoNumbers;
  set showIoNumbers(bool v) {
    if (v == _showIoNumbers) return;
    _showIoNumbers = v;
    _prefs?.setBool(_kShowIoNumbers, v);
    notifyListeners();
  }

  // ───────── チャート ─────────
  // 新規作成時の既定単位: true = ms, false = step
  bool _defaultTimeUnitIsMs = false;
  bool get defaultTimeUnitIsMs => _defaultTimeUnitIsMs;
  set defaultTimeUnitIsMs(bool v) {
    if (v == _defaultTimeUnitIsMs) return;
    _defaultTimeUnitIsMs = v;
    _prefs?.setBool(_kDefaultTimeUnitIsMs, v);
    notifyListeners();
  }

  // 表示中チャートの横軸単位（チャート固有。永続化しない）
  bool _timeUnitIsMs = false;
  bool get timeUnitIsMs => _timeUnitIsMs;
  set timeUnitIsMs(bool v) {
    if (v != _timeUnitIsMs) {
      _timeUnitIsMs = v;
      notifyListeners();
    }
  }

  void applyDefaultTimeUnit() {
    timeUnitIsMs = _defaultTimeUnitIsMs;
  }

  // 1 step あたりのミリ秒（チャート固有。永続化しない）
  double _msPerStep = 1.0;
  double get msPerStep => _msPerStep;
  set msPerStep(double v) {
    if (v > 0 && v != _msPerStep) {
      _msPerStep = v;
      notifyListeners();
    }
  }

  // stepごとの個別時間 [ms]（ms単位使用時の非等間隔に利用。永続化しない）
  List<double> _stepDurationsMs = [];
  List<double> get stepDurationsMs => List.unmodifiable(_stepDurationsMs);
  void setStepDurationsMs(List<double> durations) {
    // 0以下は除外し、最低1msに丸め
    _stepDurationsMs = durations
        .map((e) => e.isFinite && e > 0 ? e : _msPerStep)
        .toList(growable: true);
    notifyListeners();
  }

  void ensureStepDurationsLength(int length) {
    if (length <= 0) return;
    if (_stepDurationsMs.length < length) {
      _stepDurationsMs.addAll(
        List<double>.filled(length - _stepDurationsMs.length, _msPerStep),
      );
      notifyListeners();
    } else if (_stepDurationsMs.length > length) {
      _stepDurationsMs = _stepDurationsMs.sublist(0, length);
      notifyListeners();
    }
  }

  // チャート下側の時間ラベル（単位）の表示/非表示
  bool _showBottomUnitLabels = true;
  bool get showBottomUnitLabels => _showBottomUnitLabels;
  set showBottomUnitLabels(bool v) {
    if (v != _showBottomUnitLabels) {
      _showBottomUnitLabels = v;
      _prefs?.setBool(_kShowBottomUnitLabels, v);
      notifyListeners();
    }
  }

  final Map<SignalType, Color> _signalColors = {
    SignalType.input: Colors.blue,
    SignalType.output: Colors.red,
    SignalType.hwTrigger: Colors.green,
    SignalType.auxiliary: Colors.orange,
  };
  Map<SignalType, Color> get signalColors => _signalColors;
  void setSignalColor(SignalType type, Color color) {
    _signalColors[type] = color;
    if (type == SignalType.input) {
      _prefs?.setInt(_kColorInput, color.toARGB32());
    } else if (type == SignalType.output) {
      _prefs?.setInt(_kColorOutput, color.toARGB32());
    } else if (type == SignalType.hwTrigger) {
      _prefs?.setInt(_kColorHwTrigger, color.toARGB32());
    } else if (type == SignalType.auxiliary) {
      _prefs?.setInt(_kColorAuxiliary, color.toARGB32());
    }
    notifyListeners();
  }

  void resetSignalColors() {
    _signalColors[SignalType.input] = Colors.blue;
    _signalColors[SignalType.output] = Colors.red;
    _signalColors[SignalType.hwTrigger] = Colors.green;
    _signalColors[SignalType.auxiliary] = Colors.orange;
    _prefs?.setInt(_kColorInput, Colors.blue.toARGB32());
    _prefs?.setInt(_kColorOutput, Colors.red.toARGB32());
    _prefs?.setInt(_kColorHwTrigger, Colors.green.toARGB32());
    _prefs?.setInt(_kColorAuxiliary, Colors.orange.toARGB32());
    notifyListeners();
  }

  // コメント関連の色をデフォルトに戻す
  void resetCommentColors() {
    _commentDashedColor = Colors.black;
    _commentArrowColor = Colors.black;
    _omissionLineColor = Colors.black;
    _prefs?.setInt(_kCommentDashedColor, _commentDashedColor.toARGB32());
    _prefs?.setInt(_kCommentArrowColor, _commentArrowColor.toARGB32());
    _prefs?.setInt(_kOmissionLineColor, _omissionLineColor.toARGB32());
    notifyListeners();
  }

  Color _commentDashedColor = Colors.black;
  Color get commentDashedColor => _commentDashedColor;
  set commentDashedColor(Color c) {
    _commentDashedColor = c;
    _prefs?.setInt(_kCommentDashedColor, c.toARGB32());
    notifyListeners();
  }

  Color _commentArrowColor = Colors.black;
  Color get commentArrowColor => _commentArrowColor;
  set commentArrowColor(Color c) {
    _commentArrowColor = c;
    _prefs?.setInt(_kCommentArrowColor, c.toARGB32());
    notifyListeners();
  }

  // 省略記号（波線）の色
  Color _omissionLineColor = Colors.black;
  Color get omissionLineColor => _omissionLineColor;
  set omissionLineColor(Color c) {
    if (c != _omissionLineColor) {
      _omissionLineColor = c;
      _prefs?.setInt(_kOmissionLineColor, c.toARGB32());
      notifyListeners();
    }
  }

  // ───────── 入出力 ─────────
  String _exportFolder = 'Export Chart';
  String get exportFolder => _exportFolder;
  set exportFolder(String path) {
    if (path != _exportFolder && path.isNotEmpty) {
      _exportFolder = path;
      _prefs?.setString(_kExportFolder, path);
      notifyListeners();
    }
  }

  String _fileNamePrefix = '';
  String get fileNamePrefix => _fileNamePrefix;
  set fileNamePrefix(String v) {
    _fileNamePrefix = v;
    _prefs?.setString(_kFileNamePrefix, v);
    notifyListeners();
  }

  String? _lastExportDirectory;
  String? get lastExportDirectory => _lastExportDirectory;
  set lastExportDirectory(String? path) {
    final normalized = path?.trim();
    if (normalized == _lastExportDirectory) return;
    _lastExportDirectory = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;
    if (_lastExportDirectory == null) {
      _prefs?.remove(_kLastExportDirectory);
    } else {
      _prefs?.setString(_kLastExportDirectory, _lastExportDirectory!);
    }
    notifyListeners();
  }

  bool _quickExportEnabled = true;
  bool get quickExportEnabled => _quickExportEnabled;
  set quickExportEnabled(bool v) {
    if (v == _quickExportEnabled) return;
    _quickExportEnabled = v;
    _prefs?.setBool(_kQuickExportEnabled, v);
    notifyListeners();
  }

  HtmlReportSectionSet _htmlReportSections = HtmlReportSectionSet.all;
  HtmlReportSectionSet get htmlReportSections => _htmlReportSections;
  set htmlReportSections(HtmlReportSectionSet v) {
    if (!v.hasAny || v == _htmlReportSections) return;
    _htmlReportSections = v;
    _prefs?.setStringList(_kHtmlReportSections, v.toPrefIds());
    notifyListeners();
  }

  // ───────── 外観 ─────────
  bool _darkMode = false;
  bool get darkMode => _darkMode;
  set darkMode(bool v) {
    if (v != _darkMode) {
      _darkMode = v;
      _prefs?.setBool(_kDarkMode, v);
      notifyListeners();
    }
  }

  Color _accentColor = Colors.blue;
  Color get accentColor => _accentColor;
  set accentColor(Color c) {
    if (c != _accentColor) {
      _accentColor = c;
      _prefs?.setInt(_kAccentColor, c.toARGB32());
      notifyListeners();
    }
  }

  /// 言語以外のアプリ設定を初期値に戻す
  Future<void> resetAll() async {
    _defaultCameraCount = 1;
    _defaultTriggerOption = TriggerOptions.single;
    _defaultInputPort = 32;
    _defaultOutputPort = 32;
    _defaultHwTriggerEnabled = false;
    _defaultPlcEipOption = PlcEipOptions.none;
    _showIoNumbers = true;
    _defaultTimeUnitIsMs = false;
    _timeUnitIsMs = false;
    _msPerStep = 1.0;
    _stepDurationsMs = [];
    _showBottomUnitLabels = true;
    _signalColors[SignalType.input] = Colors.blue;
    _signalColors[SignalType.output] = Colors.red;
    _signalColors[SignalType.hwTrigger] = Colors.green;
    _signalColors[SignalType.auxiliary] = Colors.orange;
    _commentDashedColor = Colors.black;
    _commentArrowColor = Colors.black;
    _omissionLineColor = Colors.black;
    _exportFolder = 'Export Chart';
    _fileNamePrefix = '';
    _lastExportDirectory = null;
    _quickExportEnabled = true;
    _htmlReportSections = HtmlReportSectionSet.all;
    _darkMode = false;
    _accentColor = Colors.blue;

    final p = _prefs;
    if (p != null) {
      for (final key in [..._managedPrefKeys, ..._removedPrefKeys]) {
        await p.remove(key);
      }
    }
    notifyListeners();
  }
}
