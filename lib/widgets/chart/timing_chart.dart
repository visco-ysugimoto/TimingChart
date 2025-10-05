/*
TimingChart�E�タイミングチャート描画�E�E

こ�EウィジェチE��でできること
- チE��タル信号の波形�E�E/1�E�をグリチE��上に描画
- ラベルのドラチE��で行�E並び替え、篁E��選択で一括反転/挿入/削除/褁E��
- 右クリチE��メニューからコメント追加・編雁E�E削除、波線（省略区間）�E描画
- 画像�E力！ENG/JPEG�E�用のキャプチャ

入力と出力（親からの受け取り / 親へ提供する情報�E�E
- initialSignalNames/initialSignals/initialAnnotations/signalTypes/portNumbers を受け取り表示
- getChartData(), getAnnotations(), getSignalIdNames(), getOmissionTimeIndices() で親が取得可能
- updateSignals()/updateSignalNames()/updateAnnotations() で親が�E描画要求可能

設計�E要点
- 画面サイズに合わせたセル幁Eセル高�E動的計算！EitToScreen�E�E
- SignalType で補助信号(control/group/task)を描ぁE描かなぁE��刁E��
- ラベルは ID から現在言語�Eラベルへ翻訳�E�EuggestionLoader 経由�E�E
- CustomPainter へ責務�E割�E�グリチE��/波形/コメント）して見通し改喁E
*/
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../models/chart/timing_chart_annotation.dart';
import '../../models/chart/signal_type.dart';
import '../../models/chart/io_channel_source.dart';
import 'chart_annotations.dart';
import 'chart_grid.dart';
import 'chart_signals.dart';
import 'chart_drawing_util.dart';
import '../../suggestion_loader.dart';
import '../../providers/settings_notifier.dart';
import 'package:provider/provider.dart'; // Added for Provider
import '../../generated/l10n.dart';
import '../../providers/timing_chart_controller.dart';

// Add translation support

class TimingChart extends StatefulWidget {
  final List<String> initialSignalNames;
  final List<List<int>> initialSignals;
  final List<TimingChartAnnotation> initialAnnotations;
  final List<SignalType> signalTypes;
  final TimingChartController? controller;

  /// 画面サイズに合わせてチャート�E体をフィチE��させるかどぁE��、E
  ///
  /// true の場合�E、横幁E��けでなく縦方向（信号数�E�も含めて
  /// 表示領域に収まるよぁE��セルサイズを�E動調整します、E
  /// false�E�デフォルト）�E場合�E従来と同じ動作で、横方向�Eみ縮小し、E
  /// セル高さは固宁E40px になります、E
  final bool fitToScreen;

  /// Control / Group / Task 種別を含むすべての信号を描画対象にするかどぁE��、E
  /// 省略時�E従来互換で false�E�これらの補助信号は描画しなぁE��、E
  final bool showAllSignalTypes;

  /// 入出力信号ラベルに番号 (Input1 などの末尾数孁E を表示するかどぁE��、E
  /// 省略時�E true (番号を表示)、E
  final bool showIoNumbers;

  final List<int> portNumbers;
  final List<IoChannelSource> ioSources;
  final String plcEipMode;
  final void Function(
    List<String> names,
    List<List<int>> values,
    List<SignalType> types,
  )?
  onSignalsChanged;

  const TimingChart({
    super.key,
    required this.initialSignalNames,
    required this.initialSignals,
    required this.initialAnnotations,
    required this.signalTypes,
    this.controller,
    this.fitToScreen = false,
    this.showAllSignalTypes = false,
    this.showIoNumbers = true,
    required this.portNumbers,
    this.ioSources = const [],
    this.plcEipMode = 'None',
    this.onSignalsChanged,
  });

  @override
  State<TimingChart> createState() => TimingChartState();
}

