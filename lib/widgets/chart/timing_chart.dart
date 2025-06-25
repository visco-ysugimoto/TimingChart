import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../models/chart/timing_chart_annotation.dart';
import '../../models/chart/signal_type.dart';
import 'chart_annotations.dart';
import 'chart_grid.dart';
import 'chart_signals.dart';

class TimingChart extends StatefulWidget {
  final List<String> initialSignalNames;
  final List<List<int>> initialSignals;
  final List<TimingChartAnnotation> initialAnnotations;
  final List<SignalType> signalTypes;

  const TimingChart({
    super.key,
    required this.initialSignalNames,
    required this.initialSignals,
    required this.initialAnnotations,
    required this.signalTypes,
  });

  @override
  State<TimingChart> createState() => TimingChartState();
}

class TimingChartState extends State<TimingChart>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late List<List<int>> signals;
  late List<String> signalNames;
  late List<TimingChartAnnotation> annotations;
  List<int> _highlightTimeIndices = [];
  List<int> _visibleIndexes = [];

  double _cellWidth = 40;
  final double cellHeight = 40;

  final double labelWidth = 200.0;
  final double commentAreaHeight = 100.0;
  final double chartMarginLeft = 16.0;
  final double chartMarginTop = 16.0;

  int? _startSignalIndex;
  int? _endSignalIndex;
  int? _startTimeIndex;
  int? _endTimeIndex;

  Offset? _lastRightClickPos;

  String? _selectedAnnotationId;

  Map<String, Rect> _annotationHitRects = {};

  Offset? _dragStartGlobal;

  // 描画用のキー
  final GlobalKey _customPaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    signalNames = List.from(widget.initialSignalNames);
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
  void updateSignalNames(List<String> newNames) {
    setState(() {
      signalNames = List.from(newNames);
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
        signalNames = List.from(widget.initialSignalNames);
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

  @override
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
        edSig < signals.length &&
        stTime >= 0 &&
        edTime <= maxTime;
  }

  @override
  int _getTimeIndexFromDx(double dx) {
    double adjustedX = dx - chartMarginLeft;
    final relativeX = adjustedX - labelWidth;
    if (relativeX < 0) {
      return -1;
    }
    if (_cellWidth <= 0) return -1;
    return (relativeX / _cellWidth).floor();
  }

  @override
  int _getSignalIndexFromDy(double dy) {
    final adjustedY = dy - chartMarginTop;
    if (cellHeight <= 0) return -1;
    final index = (adjustedY / cellHeight).floor();
    return index.clamp(-1, signals.length);
  }

  @override
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

  @override
  void _handleTap(TapDownDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    final adjustedPos = Offset(
      localPos.dx - chartMarginLeft,
      localPos.dy - chartMarginTop,
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

    final clickSig = _getSignalIndexFromDy(localPos.dy);
    final clickTim = _getTimeIndexFromDx(localPos.dx);

    if (clickTim < 0 || clickSig < 0 || clickSig >= signals.length) {
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
        chartMarginTop + (stSigAbs * cellHeight).toDouble(),
        (edTimeAbs - stTimeAbs + 1) * _cellWidth,
        (edSigAbs - stSigAbs + 1) * cellHeight,
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

  @override
  void _onPanStart(DragStartDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);

    if (localPos.dy > chartMarginTop + signals.length * cellHeight) {
      _dragStartGlobal = null;
      return;
    }

    final sig = _getSignalIndexFromDy(localPos.dy);
    final tim = _getTimeIndexFromDx(localPos.dx);

    if (tim < 0 || sig < 0 || sig >= signals.length) {
      _clearSelection();
      _dragStartGlobal = null;
      return;
    }

    final adjustedPos = Offset(
      localPos.dx - chartMarginLeft,
      localPos.dy - chartMarginTop,
    );
    for (final rect in _annotationHitRects.values) {
      if (rect.contains(adjustedPos)) {
        _dragStartGlobal = null;
        return;
      }
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

  @override
  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragStartGlobal == null) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);

    final sig = _getSignalIndexFromDy(localPos.dy);
    final tim = _getTimeIndexFromDx(localPos.dx);

    final clampedSig = sig.clamp(0, signals.length - 1);
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

  @override
  void _onPanEnd(DragEndDetails details) {
    if (_dragStartGlobal == null) return;

    if (_startSignalIndex == _endSignalIndex &&
        _startTimeIndex == _endTimeIndex) {
      _clearSelection();
    }

    setState(() {
      _dragStartGlobal = null;
    });
  }

  @override
  void _showContextMenu(BuildContext context, Offset position) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    _lastRightClickPos = position;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(position);
    final adjustedPos = Offset(
      localPos.dx - chartMarginLeft,
      localPos.dy - chartMarginTop,
    );

    String? hitAnnId;
    for (final entry in _annotationHitRects.entries) {
      if (entry.value.contains(adjustedPos)) {
        hitAnnId = entry.key;
        break;
      }
    }

    List<PopupMenuEntry<String>> menuItems = [];

    if (hitAnnId != null) {
      menuItems = [
        const PopupMenuItem(value: 'editComment', child: Text('コメントを編集')),
        const PopupMenuItem(value: 'deleteComment', child: Text('コメントを削除')),
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
        const PopupMenuItem(value: 'insert', child: Text('選択範囲に0を挿入')),
        const PopupMenuItem(value: 'delete', child: Text('選択範囲を削除')),
        const PopupMenuItem(value: 'addComment', child: Text('コメントを追加')),
      ];
    }

    final selectedValue = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, 0, 0),
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
        case 'insert':
          print("selectedValue = $selectedValue");
          _insertZerosToSelection();
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
      }
    }
  }

  @override
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
        return AlertDialog(
          title: const Text("コメントを追加"),
          content: TextField(
            autofocus: true,
            onChanged: (val) => newComment = val,
            decoration: const InputDecoration(hintText: "コメントを入力"),
            maxLines: null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("OK"),
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

  @override
  Future<void> _showAddRangeCommentDialog() async {
    if (!_hasValidSelection) return;

    final int stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final int edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    String newComment = "";

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("選択範囲にコメントを追加"),
          content: TextField(
            autofocus: true,
            onChanged: (val) => newComment = val,
            decoration: const InputDecoration(hintText: "コメントを入力"),
            maxLines: null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("OK"),
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

  @override
  void _editComment(String annId) async {
    final ann = annotations.firstWhereOrNull((a) => a.id == annId);
    if (ann == null) return;

    String newText = ann.text;
    bool changed = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: ann.text);
        return AlertDialog(
          title: const Text("コメントを編集"),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                newText = controller.text;
                Navigator.pop(ctx, true);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    if (result == true && newText.isNotEmpty && newText != ann.text) {
      setState(() {
        final index = annotations.indexWhere((a) => a.id == annId);
        if (index != -1) {
          annotations[index] = TimingChartAnnotation(
            id: ann.id,
            startTimeIndex: ann.startTimeIndex,
            endTimeIndex: ann.endTimeIndex,
            text: newText,
          );
          changed = true;
        }
      });
    }
  }

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  Rect _calcSelectionRectLocal() {
    if (!_hasValidSelection) return Rect.zero;

    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    return Rect.fromLTWH(
      labelWidth + (stTime * _cellWidth),
      (stSig * cellHeight).toDouble(),
      (edTime - stTime + 1) * _cellWidth,
      (edSig - stSig + 1) * cellHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final maxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);

    final availableWidth =
        MediaQuery.of(context).size.width - chartMarginLeft - labelWidth;
    _cellWidth = maxLen > 0 ? math.max(availableWidth / maxLen, 20.0) : 40.0;

    final double totalWidth =
        chartMarginLeft + labelWidth + maxLen * _cellWidth;
    final double totalHeight =
        chartMarginTop + signals.length * cellHeight + commentAreaHeight;

    // 表示対象インデックスを抽出
    final visibleIndexes = <int>[];
    for (int i = 0; i < widget.signalTypes.length; i++) {
      final t = widget.signalTypes[i];
      if (t != SignalType.control &&
          t != SignalType.group &&
          t != SignalType.task) {
        visibleIndexes.add(i);
      }
    }

    // フィルタ済みリストを作成
    final visibleSignalNames = [for (final i in visibleIndexes) signalNames[i]];
    final visibleSignals = [for (final i in visibleIndexes) signals[i]];
    final visibleSignalTypes = [
      for (final i in visibleIndexes) widget.signalTypes[i],
    ];

    _visibleIndexes = visibleIndexes;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTapDown: _handleTap,
      onSecondaryTapDown:
          (details) => _showContextMenu(context, details.globalPosition),
      child: RepaintBoundary(
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
            cellHeight: cellHeight,
            labelWidth: labelWidth,
            commentAreaHeight: commentAreaHeight,
            chartMarginLeft: chartMarginLeft,
            chartMarginTop: chartMarginTop,
            startSignalIndex: _startSignalIndex,
            endSignalIndex: _endSignalIndex,
            startTimeIndex: _startTimeIndex,
            endTimeIndex: _endTimeIndex,
            highlightTimeIndices: _highlightTimeIndices,
            selectedAnnotationId: _selectedAnnotationId,
            annotationRects: _annotationHitRects,
          ),
        ),
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
    required this.selectedAnnotationId,
    required this.annotationRects,
  }) {
    // 各マネージャークラスを初期化
    _annotationsManager = ChartAnnotationsManager(
      annotations: annotations,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      labelWidth: labelWidth,
      highlightTimeIndices: highlightTimeIndices,
      selectedAnnotationId: selectedAnnotationId,
    );

    _gridManager = ChartGridManager(
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      labelWidth: labelWidth,
      signalNames: signalNames,
      signalTypes: signalTypes,
    );

    _signalsManager = ChartSignalsManager(
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      labelWidth: labelWidth,
      signalTypes: signalTypes,
    );
  }

  final List<List<int>> signals;
  final List<String> signalNames;
  final List<SignalType> signalTypes;
  final List<TimingChartAnnotation> annotations;
  final List<int> highlightTimeIndices;

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

  // 各種マネージャーインスタンス
  late final ChartAnnotationsManager _annotationsManager;
  late final ChartGridManager _gridManager;
  late final ChartSignalsManager _signalsManager;

  @override
  void paint(Canvas canvas, Size size) {
    debugPrint('\n=== TimingChart Paint Start ===');
    debugPrint('Canvas Size: $size');
    debugPrint('Chart Margin: Left=$chartMarginLeft, Top=$chartMarginTop');

    // 描画の開始点をオフセット
    canvas.save();
    canvas.translate(chartMarginLeft, chartMarginTop);
    debugPrint('Canvas translated by: ($chartMarginLeft, $chartMarginTop)');

    // signals, signalNames, signalTypesの長さはすべて一致している前提
    final rowCount = signals.length;

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
        selectedAnnotationId != oldDelegate.selectedAnnotationId ||
        !listEquals(highlightTimeIndices, oldDelegate.highlightTimeIndices) ||
        startSignalIndex != oldDelegate.startSignalIndex ||
        endSignalIndex != oldDelegate.endSignalIndex ||
        startTimeIndex != oldDelegate.startTimeIndex ||
        endTimeIndex != oldDelegate.endTimeIndex;
  }
}
