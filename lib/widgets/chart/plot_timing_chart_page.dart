// lib/timing_chart.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// コメント(アノテーション)を管理するクラス
class TimingChartAnnotation {
  final String id;
  final int startTimeIndex;
  final int? endTimeIndex;
  String text;

  TimingChartAnnotation({
    required this.id,
    required this.startTimeIndex,
    required this.endTimeIndex,
    required this.text,
  });
}

class TimingChartPage extends StatefulWidget {
  final List<String> initialSignalNames;
  final List<List<int>> initialSignals;
  final List<TimingChartAnnotation> initialAnnotations;

  final List<SignalType> signalTypes;

  const TimingChartPage({
    super.key,
    required this.initialSignalNames,
    required this.initialSignals,
    required this.initialAnnotations,
    required this.signalTypes,
  });

  @override
  State<TimingChartPage> createState() => _TimingChartPageState();
}

class _TimingChartPageState extends State<TimingChartPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // 0/1のデジタル信号: 行(=1信号)、列がtimeIndex
  late List<List<int>> signals;
  late List<String> signalNames;
  late List<TimingChartAnnotation> annotations;
  // ハイライト対象のtimeIndexを保持する
  List<int> _highlightTimeIndices = [];

  @override
  void initState() {
    super.initState();
    // フォームから渡されたデータをコピーして初期化
    signalNames = List.from(widget.initialSignalNames);
    signals =
        widget.initialSignals.map((list) => List<int>.from(list)).toList();
    annotations = List.from(widget.initialAnnotations);
  }

  @override
  void didUpdateWidget(covariant TimingChartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // もし widget のデータが更新されたなら、State のデータを更新する
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

  // signals の比較用
  bool _areSignalsEqual(List<List<int>> a, List<List<int>> b) {
    if (a.length != b.length) return false;
    return a.asMap().entries.every(
      (entry) => entry.key < b.length && listEquals(entry.value, b[entry.key]),
    );
  }

  // annotations の比較用
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

  // チャート表示用のセルサイズ
  double _cellWidth = 40;
  final double cellHeight = 40;

  // 信号名を描画するための横幅 (ラベル用スペース)
  final double labelWidth = 200.0;
  // 下部コメント表示領域の高さ
  final double commentAreaHeight = 100.0;
  // 画面の左、上余白
  final double chartMarginLeft = 16.0;
  final double chartMarginTop = 16.0;

  // ドラッグによる選択範囲 (行/列)
  int? _startSignalIndex;
  int? _endSignalIndex;
  int? _startTimeIndex;
  int? _endTimeIndex;

  // 「今どのコメントが選択されているか」を管理
  String? _selectedAnnotationId;
  // コメントごとの当たり判定Rect
  // Painterで計算し、Stateで参照する
  Map<String, Rect> _annotationHitRects = {};

  // ドラッグ開始時点(グローバル座標)
  Offset? _dragStartGlobal;
  // 追加: 右クリックしたときの座標を保持しておき、「コメント追加」時に利用
  Offset? _lastRightClickPos;

  /// 選択範囲が有効かどうか
  bool get _hasValidSelection {
    if (_startSignalIndex == null ||
        _endSignalIndex == null ||
        _startTimeIndex == null ||
        _endTimeIndex == null) {
      return false;
    }

    // 効率化: 簡潔な条件チェック
    return signals.isNotEmpty &&
        math.min(_startSignalIndex!, _endSignalIndex!) >= 0 &&
        math.max(_startSignalIndex!, _endSignalIndex!) < signals.length;
  }

  /// 選択範囲をリセットしてハイライト解除
  void _clearSelection() {
    setState(() {
      _startSignalIndex = null;
      _endSignalIndex = null;
      _startTimeIndex = null;
      _endTimeIndex = null;
    });
  }

  // ============ マウス(ドラッグ)操作 ============ //

  /// ドラッグ開始
  void _onPanStart(DragStartDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    // 余白分を引く（y方向も補正）
    final adjustedX =
        localPos.dx; // _getTimeIndexFromDx 内で chartMarginLeft を差し引くのでそのままでOK
    final adjustedY = localPos.dy - chartMarginTop;

    final sig = (adjustedY ~/ cellHeight);
    final tim = _getTimeIndexFromDx(localPos.dx); // この関数内で chartMarginLeft を考慮
    setState(() {
      _dragStartGlobal = details.globalPosition;
      _startSignalIndex = sig;
      _endSignalIndex = sig;
      _startTimeIndex = tim;
      _endTimeIndex = tim;
    });
  }

  /// ドラッグ中
  void _onPanUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    final adjustedY = localPos.dy - chartMarginTop;

    final sig = (adjustedY ~/ cellHeight);
    final tim = _getTimeIndexFromDx(localPos.dx);
    setState(() {
      _endSignalIndex = sig;
      _endTimeIndex = tim;
    });
  }

  /// ドラッグ終了
  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _dragStartGlobal = null;
    });
  }

  // ============ クリック(左)操作 ============ //

  /// 左クリック (タップダウン)
  void _onTapDown(TapDownDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    // 余白分（左と上）を引いて、描画側と同じ座標系に合わせる
    final adjustedPos = Offset(
      localPos.dx - chartMarginLeft,
      localPos.dy - chartMarginTop,
    );
    final adjustedY = localPos.dy - chartMarginTop;

    // クリックした行の判定（余白分を引いて計算）
    final clickSig = (adjustedY ~/ cellHeight);
    final clickTim = _getTimeIndexFromDx(localPos.dx);

    // (1) まずコメントにヒットしているか調べる
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
      // コメント上をクリックした → 選択状態にする
      setState(() {
        _selectedAnnotationId = hitAnnId;
      });
      // 範囲選択はしない(コメント操作を優先)
      return;
    } else {
      // コメント以外クリック → コメント選択解除
      setState(() {
        _selectedAnnotationId = null;
      });
    }

    if (_hasValidSelection) {
      // すでに選択範囲がある場合
      final rect = _calcSelectionRect(); // 選択範囲のRect
      if (rect.contains(localPos)) {
        // 範囲内 → 選択範囲のすべてを反転
        _toggleSignalsInSelection();
        // 必要に応じて選択解除するならここで _clearSelection();
      } else {
        // 範囲外 → 選択解除
        _clearSelection();
      }
    } else {
      // 選択範囲が無い場合 → クリックしたマスだけ反転
      if (clickSig >= 0 &&
          clickSig < signals.length &&
          clickTim >= 0 &&
          clickTim < signals[clickSig].length) {
        setState(() {
          signals[clickSig][clickTim] =
              (signals[clickSig][clickTim] == 0) ? 1 : 0;
        });
      }
    }
  }

  // ============ 右クリック(コンテキストメニュー) ============ //

  /// 右クリック→メニュー表示
  void _onSecondaryTapDown(TapDownDetails details) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final tapPosition = details.globalPosition;
    // 右クリック位置を保存
    _lastRightClickPos = tapPosition;
    final localPos = box.globalToLocal(_lastRightClickPos!);
    // 余白分（左と上）を引いて、描画側と同じ座標系に合わせる
    final adjustedPos = Offset(
      localPos.dx - chartMarginLeft,
      localPos.dy - chartMarginTop,
    );

    // (1) まずコメントヒット判定
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
      // コメント上を右クリック → 「編集」「削除」メニュー
      final selectedValue = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          _lastRightClickPos!.dx,
          _lastRightClickPos!.dy,
          0,
          0,
        ),
        items: [
          const PopupMenuItem(value: 'editComment', child: Text('コメントを編集')),
          const PopupMenuItem(value: 'deleteComment', child: Text('コメントを削除')),
        ],
      );
      if (selectedValue == 'editComment') {
        _editComment(hitAnnId);
      } else if (selectedValue == 'deleteComment') {
        _deleteComment(hitAnnId);
      }
      return;
    }

    // 1) 右クリック時点でハイライト対象を更新
    setState(() {
      _highlightTimeIndices.clear();

      final localPos = box.globalToLocal(_lastRightClickPos!);
      final clickedTime = _getTimeIndexFromDx(localPos.dx);

      if (_hasValidSelection) {
        // 範囲選択中 → 両端のtimeIndexをハイライト
        final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
        final edTime = math.max(_startTimeIndex!, _endTimeIndex!);
        _highlightTimeIndices.add(stTime);
        _highlightTimeIndices.add(edTime + 1);
      } else {
        // 範囲選択なし → 単一timeIndexだけ
        if (clickedTime >= 0) {
          _highlightTimeIndices.add(clickedTime);
        }
      }
    });

    final selectedValue = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(tapPosition.dx, tapPosition.dy, 0, 0),
      items: [
        const PopupMenuItem(value: 'insert', child: Text('選択範囲に0を挿入')),
        const PopupMenuItem(value: 'delete', child: Text('選択範囲を削除')),
        // コメントを付けるメニュー
        const PopupMenuItem(value: 'addComment', child: Text('コメントを追加')),
      ],
    );

    // メニューが閉じたらハイライトを解除
    setState(() {
      _highlightTimeIndices.clear();
    });

    if (selectedValue != null) {
      switch (selectedValue) {
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

  // ----------------------------------------
  // コメント編集/削除
  // ----------------------------------------
  void _editComment(String annId) async {
    final ann = annotations.firstWhereOrNull((a) => a.id == annId);
    if (ann == null) return;

    String newText = ann.text;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("コメントを編集"),
          content: TextField(
            controller: TextEditingController(text: ann.text),
            onChanged: (val) => newText = val,
            maxLines: null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    if (newText.isNotEmpty && newText != ann.text) {
      setState(() {
        ann.text = newText;
      });
    }
  }

  void _deleteComment(String annId) {
    setState(() {
      annotations.removeWhere((a) => a.id == annId);
      if (_selectedAnnotationId == annId) {
        _selectedAnnotationId = null;
      }

      // コメント削除後に強制的に再描画を実行する
      // 1. 一時的にハイライトを設定して画面の変更を強制
      _highlightTimeIndices.add(0); // ダミーのハイライト

      // 次の描画サイクルでハイライトをクリア
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _highlightTimeIndices.clear();
          });
        }
      });
    });

    debugPrint('コメントを削除しました: $annId');
  }

  /// signals 全体の中で最大の長さを計算し、
  /// 短い行には末尾に 0 を追加して長さを揃える
  void _normalizeSignalLengths() {
    final maxLen = signals.map((r) => r.length).fold<int>(0, math.max);
    for (var row in signals) {
      final diff = maxLen - row.length;
      if (diff > 0) {
        row.addAll(List.filled(diff, 0));
      }
    }
  }

  // ============ 選択範囲の操作(反転・挿入・削除) ============ //

  /// 選択範囲(複数行×複数列)を全て反転
  void _toggleSignalsInSelection() {
    if (!_hasValidSelection) return;

    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    setState(() {
      for (int row = stSig; row <= edSig; row++) {
        if (row < 0 || row >= signals.length) continue;
        for (int t = stTime; t <= edTime; t++) {
          if (t >= 0 && t < signals[row].length) {
            signals[row][t] = (signals[row][t] == 0) ? 1 : 0;
          }
        }
      }
    });
  }

  /// 選択範囲に0を挿入
  void _insertZerosToSelection() {
    if (!_hasValidSelection) return;

    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    final lengthToInsert = (edTime - stTime + 1);

    setState(() {
      for (int row = stSig; row <= edSig; row++) {
        if (row < 0 || row >= signals.length) continue;
        // 挿入位置がリスト範囲外ならスキップ
        if (stTime < 0 || stTime > signals[row].length) continue;
        signals[row].insertAll(stTime, List.filled(lengthToInsert, 0));
      }
      _normalizeSignalLengths();
    });
  }

  /// 選択範囲を削除
  void _deleteRange() {
    if (!_hasValidSelection) return;

    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    final lengthToRemove = (edTime - stTime + 1);

    setState(() {
      for (int row = stSig; row <= edSig; row++) {
        if (row < 0 || row >= signals.length) continue;
        // 配列の範囲チェックを追加
        if (stTime < 0 || stTime >= signals[row].length) continue;

        final removeEnd = math.min(
          stTime + lengthToRemove,
          signals[row].length,
        );
        // 削除範囲が有効かチェック
        if (removeEnd <= signals[row].length) {
          signals[row].removeRange(stTime, removeEnd);
        }
      }
      _normalizeSignalLengths();
    });
  }

  // ============ コメントを追加するダイアログ ============ //

  Future<void> _showAddCommentDialog() async {
    if (_lastRightClickPos == null) return;

    // グローバル座標→ローカル座標へ
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(_lastRightClickPos!);

    // timeIndex 計算
    final tIndex = _getTimeIndexFromDx(localPos.dx);
    if (tIndex < 0) {
      // labelWidthより左側(信号名領域)の場合はコメント付けない
      return;
    }

    // ダイアログ表示用の変数
    String newComment = "";
    bool isConfirmed = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("コメントを追加"),
          content: TextField(
            onChanged: (val) => newComment = val,
            decoration: const InputDecoration(hintText: "コメントを入力"),
            maxLines: null,
          ),
          actions: [
            TextButton(
              onPressed: () {
                // キャンセルの場合は確認フラグを立てない
                Navigator.pop(ctx);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                // OKボタンクリック時のみ確認フラグを立てる
                isConfirmed = true;
                Navigator.pop(ctx);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    // ダイアログ閉じた後、OKボタンが押され、かつ文字列が入力されていれば追加
    if (isConfirmed && newComment.isNotEmpty) {
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

  Future<void> _showAddRangeCommentDialog() async {
    if (!_hasValidSelection) return;

    // 選択範囲から、開始・終了の timeIndex を計算
    final int stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final int edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    String newComment = "";
    bool isConfirmed = false;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("コメントを追加"),
          content: TextField(
            onChanged: (val) => newComment = val,
            decoration: const InputDecoration(hintText: "コメントを入力"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // キャンセルの場合は確認フラグを立てない
                Navigator.pop(ctx);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                // OKボタンクリック時のみ確認フラグを立てる
                isConfirmed = true;
                Navigator.pop(ctx);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    if (isConfirmed && newComment.isNotEmpty) {
      final annId = "ann${DateTime.now().millisecondsSinceEpoch}";
      // 範囲コメントとして、startTimeIndex と endTimeIndex を設定
      final newAnnotation = TimingChartAnnotation(
        id: annId,
        startTimeIndex: stTime,
        endTimeIndex: edTime,
        text: newComment,
      );

      setState(() {
        annotations.add(newAnnotation);
        // 必要に応じて、選択範囲のリセットなども行う
        _clearSelection();
      });
    }
  }

  // ============ ユーティリティ ============ //

  /// X座標から timeIndex を求める (左に labelWidth のオフセット)
  int _getTimeIndexFromDx(double dx) {
    double adjustedX = dx - chartMarginLeft;
    final relativeX = adjustedX - labelWidth;
    if (relativeX < 0) {
      // ラベル部分をクリックした場合は -1 とする
      return -1;
    }
    return (relativeX / _cellWidth).floor();
  }

  /// 選択範囲のRect (Painter側と同じ計算)
  Rect _calcSelectionRect() {
    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    return Rect.fromLTWH(
      chartMarginLeft + labelWidth + (stTime * _cellWidth),
      chartMarginTop + (stSig * cellHeight).toDouble(),
      (edTime - stTime + 1) * _cellWidth,
      (edSig - stSig + 1) * cellHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 画面の幅やパディングを考慮して、利用可能な幅を計算
    final availableWidth =
        MediaQuery.of(context).size.width - chartMarginLeft - labelWidth;
    // キャンバスの幅: ラベル幅 + 各行の最大長さ × cellWidth
    final maxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).reduce(math.max);
    // 信号の最大セル数
    // セル幅は、利用可能な幅をセル数で割る（ただし最小値を設定）
    final double cellWidth =
        maxLen > 0 ? math.max(availableWidth / maxLen, 20.0) : 40.0;
    final double cellHeight = 40;
    _cellWidth = cellWidth;

    final double totalWidth = chartMarginLeft + labelWidth + maxLen * cellWidth;
    final double totalHeight =
        chartMarginTop + signals.length * cellHeight + commentAreaHeight;
    //final List<SignalType> signalTypes = widget.signalTypes;

    return GestureDetector(
      // ドラッグで範囲選択
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,

      // 左クリック
      onTapDown: _onTapDown,

      // 右クリック
      onSecondaryTapDown: _onSecondaryTapDown,

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
          chartMarginLeft: chartMarginLeft,
          chartMarginTop: chartMarginTop,
          commentAreaHeight: commentAreaHeight,
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

  void _onTabChanged(int index) {
    print('===== タブ切り替え処理開始 =====');
    print('切り替え前のタブ: ${widget.initialSignalNames}');
    print('切り替え後のタブ: $index');

    setState(() {
      signalNames = List.from(widget.initialSignalNames);
      signals =
          widget.initialSignals.map((list) => List<int>.from(list)).toList();
      annotations = List.from(widget.initialAnnotations);
    });

    print('チャートデータ更新後の状態:');
    print('信号名: $signalNames');
    print('信号タイプ: ${widget.signalTypes}');
    print('===== タブ切り替え処理終了 =====');
  }
}

enum SignalType { input, output, hwTrigger }

void drawDashedLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint, {
  double dashWidth = 5,
  double dashSpace = 3,
}) {
  if ((start - end).distance < 0.1) return;

  final path = Path();
  final delta = end - start;
  final distance = delta.distance;
  final patternLength = dashWidth + dashSpace;
  final count = (distance / patternLength).floor();

  final unitVector = delta / distance;
  var currentDistance = 0.0;

  for (var i = 0; i < count; i++) {
    final dashStart = start + unitVector * currentDistance;
    currentDistance += dashWidth;
    final dashEnd = start + unitVector * currentDistance;

    path.moveTo(dashStart.dx, dashStart.dy);
    path.lineTo(dashEnd.dx, dashEnd.dy);

    currentDistance += dashSpace;
  }

  // 残りの部分を処理
  if (currentDistance < distance) {
    final dashStart = start + unitVector * currentDistance;
    final dashEnd = end;
    path.moveTo(dashStart.dx, dashStart.dy);
    path.lineTo(dashEnd.dx, dashEnd.dy);
  }

  canvas.drawPath(path, paint);
}

/// 矩形波描画 + 信号名表示 + 選択範囲ハイライト
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
    required this.highlightTimeIndices,
    this.startSignalIndex,
    this.endSignalIndex,
    this.startTimeIndex,
    this.endTimeIndex,
    required this.chartMarginLeft,
    required this.chartMarginTop,
    required this.selectedAnnotationId,
    required this.annotationRects,
  });

  final List<List<int>> signals;
  final List<String> signalNames;
  final List<TimingChartAnnotation> annotations;
  final List<int> highlightTimeIndices;
  final List<SignalType> signalTypes;

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
  // コメント当たり判定用
  final Map<String, Rect> annotationRects;
  // 1のとき波形が少し上に上がるオフセット
  static const double waveAmplitude = 10;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(chartMarginLeft, chartMarginTop);
    // (1) 左側に信号名を描画
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
      textPainter.layout(maxWidth: labelWidth - 8);

      // 行の中央に配置してみる
      final yCenter = row * cellHeight + (cellHeight - textPainter.height) / 2;
      final offset = Offset(6, yCenter);
      textPainter.paint(canvas, offset);
    }
    debugPrint(
      'labelWidth = $labelWidth-------------------------------------------------',
    );

    // (2) 矩形波(ステップ)を描画
    var paintLine =
        Paint()
          ..color = Colors.black
          ..strokeWidth = 2.0;

    for (int row = 0; row < signals.length; row++) {
      final rowData = signals[row];
      final yOffset = row * cellHeight + (cellHeight / 2);
      debugPrint('signalTypes = ${row},${signalTypes[row]}');
      switch (signalTypes[row]) {
        case SignalType.input:
          paintLine =
              Paint()
                ..color = Colors.blue
                ..strokeWidth = 2.0;
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
        default:
          paintLine =
              Paint()
                ..color = Colors.black
                ..strokeWidth = 2;
          break;
      }

      for (int t = 0; t < rowData.length - 1; t++) {
        final currentValue = rowData[t];
        final nextValue = rowData[t + 1];

        // x座標は labelWidth 分オフセット
        final xStart = labelWidth + t * cellWidth;
        final xEnd = labelWidth + (t + 1) * cellWidth;

        final yCurrent =
            (currentValue == 1) ? (yOffset - waveAmplitude) : yOffset;
        final yNext = (nextValue == 1) ? (yOffset - waveAmplitude) : yOffset;

        // 水平線
        canvas.drawLine(
          Offset(xStart, yCurrent),
          Offset(xEnd, yCurrent),
          paintLine,
        );

        // 値変化なら垂直線
        if (currentValue != nextValue) {
          canvas.drawLine(
            Offset(xEnd, yCurrent),
            Offset(xEnd, yNext),
            paintLine,
          );
        }
      }
    }

    // (3) 選択範囲ハイライト
    if (startSignalIndex != null &&
        endSignalIndex != null &&
        startTimeIndex != null &&
        endTimeIndex != null) {
      final stSig = math.min(startSignalIndex!, endSignalIndex!);
      final edSig = math.max(startSignalIndex!, endSignalIndex!);
      final stTime = math.min(startTimeIndex!, endTimeIndex!);
      final edTime = math.max(startTimeIndex!, endTimeIndex!);

      // 例: 2行以上でのみハイライトしたい場合
      final selectedSignalCount = edSig - stSig + 1;
      final selectedTimeCount = edTime - stTime + 1;
      if (selectedSignalCount >= 2 || selectedTimeCount >= 2) {
        // 範囲をRectに
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
    }

    final commentTimeIndics = <int>{};
    for (final a in annotations) {
      commentTimeIndics.add(a.startTimeIndex);
      if (a.endTimeIndex != null) {
        commentTimeIndics.add(a.endTimeIndex!);
      }
    }

    // (4) グリッド線など(任意)
    final paintGuide =
        Paint()
          ..color = Colors.grey.withOpacity(0.5)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

    final paintHighlight =
        Paint()
          ..color = Colors.redAccent
          ..strokeWidth = 2;

    final paintAnnotations =
        Paint()
          ..color = Colors.black
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

    final maxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).reduce(math.max);

    // 縦線
    for (int i = 0; i <= maxLen; i++) {
      final x = labelWidth + i * cellWidth;
      if (highlightTimeIndices.contains(i)) {
        // 強調表示
        drawDashedLine(
          canvas,
          Offset(x, 0),
          Offset(x, size.height),
          Paint()
            ..color = Colors.blue.withOpacity(0.8)
            ..strokeWidth = 2,
          dashWidth: 4,
          dashSpace: 2,
        );
      } else if (commentTimeIndics.contains(i)) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintGuide);
      } else {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintGuide);
      }
    }
    // 横線
    for (int j = 0; j <= signals.length; j++) {
      final y = j * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGuide);
    }

    // (5) まず下部にコメント表示し、位置情報を取得
    _drawAnnotationsBelow(canvas, size);

    // 例えば、既存のグリッド線の描画後などに追加する
    for (final ann in annotations) {
      // 左側の縦線: startTimeIndex に対応する x 座標
      final double xStart = labelWidth + ann.startTimeIndex * cellWidth;
      // 対応するコメントボックスを探す
      final annId = ann.id;
      final Rect? commentRect = annotationRects[annId];
      // 境界線用のペイント（例：赤色、太さ2）
      final Paint boundaryPaint =
          Paint()
            ..color = Colors.black
            ..strokeWidth = 1;
      final double endY =
          commentRect != null ? commentRect.top : signals.length * cellHeight;
      drawDashedLine(
        canvas,
        Offset(xStart, 0),
        Offset(xStart, endY),
        Paint()
          ..color = Colors.black.withOpacity(0.7)
          ..strokeWidth = 0.5,
        dashWidth: 3,
        dashSpace: 3,
      );
      if (ann.endTimeIndex != null) {
        // 右側の縦線: endTimeIndex の右端に対応する x 座標（セルの幅分を足す）
        final double xEnd = labelWidth + (ann.endTimeIndex! + 1) * cellWidth;
        // コメントボックスのY座標（存在する場合）またはチャートの最下部
        drawDashedLine(
          canvas,
          Offset(xEnd, 0),
          Offset(xEnd, endY),
          Paint()
            ..color = Colors.black.withOpacity(0.7)
            ..strokeWidth = 0.5,
          dashWidth: 3,
          dashSpace: 3,
        );
      }
    }
    canvas.restore();
  }

  // ---------------------------------------------------------
  // 衝突回避しながらコメントを配置する例 (簡易)
  // ---------------------------------------------------------
  void _drawAnnotationsBelow(Canvas canvas, Size size) {
    annotationRects.clear();
    final chartBottomY = signals.length * cellHeight;
    // 単一セルコメント用の初期基準（矢印がない場合）
    final double baseCommentY = chartBottomY + 20;

    // annotationsが空の場合は何もしない
    if (annotations.isEmpty) {
      return;
    }

    // annotationsの並べ替え
    // 1. endTimeIndexがnullのもの（単一セルコメント）を先に、startTimeIndex順
    // 2. endTimeIndexがnullではないもの（範囲コメント）を後に、startTimeIndex順
    final sortedAnnotations = [...annotations];
    sortedAnnotations.sort((a, b) {
      // 単一セルと範囲コメントを区別（nullかどうか）
      if (a.endTimeIndex == null && b.endTimeIndex != null) {
        return -1; // aを先に（単一セルコメントを優先）
      } else if (a.endTimeIndex != null && b.endTimeIndex == null) {
        return 1; // bを先に（単一セルコメントを優先）
      } else {
        // 同じタイプ同士の場合
        if (a.endTimeIndex == null && b.endTimeIndex == null) {
          // 両方単一セルの場合はstartTimeIndexで昇順ソート
          return a.startTimeIndex.compareTo(b.startTimeIndex);
        } else {
          // 両方範囲セルの場合はendTimeIndexで昇順ソート
          return a.endTimeIndex!.compareTo(b.endTimeIndex!);
        }
      }
    });

    // 衝突回避用のリスト
    final List<Rect> placedRects = [];
    final List<Rect> placedArrowRects = [];

    // annotations が空でないことを確認してからデバッグログを出力
    if (sortedAnnotations.length > 1) {
      debugPrint('Before Annotation = ${annotations[1].startTimeIndex}');
      debugPrint('Sorted Annotation = ${sortedAnnotations[1].startTimeIndex}');
    }

    for (final ann in sortedAnnotations) {
      double xBase;
      if (ann.endTimeIndex != null) {
        // 範囲コメントの場合は範囲の中央位置を計算
        xBase =
            labelWidth +
            ((ann.startTimeIndex + ann.endTimeIndex!) / 2) * cellWidth;
      } else {
        xBase = labelWidth + ann.startTimeIndex * cellWidth;
      }

      double commentY; // コメントボックスの開始 Y 座標

      // 範囲コメントの場合は矢印を先に描画し、その下にコメントボックスを配置する
      if (ann.endTimeIndex != null) {
        // 初期の矢印描画位置
        double arrowY = chartBottomY + 10;
        final double arrowStartX = labelWidth + ann.startTimeIndex * cellWidth;
        final double arrowEndX =
            labelWidth + (ann.endTimeIndex! + 1) * cellWidth;
        const double arrowThickness = 4;
        Rect arrowRect = Rect.fromLTWH(
          arrowStartX,
          arrowY - arrowThickness / 2,
          arrowEndX - arrowStartX,
          arrowThickness,
        );

        // 衝突回避：既存の矢印と重ならないように arrowY を調整
        int arrowAttempts = 0;
        const double arrowYOffsetStep = 60;
        // 矢印同士および矢印とコメントボックスの衝突を検出する
        while ((placedArrowRects.any((r) => r.overlaps(arrowRect)) ||
                _isArrowOverlappingCommentBoxes(arrowRect, placedRects)) &&
            arrowAttempts < 15) {
          arrowY += arrowYOffsetStep;
          arrowRect = Rect.fromLTWH(
            arrowStartX,
            arrowY - arrowThickness / 2,
            arrowEndX - arrowStartX,
            arrowThickness,
          );
          arrowAttempts++;
        }
        placedArrowRects.add(arrowRect);

        // 最新の arrowY を用いて矢印の開始・終了位置を再計算
        final updatedArrowStart = Offset(arrowStartX, arrowY);
        final updatedArrowEnd = Offset(arrowEndX, arrowY);

        // 矢印（水平線）の描画
        final paintLine =
            Paint()
              ..color = Colors.blue
              ..strokeWidth = 4;
        canvas.drawLine(updatedArrowStart, updatedArrowEnd, paintLine);

        // 両端に矢印を描画
        final double arrowHeadLength = 8;
        _drawArrowhead(
          canvas,
          updatedArrowStart,
          math.pi,
          arrowHeadLength,
          paintLine,
        );
        _drawArrowhead(canvas, updatedArrowEnd, 0, arrowHeadLength, paintLine);

        // コメントは必ず矢印の下に配置する（ここでは矢印の矩形下端＋5px）
        commentY = arrowRect.bottom + 5;
      } else {
        // 単一セルの場合は従来通りの位置
        commentY = baseCommentY;
      }

      // 以下、コメントボックスの描画
      final textSpan = TextSpan(
        text: ann.text,
        style: TextStyle(color: Colors.black, fontSize: 16),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '...',
        textAlign: TextAlign.left,
      );
      textPainter.layout(maxWidth: 120);

      double tryY = commentY;
      Rect rect = Rect.fromLTWH(
        xBase,
        tryY,
        textPainter.width + 10,
        textPainter.height + 10,
      );

      int attempts = 0;
      const double yOffsetSteps = 60;
      while (placedRects.any((r) => r.overlaps(rect)) && attempts < 15) {
        tryY += yOffsetSteps;
        rect = Rect.fromLTWH(
          xBase,
          tryY,
          textPainter.width + 10,
          textPainter.height + 10,
        );
        attempts++;
      }
      placedRects.add(rect);

      // 余白の設定
      const double textPaddingLeft = 4.0;
      const double textPaddingTop = 4.0;

      // 描画：コメントボックスの背景、枠線、テキスト
      final paintBg =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
      canvas.drawRect(rect, paintBg);
      final paintBorder =
          Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
      canvas.drawRect(rect, paintBorder);
      textPainter.paint(
        canvas,
        rect.topLeft.translate(textPaddingLeft, textPaddingTop),
      );

      // ヒット判定用に登録
      annotationRects[ann.id] = rect;
    }
  }

  /// 矢印が既存のコメントボックスと重なっているかを判定するヘルパー関数
  bool _isArrowOverlappingCommentBoxes(
    Rect arrowRect,
    List<Rect> commentBoxes,
  ) {
    // 各コメントボックスについて
    for (final boxRect in commentBoxes) {
      // 矢印の水平範囲とコメントボックスの水平範囲が重なっているか
      final bool horizontalOverlap =
          !(arrowRect.right < boxRect.left || arrowRect.left > boxRect.right);

      // 矢印とコメントボックスが垂直方向に重なっているか
      final bool verticalOverlap =
          !(arrowRect.bottom < boxRect.top || arrowRect.top > boxRect.bottom);

      // 両方重なっている場合は衝突と判定
      if (horizontalOverlap && verticalOverlap) {
        return true;
      }
    }
    return false;
  }

  /// 矢印描画のためのシンプルなヘルパー関数
  void _drawArrowhead(
    Canvas canvas,
    Offset tip,
    double angle,
    double arrowHeadLength,
    Paint paint,
  ) {
    final leftEnd = Offset(
      tip.dx - arrowHeadLength * math.cos(angle - math.pi / 6),
      tip.dy - arrowHeadLength * math.sin(angle - math.pi / 6),
    );
    final rightEnd = Offset(
      tip.dx - arrowHeadLength * math.cos(angle + math.pi / 6),
      tip.dy - arrowHeadLength * math.sin(angle + math.pi / 6),
    );
    canvas.drawLine(tip, leftEnd, paint);
    canvas.drawLine(tip, rightEnd, paint);
  }

  @override
  bool shouldRepaint(covariant _StepTimingChartPainter oldDelegate) {
    return signals != oldDelegate.signals ||
        signalNames != oldDelegate.signalNames ||
        annotations != oldDelegate.annotations ||
        selectedAnnotationId != oldDelegate.selectedAnnotationId ||
        !listEquals(highlightTimeIndices, oldDelegate.highlightTimeIndices) ||
        startSignalIndex != oldDelegate.startSignalIndex ||
        endSignalIndex != oldDelegate.endSignalIndex;
  }
}
