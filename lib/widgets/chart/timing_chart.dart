import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/chart/timing_chart_annotation.dart';

enum SignalType { input, output, hwTrigger }

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
  State<TimingChart> createState() => _TimingChartState();
}

class _TimingChartState extends State<TimingChart>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late List<List<int>> signals;
  late List<String> signalNames;
  late List<TimingChartAnnotation> annotations;
  List<int> _highlightTimeIndices = [];

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

  @override
  void initState() {
    super.initState();
    signalNames = List.from(widget.initialSignalNames);
    signals =
        widget.initialSignals.map((list) => List<int>.from(list)).toList();
    annotations = List.from(widget.initialAnnotations);
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

  void _toggleSingleSignal(int sig, int time) {
    if (sig >= 0 &&
        sig < signals.length &&
        time >= 0 &&
        time < signals[sig].length) {
      setState(() {
        signals[sig][time] = (signals[sig][time] == 0) ? 1 : 0;
      });
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
        annotations.add(newAnnotation);
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
        annotations.add(newAnnotation);
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

    if (stSig < 0 || edSig >= signals.length) return;

    setState(() {
      for (int row = stSig; row <= edSig; row++) {
        final maxTimeForRow = signals[row].length - 1;
        final clampedStTime = stTime.clamp(0, maxTimeForRow);
        final clampedEdTime = edTime.clamp(0, maxTimeForRow);

        if (clampedStTime > clampedEdTime) continue;

        for (int t = clampedStTime; t <= clampedEdTime; t++) {
          signals[row][t] = (signals[row][t] == 0) ? 1 : 0;
        }
      }
    });
  }

  @override
  void _insertZerosToSelection() {
    if (!_hasValidSelection) return;

    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    if (stSig < 0 || edSig >= signals.length) return;

    final lengthToInsert = (edTime - stTime + 1);
    if (lengthToInsert <= 0) return;

    setState(() {
      for (int row = stSig; row <= edSig; row++) {
        final clampedStTime = stTime.clamp(0, signals[row].length);

        signals[row].insertAll(clampedStTime, List.filled(lengthToInsert, 0));
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

    if (stSig < 0 || edSig >= signals.length) return;

    setState(() {
      for (int row = stSig; row <= edSig; row++) {
        final maxTimeForRow = signals[row].length;
        final clampedStTime = stTime.clamp(0, maxTimeForRow);
        final clampedEdTime = (edTime + 1).clamp(0, maxTimeForRow);

        if (clampedStTime >= clampedEdTime) continue;

        signals[row].removeRange(clampedStTime, clampedEdTime);
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

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTapDown: _handleTap,
      onSecondaryTapDown:
          (details) => _showContextMenu(context, details.globalPosition),
      child: CustomPaint(
        size: Size(totalWidth, totalHeight),
        painter: _StepTimingChartPainter(
          signals: signals,
          signalNames: signalNames,
          signalTypes: widget.signalTypes,
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
    );
  }
}

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
  });

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
  static const double waveAmplitude = 10;

  final List<Rect> _placedArrowRects = [];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(chartMarginLeft, chartMarginTop);

    _drawSignalLabels(canvas, size);

    var paintLine = Paint()..strokeWidth = 2;

    for (int row = 0; row < signals.length; row++) {
      final rowData = signals[row];
      final yOffset = row * cellHeight + (cellHeight / 2);

      final currentSignalType =
          (row >= 0 && row < signalTypes.length)
              ? signalTypes[row]
              : SignalType.input;

      switch (currentSignalType) {
        case SignalType.input:
          paintLine =
              Paint()
                ..color = Colors.blue
                ..strokeWidth = 2;
          break;
        case SignalType.output:
          paintLine =
              Paint()
                ..color = Colors.red
                ..strokeWidth = 2;
          break;
        case SignalType.hwTrigger:
          paintLine =
              Paint()
                ..color = Colors.green
                ..strokeWidth = 2;
          break;
      }

      for (int t = 0; t < rowData.length - 1; t++) {
        final currentValue = rowData[t];
        final nextValue = rowData[t + 1];

        final xStart = labelWidth + t * cellWidth;
        final xEnd = labelWidth + (t + 1) * cellWidth;

        final yCurrent =
            (currentValue == 1) ? (yOffset - waveAmplitude) : yOffset;
        final yNext = (nextValue == 1) ? (yOffset - waveAmplitude) : yOffset;

        canvas.drawLine(
          Offset(xStart, yCurrent),
          Offset(xEnd, yCurrent),
          paintLine,
        );

        if (currentValue != nextValue) {
          canvas.drawLine(
            Offset(xEnd, yCurrent),
            Offset(xEnd, yNext),
            paintLine,
          );
        }
      }
      if (rowData.isNotEmpty) {
        final lastIndex = rowData.length - 1;
        final lastValue = rowData[lastIndex];
        final xStart = labelWidth + lastIndex * cellWidth;
        final xEnd = labelWidth + (lastIndex + 1) * cellWidth;
        final yLast = (lastValue == 1) ? (yOffset - waveAmplitude) : yOffset;
        canvas.drawLine(Offset(xStart, yLast), Offset(xEnd, yLast), paintLine);
      }
    }

    if (startSignalIndex != null &&
        endSignalIndex != null &&
        startTimeIndex != null &&
        endTimeIndex != null) {
      final stSig = math.min(startSignalIndex!, endSignalIndex!);
      final edSig = math.max(startSignalIndex!, endSignalIndex!);
      final stTime = math.min(startTimeIndex!, endTimeIndex!);
      final edTime = math.max(startTimeIndex!, endTimeIndex!);

      final selectionRect = Rect.fromLTWH(
        labelWidth + stTime * cellWidth,
        stSig * cellHeight,
        (edTime - stTime + 1) * cellWidth,
        (edSig - stSig + 1) * cellHeight,
      );

      final paintSelection =
          Paint()
            ..color = Colors.blue.withOpacity(0.2)
            ..style = PaintingStyle.fill;

      canvas.drawRect(selectionRect, paintSelection);
    }

    final paintGuide =
        Paint()
          ..color = Colors.grey.withOpacity(0.5)
          ..strokeWidth = 1;
    final paintHighlight =
        Paint()
          ..color = Colors.redAccent
          ..strokeWidth = 2;

    final maxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);

    final commentTimeIndices = annotations.map((a) => a.startTimeIndex).toSet();

    for (int i = 0; i <= maxLen; i++) {
      final x = labelWidth + i * cellWidth;
      final paintToUse =
          highlightTimeIndices.contains(i) ? paintHighlight : paintGuide;

      if (highlightTimeIndices.contains(i)) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height - commentAreaHeight),
          paintToUse,
        );
      } else if (!commentTimeIndices.contains(i)) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height - commentAreaHeight),
          paintGuide,
        );
      }
    }

    final chartBottomY = signals.length * cellHeight;
    _drawAnnotationsAndBoundaries(canvas, size, chartBottomY);

    canvas.restore();
  }

  void _drawSignalLabels(Canvas canvas, Size size) {
    for (int row = 0; row < signals.length; row++) {
      final name = (row < signalNames.length) ? signalNames[row] : "";
      final textSpan = TextSpan(
        text: name,
        style: const TextStyle(color: Colors.black, fontSize: 14),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      );
      textPainter.layout(maxWidth: labelWidth - 8.0 * 2);

      final yCenter = row * cellHeight + (cellHeight - textPainter.height) / 2;
      final offset = Offset(6, yCenter);
      textPainter.paint(canvas, offset);
    }
  }

  void _drawAnnotationsAndBoundaries(
    Canvas canvas,
    Size size,
    double chartBottomY,
  ) {
    annotationRects.clear();
    final double baseCommentY = chartBottomY + 20;

    if (annotations.isEmpty) {
      return;
    }

    final sortedAnnotations = [...annotations];
    sortedAnnotations.sort((a, b) {
      final startCompare = a.startTimeIndex.compareTo(b.startTimeIndex);
      if (startCompare != 0) return startCompare;
      if (a.endTimeIndex == null && b.endTimeIndex != null) return -1;
      if (a.endTimeIndex != null && b.endTimeIndex == null) return 1;
      if (a.endTimeIndex != null && b.endTimeIndex != null) {
        return a.endTimeIndex!.compareTo(b.endTimeIndex!);
      }
      return 0;
    });

    final List<Rect> placedCommentRects = [];
    _placedArrowRects.clear();

    for (final ann in sortedAnnotations) {
      double commentX, commentY;
      Rect commentRect;
      Rect? arrowRect;

      final textSpan = TextSpan(
        text: ann.text,
        style: const TextStyle(color: Colors.black, fontSize: 14),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '...',
        textAlign: TextAlign.left,
      );
      textPainter.layout(maxWidth: 120);
      final textWidth = textPainter.width;
      final textHeight = textPainter.height;
      final boxWidth = textWidth + 10;
      final boxHeight = textHeight + 10;

      if (ann.endTimeIndex != null) {
        double arrowBaseY = chartBottomY + 10;
        final double arrowStartX = labelWidth + ann.startTimeIndex * cellWidth;
        final double arrowEndX =
            labelWidth + (ann.endTimeIndex! + 1) * cellWidth;
        const double arrowThickness = 4;
        Rect currentArrowRect = Rect.fromLTWH(
          arrowStartX,
          arrowBaseY - arrowThickness / 2,
          arrowEndX - arrowStartX,
          arrowThickness,
        );

        int attempts = 0;
        while ((_placedArrowRects.any((r) => r.overlaps(currentArrowRect)) ||
                _isArrowOverlappingCommentBoxes(
                  currentArrowRect,
                  placedCommentRects,
                )) &&
            attempts < 15) {
          arrowBaseY += 20;
          currentArrowRect = Rect.fromLTWH(
            arrowStartX,
            arrowBaseY - arrowThickness / 2,
            arrowEndX - arrowStartX,
            arrowThickness,
          );
          attempts++;
        }
        arrowRect = currentArrowRect;
        _placedArrowRects.add(arrowRect);

        commentY = arrowRect.bottom + 5;
        commentX = arrowRect.center.dx - boxWidth / 2;
        commentRect = Rect.fromLTWH(commentX, commentY, boxWidth, boxHeight);
      } else {
        commentY = baseCommentY;
        commentX =
            labelWidth +
            ann.startTimeIndex * cellWidth +
            cellWidth / 2 -
            boxWidth / 2;
        commentRect = Rect.fromLTWH(commentX, commentY, boxWidth, boxHeight);
      }

      int attempts = 0;
      while (placedCommentRects.any((r) => r.overlaps(commentRect)) &&
          attempts < 15) {
        commentY += 20;
        commentRect = Rect.fromLTWH(commentX, commentY, boxWidth, boxHeight);
        attempts++;
      }
      placedCommentRects.add(commentRect);
      annotationRects[ann.id] = commentRect;

      final isSelected = selectedAnnotationId == ann.id;
      final paintBg =
          Paint()
            ..color = isSelected ? Colors.yellow.withOpacity(0.3) : Colors.white
            ..style = PaintingStyle.fill;
      final paintBorder =
          Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 2.0 : 1.0;
      canvas.drawRect(commentRect, paintBg);
      canvas.drawRect(commentRect, paintBorder);
      textPainter.paint(canvas, commentRect.topLeft.translate(4, 4));

      if (arrowRect != null) {
        final paintArrowLine =
            Paint()
              ..color = Colors.blue
              ..strokeWidth = 4;
        final startPt = Offset(arrowRect.left, arrowRect.center.dy);
        final endPt = Offset(arrowRect.right, arrowRect.center.dy);
        canvas.drawLine(startPt, endPt, paintArrowLine);
        const double headLength = 8;
        _drawArrowhead(canvas, startPt, math.pi, headLength, paintArrowLine);
        _drawArrowhead(canvas, endPt, 0, headLength, paintArrowLine);
      }

      final Rect? foundArrowRect = _placedArrowRects.firstWhereOrNull(
        (ar) => ar.left == labelWidth + ann.startTimeIndex * cellWidth,
      );
      if (foundArrowRect != null) {
        drawDashedLine(
          canvas,
          Offset(commentRect.center.dx, commentRect.bottom),
          Offset(foundArrowRect.center.dx, foundArrowRect.top),
          Paint()..color = Colors.black,
          dashWidth: 2,
          dashSpace: 2,
        );
      }
    }

    final Paint boundaryPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.7)
          ..strokeWidth = 1;
    final double dashWidth = 5;
    final double dashSpace = 3;

    for (final ann in annotations) {
      final Rect? commentRect = annotationRects[ann.id];
      if (commentRect == null) continue;

      final double startX = labelWidth + ann.startTimeIndex * cellWidth;
      final double boundaryEndY = commentRect.top;

      drawDashedLine(
        canvas,
        Offset(startX, 0),
        Offset(startX, boundaryEndY),
        boundaryPaint,
        dashWidth: dashWidth,
        dashSpace: dashSpace,
      );

      if (ann.endTimeIndex != null) {
        final double endX = labelWidth + (ann.endTimeIndex! + 1) * cellWidth;
        drawDashedLine(
          canvas,
          Offset(endX, 0),
          Offset(endX, boundaryEndY),
          boundaryPaint,
          dashWidth: dashWidth,
          dashSpace: dashSpace,
        );
        final Rect? arrowRect = _placedArrowRects.firstWhereOrNull(
          (ar) => ar.left == startX,
        );
        if (arrowRect != null) {
          drawDashedLine(
            canvas,
            commentRect.center.translate(0, commentRect.height / 2),
            Offset(arrowRect.center.dx, arrowRect.top),
            boundaryPaint,
            dashWidth: 2,
            dashSpace: 2,
          );
        }
      } else {
        final double cellCenterX = startX + cellWidth / 2;
        drawDashedLine(
          canvas,
          Offset(commentRect.center.dx, commentRect.top),
          Offset(cellCenterX, 0),
          boundaryPaint,
          dashWidth: dashWidth,
          dashSpace: dashSpace,
        );
      }
    }
  }

  bool _isArrowOverlappingCommentBoxes(
    Rect arrowRect,
    List<Rect> commentBoxes,
  ) {
    for (final boxRect in commentBoxes) {
      final bool horizontalOverlap =
          !(arrowRect.right < boxRect.left || arrowRect.left > boxRect.right);
      final bool verticalOverlap =
          !(arrowRect.bottom < boxRect.top || arrowRect.top > boxRect.bottom);
      if (horizontalOverlap && verticalOverlap) {
        return true;
      }
    }
    return false;
  }

  void _drawArrowhead(
    Canvas canvas,
    Offset tip,
    double angle,
    double length,
    Paint paint,
  ) {
    final leftEnd = Offset(
      tip.dx - length * math.cos(angle - math.pi / 6),
      tip.dy - length * math.sin(angle - math.pi / 6),
    );
    final rightEnd = Offset(
      tip.dx - length * math.cos(angle + math.pi / 6),
      tip.dy - length * math.sin(angle + math.pi / 6),
    );
    canvas.drawLine(tip, leftEnd, paint);
    canvas.drawLine(tip, rightEnd, paint);
  }

  void drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashWidth = 5,
    double dashSpace = 3,
  }) {
    if ((start - end).distance < 0.1) return;

    final totalDistance = (end - start).distance;
    final patternLength = dashWidth + dashSpace;
    if (patternLength <= 0) return;

    final dashCount = (totalDistance / patternLength).floor();
    final Offset delta = end - start;
    final Offset dashVector = delta * (dashWidth / totalDistance);
    final Offset spaceVector = delta * (dashSpace / totalDistance);

    Offset currentPoint = start;
    for (int i = 0; i < dashCount; i++) {
      final nextPoint = currentPoint + dashVector;
      canvas.drawLine(currentPoint, nextPoint, paint);
      currentPoint = nextPoint + spaceVector;
    }
    final remainingDistance = (end - currentPoint).distance;
    if (remainingDistance > 0.1) {
      canvas.drawLine(currentPoint, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StepTimingChartPainter oldDelegate) {
    return true;
  }
}
