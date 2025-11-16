import 'package:flutter/foundation.dart';

import '../models/chart/timing_chart_annotation.dart';

/// TimingChart の状態（signals / names / annotations）を集約管理するコントローラ。
///
/// 初期段階ではデータの保管と基本的な更新通知のみに責務を限定し、
/// 個々のビット編集などの細かな操作は従来通りウィジェット側で行います。
class TimingChartController extends ChangeNotifier {
  TimingChartController({
    required List<String> signalNames,
    required List<List<int>> signals,
    required List<TimingChartAnnotation> annotations,
    List<int>? omissionTimeIndices,
  })  : _signalNames = List<String>.from(signalNames),
        _signals = signals.map((e) => List<int>.from(e)).toList(),
        _annotations = List<TimingChartAnnotation>.from(annotations),
        _omissionTimeIndices = List<int>.from(omissionTimeIndices ?? const []);

  factory TimingChartController.fromInitial(
    List<String> initialSignalNames,
    List<List<int>> initialSignals,
    List<TimingChartAnnotation> initialAnnotations,
    {List<int>? omissionTimeIndices}
  ) {
    return TimingChartController(
      signalNames: initialSignalNames,
      signals: initialSignals,
      annotations: initialAnnotations,
      omissionTimeIndices: omissionTimeIndices,
    );
  }

  List<List<int>> _signals;
  List<String> _signalNames;
  List<TimingChartAnnotation> _annotations;
  int _gridResetNonce = 0;
  int _gridRecomputeNonce = 0;
  List<int> _omissionTimeIndices = [];
  List<double> _stepDurationsMs = const [];

  // Undo/Redo履歴管理
  final List<_ChartStateSnapshot> _undoStack = [];
  final List<_ChartStateSnapshot> _redoStack = [];
  static const int _maxHistorySize = 50;
  bool _isUndoRedoOperation = false;

  List<List<int>> get signals => _signals;
  List<String> get signalNames => _signalNames;
  List<TimingChartAnnotation> get annotations => _annotations;
  int get gridResetNonce => _gridResetNonce;
  int get gridRecomputeNonce => _gridRecomputeNonce;
  List<int> get omissionTimeIndices => _omissionTimeIndices;
  List<double> get stepDurationsMs => _stepDurationsMs;

  /// Undoが可能かどうか
  bool get canUndo => _undoStack.isNotEmpty;

  /// Redoが可能かどうか
  bool get canRedo => _redoStack.isNotEmpty;

  /// 現在の状態をスナップショットとして保存
  void _saveSnapshot() {
    if (_isUndoRedoOperation) return;

    final snapshot = _ChartStateSnapshot(
      signals: _signals.map((e) => e.map((v) => v).toList()).toList(),
      signalNames: List<String>.from(_signalNames),
      annotations: List<TimingChartAnnotation>.from(_annotations),
      omissionTimeIndices: List<int>.from(_omissionTimeIndices),
      stepDurationsMs: List<double>.from(_stepDurationsMs),
    );

    _undoStack.add(snapshot);
    if (_undoStack.length > _maxHistorySize) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear(); // 新しい操作が行われたらRedoスタックをクリア
  }

  /// 操作を元に戻す
  void undo() {
    if (!canUndo) return;

    // 現在の状態をRedoスタックに保存
    final currentSnapshot = _ChartStateSnapshot(
      signals: _signals.map((e) => e.map((v) => v).toList()).toList(),
      signalNames: List<String>.from(_signalNames),
      annotations: List<TimingChartAnnotation>.from(_annotations),
      omissionTimeIndices: List<int>.from(_omissionTimeIndices),
      stepDurationsMs: List<double>.from(_stepDurationsMs),
    );
    _redoStack.add(currentSnapshot);

    // Undoスタックから前の状態を取得
    final previousSnapshot = _undoStack.removeLast();

    _isUndoRedoOperation = true;
    _restoreSnapshot(previousSnapshot);
    _isUndoRedoOperation = false;

    notifyListeners();
  }

