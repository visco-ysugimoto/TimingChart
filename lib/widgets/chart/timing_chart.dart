import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../models/chart/timing_chart_annotation.dart';
import '../../models/chart/signal_type.dart';
import 'chart_annotations.dart';
import 'chart_grid.dart';
import 'chart_signals.dart';
import 'chart_drawing_util.dart';
import '../../suggestion_loader.dart';
import '../../providers/settings_notifier.dart';
import 'package:provider/provider.dart'; // Added for Provider
import '../../generated/l10n.dart';

// Add translation support

class TimingChart extends StatefulWidget {
  final List<String> initialSignalNames;
  final List<List<int>> initialSignals;
  final List<TimingChartAnnotation> initialAnnotations;
  final List<SignalType> signalTypes;

  /// 画面サイズに合わせてチャート全体をフィットさせるかどうか。
  ///
  /// true の場合は、横幅だけでなく縦方向（信号数）も含めて
  /// 表示領域に収まるようにセルサイズを自動調整します。
  /// false（デフォルト）の場合は従来と同じ動作で、横方向のみ縮小し、
  /// セル高さは固定 40px になります。
  final bool fitToScreen;

  /// Control / Group / Task 種別を含むすべての信号を描画対象にするかどうか。
  /// 省略時は従来互換で false（これらの補助信号は描画しない）。
  final bool showAllSignalTypes;

  /// 入出力信号ラベルに番号 (Input1 などの末尾数字) を表示するかどうか。
  /// 省略時は true (番号を表示)。
  final bool showIoNumbers;

  final List<int> portNumbers;

  const TimingChart({
    super.key,
    required this.initialSignalNames,
    required this.initialSignals,
    required this.initialAnnotations,
    required this.signalTypes,
    this.fitToScreen = false,
    this.showAllSignalTypes = false,
    this.showIoNumbers = true,
    required this.portNumbers,
  });

  @override
  State<TimingChart> createState() => TimingChartState();
}

