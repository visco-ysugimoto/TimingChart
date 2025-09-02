import 'package:flutter/material.dart';
import '../models/chart/signal_type.dart';

class SettingsNotifier extends ChangeNotifier {
  // ───────── 一般 ─────────
  int _defaultCameraCount = 1;
  int get defaultCameraCount => _defaultCameraCount;
  set defaultCameraCount(int v) {
    // 許可範囲は 1 〜 8
    if (v < 1 || v > 8) return;
    if (v != _defaultCameraCount) {
      _defaultCameraCount = v;
      notifyListeners();
    }
  }

  // ───────── チャート ─────────
  bool _showGridLines = true;
  bool get showGridLines => _showGridLines;
  set showGridLines(bool v) {
    if (v != _showGridLines) {
      _showGridLines = v;
      notifyListeners();
    }
  }

  int _defaultChartLength = 50;
  int get defaultChartLength => _defaultChartLength;
  set defaultChartLength(int v) {
    if (v != _defaultChartLength && v > 0) {
      _defaultChartLength = v;
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
    notifyListeners();
  }

  void resetSignalColors() {
    _signalColors[SignalType.input] = Colors.blue;
    _signalColors[SignalType.output] = Colors.red;
    _signalColors[SignalType.hwTrigger] = Colors.green;
    notifyListeners();
  }

  // コメント関連の色をデフォルトに戻す
  void resetCommentColors() {
    _commentDashedColor = Colors.black;
    _commentArrowColor = Colors.black;
    _omissionLineColor = Colors.black;
    notifyListeners();
  }

  Color _commentDashedColor = Colors.black;
  Color get commentDashedColor => _commentDashedColor;
  set commentDashedColor(Color c) {
    _commentDashedColor = c;
    notifyListeners();
  }

  Color _commentArrowColor = Colors.black;
  Color get commentArrowColor => _commentArrowColor;
  set commentArrowColor(Color c) {
    _commentArrowColor = c;
    notifyListeners();
  }

  // 省略記号（波線）の色
  Color _omissionLineColor = Colors.black;
  Color get omissionLineColor => _omissionLineColor;
  set omissionLineColor(Color c) {
    if (c != _omissionLineColor) {
      _omissionLineColor = c;
      notifyListeners();
    }
  }

  // ───────── 入出力 ─────────
  String _exportFolder = 'Export Chart';
  String get exportFolder => _exportFolder;
  set exportFolder(String path) {
    if (path != _exportFolder && path.isNotEmpty) {
      _exportFolder = path;
      notifyListeners();
    }
  }

  String _fileNamePrefix = '';
  String get fileNamePrefix => _fileNamePrefix;
  set fileNamePrefix(String v) {
    _fileNamePrefix = v;
    notifyListeners();
  }

  // ───────── 外観 ─────────
  bool _darkMode = false;
  bool get darkMode => _darkMode;
  set darkMode(bool v) {
    if (v != _darkMode) {
      _darkMode = v;
      notifyListeners();
    }
  }

  Color _accentColor = Colors.blue;
  Color get accentColor => _accentColor;
  set accentColor(Color c) {
    if (c != _accentColor) {
      _accentColor = c;
      notifyListeners();
    }
  }

  // No direct language here; handled by LocaleNotifier.
}