  /// 操作をやり直す
  void redo() {
    if (!canRedo) return;

    // 現在の状態をUndoスタックに保存
    final currentSnapshot = _ChartStateSnapshot(
      signals: _signals.map((e) => e.map((v) => v).toList()).toList(),
      signalNames: List<String>.from(_signalNames),
      annotations: List<TimingChartAnnotation>.from(_annotations),
      omissionTimeIndices: List<int>.from(_omissionTimeIndices),
      stepDurationsMs: List<double>.from(_stepDurationsMs),
    );
    _undoStack.add(currentSnapshot);

    // Redoスタックから次の状態を取得
    final nextSnapshot = _redoStack.removeLast();

    _isUndoRedoOperation = true;
    _restoreSnapshot(nextSnapshot);
    _isUndoRedoOperation = false;

    notifyListeners();
  }

  /// スナップショットを復元
  void _restoreSnapshot(_ChartStateSnapshot snapshot) {
    _signals = snapshot.signals.map((e) => List<int>.from(e)).toList();
    _signalNames = List<String>.from(snapshot.signalNames);
    _annotations = List<TimingChartAnnotation>.from(snapshot.annotations);
    _omissionTimeIndices = List<int>.from(snapshot.omissionTimeIndices);
    _stepDurationsMs = List<double>.from(snapshot.stepDurationsMs);
  }

  void setSignals(List<List<int>> newSignals) {
    // 変更前の状態を保存（変更されていない場合はスキップ）
    if (!_isUndoRedoOperation && !_areSignalsEqual(_signals, newSignals)) {
      _saveSnapshot();
    }
    _signals = newSignals.map((e) => List<int>.from(e)).toList();
    notifyListeners();
  }

  void setSignalNames(List<String> newNames) {
    // 変更前の状態を保存（変更されていない場合はスキップ）
    if (!_isUndoRedoOperation && !listEquals(_signalNames, newNames)) {
      _saveSnapshot();
    }
    _signalNames = List<String>.from(newNames);
    notifyListeners();
  }

  void setAnnotations(List<TimingChartAnnotation> newAnnotations) {
    // 変更前の状態を保存（変更されていない場合はスキップ）
    if (!_isUndoRedoOperation && !listEquals(_annotations, newAnnotations)) {
      _saveSnapshot();
    }
    _annotations = List<TimingChartAnnotation>.from(newAnnotations);
    notifyListeners();
  }

  void setOmissionTimeIndices(List<int> indices) {
    // 変更前の状態を保存（変更されていない場合はスキップ）
    if (!_isUndoRedoOperation && !listEquals(_omissionTimeIndices, indices)) {
      _saveSnapshot();
    }
    _omissionTimeIndices = List<int>.from(indices);
    notifyListeners();
  }

  void setStepDurationsMs(List<double> durations) {
    // 変更前の状態を保存（変更されていない場合はスキップ）
    if (!_isUndoRedoOperation && !listEquals(_stepDurationsMs, durations)) {
      _saveSnapshot();
    }
    _stepDurationsMs = List<double>.from(durations);
    notifyListeners();
  }

  /// 信号が等しいかどうかを判定
  bool _areSignalsEqual(List<List<int>> a, List<List<int>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!listEquals(a[i], b[i])) return false;
    }
    return true;
  }

  /// チャート側にグリッド調整リセットを要求する（非同期ワンショット）
  void requestGridReset() {
    _gridResetNonce++;
    notifyListeners();
  }

  /// グリッド寸法の再計算（ズーム境界・描画のみ更新、stepDurations は維持）
  void requestGridRecompute() {
    _gridRecomputeNonce++;
    notifyListeners();
  }

  /// 現在の状態をクローンして返す（外部保存等の用途）
  TimingChartController clone() => TimingChartController(
        signalNames: _signalNames,
        signals: _signals,
        annotations: _annotations,
      );
}

/// チャート状態のスナップショット
class _ChartStateSnapshot {
  final List<List<int>> signals;
  final List<String> signalNames;
  final List<TimingChartAnnotation> annotations;
  final List<int> omissionTimeIndices;
  final List<double> stepDurationsMs;

  _ChartStateSnapshot({
    required this.signals,
    required this.signalNames,
    required this.annotations,
    required this.omissionTimeIndices,
    required this.stepDurationsMs,
  });
}