class TimingChartState extends State<TimingChart>
    with AutomaticKeepAliveClientMixin {
  // 保持用: ID 名リスト
  late List<String> _idSignalNames;

  // 言語変更監視用
  late final VoidCallback _langListener;

  @override
  bool get wantKeepAlive => true;

  late List<List<int>> signals;
  late List<String> signalNames;
  late List<TimingChartAnnotation> annotations;
  List<int> _highlightTimeIndices = [];
  // 省略信号を描画する対象の時刻インデックス
  List<int> _omissionTimeIndices = [];
  List<int> _visibleIndexes = [];

  // ===== ラベルドラッグ用 =====
  bool _isLabelDrag = false;
  int? _labelDragStartRow;
  int? _labelDragCurrentRow;

  double _cellWidth = 40;
  // セル高さは `fitToScreen` が true の場合のみ動的に変化する。
  // デフォルト値は従来互換用に 40 としておく。
  double _cellHeight = 40;

  final double labelWidth = 200.0;
  // コメントエリアの高さ（動的計算時の下限値）
  static const double _minCommentAreaHeight = 100.0;

  // コメントが無い場合に確保する最小下余白
  static const double _noCommentBottomMargin = 40.0;

  /// コメントがはみ出さないように必要な高さを概算で計算する。
  ///
  /// 現在の描画ロジックでは、コメントが重なるごとに 20px ずつ下方向に
  /// ずらしているため、
  ///   base + 20px * (コメント数 - 1) でおおよその必要領域を見積もる。
  /// 実際のテキスト高さを完全に反映するわけではないが、
  /// 大量のコメント入力時でも最低限切り取られないだけの余白を確保できる。
  double _calculateCommentAreaHeight() {
    if (annotations.isEmpty) return _noCommentBottomMargin;

    const double baseHeight = 40.0; // 1 段目の想定高さ
    const double stepHeight = 20.0; // 衝突回避で 1 段深くするごとの増分

    final int layers = annotations.length - 1;
    final double estimated = baseHeight + stepHeight * layers;

    // コメントボックス高さの1.5倍程度の余白を確保
    final double expanded = estimated * 1.5;

    // 最低でも下限値は確保しつつ、ゆとりを持たせた値を返す
    return math.max(_minCommentAreaHeight, expanded);
  }

  final double chartMarginLeft = 16.0;
  final double chartMarginTop = 16.0;

  int? _startSignalIndex;
  int? _endSignalIndex;
  int? _startTimeIndex;
  int? _endTimeIndex;

  Offset? _lastRightClickPos;

  String? _selectedAnnotationId;

  Map<String, Rect> _annotationHitRects = {};
  // コメントボックスドラッグ用
  String? _draggingAnnotationId;
  Offset? _draggingStartLocal; // ドラッグ開始時のローカル座標
  Offset? _draggingInitialBoxTopLeft; // ドラッグ開始時のボックス位置

  Offset? _dragStartGlobal;

  // 描画用のキー
  final GlobalKey _customPaintKey = GlobalKey();
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  // スクロール制御
  final ScrollController _hScrollController = ScrollController();
  final ScrollController _vScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _idSignalNames = List.from(widget.initialSignalNames);
    signalNames = List.from(_idSignalNames); // 仮で ID 表示

    // 初期翻訳
    _translateNames();

    // 言語変更リスナー
    _langListener = () {
      _translateNames();
    };
    suggestionLanguageVersion.addListener(_langListener);

    signals =
        widget.initialSignals.map((list) => List<int>.from(list)).toList();
    annotations = List.from(widget.initialAnnotations);
  }

  // 信号データを更新するメソッド
  void updateSignals(List<List<int>> newSignals) {
    setState(() {
      signals = newSignals.map((list) => List<int>.from(list)).toList();
      _forceRepaint();
    });
  }

  // アノテーションを更新するメソッド
  void updateAnnotations(List<TimingChartAnnotation> newAnnotations) {
    setState(() {
      annotations = List.from(newAnnotations);
      _forceRepaint();
    });
  }

  // 信号名を更新するメソッド
  void updateSignalNames(List<String> newIdNames) {
    _idSignalNames = List.from(newIdNames);
    // まずは ID 表示に差し替えておき、翻訳後に再描画
    setState(() {
      signalNames = List.from(_idSignalNames);
      _forceRepaint();
    });
    _translateNames();
  }

  // ID → 現在言語ラベルへ変換して UI へ反映
  void _translateNames() async {
    final translated = await Future.wait(
      _idSignalNames.map((id) => labelOfId(id)),
    );
    if (!mounted) return;
    setState(() {
      signalNames = translated;
      _forceRepaint();
    });
  }

  // 現在の信号データを取得するメソッド
  List<List<int>> getChartData() {
    print('===== チャートデータ取得 =====');
    print('信号数: ${signals.length}');
    print('信号名: $signalNames');
    print('信号タイプ: ${widget.signalTypes}');

    List<List<int>> result = List.from(signals);
    print('返却するデータ行数: ${result.length}');
    if (result.isNotEmpty) {
      print('最初の行のデータ例: ${result[0].take(10)}...');
    }
    print('===== チャートデータ取得終了 =====');
    return result;
  }

  @override
  void didUpdateWidget(covariant TimingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.initialSignalNames, oldWidget.initialSignalNames) ||
        !_areSignalsEqual(widget.initialSignals, oldWidget.initialSignals) ||
        !_areAnnotationsEqual(
          widget.initialAnnotations,
          oldWidget.initialAnnotations,
        )) {
      setState(() {
        _idSignalNames = List.from(widget.initialSignalNames);
        signalNames = List.from(_idSignalNames); // 仮で ID 表示
        _translateNames();
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
    double adjustedX =
        dx -
        chartMarginLeft +
        (_hScrollController.hasClients ? _hScrollController.offset : 0);
    final relativeX = adjustedX - labelWidth;
    if (relativeX < 0) {
      return -1;
    }
    if (_cellWidth <= 0) return -1;
    return (relativeX / _cellWidth).floor();
  }

  int _getSignalIndexFromDy(double dy) {
    final adjustedY =
        dy -
        chartMarginTop +
        (_vScrollController.hasClients ? _vScrollController.offset : 0);
    if (_cellHeight <= 0) return -1;
    final index = (adjustedY / _cellHeight).floor();
    // 有効範囲は 0..length-1。範囲外は -1 を返す想定
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
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    final adjustedPos = Offset(
      localPos.dx -
          chartMarginLeft +
          (_hScrollController.hasClients ? _hScrollController.offset : 0),
      localPos.dy -
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

    // ラベル領域をクリックしているか判定
    final bool inLabelArea =
        localPos.dx >= chartMarginLeft &&
        localPos.dx <= chartMarginLeft + labelWidth;

    if (inLabelArea) {
      final row = _getSignalIndexFromDy(localPos.dy);
      if (row >= 0 && row < _visibleIndexes.length) {
        final originalRow = _visibleIndexes[row];
        final int maxTime =
            signals.isNotEmpty ? signals[originalRow].length - 1 : -1;
        if (maxTime >= 0) {
          setState(() {
            // すでに同じ行全体が選択されていた場合は選択解除
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
      return; // ラベルクリックでのビット反転は行わない
    }

    final clickSig = _getSignalIndexFromDy(localPos.dy);
    final clickTim = _getTimeIndexFromDx(localPos.dx);

    if (clickTim < 0 || clickSig < 0 || clickSig >= _visibleIndexes.length) {
      _clearSelection();
      return;
    }

    if (_hasValidSelection) {
      final stSigAbs = math.min(_startSignalIndex!, _endSignalIndex!);
      final edSigAbs = math.max(_startSignalIndex!, _endSignalIndex!);
      final stTimeAbs = math.min(_startTimeIndex!, _endTimeIndex!);
      final edTimeAbs = math.max(_startTimeIndex!, _endTimeIndex!);
      final selectionRectGlobal = Rect.fromLTWH(
        chartMarginLeft + labelWidth + (stTimeAbs * _cellWidth),
        chartMarginTop + (stSigAbs * _cellHeight).toDouble(),
        (edTimeAbs - stTimeAbs + 1) * _cellWidth,
        (edSigAbs - stSigAbs + 1) * _cellHeight,
      );

      if (selectionRectGlobal.contains(localPos)) {
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
            '信号を反転: 行=${originalRow}, 列=${time}, 新しい値=${signals[originalRow][time]}',
          );
          _highlightTimeIndices = [..._highlightTimeIndices];
          _forceRepaint();
        });
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);

    // 先にコメントボックスのヒットを判定（チャート領域外でもドラッグ可能にする）
    final adjustedPosForAnn = Offset(
      localPos.dx -
          chartMarginLeft +
          (_hScrollController.hasClients ? _hScrollController.offset : 0),
      localPos.dy -
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

    // --- ラベル領域でのドラッグ開始判定 ---
    final bool inLabelArea =
        (localPos.dx +
                (_hScrollController.hasClients
                    ? _hScrollController.offset
                    : 0)) >=
            chartMarginLeft &&
        (localPos.dx +
                (_hScrollController.hasClients
                    ? _hScrollController.offset
                    : 0)) <=
            chartMarginLeft + labelWidth;

    final sigIndex = _getSignalIndexFromDy(localPos.dy);
    if (inLabelArea && sigIndex >= 0 && sigIndex < _visibleIndexes.length) {
      // ラベルドラッグ開始
      setState(() {
        _isLabelDrag = true;
        _labelDragStartRow = sigIndex;
        _labelDragCurrentRow = sigIndex;
      });
      return; // selection 処理には入らない
    }

    if (localPos.dy > chartMarginTop + _visibleIndexes.length * _cellHeight) {
      _dragStartGlobal = null;
      return;
    }

    final sig = _getSignalIndexFromDy(localPos.dy);
    final tim = _getTimeIndexFromDx(localPos.dx);

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
    // コメントボックスのドラッグ更新
    if (_draggingAnnotationId != null &&
        _draggingStartLocal != null &&
        _draggingInitialBoxTopLeft != null) {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final localPos = box.globalToLocal(details.globalPosition);
      final adjustedPos = Offset(
        localPos.dx -
            chartMarginLeft +
            (_hScrollController.hasClients ? _hScrollController.offset : 0),
        localPos.dy -
            chartMarginTop +
            (_vScrollController.hasClients ? _vScrollController.offset : 0),
      );
      final delta = adjustedPos - _draggingStartLocal!;

      final annIndex = annotations.indexWhere(
        (a) => a.id == _draggingAnnotationId,
      );
      if (annIndex != -1) {
        final current = annotations[annIndex];
        // offsetX/offsetY はコメントの基準位置からの差分として扱う
        final newOffsetX = (current.offsetX ?? 0) + delta.dx;
        final newOffsetY = (current.offsetY ?? 0) + delta.dy;
        setState(() {
          annotations[annIndex] = current.copyWith(
            offsetX: newOffsetX,
            offsetY: newOffsetY,
          );
          _highlightTimeIndices = [..._highlightTimeIndices];
          _forceRepaint();
        });
        // 次回は差分をリセットするため、基準を更新
        _draggingStartLocal = adjustedPos;
        _draggingInitialBoxTopLeft = _draggingInitialBoxTopLeft! + delta;
      }
      return;
    }
    // ラベルドラッグ中は位置を追跡
    if (_isLabelDrag) {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final localPos = box.globalToLocal(details.globalPosition);
      int sig = _getSignalIndexFromDy(localPos.dy);
      sig = sig.clamp(0, _visibleIndexes.length - 1);
      if (sig != _labelDragCurrentRow) {
        setState(() {
          _labelDragCurrentRow = sig;
        });
      }
      return; // 既存の選択ドラッグは無視
    }

    if (_dragStartGlobal == null) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);

    final sig = _getSignalIndexFromDy(localPos.dy);
    final tim = _getTimeIndexFromDx(localPos.dx);

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
    // コメントドラッグ終了
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
        // ドラッグ後は選択状態・ハイライトもリセット
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

  // ロングプレスでのドラッグ（タッチデバイス向け）
  void _onLongPressStart(LongPressStartDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    final adjustedPos = Offset(
      localPos.dx -
          chartMarginLeft +
          (_hScrollController.hasClients ? _hScrollController.offset : 0),
      localPos.dy -
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
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    final adjustedPos = Offset(
      localPos.dx -
          chartMarginLeft +
          (_hScrollController.hasClients ? _hScrollController.offset : 0),
      localPos.dy -
          chartMarginTop +
          (_vScrollController.hasClients ? _vScrollController.offset : 0),
    );
    final delta = adjustedPos - _draggingStartLocal!;
    final annIndex = annotations.indexWhere(
      (a) => a.id == _draggingAnnotationId,
    );
    if (annIndex != -1) {
      final current = annotations[annIndex];
      final newOffsetX = (current.offsetX ?? 0) + delta.dx;
      final newOffsetY = (current.offsetY ?? 0) + delta.dy;
      setState(() {
        annotations[annIndex] = current.copyWith(
          offsetX: newOffsetX,
          offsetY: newOffsetY,
        );
        _highlightTimeIndices = [..._highlightTimeIndices];
        _forceRepaint();
      });
      _draggingStartLocal = adjustedPos;
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

    _lastRightClickPos = position;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(position);
    final adjustedPos = Offset(
      localPos.dx -
          chartMarginLeft +
          (_hScrollController.hasClients ? _hScrollController.offset : 0),
      localPos.dy -
          chartMarginTop +
          (_vScrollController.hasClients ? _vScrollController.offset : 0),
    );

    // クリックされたタイムインデックスを先に計算しておく
    final int clickedTime = _getTimeIndexFromDx(localPos.dx);

    // 行インデックス（可視行）とラベル領域判定を事前に計算
    final int clickedSig = _getSignalIndexFromDy(localPos.dy);

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
        final clickedTime = _getTimeIndexFromDx(localPos.dx);

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
        // 追加: 選択範囲を末尾に複製
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

    // マウス位置付近にメニューを配置するため、オーバーレイ全体を基準とした Rect を使用する
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
          print("selectedValue = $selectedValue");
          _insertZerosToSelection();
          break;
        case 'duplicate':
          print("selectedValue = $selectedValue");
          _duplicateRange();
          break;
        case 'selectAll':
          print("selectedValue = $selectedValue");
          _selectAllSignals();
          break;
        case 'delete':
          print("selectedValue = $selectedValue");
          _deleteRange();
          break;
        case 'addComment':
          print("selectedValue = $selectedValue");
          if (_hasValidSelection) {
            _showAddRangeCommentDialog();
          } else {
            _showAddCommentDialog();
          }
          break;
        case 'omit':
          print("selectedValue = $selectedValue");
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
        // 強制的に再描画をトリガーするためのダミー更新
        _highlightTimeIndices = [..._highlightTimeIndices];
        _forceRepaint();
      });
    }
  }

  Future<void> _showAddRangeCommentDialog() async {
    if (!_hasValidSelection) return;

    final int stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final int edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    String newComment = "";

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
          '範囲コメント追加: ID=${annId}, text=${newComment}, start=${stTime}, end=${edTime}',
        );
        annotations.add(newAnnotation);
        _forceRepaint();
        _clearSelection();
      });
    }
  }

  void _editComment(String annId) async {
    final ann = annotations.firstWhereOrNull((a) => a.id == annId);
    if (ann == null) return;

    String newText = ann.text;

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

    if (result == true && newText.isNotEmpty && newText != ann.text) {
      setState(() {
        final index = annotations.indexWhere((a) => a.id == annId);
        if (index != -1) {
          annotations[index] = ann.copyWith(text: newText);
        }
      });
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
  }

  void _duplicateRange() {
    if (!_hasValidSelection) return;

    // 選択範囲の信号インデックスと時刻インデックスを正規化
    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    // 選択された信号が可視範囲外の場合は処理しない
    if (stSig < 0 || edSig >= _visibleIndexes.length) return;

    // 追加: 末尾開始オフセットを計算しておく（コメント/省略記号複製用）
    final int oldMaxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).reduce(math.max);

    setState(() {
      for (int visibleRow = stSig; visibleRow <= edSig; visibleRow++) {
        final originalRow = _visibleIndexes[visibleRow];
        final maxTimeForRow = signals[originalRow].length - 1;
        final clampedStTime = stTime.clamp(0, maxTimeForRow);
        final clampedEdTime = edTime.clamp(0, maxTimeForRow);
        if (clampedStTime > clampedEdTime) continue;

        // 選択範囲のスライスを取得して末尾に追加
        final slice = signals[originalRow].sublist(
          clampedStTime,
          clampedEdTime + 1,
        );
        signals[originalRow].addAll(slice);
      }

      // ---------- アノテーションを複製 ----------
      final List<TimingChartAnnotation> duplicatedAnnotations = [];
      for (final ann in annotations) {
        final annStart = ann.startTimeIndex;
        final int annEnd = ann.endTimeIndex ?? annStart;

        // 選択範囲とアノテーションが交差しているか判定
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

      // ---------- 省略記号時刻インデックスを複製 ----------
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

  /// 指定した時刻インデックスの省略信号をトグル（追加/削除）
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // LayoutBuilder により親から渡された制約を取得し、
    // その範囲内でセルサイズを計算する。
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxLen =
              signals.isEmpty
                  ? 0
                  : signals.map((e) => e.length).fold(0, math.max);

          // 表示対象インデックスを抽出
          final visibleIndexes = <int>[];
          for (int i = 0; i < widget.signalTypes.length; i++) {
            final t = widget.signalTypes[i];
            if (widget.showAllSignalTypes ||
                (t != SignalType.control &&
                    t != SignalType.group &&
                    t != SignalType.task)) {
              visibleIndexes.add(i);
            }
          }

          // --- 横方向 ---
          final availableWidth =
              constraints.maxWidth.isFinite
                  ? constraints.maxWidth - chartMarginLeft - labelWidth
                  : MediaQuery.of(context).size.width -
                      chartMarginLeft -
                      labelWidth;

          if (widget.fitToScreen) {
            _cellWidth =
                maxLen > 0 ? math.max(availableWidth / maxLen, 5.0) : 40.0;
          } else {
            _cellWidth =
                maxLen > 0 ? math.max(availableWidth / maxLen, 20.0) : 40.0;
          }

          // ▼ コメントエリアの高さを動的に算出
          final double commentAreaHeight = _calculateCommentAreaHeight();

          // --- 縦方向 ---
          double constraintHeight =
              constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : MediaQuery.of(context).size.height;

          if (widget.fitToScreen) {
            final availableHeight =
                constraintHeight - chartMarginTop - commentAreaHeight;
            final visibleRowCount = visibleIndexes.length;
            if (visibleRowCount > 0) {
              _cellHeight = math.max(availableHeight / visibleRowCount, 5.0);
            }
          } else {
            _cellHeight = 40;
          }

          final double totalWidth =
              chartMarginLeft + labelWidth + maxLen * _cellWidth;
          final double totalHeight =
              chartMarginTop +
              visibleIndexes.length * _cellHeight +
              commentAreaHeight;

          // フィルタ済みリストを作成
          final visibleSignalNames = [
            for (final i in visibleIndexes) signalNames[i],
          ];
          final visibleSignals = [for (final i in visibleIndexes) signals[i]];
          final visibleSignalTypes = [
            for (final i in visibleIndexes) widget.signalTypes[i],
          ];
          final visiblePortNumbers = [
            for (final i in visibleIndexes) widget.portNumbers[i],
          ];

          _visibleIndexes = visibleIndexes;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final localPos = box.globalToLocal(details.globalPosition);
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
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: _onLongPressMoveUpdate,
            onLongPressEnd: _onLongPressEnd,
            onTapUp: _handleTap,
            onSecondaryTapDown:
                (details) => _showContextMenu(context, details.globalPosition),
            child: SingleChildScrollView(
              controller: _hScrollController,
              scrollDirection: Axis.horizontal,
              physics:
                  _draggingAnnotationId != null
                      ? const NeverScrollableScrollPhysics()
                      : null,
              child: SingleChildScrollView(
                controller: _vScrollController,
                scrollDirection: Axis.vertical,
                physics:
                    _draggingAnnotationId != null
                        ? const NeverScrollableScrollPhysics()
                        : null,
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
                      highlightTimeIndices: _highlightTimeIndices,
                      omissionTimeIndices: _omissionTimeIndices,
                      selectedAnnotationId: _selectedAnnotationId,
                      annotationRects: _annotationHitRects,
                      showAllSignalTypes: widget.showAllSignalTypes,
                      showIoNumbers: widget.showIoNumbers,
                      portNumbers: visiblePortNumbers,
                      labelColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                      dashedColor:
                          Theme.of(context).brightness == Brightness.dark &&
                                  Provider.of<SettingsNotifier>(
                                        context,
                                      ).commentDashedColor ==
                                      Colors.black
                              ? Colors.white
                              : Provider.of<SettingsNotifier>(
                                context,
                              ).commentDashedColor,
                      arrowColor:
                          Theme.of(context).brightness == Brightness.dark &&
                                  Provider.of<SettingsNotifier>(
                                        context,
                                      ).commentArrowColor ==
                                      Colors.black
                              ? Colors.white
                              : Provider.of<SettingsNotifier>(
                                context,
                              ).commentArrowColor,
                      omissionColor:
                          Theme.of(context).brightness == Brightness.dark &&
                                  Provider.of<SettingsNotifier>(
                                        context,
                                      ).omissionLineColor ==
                                      Colors.black
                              ? Colors.white
                              : Provider.of<SettingsNotifier>(
                                context,
                              ).omissionLineColor,
                      omissionFillColor:
                          Theme.of(context).scaffoldBackgroundColor,
                      signalColors:
                          Provider.of<SettingsNotifier>(context).signalColors,
                      draggingStartRow: _labelDragStartRow,
                      draggingCurrentRow: _labelDragCurrentRow,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 強制的に再描画をトリガーするメソッド
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

  /// チャート領域全体をJPEGとしてキャプチャして返す（背景色・品質指定）
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

      // まずPNGとして取得（RGBA）
      final ui.Image image = await boundary.toImage(pixelRatio: pr);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;

      final width = image.width;
      final height = image.height;
      final rgbaBytes = byteData.buffer.asUint8List();

      // 背景色を決定（未指定ならテーマから）
      final bg =
          backgroundColor ??
          (Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white);

      // RGBAを背景合成しつつRGBへ変換
      final int rBg = bg.red;
      final int gBg = bg.green;
      final int bBg = bg.blue;

      final Uint8List rgbBytes = Uint8List(width * height * 3);
      int si = 0; // source index
      int di = 0; // dest index
      for (int i = 0; i < width * height; i++) {
        final int r = rgbaBytes[si];
        final int g = rgbaBytes[si + 1];
        final int b = rgbaBytes[si + 2];
        final int a = rgbaBytes[si + 3];
        // aは0..255。アルファ合成: out = src * a + bg * (1 - a)
        final int outR = ((r * a + rBg * (255 - a)) / 255).round();
        final int outG = ((g * a + gBg * (255 - a)) / 255).round();
        final int outB = ((b * a + bBg * (255 - a)) / 255).round();
        rgbBytes[di] = outR;
        rgbBytes[di + 1] = outG;
        rgbBytes[di + 2] = outB;
        si += 4;
        di += 3;
      }

      // JPEGエンコード（package:image）
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

  void _invertSignal(int index) {
    print('===== 信号反転処理開始 =====');
    print('反転対象の信号インデックス: $index');
    print('反転前の信号名: ${signalNames[index]}');
    print('反転前の信号タイプ: ${widget.signalTypes[index]}');

    setState(() {
      // 信号値を反転
      for (int i = 0; i < signals[index].length; i++) {
        signals[index][i] = signals[index][i] == 0 ? 1 : 0;
      }

      // 信号名を更新
      String originalName = signalNames[index];
      if (originalName.startsWith('!')) {
        signalNames[index] = originalName.substring(1);
      } else {
        signalNames[index] = '!$originalName';
      }

      print('反転後の信号名: ${signalNames[index]}');
      print('反転後の信号タイプ: ${widget.signalTypes[index]}');
      print('反転後の信号値: ${signals[index].take(10)}...');
    });

    print('===== 信号反転処理終了 =====');
  }

  /// 現在のアノテーション一覧を取得
  List<TimingChartAnnotation> getAnnotations() => List.from(annotations);

  /// 現在チャートで表示されている信号 ID 順序を返す
  List<String> getSignalIdNames() => List.from(_idSignalNames);

  /// 省略信号(非表示区間)が描画されている時刻インデックス
  List<int> getOmissionTimeIndices() => List.from(_omissionTimeIndices);

  void setOmission(List<int> indices) {
    setState(() {
      _omissionTimeIndices = List<int>.from(indices);
      _forceRepaint();
    });
  }

  // 指定アノテーションの矢印先端を、可視行 index の水平中央に設定
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

  // ======== キーボードショートカット関連 ========
  late final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    suggestionLanguageVersion.removeListener(_langListener);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    // Ctrl + A (Mac では Meta + A) を検出
    final bool isModifierPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (isModifierPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
      _selectAllSignals();
    }
  }

  // すべての信号を選択する
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

  // ================= 行入れ替え =================
  void _moveSignal(int visibleIndex, int direction) {
    // direction -1: 上へ, 1: 下へ
    final int targetVisible = visibleIndex + direction;
    if (targetVisible < 0 || targetVisible >= _visibleIndexes.length) return;

    final int srcIdx = _visibleIndexes[visibleIndex];
    final int dstIdx = _visibleIndexes[targetVisible];

    setState(() {
      // --- 値をスワップ ---
      final tmpSignal = signals[srcIdx];
      signals[srcIdx] = signals[dstIdx];
      signals[dstIdx] = tmpSignal;

      final tmpName = signalNames[srcIdx];
      signalNames[srcIdx] = signalNames[dstIdx];
      signalNames[dstIdx] = tmpName;

      // widget.signalTypes は final だが List 自体は可変。
      final tmpType = widget.signalTypes[srcIdx];
      widget.signalTypes[srcIdx] = widget.signalTypes[dstIdx];
      widget.signalTypes[dstIdx] = tmpType;

      // ポート番号も同期して入れ替え
      if (widget.portNumbers.length > srcIdx &&
          widget.portNumbers.length > dstIdx) {
        final tmpPort = widget.portNumbers[srcIdx];
        widget.portNumbers[srcIdx] = widget.portNumbers[dstIdx];
        widget.portNumbers[dstIdx] = tmpPort;
      }

      // --- ID 順序も同期 ---
      final tmpId = _idSignalNames[srcIdx];
      _idSignalNames[srcIdx] = _idSignalNames[dstIdx];
      _idSignalNames[dstIdx] = tmpId;

      _forceRepaint();
    });
  }

  // -------- 行を任意位置へ移動 --------
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
/// 責務の分離に基づいて以下の3つのマネージャークラスを利用：
/// - ChartGridManager: グリッド線と信号名ラベルの描画
/// - ChartSignalsManager: デジタル信号波形と選択範囲の描画
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
    required this.labelColor,
    required this.dashedColor,
    required this.omissionColor,
    required this.omissionFillColor,
    required this.arrowColor,
    required this.signalColors,
    this.draggingStartRow,
    this.draggingCurrentRow,
  }) {
    // 各マネージャークラスを初期化
    _annotationsManager = ChartAnnotationsManager(
      annotations: annotations,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      labelWidth: labelWidth,
      highlightTimeIndices: highlightTimeIndices,
      selectedAnnotationId: selectedAnnotationId,
      dashedColor: dashedColor,
      arrowColor: arrowColor,
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
    );

    _signalsManager = ChartSignalsManager(
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      labelWidth: labelWidth,
      signalTypes: signalTypes,
      showAllSignalTypes: showAllSignalTypes,
      signalColors: signalColors,
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
  final Map<SignalType, Color> signalColors;

  // Colors
  final Color labelColor;
  final Color dashedColor;
  final Color omissionColor;
  final Color omissionFillColor;
  final Color arrowColor;

  // --- ラベルドラッグ用ハイライト ---
  final int? draggingStartRow;
  final int? draggingCurrentRow;

  // 各種マネージャーインスタンス
  late final ChartAnnotationsManager _annotationsManager;
  late final ChartGridManager _gridManager;
  late final ChartSignalsManager _signalsManager;

  @override
  void paint(Canvas canvas, Size size) {
    // 描画範囲幅（マージン部分を除いたエリア）
    final double drawAreaWidth = size.width - chartMarginLeft;

    debugPrint('\n=== TimingChart Paint Start ===');
    debugPrint('Canvas Size: $size');
    debugPrint('Chart Margin: Left=$chartMarginLeft, Top=$chartMarginTop');

    // 描画の開始点をオフセット
    canvas.save();
    canvas.translate(chartMarginLeft, chartMarginTop);
    debugPrint('Canvas translated by: ($chartMarginLeft, $chartMarginTop)');

    // signals, signalNames, signalTypesの長さはすべて一致している前提
    final rowCount = signals.length;

    // 0. ドラッグハイライト（背景）
    if (draggingStartRow != null) {
      final paintBg =
          Paint()
            ..color = Colors.yellow.withOpacity(0.25)
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
            ..color = Colors.blue.withOpacity(0.25)
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

    // 描画順序は背景から前景へ：
    debugPrint('\n1. Drawing signal labels');
    _gridManager.drawSignalLabels(canvas, rowCount);

    debugPrint('\n2. Drawing grid lines');
    final maxTimeSteps =
        signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);
    _gridManager.drawGridLines(canvas, size, rowCount, maxTimeSteps);

    debugPrint('\n3. Drawing highlighted time indices');
    _gridManager.drawHighlightedLines(canvas, highlightTimeIndices, size);

    debugPrint('\n4. Drawing signal waveforms');
    _signalsManager.drawSignalWaveforms(canvas, signals);

    debugPrint('\n4b. Drawing omission lines');
    _drawOmissionLines(canvas, rowCount);

    debugPrint('\n5. Drawing selection highlight');
    _signalsManager.drawSelectionHighlight(
      canvas,
      startSignalIndex,
      endSignalIndex,
      startTimeIndex,
      endTimeIndex,
    );

    debugPrint('\n6. Drawing annotations with boundary lines');
    _annotationsManager.drawAnnotations(canvas, size, rowCount);

    // アノテーションの当たり判定用Rectマップを更新
    annotationRects.clear();
    annotationRects.addAll(_annotationsManager.getAnnotationRects());

    canvas.restore();
    debugPrint('Canvas restored to original state');
    debugPrint('=== TimingChart Paint End ===\n');
  }

  /// 省略信号（波線）の描画
  void _drawOmissionLines(Canvas canvas, int rowCount) {
    if (omissionTimeIndices.isEmpty) return;

    final double chartBottom = rowCount * cellHeight;
    final paint =
        Paint()
          ..color = omissionColor
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

    for (final t in omissionTimeIndices) {
      final double x = labelWidth + t * cellWidth;
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
    // 最初に信号値の比較
    bool signalsChanged = signals.length != oldDelegate.signals.length;

    if (!signalsChanged) {
      // 各信号の長さと内容を比較
      for (int i = 0; i < signals.length; i++) {
        if (signals[i].length != oldDelegate.signals[i].length) {
          signalsChanged = true;
          break;
        }

        // ビット単位で比較して変更を検出
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
        portNumbers != oldDelegate.portNumbers;
  }
}
