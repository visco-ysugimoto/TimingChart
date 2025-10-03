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

  List<List<int>> get signals => _signals;
  List<String> get signalNames => _signalNames;
  List<TimingChartAnnotation> get annotations => _annotations;
  int get gridResetNonce => _gridResetNonce;
  int get gridRecomputeNonce => _gridRecomputeNonce;
  List<int> get omissionTimeIndices => _omissionTimeIndices;
  List<double> get stepDurationsMs => _stepDurationsMs;

  void setSignals(List<List<int>> newSignals) {
    _signals = newSignals.map((e) => List<int>.from(e)).toList();
    notifyListeners();
  }

  void setSignalNames(List<String> newNames) {
    _signalNames = List<String>.from(newNames);
    notifyListeners();
  }

  void setAnnotations(List<TimingChartAnnotation> newAnnotations) {
    _annotations = List<TimingChartAnnotation>.from(newAnnotations);
    notifyListeners();
  }

  void setOmissionTimeIndices(List<int> indices) {
    _omissionTimeIndices = List<int>.from(indices);
    notifyListeners();
  }

  void setStepDurationsMs(List<double> durations) {
    _stepDurationsMs = List<double>.from(durations);
    notifyListeners();
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


