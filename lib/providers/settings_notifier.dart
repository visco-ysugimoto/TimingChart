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
  static const _kCommentDashedColor = 'commentDashedColor';
  static const _kCommentArrowColor = 'commentArrowColor';
  static const _kOmissionLineColor = 'omissionLineColor';
  static const _kExportFolder = 'exportFolder';
  static const _kFileNamePrefix = 'fileNamePrefix';
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

    final stepJson = p.getString(_kStepDurationsMs);
    if (stepJson != null && stepJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(stepJson);
        if (decoded is List) {
          _stepDurationsMs = decoded
              .map((e) => (e as num).toDouble())
              .where((v) => v.isFinite && v > 0)
              .toList();
        }
      } catch (_) {
        // 破損時は無視してデフォルトを使う
      }
    }

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

    final cDash = p.getInt(_kCommentDashedColor);
    if (cDash != null) _commentDashedColor = Color(cDash);
    final cArrow = p.getInt(_kCommentArrowColor);
    if (cArrow != null) _commentArrowColor = Color(cArrow);
    final cOmit = p.getInt(_kOmissionLineColor);
    if (cOmit != null) _omissionLineColor = Color(cOmit);

    // 入出力
    _exportFolder = p.getString(_kExportFolder) ?? _exportFolder;
    _fileNamePrefix = p.getString(_kFileNamePrefix) ?? _fileNamePrefix;

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
  };
  Map<SignalType, Color> get signalColors => _signalColors;
  void setSignalColor(SignalType type, Color color) {
    _signalColors[type] = color;
    if (type == SignalType.input) {
      _prefs?.setInt(_kColorInput, color.value);
    } else if (type == SignalType.output) {
      _prefs?.setInt(_kColorOutput, color.value);
    } else if (type == SignalType.hwTrigger) {
      _prefs?.setInt(_kColorHwTrigger, color.value);
    }
    notifyListeners();
  }

  void resetSignalColors() {
    _signalColors[SignalType.input] = Colors.blue;
    _signalColors[SignalType.output] = Colors.red;
    _signalColors[SignalType.hwTrigger] = Colors.green;
    _prefs?.setInt(_kColorInput, Colors.blue.value);
    _prefs?.setInt(_kColorOutput, Colors.red.value);
    _prefs?.setInt(_kColorHwTrigger, Colors.green.value);
    notifyListeners();
  }

  // コメント関連の色をデフォルトに戻す
  void resetCommentColors() {
    _commentDashedColor = Colors.black;
    _commentArrowColor = Colors.black;
    _omissionLineColor = Colors.black;
    _prefs?.setInt(_kCommentDashedColor, _commentDashedColor.value);
    _prefs?.setInt(_kCommentArrowColor, _commentArrowColor.value);
    _prefs?.setInt(_kOmissionLineColor, _omissionLineColor.value);
    notifyListeners();
  }

  Color _commentDashedColor = Colors.black;
  Color get commentDashedColor => _commentDashedColor;
  set commentDashedColor(Color c) {
    _commentDashedColor = c;
    _prefs?.setInt(_kCommentDashedColor, c.value);
    notifyListeners();
  }

  Color _commentArrowColor = Colors.black;
  Color get commentArrowColor => _commentArrowColor;
  set commentArrowColor(Color c) {
    _commentArrowColor = c;
    _prefs?.setInt(_kCommentArrowColor, c.value);
    notifyListeners();
  }

  // 省略記号（波線）の色
  Color _omissionLineColor = Colors.black;
  Color get omissionLineColor => _omissionLineColor;
  set omissionLineColor(Color c) {
    if (c != _omissionLineColor) {
      _omissionLineColor = c;
      _prefs?.setInt(_kOmissionLineColor, c.value);
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
      _prefs?.setInt(_kAccentColor, c.value);
      notifyListeners();
    }
  }
}