class TimingChartState extends State<TimingChart>
    with AutomaticKeepAliveClientMixin {
  TimingChartController? _controller;
  late final VoidCallback _controllerListener;
  // 保持用: ID 名リスチE
  late List<String> _idSignalNames;

  // 言語変更監視用
  late final VoidCallback _langListener;

  @override
  bool get wantKeepAlive => true;

  late List<List<int>> signals;
  late List<String> signalNames;
  late List<TimingChartAnnotation> annotations;
  List<int> _highlightTimeIndices = [];
  // 省略信号を描画する対象の時刻インチE��クス
  List<int> _omissionTimeIndices = [];
  List<int> _visibleIndexes = [];

  // ===== ラベルドラチE��用 =====
  bool _isLabelDrag = false;
  int? _labelDragStartRow;
  int? _labelDragCurrentRow;

  double _cellWidth = 40;
  // セル高さは `fitToScreen` ぁEtrue の場合�Eみ動的に変化する、E
  // チE��ォルト値は従来互換用に 40 としておく、E
  double _cellHeight = 40;
  double _zoomFactor = 1.0; // Horizontal scaling multiplier.
  double _effectiveZoomFactor = 1.0;
  double _minZoomFactorForView = 1.0;
  double _maxZoomFactorForView = 10.0; // レイアウト時に動的に設定（上限撤廁E�Eため�E�E
  static const double _minZoom = 0.1;
  static const double _zoomStep = 0.25;
  static const double _minZoomCellWidth = 2.0;
  static const double _maxZoomCellWidth = 500.0;

  bool _isModifierPressed = false;
  final double labelWidth = 200.0;
  // コメントエリアの高さ�E�動皁E��算時の下限値�E�E
  static const double _minCommentAreaHeight = 100.0;

  // コメントが無ぁE��合に確保する最小下余白
  static const double _noCommentBottomMargin = 40.0;

  /// コメントがはみ出さなぁE��ぁE��忁E��な高さを概算で計算する、E
  ///
  /// 現在の描画ロジチE��では、コメントが重なるごとに 20px ずつ下方向に
  /// ずらしてぁE��ため、E
  ///   base + 20px * (コメント数 - 1) でおおよその忁E��E��域を見積もる、E
  /// 実際のチE��スト高さを完�Eに反映するわけではなぁE��、E
  /// 大量�Eコメント�E力時でも最低限刁E��取られなぁE��け�E余白を確保できる、E
  double _calculateCommentAreaHeight() {
    if (annotations.isEmpty) return _noCommentBottomMargin;

    const double baseHeight = 40.0; // 1 段目の想定高さ
    const double stepHeight = 20.0; // 衝突回避で 1 段深くするごとの増�E

    final int layers = annotations.length - 1;
    final double estimated = baseHeight + stepHeight * layers;

    // コメント�EチE��ス高さの1.5倍程度の余白を確俁E
    final double expanded = estimated * 1.5;

    // 最低でも下限値は確保しつつ、ゆとりを持たせた値を返す
    return math.max(_minCommentAreaHeight, expanded);
  }

  final double chartMarginLeft = 16.0;
  final double chartMarginTop = 16.0;
  // ヘッダー(トグル)の固定高さ。ヒチE��チE��ト補正に使用
  final double _fixedHeaderHeight = 48.0;

  int? _startSignalIndex;
  int? _endSignalIndex;
  int? _startTimeIndex;
  int? _endTimeIndex;

  Offset? _lastRightClickPos;

  String? _selectedAnnotationId;

  Map<String, Rect> _annotationHitRects = {};
  // コメント�EチE��スドラチE��用
  String? _draggingAnnotationId;
  Offset? _draggingStartLocal; // ドラチE��開始時のローカル座樁E
  Offset? _draggingInitialBoxTopLeft; // ドラチE��開始時のボックス位置

  Offset? _dragStartGlobal;

  // 描画用のキー
  final GlobalKey _customPaintKey = GlobalKey();
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  // スクロール制御
  final ScrollController _hScrollController = ScrollController();
  final ScrollController _vScrollController = ScrollController();

  // ===== メモリ編雁E��ード！Es非等間隔�E寸法編雁E��E=====
  bool _isEditingSteps = false;
  int? _activeStepIndex; // 強調する墁E�� i�E�E は 0..maxTimeSteps�E�E
  double? _dragStartX;

  @override
  void initState() {
    super.initState();
    _idSignalNames = List.from(widget.initialSignalNames);
    signalNames = List.from(_idSignalNames); // 仮で ID 表示

    // 初期化時に ID ↁE現在言語ラベルへ変換してから描画する
    // 初期翻訳
    _translateNames();

    // 言語変更リスナ�E
    _langListener = () {
      _translateNames();
    };
    suggestionLanguageVersion.addListener(_langListener);

    HardwareKeyboard.instance.addHandler(_handleModifierKeyEvent);
    _isModifierPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // コントローラ初期化（外部提供がなければ冁E��で生�E�E�E
    _controller =
        widget.controller ??
        TimingChartController.fromInitial(
          widget.initialSignalNames,
          widget.initialSignals,
          widget.initialAnnotations,
          omissionTimeIndices: _omissionTimeIndices,
        );
    signals = _controller!.signals.map((list) => List<int>.from(list)).toList();
    annotations = List.from(_controller!.annotations);

    _controllerListener = () {
      if (!mounted) return;
      final List<List<int>> controllerSignals =
          _controller!.signals.map((e) => List<int>.from(e)).toList();
      final List<String> controllerNames =
          List<String>.from(_controller!.signalNames);
      final bool namesChanged =
          !listEquals(_idSignalNames, controllerNames);
      final List<TimingChartAnnotation> controllerAnnotations =
          List.from(_controller!.annotations);
      final List<int> controllerOmission =
          List<int>.from(_controller!.omissionTimeIndices);

      setState(() {
        signals = controllerSignals;
        _idSignalNames = controllerNames;
        annotations = controllerAnnotations;
        _omissionTimeIndices = controllerOmission;
        _forceRepaint();
      });
      if (namesChanged) {
        _translateNames();
      }
      // ziq インポ�Eト等で signals 長が変わった際、ms モード�Eために stepDurations 長を同朁E
      final settingsRW = Provider.of<SettingsNotifier>(context, listen: false);
      final int maxLen =
          signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);
      if (settingsRW.stepDurationsMs.length != maxLen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) settingsRW.ensureStepDurationsLength(maxLen);
        });
      }
      // グリチE��リセチE��要求が来てぁE��ら適用
      if (_lastHandledGridResetNonce != _controller!.gridResetNonce) {
        _lastHandledGridResetNonce = _controller!.gridResetNonce;
        resetGridAdjustments();
      }
      // ズーム墁E��・セル幁E�E計算を要求されたら�Eビルドで反映
      if (_lastHandledGridRecomputeNonce != _controller!.gridRecomputeNonce) {
        _lastHandledGridRecomputeNonce = _controller!.gridRecomputeNonce;
        setState(() {});
      }
    };
    _controller!.addListener(_controllerListener);
  }

  // 信号チE�Eタを更新するメソチE��
  void updateSignals(List<List<int>> newSignals) {
    setState(() {
      signals = newSignals.map((list) => List<int>.from(list)).toList();
      _forceRepaint();
    });
    _controller?.setSignals(signals);
  }

  void _notifySignalsChanged() {
    final callback = widget.onSignalsChanged;
    if (callback == null) return;
    final names = List<String>.from(_idSignalNames);
    final values = signals
        .map((row) => List<int>.from(row))
        .toList(growable: false);
    final types = List<SignalType>.from(widget.signalTypes);
    callback(names, values, types);
  }

  void _commitSignalsFromChartEdit() {
    _controller?.setSignals(signals);
    _notifySignalsChanged();
  }

  // アノテーションを更新するメソチE��
  void updateAnnotations(List<TimingChartAnnotation> newAnnotations) {
    setState(() {
      annotations = List.from(newAnnotations);
      _forceRepaint();
    });
    _controller?.setAnnotations(annotations);
  }

  // 信号名を更新するメソチE��
  void updateSignalNames(List<String> newIdNames) {
    if (listEquals(_idSignalNames, newIdNames)) {
      return;
    }
    setState(() {
      _idSignalNames = List.from(newIdNames);
      _forceRepaint();
    });
    _controller?.setSignalNames(_idSignalNames);
    _translateNames();
  }

  // ID ↁE現在言語ラベルへ変換して UI へ反映
  void _translateNames() async {
    final translated = await Future.wait(
      _idSignalNames.map((id) async {
        // 形弁E PREFIXn: ID なめEID 部刁E�Eみ翻訳し、PREFIXn: の後に半角スペ�Eスを保つ
        final int colonIdx = id.indexOf(':');
        if (colonIdx > 0) {
          final prefix = id.substring(0, colonIdx + 1); // 含む
          final raw = id.substring(colonIdx + 1).trim();
          final label = await labelOfId(raw);
          return '$prefix $label';
        }
        return await labelOfId(id);
      }),
    );
    if (!mounted) return;
    setState(() {
      signalNames = translated;
      _forceRepaint();
    });
  }

  // 現在の信号チE�Eタを取得するメソチE��
  List<List<int>> getChartData() {
    debugPrint('===== チャートデータ取征E=====');
    debugPrint('信号数: ${signals.length}');
    debugPrint('信号吁E $signalNames');
    debugPrint('信号タイチE ${widget.signalTypes}');

    List<List<int>> result = List.from(signals);
    debugPrint('返却するチE�Eタ行数: ${result.length}');
    if (result.isNotEmpty) {
      debugPrint('最初�E行�EチE�Eタ侁E ${result[0].take(10)}...');
    }
    debugPrint('===== チャートデータ取得終亁E=====');
    return result;
  }

  @override
  void didUpdateWidget(covariant TimingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool namesChanged =
        !listEquals(widget.initialSignalNames, oldWidget.initialSignalNames);
    if (namesChanged ||
        !_areSignalsEqual(widget.initialSignals, oldWidget.initialSignals) ||
        !_areAnnotationsEqual(
          widget.initialAnnotations,
          oldWidget.initialAnnotations,
        )) {
      setState(() {
        if (namesChanged) {
          _idSignalNames = List.from(widget.initialSignalNames);
          signalNames = List.from(_idSignalNames); // 仮で ID 表示
          _translateNames();
        }
        signals =
            widget.initialSignals.map((list) => List<int>.from(list)).toList();
        annotations = List.from(widget.initialAnnotations);
      });
    }
  }

  bool _areSignalsEqual(List<List<int>> a, List<List<int>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!listEquals(a[i], b[i])) return false;
    }
    return true;
  }

  bool _areAnnotationsEqual(
    List<TimingChartAnnotation> a,
    List<TimingChartAnnotation> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].startTimeIndex != b[i].startTimeIndex ||
          a[i].endTimeIndex != b[i].endTimeIndex ||
          a[i].text != b[i].text) {
        return false;
      }
    }
    return true;
  }

  bool get _hasValidSelection {
    if (_startSignalIndex == null ||
        _endSignalIndex == null ||
        _startTimeIndex == null ||
        _endTimeIndex == null) {
      return false;
    }
    if (signals.isEmpty || signals[0].isEmpty) {
      return false;
    }

    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    final maxTime = signals[0].length - 1;

    return stSig >= 0 &&
        edSig < _visibleIndexes.length &&
        stTime >= 0 &&
        edTime <= maxTime;
  }

  int _getTimeIndexFromDx(double dx) {
    // 画面座樁EↁEチャート�E部座標（左余白と横スクロールを補正�E�E
    final double chartX =
        dx -
        chartMarginLeft +
        (_hScrollController.hasClients ? _hScrollController.offset : 0);
    // ラベル領域より左は無効
    if (chartX < labelWidth) return -1;
    if (_cellWidth <= 0) return -1;

    final double relX = chartX - labelWidth; // チャート本体�E原点からの X

    // 非等間隔モード！Es�E�では累積墁E��に基づぁE��近いインチE��クスを返す
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    final int maxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);
    if (settings.timeUnitIsMs && maxLen > 0) {
      final List<double> pos = List<double>.filled(maxLen + 1, 0.0);
      for (int i = 0; i < maxLen; i++) {
        final durSteps =
            (i < settings.stepDurationsMs.length && settings.msPerStep > 0)
                ? settings.stepDurationsMs[i] / settings.msPerStep
                : 1.0;
        pos[i + 1] = pos[i] + durSteps;
      }
      // relX が属する区閁E[pos[i], pos[i+1]) を探索し、その i を返す
      final double targetPx = relX;
      for (int i = 0; i < maxLen; i++) {
        final double leftPx = pos[i] * _cellWidth;
        final double rightPx = pos[i + 1] * _cellWidth;
        if (targetPx >= leftPx && targetPx < rightPx) {
          return i;
        }
      }
      // 右端は最後�EインチE��クス
      return maxLen - 1;
    }

    // 等間隔�E従来通り
    return (relX / _cellWidth).floor();
  }

  int _getSignalIndexFromDy(double dy) {
    final adjustedY =
        dy -
        chartMarginTop +
        (_vScrollController.hasClients ? _vScrollController.offset : 0);
    if (_cellHeight <= 0) return -1;
    final index = (adjustedY / _cellHeight).floor();
    // 有効篁E��は 0..length-1。篁E��外�E -1 を返す想宁E
    if (index < 0 || index >= _visibleIndexes.length) {
      return -1;
    }
    return index;
  }

  void _clearSelection() {
    if (_startSignalIndex == null &&
        _startTimeIndex == null &&
        _endSignalIndex == null &&
        _endTimeIndex == null) {
      return;
    }
    setState(() {
      _startSignalIndex = null;
      _endSignalIndex = null;
      _startTimeIndex = null;
      _endTimeIndex = null;
    });
  }

  void _handleTap(TapUpDetails details) {
    final chartLocalPos = details.localPosition;
    final adjustedPos = Offset(
      chartLocalPos.dx -
          chartMarginLeft +
          (_hScrollController.hasClients ? _hScrollController.offset : 0),
      chartLocalPos.dy -
          chartMarginTop +
          (_vScrollController.hasClients ? _vScrollController.offset : 0),
    );

    String? hitAnnId;
    for (final entry in _annotationHitRects.entries) {
      final annId = entry.key;
      final rect = entry.value;
      if (rect.contains(adjustedPos)) {
        hitAnnId = annId;
        break;
      }
    }

    if (hitAnnId != null) {
      setState(() {
        _selectedAnnotationId = hitAnnId;
      });
      _clearSelection();
      return;
    } else {
      if (_selectedAnnotationId != null) {
        setState(() {
          _selectedAnnotationId = null;
        });
      }
    }

    // ラベル領域をクリチE��してぁE��か判宁E
    final bool inLabelArea =
        chartLocalPos.dx >= chartMarginLeft &&
        chartLocalPos.dx <= chartMarginLeft + labelWidth;

    if (inLabelArea) {
      final row = _getSignalIndexFromDy(chartLocalPos.dy);
      if (row >= 0 && row < _visibleIndexes.length) {
        final originalRow = _visibleIndexes[row];
        final int maxTime =
            signals.isNotEmpty ? signals[originalRow].length - 1 : -1;
        if (maxTime >= 0) {
          setState(() {
            // すでに同じ行�E体が選択されてぁE��場合�E選択解除
            if (_startSignalIndex == row &&
                _endSignalIndex == row &&
                _startTimeIndex == 0 &&
                _endTimeIndex == maxTime) {
              _clearSelection();
            } else {
              _startSignalIndex = row;
              _endSignalIndex = row;
              _startTimeIndex = 0;
              _endTimeIndex = maxTime;
            }
            _selectedAnnotationId = null;
            _forceRepaint();
          });
        }
      }
      return; // ラベルクリチE��でのビット反転は行わなぁE
    }

    final clickSig = _getSignalIndexFromDy(chartLocalPos.dy);
    final clickTim = _getTimeIndexFromDx(chartLocalPos.dx);

    if (clickTim < 0 || clickSig < 0 || clickSig >= _visibleIndexes.length) {
      _clearSelection();
      return;
    }

    if (_hasValidSelection) {
      final stSigAbs = math.min(_startSignalIndex!, _endSignalIndex!);
      final edSigAbs = math.max(_startSignalIndex!, _endSignalIndex!);
      final stTimeAbs = math.min(_startTimeIndex!, _endTimeIndex!);
      final edTimeAbs = math.max(_startTimeIndex!, _endTimeIndex!);
      // 非等間隁Ems)に対応した選択矩形を計箁E
      final settings = Provider.of<SettingsNotifier>(context, listen: false);
      double xStartPx;
      double xEndPx;
      if (settings.timeUnitIsMs) {
        // 累積スチE��プ位置→px
        double pos = 0.0;
        for (int t = 0; t < stTimeAbs; t++) {
          final durSteps =
              (t < settings.stepDurationsMs.length && settings.msPerStep > 0)
                  ? settings.stepDurationsMs[t] / settings.msPerStep
                  : 1.0;
          pos += durSteps;
        }
        xStartPx = chartMarginLeft + labelWidth + pos * _cellWidth;
        for (int t = stTimeAbs; t <= edTimeAbs; t++) {
          final durSteps =
              (t < settings.stepDurationsMs.length && settings.msPerStep > 0)
                  ? settings.stepDurationsMs[t] / settings.msPerStep
                  : 1.0;
          pos += durSteps;
        }
        xEndPx = chartMarginLeft + labelWidth + pos * _cellWidth;
      } else {
        xStartPx = chartMarginLeft + labelWidth + (stTimeAbs * _cellWidth);
        xEndPx = chartMarginLeft + labelWidth + ((edTimeAbs + 1) * _cellWidth);
      }
      final selectionRectGlobal = Rect.fromLTWH(
        xStartPx,
        chartMarginTop + (stSigAbs * _cellHeight).toDouble(),
        (xEndPx - xStartPx).clamp(0.0, double.infinity),
        (edSigAbs - stSigAbs + 1) * _cellHeight,
      );

      if (selectionRectGlobal.contains(chartLocalPos)) {
        _toggleSignalsInSelection();
      } else {
        _clearSelection();
        _toggleSingleSignal(clickSig, clickTim);
      }
    } else {
      _toggleSingleSignal(clickSig, clickTim);
    }
  }

  void _toggleSingleSignal(int visibleRow, int time) {
    if (visibleRow >= 0 && visibleRow < _visibleIndexes.length) {
      final originalRow = _visibleIndexes[visibleRow];
      if (time >= 0 && time < signals[originalRow].length) {
        setState(() {
          signals[originalRow][time] =
              (signals[originalRow][time] == 0) ? 1 : 0;
          debugPrint(
            '信号を反転: 衁E${originalRow}, 刁E${time}, 新しい値=${signals[originalRow][time]}',
          );
          _highlightTimeIndices = [..._highlightTimeIndices];
          _forceRepaint();
        });
        _commitSignalsFromChartEdit();
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    final chartLocalPos = Offset(localPos.dx, localPos.dy - _fixedHeaderHeight);

    // 先にコメント�EチE��スのヒットを判定（チャート領域外でもドラチE��可能にする�E�E
    final adjustedPosForAnn = Offset(
      chartLocalPos.dx -
          chartMarginLeft +
          (_hScrollController.hasClients ? _hScrollController.offset : 0),
      chartLocalPos.dy -
          chartMarginTop +
          (_vScrollController.hasClients ? _vScrollController.offset : 0),
    );
    for (final entry in _annotationHitRects.entries) {
      final rect = entry.value;
      if (rect.contains(adjustedPosForAnn)) {
        setState(() {
          _draggingAnnotationId = entry.key;
          _draggingStartLocal = adjustedPosForAnn;
          _draggingInitialBoxTopLeft = rect.topLeft;
          _selectedAnnotationId = entry.key;
        });
        _dragStartGlobal = null;
        return;
      }
    }

    // --- ラベル領域でのドラチE��開始判宁E---
    final bool inLabelArea =
        chartLocalPos.dx >= chartMarginLeft &&
        chartLocalPos.dx <= chartMarginLeft + labelWidth;

    final sigIndex = _getSignalIndexFromDy(chartLocalPos.dy);
    if (inLabelArea && sigIndex >= 0 && sigIndex < _visibleIndexes.length) {
      // ラベルドラチE��開姁E
      setState(() {
        _isLabelDrag = true;
        _labelDragStartRow = sigIndex;
        _labelDragCurrentRow = sigIndex;
      });
      return; // selection 処琁E��は入らなぁE
    }

    if (chartLocalPos.dy >
        chartMarginTop + _visibleIndexes.length * _cellHeight) {
      _dragStartGlobal = null;
      return;
    }

    final sig = _getSignalIndexFromDy(chartLocalPos.dy);
    final tim = _getTimeIndexFromDx(chartLocalPos.dx);

    if (tim < 0 || sig < 0 || sig >= _visibleIndexes.length) {
      _clearSelection();
      _dragStartGlobal = null;
      return;
    }

    setState(() {
      _dragStartGlobal = details.globalPosition;
      _startSignalIndex = sig;
      _endSignalIndex = sig;
      _startTimeIndex = tim;
      _endTimeIndex = tim;
      _selectedAnnotationId = null;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // コメント�EチE��スのドラチE��更新
    if (_draggingAnnotationId != null &&
        _draggingStartLocal != null &&
        _draggingInitialBoxTopLeft != null) {
      final chartLocalPos = details.localPosition;
      final adjustedPos = Offset(
        chartLocalPos.dx -
            chartMarginLeft +
            (_hScrollController.hasClients ? _hScrollController.offset : 0),
        chartLocalPos.dy -
            chartMarginTop +
            (_vScrollController.hasClients ? _vScrollController.offset : 0),
      );
      final delta = adjustedPos - _draggingStartLocal!;
      // 上方向にはみ出さなぁE��ぁE��YをクランチE
      Offset deltaClamped = delta;
      final proposedTopLeft = _draggingInitialBoxTopLeft! + delta;
      if (proposedTopLeft.dy < 0) {
        deltaClamped = Offset(delta.dx, -_draggingInitialBoxTopLeft!.dy);
      }

      final annIndex = annotations.indexWhere(
        (a) => a.id == _draggingAnnotationId,
      );
      if (annIndex != -1) {
        final current = annotations[annIndex];
        // offsetX/offsetY はコメント�E基準位置からの差刁E��して扱ぁE
        final newOffsetX = (current.offsetX ?? 0) + deltaClamped.dx;
        final newOffsetY = (current.offsetY ?? 0) + deltaClamped.dy;
        setState(() {
          annotations[annIndex] = current.copyWith(
            offsetX: newOffsetX,
            offsetY: newOffsetY,
          );
          _highlightTimeIndices = [..._highlightTimeIndices];
          _forceRepaint();
        });
        // 次回�E差刁E��リセチE��するため、基準を更新�E�クランプ後�E実移動量で更新�E�E
        _draggingStartLocal = _draggingStartLocal! + deltaClamped;
        _draggingInitialBoxTopLeft = _draggingInitialBoxTopLeft! + deltaClamped;
      }
      return;
    }
    // ラベルドラチE��中は位置を追跡
    if (_isLabelDrag) {
      final chartLocalPos = details.localPosition;
      int sig = _getSignalIndexFromDy(chartLocalPos.dy);
      sig = sig.clamp(0, _visibleIndexes.length - 1);
      if (sig != _labelDragCurrentRow) {
        setState(() {
          _labelDragCurrentRow = sig;
        });
      }
      return; // 既存�E選択ドラチE��は無要E
    }

    if (_dragStartGlobal == null) return;

    final chartLocalPos = details.localPosition;

    final sig = _getSignalIndexFromDy(chartLocalPos.dy);
    final tim = _getTimeIndexFromDx(chartLocalPos.dx);

    final clampedSig = sig.clamp(0, _visibleIndexes.length - 1);
    final maxTimeIndex =
        signals.isEmpty
            ? -1
            : signals.map((e) => e.length).fold(0, math.max) - 1;
    final clampedTim = tim < 0 ? 0 : tim.clamp(0, maxTimeIndex);

    if (_endSignalIndex == clampedSig && _endTimeIndex == clampedTim) return;

    setState(() {
      _endSignalIndex = clampedSig;
      _endTimeIndex = clampedTim;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // コメントドラチE��終亁E
    if (_draggingAnnotationId != null) {
      setState(() {
        _draggingAnnotationId = null;
        _draggingStartLocal = null;
        _draggingInitialBoxTopLeft = null;
      });
      _forceRepaint();
      return;
    }
    if (_isLabelDrag) {
      if (_labelDragStartRow != null &&
          _labelDragCurrentRow != null &&
          _labelDragStartRow != _labelDragCurrentRow) {
        _reorderSignalRows(_labelDragStartRow!, _labelDragCurrentRow!);
      }
      setState(() {
        _isLabelDrag = false;
        _labelDragStartRow = null;
        _labelDragCurrentRow = null;
        // ドラチE��後�E選択状態�EハイライトもリセチE��
        _startSignalIndex = null;
        _endSignalIndex = null;
        _startTimeIndex = null;
        _endTimeIndex = null;
      });
      _forceRepaint();
      return;
    }

    if (_dragStartGlobal == null) return;

    if (_startSignalIndex == _endSignalIndex &&
        _startTimeIndex == _endTimeIndex) {
      _clearSelection();
    }

    setState(() {
      _dragStartGlobal = null;
    });
  }

  // ===== メモリ編雁E��非等間隔）用ハンドラ =====
  void _onPanStartEditSteps(DragStartDetails details) {
    if (!_isEditingSteps) return;
    final chartLocalPos = details.localPosition;
    final double dx = chartLocalPos.dx;
    // チャート�E部X�E�Eanvas.translate(chartMarginLeft, ...) を打ち消す�E�E
    final double chartX =
        dx -
        chartMarginLeft +
        (_hScrollController.hasClients ? _hScrollController.offset : 0);
    _dragStartX = chartX;

    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    final maxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);
    // 吁E��E��のXを累積しながら最も近い墁E��を探ぁE
    double cursorSteps = 0;
    int nearest = 0;
    double nearestDist = double.infinity;
    for (int i = 0; i <= maxLen; i++) {
      // ラベル幁E��除ぁE��チャート本体原点からの墁E��px
      final double boundaryPx = cursorSteps * _cellWidth;
      final double relX = (chartX - labelWidth).clamp(0, double.infinity);
      final double d = (boundaryPx - relX).abs();
      if (d < nearestDist) {
        nearestDist = d;
        nearest = i;
      }
      if (i < maxLen) {
        final dur =
            (i < settings.stepDurationsMs.length)
                ? (settings.timeUnitIsMs
                    ? settings.stepDurationsMs[i] / settings.msPerStep
                    : 1.0)
                : 1.0;
        cursorSteps += dur;
      }
    }
    setState(() => _activeStepIndex = nearest);
    // ドラチE��開始時点の墁E��の絶対X(px)を保存（ラベルを除ぁE��相対尺度�E�E
    _dragStartX = (chartX - labelWidth).clamp(0, double.infinity);
  }

  void _onPanUpdateEditSteps(DragUpdateDetails details) {
    if (!_isEditingSteps || _activeStepIndex == null) return;
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    // 0番墁E���E�左端�E�や末端はドラチE��対象にしなぁE��めEidx は前スチE��チE
    final idx = _activeStepIndex! - 1;
    final maxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);
    if (idx < 0 || idx >= maxLen) return;

    final chartLocalPos = details.localPosition;
    final double dx = chartLocalPos.dx;
    final double chartX =
        dx -
        chartMarginLeft +
        (_hScrollController.hasClients ? _hScrollController.offset : 0);
    final double relX = (chartX - labelWidth).clamp(0, double.infinity);
    _dragStartX = relX;

    // 目樁E 選択墁E�� i の画面位置 boundaryPx をカーソル relX に一致させめE
    // 墁E�� i のスチE��プ位置 pos[i] = pos[i-1] + dur[idx]/msPerStep
    // よって dur[idx] = (targetSteps - pos[i-1]) * msPerStep
    final List<double> list = List<double>.from(settings.stepDurationsMs);
    if (list.length < maxLen) {
      list.addAll(List.filled(maxLen - list.length, settings.msPerStep));
    }
    // 累積スチE��プ位置�E�Eteps単位！E
    final List<double> pos = List<double>.filled(maxLen + 1, 0.0);
    for (int t = 0; t < maxLen; t++) {
      final durSteps =
          (t < list.length && settings.msPerStep > 0)
              ? list[t] / settings.msPerStep
              : 1.0;
      pos[t + 1] = pos[t] + durSteps;
    }
    final int boundaryIndex = _activeStepIndex!; // i
    final double targetSteps = relX / _cellWidth;
    final double prevSteps = pos[boundaryIndex - 1];
    double newDurSteps = targetSteps - prevSteps;
    if (newDurSteps < 0.005) newDurSteps = 0.005; // 最小幁E 紁E.5%スチE��チE
    double newMs = newDurSteps * settings.msPerStep;
    if (newMs < 0.1) newMs = 0.1; // 絶対最封E0.1ms
    list[idx] = newMs;
    settings.setStepDurationsMs(list);
  }

  void _onPanEndEditSteps(DragEndDetails details) {
    // スナップや確定�E琁E��忁E��ならここに実裁E
  }

  // 外部から呼び出してグリチE��調整を�E期化�E�Elean 対応！E
  void resetGridAdjustments() {
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    // 個別調整をクリア�E�次回�E等間隔に復帰�E�E
    settings.setStepDurationsMs([]);
    setState(() {
      _isEditingSteps = false;
      _activeStepIndex = null;
    });
  }

  // クリチE���E�タチE�E�E�で墁E��を選択し、その後�EドラチE��で反映させめE
  void _onTapUpEditSteps(TapUpDetails details) {
    if (!_isEditingSteps) return;
    final chartLocalPos = details.localPosition;
    final double dx = chartLocalPos.dx;
    final double chartX =
        dx -
        chartMarginLeft +
        (_hScrollController.hasClients ? _hScrollController.offset : 0);

    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    final maxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);
    final double relX = (chartX - labelWidth).clamp(0, double.infinity);

    // 累積墁E���E�Eteps単位）を配�Eで用愁E
    final List<double> pos = List<double>.filled(maxLen + 1, 0.0);
    for (int i = 0; i < maxLen; i++) {
      final durSteps =
          (i < settings.stepDurationsMs.length && settings.msPerStep > 0)
              ? settings.stepDurationsMs[i] / settings.msPerStep
              : 1.0;
      pos[i + 1] = pos[i] + durSteps;
    }

    // 近傍墁E��の探索�E�Ex距離�E�E
    int nearest = 0;
    double best = double.infinity;
    for (int i = 0; i <= maxLen; i++) {
      final double boundaryPx = pos[i] * _cellWidth;
      final double d = (boundaryPx - relX).abs();
      if (d < best) {
        best = d;
        nearest = i;
      }
    }

    // 墁E��クリチE��のしきぁE��
    const double snapPx = 6.0;
    if (best <= snapPx) {
      setState(() {
        _activeStepIndex = nearest;
        _dragStartX = relX;
      });
      return;
    }

    // 区閁E[idx, idx+1) を決宁E
    int idx = 0;
    for (int i = 0; i < maxLen; i++) {
      final double leftPx = pos[i] * _cellWidth;
      final double rightPx = pos[i + 1] * _cellWidth;
      if (relX >= leftPx && relX < rightPx) {
        idx = i;
        break;
      }
      idx = math.max(0, maxLen - 1);
    }

    // 入力ダイアログを表示して [idx] の ms を設宁E
    final currentMs =
        (idx < settings.stepDurationsMs.length)
            ? settings.stepDurationsMs[idx]
            : settings.msPerStep;
    final controller = TextEditingController(
      text: currentMs.toStringAsFixed(3),
    );
    showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Set step duration (ms)'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: 'e.g. 1.0'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Apply'),
              ),
            ],
          ),
    ).then((ok) {
      if (ok != true) return;
      final v = double.tryParse(controller.text.trim());
      if (v == null || !(v.isFinite) || v <= 0) return;
      final List<double> list = List<double>.from(settings.stepDurationsMs);
      if (list.length < maxLen) {
        list.addAll(List.filled(maxLen - list.length, settings.msPerStep));
      }
      list[idx] = v;
      settings.setStepDurationsMs(list);
      setState(() => _activeStepIndex = idx);
    });
  }

  // ロングプレスでのドラチE���E�タチE��チE��イス向け�E�E
  void _onLongPressStart(LongPressStartDetails details) {
    final chartLocalPos = details.localPosition;
    final adjustedPos = Offset(
      chartLocalPos.dx -
          chartMarginLeft +
          (_hScrollController.hasClients ? _hScrollController.offset : 0),
      chartLocalPos.dy -
          chartMarginTop +
          (_vScrollController.hasClients ? _vScrollController.offset : 0),
    );
    for (final entry in _annotationHitRects.entries) {
      final rect = entry.value;
      if (rect.contains(adjustedPos)) {
        setState(() {
          _draggingAnnotationId = entry.key;
          _draggingStartLocal = adjustedPos;
          _draggingInitialBoxTopLeft = rect.topLeft;
          _selectedAnnotationId = entry.key;
        });
        return;
      }
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_draggingAnnotationId == null || _draggingStartLocal == null) return;
    final chartLocalPos = details.localPosition;
    final adjustedPos = Offset(
      chartLocalPos.dx -
          chartMarginLeft +
          (_hScrollController.hasClients ? _hScrollController.offset : 0),
      chartLocalPos.dy -
          chartMarginTop +
          (_vScrollController.hasClients ? _vScrollController.offset : 0),
    );
    final delta = adjustedPos - _draggingStartLocal!;
    // 上方向にはみ出さなぁE��ぁE��YをクランチE
    Offset deltaClamped = delta;
    final proposedTopLeft = _draggingInitialBoxTopLeft ?? Offset.zero + delta;
    if (_draggingInitialBoxTopLeft != null && proposedTopLeft.dy < 0) {
      deltaClamped = Offset(delta.dx, -_draggingInitialBoxTopLeft!.dy);
    }
    final annIndex = annotations.indexWhere(
      (a) => a.id == _draggingAnnotationId,
    );
    if (annIndex != -1) {
      final current = annotations[annIndex];
      final newOffsetX = (current.offsetX ?? 0) + deltaClamped.dx;
      final newOffsetY = (current.offsetY ?? 0) + deltaClamped.dy;
      setState(() {
        annotations[annIndex] = current.copyWith(
          offsetX: newOffsetX,
          offsetY: newOffsetY,
        );
        _highlightTimeIndices = [..._highlightTimeIndices];
        _forceRepaint();
      });
      _controller?.setAnnotations(annotations);
      _draggingStartLocal = _draggingStartLocal! + deltaClamped;
      _draggingInitialBoxTopLeft =
          (_draggingInitialBoxTopLeft ?? Offset.zero) + deltaClamped;
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_draggingAnnotationId != null) {
      setState(() {
        _draggingAnnotationId = null;
        _draggingStartLocal = null;
        _draggingInitialBoxTopLeft = null;
      });
      _forceRepaint();
    }
  }

  void _showContextMenu(BuildContext context, Offset position) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    _lastRightClickPos = position; // グローバル保持

    // グローバル座樁EↁEチャーチECustomPaint)のローカル座標へ
    final RenderBox? paintBox =
        _customPaintKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset chartLocalPos =
        paintBox != null ? paintBox.globalToLocal(position) : position;
    final adjustedPos = Offset(
      chartLocalPos.dx -
          chartMarginLeft +
          (_hScrollController.hasClients ? _hScrollController.offset : 0),
      chartLocalPos.dy -
          chartMarginTop +
          (_vScrollController.hasClients ? _vScrollController.offset : 0),
    );

    // クリチE��されたタイムインチE��クスを�Eに計算しておく
    final int clickedTime = _getTimeIndexFromDx(chartLocalPos.dx);

    // 行インチE��クス�E�可視行）とラベル領域判定を事前に計箁E
    final int clickedSig = _getSignalIndexFromDy(chartLocalPos.dy);

    String? hitAnnId;
    for (final entry in _annotationHitRects.entries) {
      if (entry.value.contains(adjustedPos)) {
        hitAnnId = entry.key;
        break;
      }
    }

    List<PopupMenuEntry<String>> menuItems = [];
    final s = S.of(context);

    if (hitAnnId != null) {
      final ann = annotations.firstWhereOrNull((a) => a.id == hitAnnId);
      final bool horizontalOn = ann?.arrowHorizontal != false; // null含めON
      menuItems = [
        PopupMenuItem(value: 'editComment', child: Text(s.ctx_edit_comment)),
        PopupMenuItem(
          value: 'deleteComment',
          child: Text(s.ctx_delete_comment),
        ),
        PopupMenuItem(
          value: 'toggleArrowHorizontal',
          child: Text(
            horizontalOn
                ? s.ctx_arrow_horizontal_on_to_off
                : s.ctx_arrow_horizontal_off_to_on,
          ),
        ),
        if (!(horizontalOn))
          PopupMenuItem(
            value: 'setArrowTipToRow',
            child: Text(s.ctx_set_arrow_tip_to_row),
          ),
      ];
    } else {
      setState(() {
        _highlightTimeIndices.clear();
        // ms 非等間隔に対応したクリチE��位置の墁E��/区間判宁E
        final settings = Provider.of<SettingsNotifier>(context, listen: false);
        int clickedTime;
        if (settings.timeUnitIsMs) {
          final int maxLen =
              signals.isEmpty
                  ? 0
                  : signals.map((e) => e.length).fold(0, math.max);
          final double chartX =
              chartLocalPos.dx -
              chartMarginLeft +
              (_hScrollController.hasClients ? _hScrollController.offset : 0);
          final double relX = (chartX - labelWidth).clamp(0, double.infinity);
          // 累積墁E��
          final List<double> pos = List<double>.filled(maxLen + 1, 0.0);
          for (int i = 0; i < maxLen; i++) {
            final durSteps =
                (i < settings.stepDurationsMs.length && settings.msPerStep > 0)
                    ? settings.stepDurationsMs[i] / settings.msPerStep
                    : 1.0;
            pos[i + 1] = pos[i] + durSteps;
          }
          // 近傍墁E��
          int nearest = 0;
          double best = double.infinity;
          for (int i = 0; i <= maxLen; i++) {
            final double boundaryPx = pos[i] * _cellWidth;
            final double d = (boundaryPx - relX).abs();
            if (d < best) {
              best = d;
              nearest = i;
            }
          }
          // 墁E��しきぁE��(px)
          const double snapPx = 6.0;
          if (best <= snapPx) {
            clickedTime = nearest.clamp(0, math.max(0, maxLen - 1));
          } else {
            // 区間にマッチE
            int idx = 0;
            for (int i = 0; i < maxLen; i++) {
              final double leftPx = pos[i] * _cellWidth;
              final double rightPx = pos[i + 1] * _cellWidth;
              if (relX >= leftPx && relX < rightPx) {
                idx = i;
                break;
              }
              idx = maxLen - 1;
            }
            clickedTime = idx;
          }
        } else {
          clickedTime = _getTimeIndexFromDx(chartLocalPos.dx);
        }

        if (_hasValidSelection) {
          final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
          final edTime = math.max(_startTimeIndex!, _endTimeIndex!);
          _highlightTimeIndices.add(stTime);
          _highlightTimeIndices.add(edTime + 1);
        } else {
          if (clickedTime >= 0) {
            _highlightTimeIndices.add(clickedTime);
          }
        }
      });

      menuItems = [
        PopupMenuItem(value: 'insert', child: Text(s.ctx_insert_zeros)),
        // 追加: 選択篁E��を末尾に褁E��
        PopupMenuItem(value: 'duplicate', child: Text(s.ctx_duplicate_to_tail)),
        PopupMenuItem(
          value: 'selectAll',
          child: Text(s.ctx_select_all_signals),
        ),
        PopupMenuItem(value: 'delete', child: Text(s.ctx_delete_selection)),
        PopupMenuItem(value: 'addComment', child: Text(s.ctx_add_comment)),
        PopupMenuItem(value: 'omit', child: Text(s.ctx_draw_omission)),
      ];
    }

    // マウス位置付近にメニューを�E置するため、オーバ�Eレイ全体を基準とした Rect を使用する
    final selectedValue = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: menuItems,
    );

    setState(() {
      _highlightTimeIndices.clear();
    });

    if (selectedValue != null) {
      switch (selectedValue) {
        case 'editComment':
          if (hitAnnId != null) _editComment(hitAnnId);
          break;
        case 'deleteComment':
          if (hitAnnId != null) _deleteComment(hitAnnId);
          break;
        case 'toggleArrowHorizontal':
          if (hitAnnId != null) {
            final idx = annotations.indexWhere((a) => a.id == hitAnnId);
            if (idx != -1) {
              final current = annotations[idx];
              final bool horizontalOn = current.arrowHorizontal != false;
              setState(() {
                annotations[idx] = current.copyWith(
                  arrowHorizontal: !horizontalOn,
                );
                _forceRepaint();
              });
            }
          }
          break;
        case 'setArrowTipToRow':
          if (hitAnnId != null &&
              clickedSig >= 0 &&
              clickedSig < _visibleIndexes.length) {
            _setAnnotationArrowToSignal(hitAnnId, clickedSig);
          }
          break;
        case 'insert':
          debugPrint("selectedValue = $selectedValue");
          _insertZerosToSelection();
          break;
        case 'duplicate':
          debugPrint("selectedValue = $selectedValue");
          _duplicateRange();
          break;
        case 'selectAll':
          debugPrint("selectedValue = $selectedValue");
          _selectAllSignals();
          break;
        case 'delete':
          debugPrint("selectedValue = $selectedValue");
          _deleteRange();
          break;
        case 'addComment':
          debugPrint("selectedValue = $selectedValue");
          if (_hasValidSelection) {
            _showAddRangeCommentDialog();
          } else {
            _showAddCommentDialog();
          }
          break;
        case 'omit':
          debugPrint("selectedValue = $selectedValue");
          _toggleOmissionTime(clickedTime);
          break;
      }
    }
  }

  Future<void> _showAddCommentDialog() async {
    if (_lastRightClickPos == null) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(_lastRightClickPos!);

    final tIndex = _getTimeIndexFromDx(localPos.dx);
    if (tIndex < 0) {
      return;
    }

    String newComment = "";

    // ダイアログ入力時にチャート�Eキーボ�Eドフォーカスを外す
    final bool prevCanRequest = _focusNode.canRequestFocus;
    _focusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final s = S.of(context);
        return AlertDialog(
          title: Text(s.comment_add_title),
          content: TextField(
            autofocus: true,
            onChanged: (val) => newComment = val,
            decoration: InputDecoration(hintText: s.comment_input_hint),
            maxLines: null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.common_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.common_ok),
            ),
          ],
        );
      },
    );

    // フォーカス設定を允E��戻ぁE
    _focusNode.canRequestFocus = prevCanRequest;
    if (mounted) _focusNode.requestFocus();

    if (result == true && newComment.isNotEmpty) {
      final annId = "ann${DateTime.now().millisecondsSinceEpoch}";
      final newAnnotation = TimingChartAnnotation(
        id: annId,
        startTimeIndex: tIndex,
        endTimeIndex: null,
        text: newComment,
      );

      setState(() {
        debugPrint('コメント追加: ID=${annId}, text=${newComment}, index=${tIndex}');
        annotations.add(newAnnotation);
        // 強制皁E��再描画をトリガーするためのダミ�E更新
        _highlightTimeIndices = [..._highlightTimeIndices];
        _forceRepaint();
      });
      _controller?.setAnnotations(annotations);
    }
  }

  Future<void> _showAddRangeCommentDialog() async {
    if (!_hasValidSelection) return;

    final int stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final int edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    String newComment = "";

    // ダイアログ入力時にチャート�Eキーボ�Eドフォーカスを外す
    final bool prevCanRequest = _focusNode.canRequestFocus;
    _focusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final s = S.of(context);
        return AlertDialog(
          title: Text(s.comment_add_range_title),
          content: TextField(
            autofocus: true,
            onChanged: (val) => newComment = val,
            decoration: InputDecoration(hintText: s.comment_input_hint),
            maxLines: null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.common_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.common_ok),
            ),
          ],
        );
      },
    );

    // フォーカス設定を允E��戻ぁE
    _focusNode.canRequestFocus = prevCanRequest;
    if (mounted) _focusNode.requestFocus();

    if (result == true && newComment.isNotEmpty) {
      final annId = "ann${DateTime.now().millisecondsSinceEpoch}";
      final newAnnotation = TimingChartAnnotation(
        id: annId,
        startTimeIndex: stTime,
        endTimeIndex: edTime,
        text: newComment,
      );

      setState(() {
        debugPrint(
          '篁E��コメント追加: ID=${annId}, text=${newComment}, start=${stTime}, end=${edTime}',
        );
        annotations.add(newAnnotation);
        _forceRepaint();
        _clearSelection();
      });
      _controller?.setAnnotations(annotations);
    }
  }

  void _editComment(String annId) async {
    final ann = annotations.firstWhereOrNull((a) => a.id == annId);
    if (ann == null) return;

    String newText = ann.text;

    // ダイアログ入力時にチャート�Eキーボ�Eドフォーカスを外す
    final bool prevCanRequest = _focusNode.canRequestFocus;
    _focusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: ann.text);
        final s = S.of(context);
        return AlertDialog(
          title: Text(s.comment_edit_title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.common_cancel),
            ),
            TextButton(
              onPressed: () {
                newText = controller.text;
                Navigator.pop(ctx, true);
              },
              child: Text(s.common_ok),
            ),
          ],
        );
      },
    );

    // フォーカス設定を允E��戻ぁE
    _focusNode.canRequestFocus = prevCanRequest;
    if (mounted) _focusNode.requestFocus();

    if (result == true && newText.isNotEmpty && newText != ann.text) {
      setState(() {
        final index = annotations.indexWhere((a) => a.id == annId);
        if (index != -1) {
          annotations[index] = ann.copyWith(text: newText);
        }
      });
      _controller?.setAnnotations(annotations);
    }
  }

  void _deleteComment(String annId) {
    final index = annotations.indexWhere((a) => a.id == annId);
    if (index == -1) return;

    setState(() {
      annotations.removeAt(index);
      if (_selectedAnnotationId == annId) {
        _selectedAnnotationId = null;
      }
    });
    _controller?.setAnnotations(annotations);
  }

  void _toggleSignalsInSelection() {
    if (!_hasValidSelection) return;
    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    if (stSig < 0 || edSig >= _visibleIndexes.length) return;
    setState(() {
      for (int visibleRow = stSig; visibleRow <= edSig; visibleRow++) {
        final originalRow = _visibleIndexes[visibleRow];
        final maxTimeForRow = signals[originalRow].length - 1;
        final clampedStTime = stTime.clamp(0, maxTimeForRow);
        final clampedEdTime = edTime.clamp(0, maxTimeForRow);
        if (clampedStTime > clampedEdTime) continue;
        for (int t = clampedStTime; t <= clampedEdTime; t++) {
          signals[originalRow][t] = (signals[originalRow][t] == 0) ? 1 : 0;
        }
      }
      _highlightTimeIndices = [..._highlightTimeIndices];
      _forceRepaint();
    });
    _commitSignalsFromChartEdit();
  }

  void _insertZerosToSelection() {
    if (!_hasValidSelection) return;
    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    if (stSig < 0 || edSig >= _visibleIndexes.length) return;
    final lengthToInsert = (edTime - stTime + 1);
    if (lengthToInsert <= 0) return;
    setState(() {
      for (int visibleRow = stSig; visibleRow <= edSig; visibleRow++) {
        final originalRow = _visibleIndexes[visibleRow];
        final clampedStTime = stTime.clamp(0, signals[originalRow].length);
        signals[originalRow].insertAll(
          clampedStTime,
          List.filled(lengthToInsert, 0),
        );
      }
      _normalizeSignalLengths();
      _clearSelection();
    });
    _commitSignalsFromChartEdit();
  }

  void _deleteRange() {
    if (!_hasValidSelection) return;
    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    if (stSig < 0 || edSig >= _visibleIndexes.length) return;
    setState(() {
      for (int visibleRow = stSig; visibleRow <= edSig; visibleRow++) {
        final originalRow = _visibleIndexes[visibleRow];
        final maxTimeForRow = signals[originalRow].length;
        final clampedStTime = stTime.clamp(0, maxTimeForRow);
        final clampedEdTime = (edTime + 1).clamp(0, maxTimeForRow);
        if (clampedStTime >= clampedEdTime) continue;
        signals[originalRow].removeRange(clampedStTime, clampedEdTime);
      }
      _normalizeSignalLengths();
      _clearSelection();
    });
    _commitSignalsFromChartEdit();
  }

  void _duplicateRange() {
    if (!_hasValidSelection) return;

    // 選択篁E��の信号インチE��クスと時刻インチE��クスを正規化
    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    // 選択された信号が可視篁E��外�E場合�E処琁E��なぁE
    if (stSig < 0 || edSig >= _visibleIndexes.length) return;

    // 追加: 末尾開始オフセチE��を計算しておく�E�コメンチE省略記号褁E��用�E�E
    final int oldMaxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).reduce(math.max);

    setState(() {
      for (int visibleRow = stSig; visibleRow <= edSig; visibleRow++) {
        final originalRow = _visibleIndexes[visibleRow];
        final maxTimeForRow = signals[originalRow].length - 1;
        final clampedStTime = stTime.clamp(0, maxTimeForRow);
        final clampedEdTime = edTime.clamp(0, maxTimeForRow);
        if (clampedStTime > clampedEdTime) continue;

        // 選択篁E��のスライスを取得して末尾に追加
        final slice = signals[originalRow].sublist(
          clampedStTime,
          clampedEdTime + 1,
        );
        signals[originalRow].addAll(slice);
      }

      // ---------- アノテーションを褁E�� ----------
      final List<TimingChartAnnotation> duplicatedAnnotations = [];
      for (final ann in annotations) {
        final annStart = ann.startTimeIndex;
        final int annEnd = ann.endTimeIndex ?? annStart;

        // 選択篁E��とアノテーションが交差してぁE��か判宁E
        if (annEnd >= stTime && annStart <= edTime) {
          final int offset = oldMaxLen - stTime;
          final newAnn = ann.copyWith(
            id:
                'ann${DateTime.now().millisecondsSinceEpoch}_${duplicatedAnnotations.length}',
            startTimeIndex: annStart + offset,
            endTimeIndex:
                ann.endTimeIndex != null ? ann.endTimeIndex! + offset : null,
          );
          duplicatedAnnotations.add(newAnn);
        }
      }
      annotations.addAll(duplicatedAnnotations);

      // ---------- 省略記号時刻インチE��クスを褁E�� ----------
      final List<int> newOmissions = [];
      for (final t in _omissionTimeIndices) {
        if (t >= stTime && t <= edTime) {
          newOmissions.add(t + (oldMaxLen - stTime));
        }
      }
      _omissionTimeIndices.addAll(newOmissions);

      // 全信号長を揃える
      _normalizeSignalLengths();
      // 選択状態をクリア
      _clearSelection();

      // 再描画
      _forceRepaint();
    });
    _commitSignalsFromChartEdit();
    _controller?.setAnnotations(annotations);
  }

  void _normalizeSignalLengths() {
    if (signals.isEmpty) return;

    int maxLen = 0;
    for (final signal in signals) {
      if (signal.length > maxLen) {
        maxLen = signal.length;
      }
    }

    for (final signal in signals) {
      final diff = maxLen - signal.length;
      if (diff > 0) {
        signal.addAll(List.filled(diff, 0));
      }
    }
  }

  /// 持E��した時刻インチE��クスの省略信号をトグル�E�追加/削除�E�E
  void _toggleOmissionTime(int timeIndex) {
    if (timeIndex < 0) return;
    setState(() {
      if (_omissionTimeIndices.contains(timeIndex)) {
        _omissionTimeIndices.remove(timeIndex);
      } else {
        _omissionTimeIndices.add(timeIndex);
      }
      _forceRepaint();
    });
  }

  void _zoomIn() {
    final double current = math.max(_zoomFactor, _minZoomFactorForView);
    final double next = math.min(current + _zoomStep, _maxZoomFactorForView);
    if ((next - _zoomFactor).abs() < 1e-6) return;
    setState(() {
      _zoomFactor = next;
    });
  }

  void _zoomOut() {
    final double current = math.max(_zoomFactor, _minZoomFactorForView);
    final double next = math.max(current - _zoomStep, _minZoomFactorForView);
    if ((next - _zoomFactor).abs() < 1e-6) return;
    setState(() {
      _zoomFactor = next;
    });
  }

  void _resetZoom() {
    final double target = math.max(_minZoomFactorForView, _minZoom);
    if ((_zoomFactor - target).abs() < 1e-6) return;
    setState(() {
      _zoomFactor = target;
    });
  }

  // ===== アンカー付きズーム用ヘルパ�E =====
  double _getViewportWaveWidth() {
    // build 中に context.size を参照すると例外になるため、MediaQuery を使用
    final double widgetWidth = MediaQuery.of(context).size.width;
    final double viewportWaveWidth = widgetWidth - chartMarginLeft - labelWidth;
    return viewportWaveWidth.isFinite ? math.max(0.0, viewportWaveWidth) : 0.0;
  }

  double _computeTotalStepUnits() {
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    final int maxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);
    if (maxLen <= 0) return 0.0;
    if (settings.timeUnitIsMs) {
      double sum = 0.0;
      for (int i = 0; i < maxLen; i++) {
        final dur =
            (i < settings.stepDurationsMs.length)
                ? settings.stepDurationsMs[i]
                : settings.msPerStep;
        sum += (settings.msPerStep > 0) ? (dur / settings.msPerStep) : 1.0;
      }
      return sum;
    } else {
      return maxLen.toDouble();
    }
  }

  void _applyAnchorScrollCorrection({
    required double anchorXInWave,
    required double stepsUnitsBefore,
  }) {
    final double viewportWaveWidth = _getViewportWaveWidth();
    final double contentWidth = _computeTotalStepUnits() * _cellWidth;
    final double newContentX = stepsUnitsBefore * _cellWidth;
    double newScroll = newContentX - anchorXInWave;
    final double maxScroll = math.max(0.0, contentWidth - viewportWaveWidth);
    newScroll = newScroll.clamp(0.0, maxScroll);
    if (_hScrollController.hasClients) {
      try {
        _hScrollController.jumpTo(newScroll);
      } catch (_) {
        // ignore jump errors
      }
    }
  }

  void _zoomInWithAnchorAtCenter() {
    final double viewportWaveWidth = _getViewportWaveWidth();
    final double anchorXInWave = viewportWaveWidth / 2;
    final double scrollBefore =
        _hScrollController.hasClients ? _hScrollController.offset : 0.0;
    final double stepsUnitsBefore =
        (scrollBefore + anchorXInWave) / (_cellWidth <= 0 ? 1.0 : _cellWidth);
    _zoomIn();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyAnchorScrollCorrection(
        anchorXInWave: anchorXInWave,
        stepsUnitsBefore: stepsUnitsBefore,
      );
    });
  }

  void _zoomOutWithAnchorAtCenter() {
    final double viewportWaveWidth = _getViewportWaveWidth();
    final double anchorXInWave = viewportWaveWidth / 2;
    final double scrollBefore =
        _hScrollController.hasClients ? _hScrollController.offset : 0.0;
    final double stepsUnitsBefore =
        (scrollBefore + anchorXInWave) / (_cellWidth <= 0 ? 1.0 : _cellWidth);
    _zoomOut();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyAnchorScrollCorrection(
        anchorXInWave: anchorXInWave,
        stepsUnitsBefore: stepsUnitsBefore,
      );
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final bool modifierPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!modifierPressed) return;

    final double verticalDelta = event.scrollDelta.dy;
    final double horizontalDelta = event.scrollDelta.dx;
    final double dominantDelta =
        verticalDelta.abs() >= horizontalDelta.abs()
            ? verticalDelta
            : horizontalDelta;

    // アンカー位置�E�カーソルX�E�を取得（波形エリア座標！E
    double viewportWaveWidth = _getViewportWaveWidth();
    double anchorXInWave;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      final local = box.globalToLocal(event.position);
      anchorXInWave = local.dx - chartMarginLeft - labelWidth;
      if (!anchorXInWave.isFinite) anchorXInWave = viewportWaveWidth / 2;
    } else {
      anchorXInWave = viewportWaveWidth / 2;
    }
    anchorXInWave = anchorXInWave.clamp(0.0, viewportWaveWidth);

    final double scrollBefore =
        _hScrollController.hasClients ? _hScrollController.offset : 0.0;
    final double stepsUnitsBefore =
        (scrollBefore + anchorXInWave) / (_cellWidth <= 0 ? 1.0 : _cellWidth);

    if (dominantDelta < 0) {
      _zoomIn();
    } else if (dominantDelta > 0) {
      _zoomOut();
    }

    // ズーム反映後にスクロール位置を補正
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyAnchorScrollCorrection(
        anchorXInWave: anchorXInWave,
        stepsUnitsBefore: stepsUnitsBefore,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // レイアウト�E岐用の設定取征E
    final settingsTop = Provider.of<SettingsNotifier>(context);

    return (_isEditingSteps && settingsTop.timeUnitIsMs)
        ? Listener(
          onPointerSignal: _handlePointerSignal,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final settings = Provider.of<SettingsNotifier>(context);
              final maxLen =
                  signals.isEmpty
                      ? 0
                      : signals.map((e) => e.length).fold(0, math.max);
              // 表示対象インチE��クスを抽出
              final visibleIndexes = <int>[];
              final int safeLen = math.min(
                widget.signalTypes.length,
                math.min(signals.length, signalNames.length),
              );
              for (int i = 0; i < safeLen; i++) {
                final t = widget.signalTypes[i];
                if (widget.showAllSignalTypes ||
                    (t != SignalType.control &&
                        t != SignalType.group &&
                        t != SignalType.task)) {
                  visibleIndexes.add(i);
                }
              }

              // --- 横方吁E---
              final availableWidth =
                  constraints.maxWidth.isFinite
                      ? constraints.maxWidth - chartMarginLeft - labelWidth
                      : MediaQuery.of(context).size.width -
                          chartMarginLeft -
                          labelWidth;

              // 合計スチE��プ幁E��Es モードでは吁E��チE��プ�E相対幁E�E総和�E�E
              final bool isMs = settings.timeUnitIsMs;
              final List<double> durationsForLayout =
                  (_controller?.stepDurationsMs.isNotEmpty ?? false)
                      ? _controller!.stepDurationsMs
                      : settings.stepDurationsMs;
              double totalSteps = 0.0;
              if (isMs && maxLen > 0) {
                for (int i = 0; i < maxLen; i++) {
                  final dur =
                      (i < durationsForLayout.length)
                          ? durationsForLayout[i]
                          : settings.msPerStep;
                  totalSteps +=
                      (settings.msPerStep > 0)
                          ? (dur / settings.msPerStep)
                          : 1.0;
                }
              } else {
                totalSteps = maxLen.toDouble();
              }

              double baseCellWidth;
              if (widget.fitToScreen) {
                baseCellWidth =
                    totalSteps > 0
                        ? math.max(availableWidth / totalSteps, 5.0)
                        : 40.0;
              } else {
                baseCellWidth =
                    totalSteps > 0
                        ? math.max(availableWidth / totalSteps, 20.0)
                        : 40.0;
              }

              double minCellWidthForFullView = baseCellWidth;
              if (totalSteps > 0 &&
                  availableWidth.isFinite &&
                  availableWidth > 0) {
                final double perStepWidth = availableWidth / totalSteps;
                if (perStepWidth.isFinite && perStepWidth > 0) {
                  minCellWidthForFullView = math.min(
                    baseCellWidth,
                    math.max(perStepWidth, _minZoomCellWidth),
                  );
                }
              }
              minCellWidthForFullView =
                  (minCellWidthForFullView.clamp(
                    _minZoomCellWidth,
                    baseCellWidth,
                  )).toDouble();

              // 下限が上限を趁E��なぁE��ぁE��上限へキャチE�E
              minCellWidthForFullView = math.min(
                minCellWidthForFullView,
                _maxZoomCellWidth,
              );

              // 上限: チャート上に最佁EスチE��プが表示できるまで拡大を許可
              final double viewportWaveWidth = _getViewportWaveWidth();
              final double maxCellWidthForTwoSteps =
                  (viewportWaveWidth.isFinite && viewportWaveWidth > 0)
                      ? (viewportWaveWidth / 2.0)
                      : _maxZoomCellWidth;
              final double maxCellWidthAllowed = maxCellWidthForTwoSteps;

              final double minZoomFactorForView =
                  baseCellWidth <= 0
                      ? 1.0
                      : (minCellWidthForFullView / baseCellWidth).clamp(
                        _minZoom,
                        double.maxFinite,
                      );
              final double maxZoomFactorForView =
                  baseCellWidth <= 0
                      ? 1.0
                      : (maxCellWidthAllowed / baseCellWidth);
              final double effectiveZoomFactor = _zoomFactor.clamp(
                minZoomFactorForView,
                maxZoomFactorForView,
              );

              _cellWidth =
                  (baseCellWidth * effectiveZoomFactor)
                      .clamp(minCellWidthForFullView, maxCellWidthAllowed)
                      .toDouble();

              _minZoomFactorForView = minZoomFactorForView;
              _maxZoomFactorForView = maxZoomFactorForView;
              _effectiveZoomFactor = effectiveZoomFactor;
              // ▼ コメントエリアの高さを動皁E��算�E
              final double commentAreaHeight = _calculateCommentAreaHeight();

              // --- 縦方吁E---
              double constraintHeight =
                  constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : MediaQuery.of(context).size.height;

              if (widget.fitToScreen) {
                final availableHeight =
                    constraintHeight - chartMarginTop - commentAreaHeight;
                final visibleRowCount = visibleIndexes.length;
                if (visibleRowCount > 0) {
                  _cellHeight = math.max(
                    availableHeight / visibleRowCount,
                    5.0,
                  );
                }
              } else {
                _cellHeight = 40;
              }

              final double totalWidth =
                  chartMarginLeft + labelWidth + totalSteps * _cellWidth;
              final double totalHeight =
                  chartMarginTop +
                  visibleIndexes.length * _cellHeight +
                  commentAreaHeight;

              // フィルタ済みリストを作�E
              final visibleSignalNames = [
                for (final i in visibleIndexes) signalNames[i],
              ];
              final visibleSignals = [
                for (final i in visibleIndexes)
                  if (i < signals.length) signals[i],
              ];
              final visibleSignalTypes = [
                for (final i in visibleIndexes) widget.signalTypes[i],
              ];
              final visiblePortNumbers = [
                for (final i in visibleIndexes)
                  (i < widget.portNumbers.length) ? widget.portNumbers[i] : 0,
              ];
              final visibleIoSources = [
                for (final i in visibleIndexes)
                  (i < widget.ioSources.length)
                      ? widget.ioSources[i]
                      : IoChannelSource.unknown,
              ];

              _visibleIndexes = visibleIndexes;

              // ビルド後に stepDurations 長を同朁E
              final settingsRW = Provider.of<SettingsNotifier>(
                context,
                listen: false,
              );
              if (settings.stepDurationsMs.length != maxLen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) settingsRW.ensureStepDurationsLength(maxLen);
                });
              }

              // 上部にトグル、下部にチャート本体を配置して重なりを回避
              const double _topControlsHeight = 48.0;
              // fitToScreen 時�E高さ計算に上部コントロール刁E��控除
              if (widget.fitToScreen) {
                final availableHeight =
                    (constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : MediaQuery.of(context).size.height) -
                    _topControlsHeight -
                    chartMarginTop -
                    commentAreaHeight;
                final visibleRowCount = visibleIndexes.length;
                if (visibleRowCount > 0) {
                  _cellHeight = math.max(
                    availableHeight / visibleRowCount,
                    5.0,
                  );
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, top: 8),
                      child: _buildUnitToggle(context),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: _onPanStartEditSteps,
                          onPanUpdate: _onPanUpdateEditSteps,
                          onPanEnd: _onPanEndEditSteps,
                          onTapUp: _onTapUpEditSteps,
                          child: SingleChildScrollView(
                            controller: _hScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            child: SingleChildScrollView(
                              controller: _vScrollController,
                              scrollDirection: Axis.vertical,
                              physics: const NeverScrollableScrollPhysics(),
                              clipBehavior: Clip.none,
                              child: RepaintBoundary(
                                key: _repaintBoundaryKey,
                                child: CustomPaint(
                                  key: _customPaintKey,
                                  isComplex: true,
                                  willChange: true,
                                  size: Size(totalWidth, totalHeight),
                                  painter: _StepTimingChartPainter(
                                    signals: visibleSignals,
                                    signalNames: visibleSignalNames,
                                    signalTypes: visibleSignalTypes,
                                    annotations: annotations,
                                    cellWidth: _cellWidth,
                                    cellHeight: _cellHeight,
                                    labelWidth: labelWidth,
                                    commentAreaHeight: commentAreaHeight,
                                    chartMarginLeft: chartMarginLeft,
                                    chartMarginTop: chartMarginTop,
                                    startSignalIndex: null,
                                    endSignalIndex: null,
                                    startTimeIndex: null,
                                    endTimeIndex: null,
                                    highlightTimeIndices: const [],
                                    omissionTimeIndices: _omissionTimeIndices,
                                    selectedAnnotationId: null,
                                    annotationRects: _annotationHitRects,
                                    showAllSignalTypes:
                                        widget.showAllSignalTypes,
                                    showIoNumbers: widget.showIoNumbers,
                                    portNumbers: visiblePortNumbers,
                                    timeUnitIsMs: settings.timeUnitIsMs,
                                    msPerStep: settings.msPerStep,
                                    stepDurationsMs: settingsRW.stepDurationsMs,
                                    activeStepIndex:
                                        (settings.timeUnitIsMs &&
                                                _isEditingSteps)
                                            ? _activeStepIndex
                                            : null,
                                    showBottomUnitLabels:
                                        Provider.of<SettingsNotifier>(
                                          context,
                                        ).showBottomUnitLabels,
                                    labelColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black,
                                    dashedColor:
                                        Theme.of(context).brightness ==
                                                    Brightness.dark &&
                                                Provider.of<SettingsNotifier>(
                                                      context,
                                                    ).commentDashedColor ==
                                                    Colors.black
                                            ? Colors.white
                                            : Provider.of<SettingsNotifier>(
                                              context,
                                            ).commentDashedColor,
                                    arrowColor:
                                        Theme.of(context).brightness ==
                                                    Brightness.dark &&
                                                Provider.of<SettingsNotifier>(
                                                      context,
                                                    ).commentArrowColor ==
                                                    Colors.black
                                            ? Colors.white
                                            : Provider.of<SettingsNotifier>(
                                              context,
                                            ).commentArrowColor,
                                    omissionColor:
                                        Theme.of(context).brightness ==
                                                    Brightness.dark &&
                                                Provider.of<SettingsNotifier>(
                                                      context,
                                                    ).omissionLineColor ==
                                                    Colors.black
                                            ? Colors.white
                                            : Provider.of<SettingsNotifier>(
                                              context,
                                            ).omissionLineColor,
                                    omissionFillColor:
                                        Theme.of(
                                          context,
                                        ).scaffoldBackgroundColor,
                                    signalColors:
                                        Provider.of<SettingsNotifier>(
                                          context,
                                        ).signalColors,
                                    draggingStartRow: null,
                                    draggingCurrentRow: null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 左ラベルの固定オーバ�Eレイ
                        Positioned(
                          left: chartMarginLeft,
                          top: 0,
                          child: IgnorePointer(
                            child: ClipRect(
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  chartMarginTop -
                                      (_vScrollController.hasClients
                                          ? _vScrollController.offset
                                          : 0.0),
                                ),
                                child: SizedBox(
                                  width: labelWidth,
                                  height: totalHeight,
                                  child: CustomPaint(
                                    isComplex: false,
                                    willChange: true,
                                    size: Size(labelWidth, totalHeight),
                                    painter: _LabelsOverlayPainter(
                                      signalNames: visibleSignalNames,
                                      signalTypes: visibleSignalTypes,
                                      showAllSignalTypes:
                                          widget.showAllSignalTypes,
                                      showIoNumbers: widget.showIoNumbers,
                                      portNumbers: visiblePortNumbers,
                                      ioSources: visibleIoSources,
                                      plcEipMode: widget.plcEipMode,
                                      labelColor:
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black,
                                      backgroundColor:
                                          Theme.of(
                                            context,
                                          ).scaffoldBackgroundColor,
                                      labelWidth: labelWidth,
                                      chartMarginLeft: chartMarginLeft,
                                      cellHeight: _cellHeight,
                                      highlightStartRow: null,
                                      highlightEndRow: null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        )
        : KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: Listener(
            onPointerSignal: _handlePointerSignal,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final settings = Provider.of<SettingsNotifier>(context);
                final maxLen =
                    signals.isEmpty
                        ? 0
                        : signals.map((e) => e.length).fold(0, math.max);
                // 表示対象インチE��クスを抽出
                final visibleIndexes = <int>[];
                final int safeLen = math.min(
                  widget.signalTypes.length,
                  math.min(signals.length, signalNames.length),
                );
                for (int i = 0; i < safeLen; i++) {
                  final t = widget.signalTypes[i];
                  if (widget.showAllSignalTypes ||
                      (t != SignalType.control &&
                          t != SignalType.group &&
                          t != SignalType.task)) {
                    visibleIndexes.add(i);
                  }
                }

                // --- 横方吁E---
                final availableWidth =
                    constraints.maxWidth.isFinite
                        ? constraints.maxWidth - chartMarginLeft - labelWidth
                        : MediaQuery.of(context).size.width -
                            chartMarginLeft -
                            labelWidth;

                // 合計スチE��プ幁E��Es モードでは吁E��チE��プ�E相対幁E�E総和�E�E
                final bool isMs = settings.timeUnitIsMs;
                final List<double> durationsForLayout =
                    (_controller?.stepDurationsMs.isNotEmpty ?? false)
                        ? _controller!.stepDurationsMs
                        : settings.stepDurationsMs;
                double totalSteps = 0.0;
                if (isMs && maxLen > 0) {
                  for (int i = 0; i < maxLen; i++) {
                    final dur =
                        (i < durationsForLayout.length)
                            ? durationsForLayout[i]
                            : settings.msPerStep;
                    totalSteps +=
                        (settings.msPerStep > 0)
                            ? (dur / settings.msPerStep)
                            : 1.0;
                  }
                } else {
                  totalSteps = maxLen.toDouble();
                }

                double baseCellWidth;
                if (widget.fitToScreen) {
                  baseCellWidth =
                      totalSteps > 0
                          ? math.max(availableWidth / totalSteps, 5.0)
                          : 40.0;
                } else {
                  baseCellWidth =
                      totalSteps > 0
                          ? math.max(availableWidth / totalSteps, 20.0)
                          : 40.0;
                }

                double minCellWidthForFullView = baseCellWidth;
                if (totalSteps > 0 &&
                    availableWidth.isFinite &&
                    availableWidth > 0) {
                  final double perStepWidth = availableWidth / totalSteps;
                  if (perStepWidth.isFinite && perStepWidth > 0) {
                    minCellWidthForFullView = math.min(
                      baseCellWidth,
                      math.max(perStepWidth, _minZoomCellWidth),
                    );
                  }
                }
                minCellWidthForFullView =
                    minCellWidthForFullView
                        .clamp(_minZoomCellWidth, baseCellWidth)
                        .toDouble();

                // 下限が上限を趁E��なぁE��ぁE��上限へキャチE�E
                minCellWidthForFullView = math.min(
                  minCellWidthForFullView,
                  _maxZoomCellWidth,
                );

                // 上限: チャート上に最佁EスチE��プが表示できるまで拡大を許可
                final double viewportWaveWidth = _getViewportWaveWidth();
                final double maxCellWidthForTwoSteps =
                    (viewportWaveWidth.isFinite && viewportWaveWidth > 0)
                        ? (viewportWaveWidth / 2.0)
                        : _maxZoomCellWidth;
                final double maxCellWidthAllowed = maxCellWidthForTwoSteps;

                final double minZoomFactorForView =
                    baseCellWidth <= 0
                        ? 1.0
                        : (minCellWidthForFullView / baseCellWidth).clamp(
                          _minZoom,
                          double.maxFinite,
                        );
                final double maxZoomFactorForView =
                    baseCellWidth <= 0
                        ? 1.0
                        : (maxCellWidthAllowed / baseCellWidth);
                final double effectiveZoomFactor = _zoomFactor.clamp(
                  minZoomFactorForView,
                  maxZoomFactorForView,
                );

                _cellWidth =
                    (baseCellWidth * effectiveZoomFactor)
                        .clamp(minCellWidthForFullView, maxCellWidthAllowed)
                        .toDouble();

                _minZoomFactorForView = minZoomFactorForView;
                _maxZoomFactorForView = maxZoomFactorForView;
                _effectiveZoomFactor = effectiveZoomFactor;
                // ▼ コメントエリアの高さを動皁E��算�E
                final double commentAreaHeight = _calculateCommentAreaHeight();

                // --- 縦方吁E---
                double constraintHeight =
                    constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : MediaQuery.of(context).size.height;

                if (widget.fitToScreen) {
                  final availableHeight =
                      constraintHeight - chartMarginTop - commentAreaHeight;
                  final visibleRowCount = visibleIndexes.length;
                  if (visibleRowCount > 0) {
                    _cellHeight = math.max(
                      availableHeight / visibleRowCount,
                      5.0,
                    );
                  }
                } else {
                  _cellHeight = 40;
                }

                final double totalWidth =
                    chartMarginLeft + labelWidth + totalSteps * _cellWidth;
                final double totalHeight =
                    chartMarginTop +
                    visibleIndexes.length * _cellHeight +
                    commentAreaHeight;

                // フィルタ済みリストを作�E
                final visibleSignalNames = [
                  for (final i in visibleIndexes) signalNames[i],
                ];
                final visibleSignals = [
                  for (final i in visibleIndexes)
                    if (i < signals.length) signals[i],
                ];
                final visibleSignalTypes = [
                  for (final i in visibleIndexes) widget.signalTypes[i],
                ];
                final visiblePortNumbers = [
                  for (final i in visibleIndexes)
                    (i < widget.portNumbers.length) ? widget.portNumbers[i] : 0,
                ];
                final visibleIoSources = [
                  for (final i in visibleIndexes)
                    (i < widget.ioSources.length)
                        ? widget.ioSources[i]
                        : IoChannelSource.unknown,
                ];

                _visibleIndexes = visibleIndexes;

                // 非等間隔用: Settings にチャート長を通知して長さを揁E��る（ビルド後に実行！E
                final settingsRW = Provider.of<SettingsNotifier>(
                  context,
                  listen: false,
                );
                if (settings.stepDurationsMs.length != maxLen) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) settingsRW.ensureStepDurationsLength(maxLen);
                  });
                }

                // 上部にトグル、下部にチャート本体を配置して重なりを回避
                const double _topControlsHeight = 48.0;
                if (widget.fitToScreen) {
                  final availableHeight =
                      (constraints.maxHeight.isFinite
                          ? constraints.maxHeight
                          : MediaQuery.of(context).size.height) -
                      _topControlsHeight -
                      chartMarginTop -
                      commentAreaHeight;
                  final visibleRowCount = visibleIndexes.length;
                  if (visibleRowCount > 0) {
                    _cellHeight = math.max(
                      availableHeight / visibleRowCount,
                      5.0,
                    );
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8, top: 8),
                        child: _buildUnitToggle(context),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanDown: (details) {
                              if (_isEditingSteps) return; // 編雁E��は他機�Eを無効匁E
                              final box =
                                  context.findRenderObject() as RenderBox?;
                              if (box == null) return;
                              final localPos = box.globalToLocal(
                                details.globalPosition,
                              );
                              final adjustedPos = Offset(
                                localPos.dx -
                                    chartMarginLeft +
                                    (_hScrollController.hasClients
                                        ? _hScrollController.offset
                                        : 0),
                                localPos.dy -
                                    chartMarginTop +
                                    (_vScrollController.hasClients
                                        ? _vScrollController.offset
                                        : 0),
                              );
                              for (final entry in _annotationHitRects.entries) {
                                final rect = entry.value;
                                if (rect.contains(adjustedPos)) {
                                  setState(() {
                                    _draggingAnnotationId = entry.key;
                                    _draggingStartLocal = adjustedPos;
                                    _draggingInitialBoxTopLeft = rect.topLeft;
                                    _selectedAnnotationId = entry.key;
                                  });
                                  break;
                                }
                              }
                            },
                            onPanStart:
                                _isEditingSteps
                                    ? _onPanStartEditSteps
                                    : _onPanStart,
                            onPanUpdate:
                                _isEditingSteps
                                    ? _onPanUpdateEditSteps
                                    : _onPanUpdate,
                            onPanEnd:
                                _isEditingSteps
                                    ? _onPanEndEditSteps
                                    : _onPanEnd,
                            onLongPressStart:
                                _isEditingSteps ? null : _onLongPressStart,
                            onLongPressMoveUpdate:
                                _isEditingSteps ? null : _onLongPressMoveUpdate,
                            onLongPressEnd:
                                _isEditingSteps ? null : _onLongPressEnd,
                            onTapUp: _isEditingSteps ? null : _handleTap,
                            onSecondaryTapDown:
                                _isEditingSteps
                                    ? null
                                    : (details) => _showContextMenu(
                                      context,
                                      details.globalPosition,
                                    ),
                            child: SingleChildScrollView(
                              controller: _hScrollController,
                              scrollDirection: Axis.horizontal,
                              physics:
                                  (_draggingAnnotationId != null ||
                                          _isModifierPressed)
                                      ? const NeverScrollableScrollPhysics()
                                      : null,
                              child: SingleChildScrollView(
                                controller: _vScrollController,
                                scrollDirection: Axis.vertical,
                                physics: const NeverScrollableScrollPhysics(),
                                clipBehavior: Clip.none,
                                child: RepaintBoundary(
                                  key: _repaintBoundaryKey,
                                  child: CustomPaint(
                                    key: _customPaintKey,
                                    isComplex: true,
                                    willChange: true,
                                    size: Size(totalWidth, totalHeight),
                                    painter: _StepTimingChartPainter(
                                      signals: visibleSignals,
                                      signalNames: visibleSignalNames,
                                      signalTypes: visibleSignalTypes,
                                      annotations: annotations,
                                      cellWidth: _cellWidth,
                                      cellHeight: _cellHeight,
                                      labelWidth: labelWidth,
                                      commentAreaHeight: commentAreaHeight,
                                      chartMarginLeft: chartMarginLeft,
                                      chartMarginTop: chartMarginTop,
                                      startSignalIndex: _startSignalIndex,
                                      endSignalIndex: _endSignalIndex,
                                      startTimeIndex: _startTimeIndex,
                                      endTimeIndex: _endTimeIndex,
                                      highlightTimeIndices:
                                          _highlightTimeIndices,
                                      omissionTimeIndices: _omissionTimeIndices,
                                      selectedAnnotationId:
                                          _selectedAnnotationId,
                                      annotationRects: _annotationHitRects,
                                      showAllSignalTypes:
                                          widget.showAllSignalTypes,
                                      showIoNumbers: widget.showIoNumbers,
                                      portNumbers: visiblePortNumbers,
                                      timeUnitIsMs: settings.timeUnitIsMs,
                                      msPerStep: settings.msPerStep,
                                      stepDurationsMs:
                                          settingsRW.stepDurationsMs,
                                      activeStepIndex:
                                          (settings.timeUnitIsMs &&
                                                  _isEditingSteps)
                                              ? _activeStepIndex
                                              : null,
                                      showBottomUnitLabels:
                                          Provider.of<SettingsNotifier>(
                                            context,
                                          ).showBottomUnitLabels,
                                      labelColor:
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black,
                                      dashedColor:
                                          Theme.of(context).brightness ==
                                                      Brightness.dark &&
                                                  Provider.of<SettingsNotifier>(
                                                        context,
                                                      ).commentDashedColor ==
                                                      Colors.black
                                              ? Colors.white
                                              : Provider.of<SettingsNotifier>(
                                                context,
                                              ).commentDashedColor,
                                      arrowColor:
                                          Theme.of(context).brightness ==
                                                      Brightness.dark &&
                                                  Provider.of<SettingsNotifier>(
                                                        context,
                                                      ).commentArrowColor ==
                                                      Colors.black
                                              ? Colors.white
                                              : Provider.of<SettingsNotifier>(
                                                context,
                                              ).commentArrowColor,
                                      omissionColor:
                                          Theme.of(context).brightness ==
                                                      Brightness.dark &&
                                                  Provider.of<SettingsNotifier>(
                                                        context,
                                                      ).omissionLineColor ==
                                                      Colors.black
                                              ? Colors.white
                                              : Provider.of<SettingsNotifier>(
                                                context,
                                              ).omissionLineColor,
                                      omissionFillColor:
                                          Theme.of(
                                            context,
                                          ).scaffoldBackgroundColor,
                                      signalColors:
                                          Provider.of<SettingsNotifier>(
                                            context,
                                          ).signalColors,
                                      draggingStartRow: _labelDragStartRow,
                                      draggingCurrentRow: _labelDragCurrentRow,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 左ラベルの固定オーバ�Eレイ�E�非編雁E��ード！E
                          Positioned(
                            left: 0,
                            top: 0,
                            child: IgnorePointer(
                              child: ClipRect(
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    chartMarginTop -
                                        (_vScrollController.hasClients
                                            ? _vScrollController.offset
                                            : 0.0),
                                  ),
                                  child: SizedBox(
                                    width: chartMarginLeft + labelWidth,
                                    height: totalHeight,
                                    child: CustomPaint(
                                      isComplex: false,
                                      willChange: true,
                                      size: Size(
                                        chartMarginLeft + labelWidth,
                                        totalHeight,
                                      ),
                                      painter: _LabelsOverlayPainter(
                                        signalNames: visibleSignalNames,
                                        signalTypes: visibleSignalTypes,
                                        showAllSignalTypes:
                                            widget.showAllSignalTypes,
                                        showIoNumbers: widget.showIoNumbers,
                                        portNumbers: visiblePortNumbers,
                                        ioSources: visibleIoSources,
                                        plcEipMode: widget.plcEipMode,
                                        labelColor:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black,
                                        backgroundColor:
                                            Theme.of(
                                              context,
                                            ).scaffoldBackgroundColor,
                                        labelWidth: labelWidth,
                                        chartMarginLeft: chartMarginLeft,
                                        cellHeight: _cellHeight,
                                        highlightStartRow: _startSignalIndex,
                                        highlightEndRow: _endSignalIndex,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
  }

  Widget _buildZoomControls() {
    final int zoomPercent = (_effectiveZoomFactor * 100).round();
    final bool canZoomIn = _effectiveZoomFactor < _maxZoomFactorForView - 0.001;
    final bool canZoomOut =
        _effectiveZoomFactor > _minZoomFactorForView + 0.001;
    final bool canReset =
        (_effectiveZoomFactor - _minZoomFactorForView).abs() > 0.001;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$zoomPercent%'),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          icon: const Icon(Icons.zoom_out, size: 16),
          label: const Text('Zoom out'),
          onPressed: canZoomOut ? _zoomOutWithAnchorAtCenter : null,
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          icon: const Icon(Icons.zoom_in, size: 16),
          label: const Text('Zoom in'),
          onPressed: canZoomIn ? _zoomInWithAnchorAtCenter : null,
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          icon: const Icon(Icons.fit_screen, size: 16),
          label: const Text('Fit'),
          onPressed: canReset ? _resetZoom : null,
        ),
      ],
    );
  }

  // 選択篁E��の合計時間[ms]を計算！Es単位�E非等間隔に対応！E
  double _computeSelectionDurationMs(SettingsNotifier settings) {
    if (!_hasValidSelection) return 0.0;
    final int stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final int edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    // レイアウトと同じソース�E�Eontroller優先�Eなければsettings�E�を使用
    final List<double> durations =
        (_controller?.stepDurationsMs.isNotEmpty ?? false)
            ? _controller!.stepDurationsMs
            : settings.stepDurationsMs;
    double sumMs = 0.0;
    for (int i = stTime; i <= edTime; i++) {
      final double ms =
          (i < durations.length && settings.msPerStep > 0)
              ? durations[i]
              : settings.msPerStep;
      sumMs += ms.isFinite && ms > 0 ? ms : 0.0;
    }
    return sumMs;
  }

  // 選択篁E��のスチE��プ数を計算（等間隔単佁Estep用�E�E
  int _computeSelectionSteps() {
    if (!_hasValidSelection) return 0;
    final int stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final int edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    return (edTime - stTime + 1).clamp(0, 1 << 30);
  }

  // 現在の単位に合わせた選択篁E��ラベルを生戁E
  String _buildSelectionLabel(SettingsNotifier settings) {
    if (settings.timeUnitIsMs) {
      final double ms = _computeSelectionDurationMs(settings);
      final int rounded = ms.round();
      return '$rounded ms';
    } else {
      final int steps = _computeSelectionSteps();
      return '$steps step';
    }
  }

  Widget _buildUnitToggle(BuildContext context) {
    final settings = Provider.of<SettingsNotifier>(context);
    final bool isMs = settings.timeUnitIsMs;
    final String label = isMs ? 'ms' : 'step';
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          Theme.of(context).colorScheme.surface.withAlpha((0.9 * 255).round()),
          Colors.transparent,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Unit:'),
          const SizedBox(width: 6),
          Switch(
            value: isMs,
            onChanged: (v) {
              settings.timeUnitIsMs = v;
              setState(() {});
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _resetZoom();
              });
              if (!v && _isEditingSteps) {
                setState(() {
                  _isEditingSteps = false;
                  _activeStepIndex = null;
                });
              }
            },
          ),
          Text(label),
          const SizedBox(width: 12),
          // 下部の単位ラベル�E�時間ラベル�E�表示刁E��
          Text('Labels:'),
          const SizedBox(width: 6),
          Switch(
            value: settings.showBottomUnitLabels,
            onChanged: (v) => settings.showBottomUnitLabels = v,
          ),
          const SizedBox(width: 12),
          if (isMs) ...[
            Text('ms/step'),
            const SizedBox(width: 6),
            _buildMsPerStepField(),
            const SizedBox(width: 12),
            _buildEditStepDurationsButton(),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              icon: Icon(
                _isEditingSteps ? Icons.close_fullscreen : Icons.open_in_full,
                size: 16,
              ),
              label: Text(_isEditingSteps ? 'Done' : 'Edit grid'),
              onPressed: () {
                setState(() {
                  _isEditingSteps = !_isEditingSteps;
                  _activeStepIndex = null;
                });
              },
            ),
          ],
          const SizedBox(width: 12),
          _buildZoomControls(),
          const SizedBox(width: 12),
          Text('Sel: ${_buildSelectionLabel(settings)}'),
        ],
      ),
    );
  }

  // 小さな数値入力！Es/step�E�E
  Widget _buildMsPerStepField() {
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    final controller = TextEditingController(
      text: settings.msPerStep.toStringAsFixed(2),
    );
    return SizedBox(
      width: 72,
      height: 32,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (val) {
          final v = double.tryParse(val);
          if (v != null && v > 0) {
            settings.msPerStep = v;
          }
        },
      ),
    );
  }

  // スチE��プ個別時間の編雁E��イアログ
  Widget _buildEditStepDurationsButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.tune, size: 16),
      label: const Text('Edit steps'),
      onPressed: () async {
        final settings = Provider.of<SettingsNotifier>(context, listen: false);
        final maxLen =
            signals.isEmpty
                ? 0
                : signals.map((e) => e.length).fold(0, math.max);
        settings.ensureStepDurationsLength(maxLen);
        final controller = TextEditingController(
          text: settings.stepDurationsMs.join(','),
        );
        // 入力ダイアログ中はチャート�Eのキーボ�Eドフォーカスを外す
        final bool prevCanRequest = _focusNode.canRequestFocus;
        _focusNode.canRequestFocus = false;
        FocusScope.of(context).unfocus();

        final ok =
            await showDialog<bool>(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: const Text('Step durations (ms, comma-separated)'),
                    content: TextField(
                      controller: controller,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 1,1,2,0.5,0.5,3',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
            ) ??
            false;
        // フォーカス設定を復帰
        _focusNode.canRequestFocus = prevCanRequest;
        if (mounted) _focusNode.requestFocus();
        if (!ok) return;
        final parts = controller.text.split(',');
        final parsed = <double>[];
        for (final p in parts) {
          final v = double.tryParse(p.trim());
          if (v != null && v > 0) parsed.add(v);
        }
        if (parsed.isNotEmpty) {
          settings.setStepDurationsMs(parsed);
        }
      },
    );
  }

  // 強制皁E��再描画をトリガーするメソチE��
  void _forceRepaint() {
    final customPaint = _customPaintKey.currentContext?.findRenderObject();
    if (customPaint is RenderCustomPaint) {
      customPaint.markNeedsPaint();
    }
  }

  /// チャート領域全体をPNGとしてキャプチャして返す
  Future<Uint8List?> captureChartPng({double? pixelRatio}) async {
    try {
      final boundary =
          _repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final double pr =
          pixelRatio ?? MediaQuery.of(context).devicePixelRatio.clamp(1.0, 4.0);
      final ui.Image image = await boundary.toImage(pixelRatio: pr);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing chart PNG: $e');
      return null;
    }
  }

  /// チャート領域全体をJPEGとしてキャプチャして返す�E�背景色・品質持E��！E
  Future<Uint8List?> captureChartJpeg({
    double? pixelRatio,
    Color? backgroundColor,
    int quality = 90,
  }) async {
    try {
      final boundary =
          _repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final double pr =
          pixelRatio ?? MediaQuery.of(context).devicePixelRatio.clamp(1.0, 4.0);

      // まずPNGとして取得！EGBA�E�E
      final ui.Image image = await boundary.toImage(pixelRatio: pr);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;

      final width = image.width;
      final height = image.height;
      final rgbaBytes = byteData.buffer.asUint8List();

      // 背景色を決定（未持E��ならテーマから！E
      final bg =
          backgroundColor ??
          (Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white);

      // RGBAを背景合�EしつつRGBへ変換
      final int rBg = (bg.r * 255).round();
      final int gBg = (bg.g * 255).round();
      final int bBg = (bg.b * 255).round();

      final Uint8List rgbBytes = Uint8List(width * height * 3);
      int si = 0; // source index
      int di = 0; // dest index
      for (int i = 0; i < width * height; i++) {
        final int r = rgbaBytes[si];
        final int g = rgbaBytes[si + 1];
        final int b = rgbaBytes[si + 2];
        final int a = rgbaBytes[si + 3];
        // aは0..255。アルファ合�E: out = src * a + bg * (1 - a)
        final int outR = ((r * a + rBg * (255 - a)) / 255).round();
        final int outG = ((g * a + gBg * (255 - a)) / 255).round();
        final int outB = ((b * a + bBg * (255 - a)) / 255).round();
        rgbBytes[di] = outR;
        rgbBytes[di + 1] = outG;
        rgbBytes[di + 2] = outB;
        si += 4;
        di += 3;
      }

      // JPEGエンコード！Eackage:image�E�E
      final img.Image rgbImage = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgbBytes.buffer,
        numChannels: 3,
      );
      final jpg = img.encodeJpg(rgbImage, quality: quality);
      return Uint8List.fromList(jpg);
    } catch (e) {
      debugPrint('Error capturing chart JPEG: $e');
      return null;
    }
  }

  /// 現在のアノテーション一覧を取征E
  List<TimingChartAnnotation> getAnnotations() => List.from(annotations);

  /// 現在チャートで表示されてぁE��信号 ID 頁E��を返す
  List<String> getSignalIdNames() => List.from(_idSignalNames);

  /// 省略信号(非表示区閁Eが描画されてぁE��時刻インチE��クス
  List<int> getOmissionTimeIndices() => List.from(_omissionTimeIndices);

  void setOmission(List<int> indices) {
    setState(() {
      _omissionTimeIndices = List<int>.from(indices);
      _forceRepaint();
    });
    _controller?.setOmissionTimeIndices(_omissionTimeIndices);
  }

  // 持E��アノテーションの矢印先端を、可視衁Eindex の水平中央に設宁E
  void _setAnnotationArrowToSignal(String annId, int visibleRowIndex) {
    if (visibleRowIndex < 0 || visibleRowIndex >= _visibleIndexes.length)
      return;
    final absoluteRowIndex = _visibleIndexes[visibleRowIndex];
    setState(() {
      final idx = annotations.indexWhere((a) => a.id == annId);
      if (idx != -1) {
        final rowCenterY = (absoluteRowIndex + 0.5) * _cellHeight;
        annotations[idx] = annotations[idx].copyWith(arrowTipY: rowCenterY);
        _forceRepaint();
      }
    });
  }

  // ======== キーボ�EドショートカチE��関連 ========
  late final FocusNode _focusNode = FocusNode();
  int _lastHandledGridResetNonce = 0;
  int _lastHandledGridRecomputeNonce = 0;

  @override
  void dispose() {
    suggestionLanguageVersion.removeListener(_langListener);
    HardwareKeyboard.instance.removeHandler(_handleModifierKeyEvent);
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    final bool pressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (pressed != _isModifierPressed) {
      setState(() {
        _isModifierPressed = pressed;
      });
    }
    return KeyEventResult.ignored;
  }

  bool _handleModifierKeyEvent(KeyEvent event) {
    final bool pressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (pressed != _isModifierPressed) {
      setState(() {
        _isModifierPressed = pressed;
      });
    }
    return false;
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final bool isModifierPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (isModifierPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
      _selectAllSignals();
    }
  }

  // すべての信号を選択すめE
  void _selectAllSignals() {
    if (signals.isEmpty || _visibleIndexes.isEmpty) return;
    setState(() {
      _startSignalIndex = 0;
      _endSignalIndex = _visibleIndexes.length - 1;
      _startTimeIndex = 0;
      _endTimeIndex = signals[0].length - 1;
      _forceRepaint();
    });
  }

  // ================= 行�Eれ替ぁE=================
  void _moveSignal(int visibleIndex, int direction) {
    // direction -1: 上へ, 1: 下へ
    final int targetVisible = visibleIndex + direction;
    if (targetVisible < 0 || targetVisible >= _visibleIndexes.length) return;

    final int srcIdx = _visibleIndexes[visibleIndex];
    final int dstIdx = _visibleIndexes[targetVisible];

    setState(() {
      // --- 値をスワチE�E ---
      final tmpSignal = signals[srcIdx];
      signals[srcIdx] = signals[dstIdx];
      signals[dstIdx] = tmpSignal;

      final tmpName = signalNames[srcIdx];
      signalNames[srcIdx] = signalNames[dstIdx];
      signalNames[dstIdx] = tmpName;

      // widget.signalTypes は final だぁEList 自体�E可変、E
      final tmpType = widget.signalTypes[srcIdx];
      widget.signalTypes[srcIdx] = widget.signalTypes[dstIdx];
      widget.signalTypes[dstIdx] = tmpType;

      // ポ�Eト番号も同期して入れ替ぁE
      if (widget.portNumbers.length > srcIdx &&
          widget.portNumbers.length > dstIdx) {
        final tmpPort = widget.portNumbers[srcIdx];
        widget.portNumbers[srcIdx] = widget.portNumbers[dstIdx];
        widget.portNumbers[dstIdx] = tmpPort;
      }

      if (widget.ioSources.length > srcIdx &&
          widget.ioSources.length > dstIdx) {
        final tmpSource = widget.ioSources[srcIdx];
        widget.ioSources[srcIdx] = widget.ioSources[dstIdx];
        widget.ioSources[dstIdx] = tmpSource;
      }

      // --- ID 頁E��も同期 ---
      final tmpId = _idSignalNames[srcIdx];
      _idSignalNames[srcIdx] = _idSignalNames[dstIdx];
      _idSignalNames[dstIdx] = tmpId;

      _forceRepaint();
    });
  }

  // -------- 行を任意位置へ移勁E--------
  void _reorderSignalRows(int fromVisible, int toVisible) {
    if (fromVisible == toVisible) return;

    if (fromVisible < toVisible) {
      for (int i = fromVisible; i < toVisible; i++) {
        _moveSignal(i, 1);
      }
    } else {
      for (int i = fromVisible; i > toVisible; i--) {
        _moveSignal(i, -1);
      }
    }
  }
}

/// タイミングチャートを描画するカスタムペインター
///
/// 責務�E刁E��に基づぁE��以下�E3つのマネージャークラスを利用�E�E
/// - ChartGridManager: グリチE��線と信号名ラベルの描画
/// - ChartSignalsManager: チE��タル信号波形と選択篁E��の描画
/// - ChartAnnotationsManager: コメント関連の描画
class _StepTimingChartPainter extends CustomPainter {
  _StepTimingChartPainter({
    required this.signals,
    required this.signalNames,
    required this.signalTypes,
    required this.annotations,
    required this.cellWidth,
    required this.cellHeight,
    required this.labelWidth,
    required this.commentAreaHeight,
    required this.chartMarginLeft,
    required this.chartMarginTop,
    required this.startSignalIndex,
    required this.endSignalIndex,
    required this.startTimeIndex,
    required this.endTimeIndex,
    required this.highlightTimeIndices,
    required this.omissionTimeIndices,
    required this.selectedAnnotationId,
    required this.annotationRects,
    required this.showAllSignalTypes,
    required this.showIoNumbers,
    required this.portNumbers,
    required this.timeUnitIsMs,
    required this.msPerStep,
    required this.stepDurationsMs,
    required this.activeStepIndex,
    required this.labelColor,
    required this.dashedColor,
    required this.omissionColor,
    required this.omissionFillColor,
    required this.arrowColor,
    required this.signalColors,
    required this.showBottomUnitLabels,
    this.draggingStartRow,
    this.draggingCurrentRow,
  }) {
    // 吁E�Eネ�Eジャークラスを�E期化
    _annotationsManager = ChartAnnotationsManager(
      annotations: annotations,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      labelWidth: labelWidth,
      highlightTimeIndices: highlightTimeIndices,
      selectedAnnotationId: selectedAnnotationId,
      dashedColor: dashedColor,
      arrowColor: arrowColor,
      timeUnitIsMs: timeUnitIsMs,
      msPerStep: msPerStep,
      stepDurationsMs: stepDurationsMs,
    );

    _gridManager = ChartGridManager(
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      labelWidth: labelWidth,
      signalNames: signalNames,
      signalTypes: signalTypes,
      showAllSignalTypes: showAllSignalTypes,
      showIoNumbers: showIoNumbers,
      portNumbers: portNumbers,
      labelColor: labelColor,
      highlightStartRow: startSignalIndex,
      highlightEndRow: endSignalIndex,
      highlightTextColor: arrowColor, // 矢印色と統一
      timeUnitIsMs: timeUnitIsMs,
      msPerStep: msPerStep,
      stepDurationsMs: stepDurationsMs,
      activeStepIndex: activeStepIndex,
      showBottomUnitLabels: showBottomUnitLabels,
    );

    _signalsManager = ChartSignalsManager(
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      labelWidth: labelWidth,
      signalTypes: signalTypes,
      showAllSignalTypes: showAllSignalTypes,
      signalColors: signalColors,
      timeUnitIsMs: timeUnitIsMs,
      msPerStep: msPerStep,
      stepDurationsMs: stepDurationsMs,
    );
  }

  final List<List<int>> signals;
  final List<String> signalNames;
  final List<SignalType> signalTypes;
  final List<TimingChartAnnotation> annotations;
  final List<int> highlightTimeIndices;
  final List<int> omissionTimeIndices;

  final double cellWidth;
  final double cellHeight;
  final double labelWidth;
  final double commentAreaHeight;
  final double chartMarginLeft;
  final double chartMarginTop;

  final int? startSignalIndex;
  final int? endSignalIndex;
  final int? startTimeIndex;
  final int? endTimeIndex;

  final String? selectedAnnotationId;
  final Map<String, Rect> annotationRects;
  final bool showAllSignalTypes;
  final bool showIoNumbers;
  final List<int> portNumbers;
  final bool timeUnitIsMs;
  final double msPerStep;
  final List<double> stepDurationsMs;
  final int? activeStepIndex;
  final Map<SignalType, Color> signalColors;

  // Colors
  final Color labelColor;
  final Color dashedColor;
  final Color omissionColor;
  final Color omissionFillColor;
  final Color arrowColor;
  // 下部の単位ラベル表示制御
  final bool showBottomUnitLabels;

  // --- ラベルドラチE��用ハイライチE---
  final int? draggingStartRow;
  final int? draggingCurrentRow;

  // 吁E��マネージャーインスタンス
  late final ChartAnnotationsManager _annotationsManager;
  late final ChartGridManager _gridManager;
  late final ChartSignalsManager _signalsManager;

  @override
  void paint(Canvas canvas, Size size) {
    // 描画篁E��幁E���Eージン部刁E��除ぁE��エリア�E�E
    final double drawAreaWidth = size.width - chartMarginLeft;

    debugPrint('\n=== TimingChart Paint Start ===');
    debugPrint('Canvas Size: $size');
    debugPrint('Chart Margin: Left=$chartMarginLeft, Top=$chartMarginTop');

    // 描画の開始点をオフセチE��
    canvas.save();
    canvas.translate(chartMarginLeft, chartMarginTop);
    debugPrint('Canvas translated by: ($chartMarginLeft, $chartMarginTop)');

    // signals, signalNames, signalTypesの長さ�Eすべて一致してぁE��前提
    final rowCount = signals.length;

    // ラベル領域の背景を�Eに塗りつぶし（波形めE��リチE��のにじみ対策！E
    final double maskHeight = rowCount * cellHeight + commentAreaHeight;
    final Paint labelMaskPaint =
        Paint()
          ..color = omissionFillColor
          ..style = PaintingStyle.fill;
    // 右端めEpx空けて塗りつぶし！E刻みの線を要E��なぁE��E
    final double maskWidth = (labelWidth - 1).clamp(0.0, double.infinity);
    canvas.drawRect(Rect.fromLTWH(0, 0, maskWidth, maskHeight), labelMaskPaint);

    // 0. ドラチE��ハイライト（背景�E�E
    if (draggingStartRow != null) {
      final paintBg =
          Paint()
            ..color = Colors.yellow.withAlpha((0.25 * 255).round())
            ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          draggingStartRow! * cellHeight,
          drawAreaWidth,
          cellHeight,
        ),
        paintBg,
      );
    }
    if (draggingCurrentRow != null) {
      final paintBg =
          Paint()
            ..color = Colors.blue.withAlpha((0.25 * 255).round())
            ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          draggingCurrentRow! * cellHeight,
          drawAreaWidth,
          cellHeight,
        ),
        paintBg,
      );
    }

    // 描画頁E���E背景から前景へ�E�E
    // Labels are drawn by overlay painter to keep them pinned on the left.

    debugPrint('\n2. Drawing grid lines');
    final maxTimeSteps =
        signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);
    // ms単位�E非等間隔描画にも対応できるよう gridManager に stepDurations を渡済み
    _gridManager.drawGridLines(canvas, size, rowCount, maxTimeSteps);

    debugPrint('\n3. Drawing highlighted time indices');
    _gridManager.drawHighlightedLines(canvas, highlightTimeIndices, size);

    debugPrint('\n4. Drawing signal waveforms');
    // ラベル領域に波形が�Eみ出さなぁE��ぁE��リチE�E
    canvas.save();
    final double clipHeight = rowCount * cellHeight + commentAreaHeight;
    // クリチE�E開始を1px右へ�E�E刻みの線を確実に残す�E�E
    canvas.clipRect(
      Rect.fromLTWH(
        labelWidth + 1,
        0,
        drawAreaWidth - (labelWidth + 1),
        clipHeight,
      ),
    );
    // 現行�E描画は step 等間隔�Eため、x = labelWidth + t*cellWidth
    // ms非等間隔対応�E今征Emapper ベ�Eスに差し替え予宁E
    _signalsManager.drawSignalWaveforms(canvas, signals);

    debugPrint('\n4b. Drawing omission lines');
    _drawOmissionLines(canvas, rowCount);
    canvas.restore();

    debugPrint('\n5. Drawing selection highlight');
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        labelWidth + 1,
        0,
        drawAreaWidth - (labelWidth + 1),
        rowCount * cellHeight + commentAreaHeight,
      ),
    );
    _signalsManager.drawSelectionHighlight(
      canvas,
      startSignalIndex,
      endSignalIndex,
      startTimeIndex,
      endTimeIndex,
    );
    canvas.restore();

    debugPrint('\n6. Drawing annotations with boundary lines');
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        labelWidth + 1,
        0,
        drawAreaWidth - (labelWidth + 1),
        rowCount * cellHeight + commentAreaHeight,
      ),
    );
    _annotationsManager.drawAnnotations(canvas, size, rowCount);
    canvas.restore();

    // 時間ラベル�E�下部�E�E
    _gridManager.drawTimeLabels(canvas, size, rowCount, maxTimeSteps);

    // アノテーションの当たり判定用Rectマップを更新
    annotationRects.clear();
    annotationRects.addAll(_annotationsManager.getAnnotationRects());

    canvas.restore();
    debugPrint('Canvas restored to original state');
    debugPrint('=== TimingChart Paint End ===\n');
  }

  /// 省略信号�E�波線）�E描画
  void _drawOmissionLines(Canvas canvas, int rowCount) {
    if (omissionTimeIndices.isEmpty) return;

    final double chartBottom = rowCount * cellHeight;
    final paint =
        Paint()
          ..color = omissionColor
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

    for (final t in omissionTimeIndices) {
      double x;
      if (timeUnitIsMs) {
        double steps = 0.0;
        for (int k = 0; k < t; k++) {
          final durSteps =
              (k < stepDurationsMs.length && msPerStep > 0)
                  ? stepDurationsMs[k] / msPerStep
                  : 1.0;
          steps += durSteps;
        }
        x = labelWidth + steps * cellWidth;
      } else {
        x = labelWidth + t * cellWidth;
      }
      drawDoubleWavyVerticalLine(
        canvas,
        Offset(x, 0),
        Offset(x, chartBottom),
        paint,
        amplitude: 12.0,
        wavelength: 32.0,
        gap: 8.0,
        fillColor: omissionFillColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StepTimingChartPainter oldDelegate) {
    // 最初に信号値の比輁E
    bool signalsChanged = signals.length != oldDelegate.signals.length;

    if (!signalsChanged) {
      // 吁E��号の長さと冁E��を比輁E
      for (int i = 0; i < signals.length; i++) {
        if (signals[i].length != oldDelegate.signals[i].length) {
          signalsChanged = true;
          break;
        }

        // ビット単位で比輁E��て変更を検�E
        for (int j = 0; j < signals[i].length; j++) {
          if (signals[i][j] != oldDelegate.signals[i][j]) {
            signalsChanged = true;
            break;
          }
        }

        if (signalsChanged) break;
      }
    }

    return signalsChanged ||
        signalNames != oldDelegate.signalNames ||
        annotations != oldDelegate.annotations ||
        labelColor != oldDelegate.labelColor ||
        dashedColor != oldDelegate.dashedColor ||
        omissionColor != oldDelegate.omissionColor ||
        omissionFillColor != oldDelegate.omissionFillColor ||
        arrowColor != oldDelegate.arrowColor ||
        !mapEquals(signalColors, oldDelegate.signalColors) ||
        selectedAnnotationId != oldDelegate.selectedAnnotationId ||
        !listEquals(highlightTimeIndices, oldDelegate.highlightTimeIndices) ||
        !listEquals(omissionTimeIndices, oldDelegate.omissionTimeIndices) ||
        startSignalIndex != oldDelegate.startSignalIndex ||
        endSignalIndex != oldDelegate.endSignalIndex ||
        startTimeIndex != oldDelegate.startTimeIndex ||
        endTimeIndex != oldDelegate.endTimeIndex ||
        showIoNumbers != oldDelegate.showIoNumbers ||
        portNumbers != oldDelegate.portNumbers ||
        // ms/編雁E��E��の変化も�E描画トリガ
        timeUnitIsMs != oldDelegate.timeUnitIsMs ||
        msPerStep != oldDelegate.msPerStep ||
        !listEquals(stepDurationsMs, oldDelegate.stepDurationsMs) ||
        activeStepIndex != oldDelegate.activeStepIndex;
  }
}

/// ラベルを独立して固定描画するオーバ�Eレイ用ペインター
class _LabelsOverlayPainter extends CustomPainter {
  _LabelsOverlayPainter({
    required this.signalNames,
    required this.signalTypes,
    required this.showAllSignalTypes,
    required this.showIoNumbers,
    required this.portNumbers,
    required this.ioSources,
    required this.plcEipMode,
    required this.labelColor,
    required this.backgroundColor,
    required this.labelWidth,
    required this.chartMarginLeft,
    required this.cellHeight,
    required this.highlightStartRow,
    required this.highlightEndRow,
  });

  final List<String> signalNames;
  final List<SignalType> signalTypes;
  final bool showAllSignalTypes;
  final bool showIoNumbers;
  final List<int> portNumbers;
  final List<IoChannelSource> ioSources;
  final String plcEipMode;
  final Color labelColor;
  final Color backgroundColor;
  final double labelWidth;
  final double chartMarginLeft;
  final double cellHeight;
  final int? highlightStartRow;
  final int? highlightEndRow;

  @override
  void paint(Canvas canvas, Size size) {
    // 背景でラベル領域�E�左端〜ラベル右端�E�を塗りつぶし、下層の波形を完�Eに隠ぁE
    final bgPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.fill;
    // 右端めEpx空けて塗る�E�E刻みの線を要E��なぁE��E
    final double overlayWidth = (chartMarginLeft + labelWidth - 1).clamp(
      0.0,
      double.infinity,
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, overlayWidth, size.height), bgPaint);

    // 行区刁E��線を描画�E�ラベルごとの区刁E���E�E
    final gridPaint =
        Paint()
          ..color = labelColor.withAlpha((0.2 * 255).round())
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
    final double overlayWidthForLines = chartMarginLeft + labelWidth - 1;
    final int rows = signalNames.length;
    for (int i = 0; i <= rows; i++) {
      final double y = i * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(overlayWidthForLines, y), gridPaint);
    }

    // ラベルの右端に縦の区刁E��線！Epx�E�E
    final borderPaint =
        Paint()
          ..color = labelColor.withAlpha((0.35 * 255).round())
          ..strokeWidth = 1.0;
    final double borderX = chartMarginLeft + labelWidth;
    canvas.drawLine(
      Offset(borderX, 0),
      Offset(borderX, size.height),
      borderPaint,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    );

    for (
      int row = 0;
      row < signalNames.length && row < signalTypes.length;
      row++
    ) {
      final currentSignalType = signalTypes[row];
      if (!showAllSignalTypes &&
          (currentSignalType == SignalType.control ||
              currentSignalType == SignalType.group ||
              currentSignalType == SignalType.task)) {
        continue;
      }

      bool isHighlighted = false;
      if (highlightStartRow != null && highlightEndRow != null) {
        final int minRow =
            highlightStartRow! < highlightEndRow!
                ? highlightStartRow!
                : highlightEndRow!;
        final int maxRow =
            highlightStartRow! > highlightEndRow!
                ? highlightStartRow!
                : highlightEndRow!;
        if (row >= minRow && row <= maxRow) {
          isHighlighted = true;
        }
      }

      final int portNum = (row < portNumbers.length) ? portNumbers[row] : 0;
      final IoChannelSource rawSource =
          (row < ioSources.length) ? ioSources[row] : IoChannelSource.unknown;
      final IoChannelSource source = _effectiveSource(rawSource);

      String prefix = '';
      if (showIoNumbers && portNum > 0) {
        switch (currentSignalType) {
          case SignalType.input:
            prefix = '${_inputPrefixFor(source)}$portNum: ';
            break;
          case SignalType.output:
            prefix = '${_outputPrefixFor(source)}$portNum: ';
            break;
          case SignalType.hwTrigger:
            prefix = 'HW$portNum: ';
            break;
          default:
            break;
        }
      }

      final displayName =
          showIoNumbers ? '$prefix${signalNames[row]}' : signalNames[row];
      textPainter.text = TextSpan(
        text: displayName,
        style: TextStyle(
          color: isHighlighted ? Colors.orange : labelColor,
          fontSize: 14,
          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout(maxWidth: labelWidth - 16);
      final yCenter = row * cellHeight + (cellHeight - textPainter.height) / 2;
      // ラベル斁E���Eチャート左余白の後ろから描画
      textPainter.paint(canvas, Offset(chartMarginLeft + 6, yCenter));
    }
  }

  IoChannelSource _effectiveSource(IoChannelSource source) {
    if (source == IoChannelSource.plcEip) {
      if (plcEipMode == 'PLC') return IoChannelSource.plc;
      if (plcEipMode == 'EIP') return IoChannelSource.eip;
      return IoChannelSource.unknown;
    }
    return source;
  }

  String _inputPrefixFor(IoChannelSource source) {
    switch (_effectiveSource(source)) {
      case IoChannelSource.plc:
        return 'PLI';
      case IoChannelSource.eip:
        return 'ESI';
      default:
        return 'Input';
    }
  }

  String _outputPrefixFor(IoChannelSource source) {
    switch (_effectiveSource(source)) {
      case IoChannelSource.plc:
        return 'PLO';
      case IoChannelSource.eip:
        return 'ESO';
      default:
        return 'Output';
    }
  }

  @override
  bool shouldRepaint(covariant _LabelsOverlayPainter oldDelegate) {
    return signalNames != oldDelegate.signalNames ||
        signalTypes != oldDelegate.signalTypes ||
        showAllSignalTypes != oldDelegate.showAllSignalTypes ||
        showIoNumbers != oldDelegate.showIoNumbers ||
        portNumbers != oldDelegate.portNumbers ||
        !listEquals(ioSources, oldDelegate.ioSources) ||
        plcEipMode != oldDelegate.plcEipMode ||
        labelColor != oldDelegate.labelColor ||
        labelWidth != oldDelegate.labelWidth ||
        cellHeight != oldDelegate.cellHeight ||
        highlightStartRow != oldDelegate.highlightStartRow ||
        highlightEndRow != oldDelegate.highlightEndRow;
  }
}
