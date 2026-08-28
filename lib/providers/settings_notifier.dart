import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chart/signal_type.dart';

class SettingsNotifier extends ChangeNotifier {
  SharedPreferences? _prefs;
  late final Future<void> initialized;

  // 保存用キー
  static const _kDefaultCameraCount = 'defaultCameraCount';
  static const _kTimeUnitIsMs = 'timeUnitIsMs';
  static const _kMsPerStep = 'msPerStep';
  static const _kStepDurationsMs = 'stepDurationsMs';
  static const _kShowGridLines = 'showGridLines';
  static const _kShowBottomUnitLabels = 'showBottomUnitLabels';
  static const _kDefaultChartLength = 'defaultChartLength';
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
  static const _kDarkMode = 'darkMode';
  static const _kAccentColor = 'accentColor';

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

    // 一般
    _defaultCameraCount = p.getInt(_kDefaultCameraCount) ?? _defaultCameraCount;

    // チャート
    _timeUnitIsMs = p.getBool(_kTimeUnitIsMs) ?? _timeUnitIsMs;
    _msPerStep = p.getDouble(_kMsPerStep) ?? _msPerStep;

    // stepDurationsMs はアプリ起動時に初期化する（前回の値を読み込まない）
    // SharedPreferences からも削除して、常に空のリストから開始する
    _stepDurationsMs = [];
    _prefs?.remove(_kStepDurationsMs);

    _showGridLines = p.getBool(_kShowGridLines) ?? _showGridLines;
    _showBottomUnitLabels =
        p.getBool(_kShowBottomUnitLabels) ?? _showBottomUnitLabels;
    _defaultChartLength = p.getInt(_kDefaultChartLength) ?? _defaultChartLength;

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
    _quickExportEnabled = p.getBool(_kQuickExportEnabled) ?? _quickExportEnabled;

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

  // ───────── チャート ─────────
  // 横軸の単位: true = ms, false = step
  bool _timeUnitIsMs = false;
  bool get timeUnitIsMs => _timeUnitIsMs;
  set timeUnitIsMs(bool v) {
    if (v != _timeUnitIsMs) {
      _timeUnitIsMs = v;
      _prefs?.setBool(_kTimeUnitIsMs, v);
      notifyListeners();
    }
  }

  // 1 step あたりのミリ秒
  double _msPerStep = 1.0;
  double get msPerStep => _msPerStep;
  set msPerStep(double v) {
    if (v > 0 && v != _msPerStep) {
      _msPerStep = v;
      _prefs?.setDouble(_kMsPerStep, v);
      notifyListeners();
    }
  }

  // stepごとの個別時間 [ms]（ms単位使用時の非等間隔に利用）
  List<double> _stepDurationsMs = [];
  List<double> get stepDurationsMs => List.unmodifiable(_stepDurationsMs);
  void setStepDurationsMs(List<double> durations) {
    // 0以下は除外し、最低1msに丸め
    _stepDurationsMs = durations
        .map((e) => e.isFinite && e > 0 ? e : _msPerStep)
        .toList(growable: true);
    _prefs?.setString(_kStepDurationsMs, jsonEncode(_stepDurationsMs));
    notifyListeners();
  }

  void ensureStepDurationsLength(int length) {
    if (length <= 0) return;
    if (_stepDurationsMs.length < length) {
      _stepDurationsMs.addAll(
        List<double>.filled(length - _stepDurationsMs.length, _msPerStep),
      );
      _prefs?.setString(_kStepDurationsMs, jsonEncode(_stepDurationsMs));
      notifyListeners();
    } else if (_stepDurationsMs.length > length) {
      _stepDurationsMs = _stepDurationsMs.sublist(0, length);
      _prefs?.setString(_kStepDurationsMs, jsonEncode(_stepDurationsMs));
      notifyListeners();
    }
  }

  bool _showGridLines = true;
  bool get showGridLines => _showGridLines;
  set showGridLines(bool v) {
    if (v != _showGridLines) {
      _showGridLines = v;
      _prefs?.setBool(_kShowGridLines, v);
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

  int _defaultChartLength = 50;
  int get defaultChartLength => _defaultChartLength;
  set defaultChartLength(int v) {
    if (v != _defaultChartLength && v > 0) {
      _defaultChartLength = v;
      _prefs?.setInt(_kDefaultChartLength, v);
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
    _lastExportDirectory =
        (normalized == null || normalized.isEmpty) ? null : normalized;
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
}
