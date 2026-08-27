import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import '../../utils/web_jpeg.dart' as web_jpeg;
import '../../models/chart/timing_chart_annotation.dart';
import '../../models/chart/signal_type.dart';
import '../../models/chart/io_channel_source.dart';
import 'chart_annotations.dart';
import 'chart_grid.dart';
import 'chart_signals.dart';
import 'chart_drawing_util.dart';
import '../../suggestion_loader.dart';
import '../../providers/settings_notifier.dart';
import 'package:provider/provider.dart'; // Provider用
import '../../generated/l10n.dart';
import '../../providers/timing_chart_controller.dart';

part 'timing_chart_types.dart';
part 'timing_chart_auto_comments.dart';
part 'timing_chart_painters.dart';
part 'timing_chart_export.dart';
part 'timing_chart_selection_ops.dart';
part 'timing_chart_gestures.dart';
part 'timing_chart_edit_steps.dart';
part 'timing_chart_zoom_scroll.dart';
part 'timing_chart_keyboard.dart';
part 'timing_chart_row_reorder.dart';

// NOTE: `part` 構成（責務別）
// - types: 型/計算（`timing_chart_types.dart`）
// - auto comments: 自動コメント生成（`timing_chart_auto_comments.dart`）
// - painters: 描画（`timing_chart_painters.dart`）
// - export: 画像/データのエクスポート（`timing_chart_export.dart`）
// - selection ops: 選択操作（`timing_chart_selection_ops.dart`）
// - gestures: ポインタ/ジェスチャー（`timing_chart_gestures.dart`）
// - edit steps: Edit grid（`timing_chart_edit_steps.dart`）
// - zoom/scroll: ズーム/スクロール（`timing_chart_zoom_scroll.dart`）
// - keyboard: キーボード/フォーカス（`timing_chart_keyboard.dart`）
// - row reorder: 行の並べ替え（`timing_chart_row_reorder.dart`）

// 翻訳サポート用

// NOTE: 小さな型/ヘルパーは `timing_chart_types.dart` に分離しました。

/// インタラクティブなタイミング図チャートを表示するStatefulWidget
///
/// このウィジェットは、時間経過に伴う信号波形を表示するタイミングチャートをレンダリングします。
/// ズーム、パン、編集、アノテーション、およびさまざまな表示モードをサポートします。
/// ステップベースとミリ秒ベースの両方の時間単位を処理します。
class TimingChart extends StatefulWidget {
  /// 各信号行の初期信号名（ID）
  final List<String> initialSignalNames;

  /// 初期信号データ：信号行のリスト。各行は時間経過に伴う0/1値のリスト
  final List<List<int>> initialSignals;

  /// チャートに表示する初期アノテーション（コメント）
  final List<TimingChartAnnotation> initialAnnotations;

  /// 各信号行の信号タイプ（入力、出力、制御など）
  final List<SignalType> signalTypes;

  /// チャート状態とアンドゥ/リドゥを管理するオプションのコントローラー
  final TimingChartController? controller;

  /// チャートを画面サイズに自動的にフィットするかどうか
  final bool fitToScreen;

  /// 制御/グループ/タスク信号を含むすべての信号タイプを表示するかどうか
  final bool showAllSignalTypes;

  /// 信号ラベルにIOポート番号を表示するかどうか
  final bool showIoNumbers;

  /// 各信号のポート番号（showIoNumbersがtrueの場合に使用）
  final List<int> portNumbers;

  /// 信号ごとに IO 番号プレフィックスを表示するか（グローバル設定 ON 時に反映）
  final List<bool> showIoNumbersPerSignal;

  /// 各信号のIOチャネルソース（PLC、EIPなど）
  final List<IoChannelSource> ioSources;

  /// PLC/EIPモード設定（'PLC'、'EIP'、または'None'）
  final String plcEipMode;

  /// ユーザー操作によって信号値が変更されたときに呼び出されるコールバック
  final void Function(
    List<String> names,
    List<List<int>> values,
    List<SignalType> types,
  )?
  onSignalsChanged;

  /// 信号ラベルの IO 番号表示が変更されたときに呼び出されるコールバック
  final void Function(int originalIndex, bool showIoNumber)?
  onSignalShowIoNumberChanged;

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
    this.showIoNumbersPerSignal = const [],
    this.ioSources = const [],
    this.plcEipMode = 'None',
    this.onSignalsChanged,
    this.onSignalShowIoNumberChanged,
  });

  @override
  State<TimingChart> createState() => TimingChartState();
}

/// TimingChartウィジェットのStateクラス
///
/// 信号、アノテーション、ズーム、選択、ユーザー操作を含むすべてのチャート状態を管理します。
/// AutomaticKeepAliveClientMixinを使用して、ウィジェットが表示されていないときに状態を保持します。
class TimingChartState extends State<TimingChart>
    with AutomaticKeepAliveClientMixin {
  /// チャート状態とアンドゥ/リドゥ操作を管理するコントローラー
  TimingChartController? _controller;

  /// コントローラーの状態変更用のコールバックリスナー
  late final VoidCallback _controllerListener;

  /// 元のID形式の信号名（翻訳前）
  late List<String> _idSignalNames;

  /// 言語変更用のコールバックリスナー（信号名の翻訳用）
  late final VoidCallback _langListener;

  @override
  bool get wantKeepAlive => true;

  /// 信号データ：行のリスト。各行には各時間ステップの0/1値が含まれます
  late List<List<int>> signals;

  /// 信号の表示名（IDから翻訳された可能性がある）
  late List<String> signalNames;

  /// チャートに表示されるアノテーション（コメント）
  late List<TimingChartAnnotation> annotations;

  /// 特別な視覚的スタイリングでハイライトする時間ステップインデックス
  List<int> _highlightTimeIndices = [];

  /// 省略マーク（波線）を描画する時間ステップインデックス
  List<int> _omissionTimeIndices = [];

  /// 現在表示されている信号行インデックスのリスト（フィルタリング後）
  List<int> _visibleIndexes = [];

  /// ユーザーが現在信号ラベルをドラッグして行を並べ替えているかどうか
  bool _isLabelDrag = false;

  /// ラベルをドラッグする際の開始行インデックス
  int? _labelDragStartRow;

  /// ラベルドラッグ操作中の現在の行インデックス
  int? _labelDragCurrentRow;

  /// チャート上の信号編集（反転・挿入・複製・行入替・削除）をロックするかどうか
  bool _isChartEditLocked = false;

  /// 各時間ステップセルの幅（ピクセル）
  double _cellWidth = 40;

  /// 各信号行セルの高さ（ピクセル）
  double _cellHeight = 40;

  /// 水平ズーム係数（1.0 = ズームなし、>1.0 = ズームイン）
  double _zoomFactor = 1.0;

  /// 最小/最大境界にクランプされた後の実効ズーム係数
  double _effectiveZoomFactor = 1.0;

  /// 現在のビューで許可される最小ズーム係数
  double _minZoomFactorForView = 1.0;

  /// 現在のビューで許可される最大ズーム係数
  double _maxZoomFactorForView = 10.0;

  /// 絶対最小ズーム係数（ハードリミット）
  static const double _minZoom = 0.1;

  /// ズームイン/アウト操作のステップサイズ
  static const double _zoomStep = 0.25;

  /// 許可される最小セル幅（ピクセル）
  static const double _minZoomCellWidth = 2.0;

  /// 許可される最大セル幅（ピクセル）
  static const double _maxZoomCellWidth = 20000.0;

  /// チャートエクスポート/キャプチャ用のデフォルトピクセル比
  static const double _defaultExportPixelRatio = 3.0;

  /// チャートエクスポート/キャプチャ用の最大ピクセル比
  static const double _maxExportPixelRatio = 6.0;

  /// GPU/エンコーダ制限を避けるためのエクスポート画像の最大辺（論理px × pixelRatio）
  static const double _maxExportImageDimension = 8192;

  /// 修飾キー（Ctrl/Cmd）が現在押されているかどうか
  bool _isModifierPressed = false;

  /// 左側の信号ラベル領域の幅
  final double labelWidth = 200.0;

  /// 下部のコメント領域の最小高さ
  static const double _minCommentAreaHeight = 100.0;

  /// コメント増加時に許容する最小の縦スケール（コメントなし時の行高さに対する比率）
  static const double _minVerticalFitScale = 0.6;

  /// 信号行の絶対最小高さ（ピクセル）
  static const double _minCellHeight = 5.0;

  /// 上部のコメント領域の最大高さ（下部と同程度）
  static const double _maxTopCommentAreaHeight = 100.0;

  /// コメントがない場合の下部マージン
  static const double _noCommentBottomMargin = 40.0;

  /// 自動生成コメント用の連番（ID重複防止）
  int _autoCommentSerial = 0;

  /// 描画結果から計測したコメント領域の高さ（null の場合は未計測）
  double? _measuredCommentAreaHeight;

  /// 描画結果から計測した上部コメント領域の高さ（null の場合は未計測）
  double? _measuredTopCommentAreaHeight;

  /// 現在のレイアウトで使用している上部コメント領域の高さ（座標補正に使用）
  double _topCommentAreaHeight = 0.0;

  /// ドラッグ中に上部へはみ出した分を先取り確保する高さ
  double _dragPreviewTopExtent = 0.0;

  /// ヒットテスト等で使用する、上部コメント領域を含むチャート上端マージン
  double get _effectiveChartTopMargin =>
      chartMarginTop +
      math.max(
        _topCommentAreaHeight,
        math.min(_dragPreviewTopExtent, _maxTopCommentAreaHeight),
      );

  /// 高度なタイミング制御を表示するかどうか（現在は常にfalse）
  bool get _showAdvancedTimingControls => true;

  /// チャート下部のコメント領域に必要な高さを計算します
  ///
  /// 高さはアノテーションの数に基づいており、可読性を確保するための最小高さがあります。
  /// アノテーションがない場合は固定マージンを返します。
  ///
  /// 計算された高さ（ピクセル）を返します
  double _calculateCommentAreaHeight() {
    // コメントが無ければ固定の下マージンのみ
    if (annotations.isEmpty) {
      _measuredCommentAreaHeight = null;
      return _noCommentBottomMargin;
    }

    // 描画結果から実際のコメントの最下端を計測できていれば優先して使用
    if (_measuredCommentAreaHeight != null &&
        _measuredCommentAreaHeight!.isFinite &&
        _measuredCommentAreaHeight! > 0) {
      return _measuredCommentAreaHeight!;
    }

    // 初回など、まだ実測値がない場合は従来どおり件数ベースで概算
    const double baseHeight = 40.0;
    const double stepHeight = 20.0;
    final int layers = annotations.length - 1;
    final double estimated = baseHeight + stepHeight * layers;
    final double expanded = estimated * 1.5;

    return math.max(_minCommentAreaHeight, expanded);
  }

  /// ペインター側で計測したコメント領域の高さを受け取る
  void _onCommentAreaMeasured(double height) {
    if (!mounted) return;
    if (!height.isFinite || height <= 0) return;

    final double normalized = height < _noCommentBottomMargin
        ? _noCommentBottomMargin
        : height;

    // ほぼ同じなら再ビルド不要
    if (_measuredCommentAreaHeight != null &&
        (_measuredCommentAreaHeight! - normalized).abs() < 0.5) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _measuredCommentAreaHeight = normalized;
      });
    });
  }

  /// チャート上部のコメント領域に必要な高さを計算します
  double _calculateTopCommentAreaHeight() {
    // 上部に配置されたコメントが無ければ 0
    final bool hasTop = annotations.any((a) => a.placement == 'top');
    if (!hasTop) {
      _measuredTopCommentAreaHeight = null;
      return 0.0;
    }
    // 実測値があれば優先
    if (_measuredTopCommentAreaHeight != null &&
        _measuredTopCommentAreaHeight!.isFinite &&
        _measuredTopCommentAreaHeight! > 0) {
      return math.min(_measuredTopCommentAreaHeight!, _maxTopCommentAreaHeight);
    }
    // 初回など実測前は件数ベースで概算
    final int topCount = annotations.where((a) => a.placement == 'top').length;
    return math.min(
      math.max(60.0, 40.0 + 20.0 * (topCount - 1)),
      _maxTopCommentAreaHeight,
    );
  }

  /// ペインター側で計測した上部コメント領域の高さを受け取る
  void _onTopCommentAreaMeasured(double height) {
    if (!mounted) return;
    if (!height.isFinite || height < 0) return;

    // ほぼ同じなら再ビルド不要
    final double prev = _measuredTopCommentAreaHeight ?? 0.0;
    if ((prev - height).abs() < 0.5) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _measuredTopCommentAreaHeight = height <= 0
            ? null
            : math.min(height, _maxTopCommentAreaHeight);
      });
    });
  }

  /// チャートを現在選択されている時間範囲にフィットするようにズームします
  ///
  /// 選択された時間範囲がビューポートを埋めるように適切なズーム係数を計算し、
  /// その後、選択範囲が見えるようにスクロール位置を調整します。
  /// 有効な選択がある場合にのみ機能します。
  void _zoomToSelectionFit() {
    _zoomToSelectionFitImpl();
  }

  final double chartMarginLeft = 16.0;
  final double chartMarginTop = 16.0;
  final double _fixedHeaderHeight = 48.0;

  /// 選択の開始信号行インデックス（表示インデックス空間内）
  int? _startSignalIndex;

  /// 選択の終了信号行インデックス（表示インデックス空間内）
  int? _endSignalIndex;

  /// 選択の開始時間ステップインデックス
  int? _startTimeIndex;

  /// 選択の終了時間ステップインデックス
  int? _endTimeIndex;

  /// コンテキストメニュー用の最後の右クリック位置
  Offset? _lastRightClickPos;

  /// 現在選択されているアノテーションのID（存在する場合）
  String? _selectedAnnotationId;

  /// アノテーションIDからそのヒットテスト矩形へのマップ
  final Map<String, Rect> _annotationHitRects = {};

  /// 現在ドラッグされているアノテーションのID
  String? _draggingAnnotationId;

  /// ドラッグ開始時のアノテーションボックスの初期左上位置
  Offset? _draggingInitialBoxTopLeft;

  /// ドラッグ開始時のアノテーションボックスのサイズ
  Size? _draggingBoxSize;

  /// ドラッグ開始時の指位置（CustomPaint ローカル Y）
  double? _draggingStartFingerLocalY;

  /// ドラッグ開始時の指位置（チャートローカル X、水平スクロール込み）
  double? _draggingStartFingerChartX;

  /// パン/ドラッグジェスチャーが開始されたグローバル位置
  Offset? _dragStartGlobal;

  /// チャートをレンダリングするCustomPaintウィジェットのキー
  final GlobalKey _customPaintKey = GlobalKey();

  /// チャートコンテンツ周辺のRepaintBoundaryのキー
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  /// ビューポート周辺のRepaintBoundaryのキー
  final GlobalKey _viewportBoundaryKey = GlobalKey();

  /// 信号ラベルオーバーレイ（画面上は横スクロール時に左端固定）
  final GlobalKey _labelsOverlayKey = GlobalKey();

  /// チャートコンテンツの水平スクロールコントローラー
  final ScrollController _hScrollController = ScrollController();

  /// チャートコンテンツの垂直スクロールコントローラー
  final ScrollController _vScrollController = ScrollController();

  /// ステップ継続時間編集モードがアクティブかどうか
  bool _isEditingSteps = false;

  /// 現在編集中のステップ境界のインデックス（編集モードがオンの場合）
  int? _activeStepIndex;

  /// stepDurationsMs を「この画面のUndo/Redo対象」として controller 側を優先するか。
  ///
  /// - まだ一度もこの画面で stepDurationsMs を controller にコミットしていない場合は false
  ///   （= 既存仕様どおり settings の値を使う）
  /// - 一度でもコミットした後は true（= controller の値が空でも controller を優先）
  bool _useControllerStepDurations = false;

  List<double> _durationsForLayout(SettingsNotifier settings) {
    // Edit grid 中はドラッグ/タップで settings.stepDurationsMs がリアルタイムに変化する。
    // ここで controller を優先すると、確定コミット（ドラッグ終了等）まで描画が更新されず
    // 「離した瞬間にだけ目盛りが動く」挙動になってしまうため、編集中は settings を優先する。
    if (_isEditingSteps) return settings.stepDurationsMs;

    final c = _controller;
    if (c == null) return settings.stepDurationsMs;
    if (_useControllerStepDurations) return c.stepDurationsMs;
    if (c.stepDurationsMs.isNotEmpty) return c.stepDurationsMs;
    return settings.stepDurationsMs;
  }

  // NOTE: キーボード/フォーカス処理は `timing_chart_keyboard.dart` に分離しました。
  bool _handleModifierKeyEvent(KeyEvent event) =>
      _handleModifierKeyEventImpl(event);

  void _onKeyEvent(KeyEvent event) => _onKeyEventImpl(event);

  /// ウィジェットが最初に作成されたときに状態を初期化します
  ///
  /// 信号名、翻訳、キーボードハンドラー、コントローラーを設定します。
  /// 言語変更とコントローラー更新のリスナーを登録します。
  @override
  void initState() {
    super.initState();
    _idSignalNames = List.from(widget.initialSignalNames);
    signalNames = _buildImmediateSignalNames(
      _idSignalNames,
      priorLabels: const {},
    );

    _translateNames();

    _langListener = () {
      _translateNames();
    };
    suggestionLanguageVersion.addListener(_langListener);

    HardwareKeyboard.instance.addHandler(_handleModifierKeyEvent);
    _isModifierPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

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
    _useControllerStepDurations = _controller!.stepDurationsMs.isNotEmpty;

    _controllerListener = () {
      if (!mounted) return;
      final List<List<int>> controllerSignals = _controller!.signals
          .map((e) => List<int>.from(e))
          .toList();
      final List<String> controllerNames = List<String>.from(
        _controller!.signalNames,
      );
      final bool namesChanged = !listEquals(_idSignalNames, controllerNames);
      final List<TimingChartAnnotation> controllerAnnotations = List.from(
        _controller!.annotations,
      );
      final List<int> controllerOmission = List<int>.from(
        _controller!.omissionTimeIndices,
      );
      final priorLabels = _buildPriorLabelMap();

      setState(() {
        signals = controllerSignals;
        _idSignalNames = controllerNames;
        signalNames = _buildImmediateSignalNames(
          _idSignalNames,
          priorLabels: priorLabels,
        );
        annotations = controllerAnnotations;
        _omissionTimeIndices = controllerOmission;
        _forceRepaint();
      });
      if (namesChanged) {
        _translateNames();
      }
      final settingsRW = Provider.of<SettingsNotifier>(context, listen: false);
      final int maxLen = signals.isEmpty
          ? 0
          : signals.map((e) => e.length).fold(0, math.max);
      // controller のUndo/Redoで stepDurationsMs が変わった場合、settingsにも同期して
      // 描画/入力UIが同じ状態を指すようにする。
      // ただし、まだ controller を使用していない場合は settings を尊重する。
      if (_controller!.stepDurationsMs.isNotEmpty) {
        _useControllerStepDurations = true;
      }
      if (_useControllerStepDurations && !_isEditingSteps) {
        final desired = _controller!.stepDurationsMs;
        if (!listEquals(settingsRW.stepDurationsMs, desired)) {
          settingsRW.setStepDurationsMs(desired);
        }
      } else {
        // 空配列は「均一（msPerStep）」の意味として扱うため、長さ強制はしない。
        if (settingsRW.stepDurationsMs.isNotEmpty &&
            settingsRW.stepDurationsMs.length != maxLen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) settingsRW.ensureStepDurationsLength(maxLen);
          });
        }
      }
      if (_lastHandledGridResetNonce != _controller!.gridResetNonce) {
        _lastHandledGridResetNonce = _controller!.gridResetNonce;
        resetGridAdjustments();
      }
      if (_lastHandledGridRecomputeNonce != _controller!.gridRecomputeNonce) {
        _lastHandledGridRecomputeNonce = _controller!.gridRecomputeNonce;
        setState(() {});
      }
    };
    _controller!.addListener(_controllerListener);
  }

  /// ズーム、選択、スクロール位置を含むすべてのグリッド調整をリセットします
  ///
  /// コントローラーからグリッドがリセットされたときに呼び出されます。
  /// ズームを1.0にリセットし、選択とハイライトをクリアし、左上にスクロールします。
  void resetGridAdjustments() {
    setState(() {
      _zoomFactor = 1.0;
      _effectiveZoomFactor = 1.0;
      _highlightTimeIndices.clear();
      _startSignalIndex = null;
      _endSignalIndex = null;
      _startTimeIndex = null;
      _endTimeIndex = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hScrollController.hasClients) {
        _hScrollController.jumpTo(0);
      }
      if (_vScrollController.hasClients) {
        _vScrollController.jumpTo(0);
      }
    });

    _forceRepaint();
  }

  /// 外部ソースから信号データを更新します
  ///
  /// [newSignals] - 現在の信号を置き換える新しい信号データ
  void updateSignals(List<List<int>> newSignals) {
    setState(() {
      signals = newSignals.map((list) => List<int>.from(list)).toList();
      _forceRepaint();
    });
    _controller?.setSignals(signals);
  }

  /// 親ウィジェットに信号が変更されたことを通知します
  ///
  /// 提供されている場合はonSignalsChangedコールバックを呼び出します。
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

  /// チャート編集からの信号変更をコントローラーにコミットし、親に通知します
  ///
  /// ユーザーがチャート上で直接信号を編集した後に呼び出されます。
  void _commitSignalsFromChartEdit() {
    _controller?.setSignals(signals);
    _notifySignalsChanged();
  }

  /// 外部ソースからアノテーションを更新します
  ///
  /// [newAnnotations] - 現在のアノテーションを置き換える新しいアノテーション
  void updateAnnotations(List<TimingChartAnnotation> newAnnotations) {
    setState(() {
      annotations = List.from(newAnnotations);
      _forceRepaint();
    });
    _controller?.setAnnotations(annotations);
  }

  /// 外部ソースから信号名を更新します
  ///
  /// [newIdNames] - 現在の信号名を置き換える新しい信号ID名
  void updateSignalNames(List<String> newIdNames) {
    if (listEquals(_idSignalNames, newIdNames)) {
      return;
    }
    final priorLabels = _buildPriorLabelMap();
    setState(() {
      _idSignalNames = List.from(newIdNames);
      signalNames = _buildImmediateSignalNames(
        _idSignalNames,
        priorLabels: priorLabels,
      );
      _forceRepaint();
    });
    _controller?.setSignalNames(_idSignalNames);
    _translateNames();
  }

  /// 現在の言語に基づいて信号名をIDから表示名に翻訳します
  ///
  /// すべての信号名の翻訳を非同期で読み込み、表示名を更新します。
  /// コロンプレフィックス付きの名前（例：「Type: id」）を処理します。
  void _translateNames() async {
    final translated = await Future.wait(
      _idSignalNames.map((id) async {
        //
        final int colonIdx = id.indexOf(':');
        if (colonIdx > 0) {
          final prefix = id.substring(0, colonIdx + 1); // 蜷ｫ繧
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

  Map<String, String> _buildPriorLabelMap() {
    final map = <String, String>{};
    final int safeLen = math.min(_idSignalNames.length, signalNames.length);
    for (int i = 0; i < safeLen; i++) {
      map[_idSignalNames[i]] = signalNames[i];
    }
    return map;
  }

  String _translateIdImmediate(String id, Map<String, String> priorLabels) {
    final cached = priorLabels[id];
    if (cached != null) return cached;
    final int colonIdx = id.indexOf(':');
    if (colonIdx > 0) {
      final prefix = id.substring(0, colonIdx + 1);
      final raw = id.substring(colonIdx + 1).trim();
      final label = labelOfIdSync(raw);
      return '$prefix $label';
    }
    return labelOfIdSync(id);
  }

  List<String> _buildImmediateSignalNames(
    List<String> newIds, {
    Map<String, String>? priorLabels,
  }) {
    final labels = priorLabels ?? _buildPriorLabelMap();
    return newIds.map((id) => _translateIdImmediate(id, labels)).toList();
  }

  List<List<int>> getChartData() {
    return List.from(signals);
  }

  @override
  void didUpdateWidget(covariant TimingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool namesChanged = !listEquals(
      widget.initialSignalNames,
      oldWidget.initialSignalNames,
    );
    final bool signalsChanged = !_areSignalsEqual(
      widget.initialSignals,
      oldWidget.initialSignals,
    );
    final bool annotationsChanged = !_areAnnotationsEqual(
      widget.initialAnnotations,
      oldWidget.initialAnnotations,
    );
    final priorLabels = namesChanged ? _buildPriorLabelMap() : null;
    if (namesChanged || signalsChanged || annotationsChanged) {
      setState(() {
        if (namesChanged) {
          _idSignalNames = List.from(widget.initialSignalNames);
          signalNames = _buildImmediateSignalNames(
            _idSignalNames,
            priorLabels: priorLabels,
          );
          _translateNames();
        }
        if (signalsChanged) {
          signals = widget.initialSignals
              .map((list) => List<int>.from(list))
              .toList();
        }
        if (annotationsChanged) {
          annotations = List.from(widget.initialAnnotations);
        }
      });
      if (annotationsChanged) {
        _controller?.setAnnotations(annotations);
      }
      if (signalsChanged) {
        _controller?.setSignals(signals);
      }
      if (namesChanged) {
        _controller?.setSignalNames(_idSignalNames);
      }
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
          a[i].text != b[i].text ||
          a[i].offsetX != b[i].offsetX ||
          a[i].offsetY != b[i].offsetY ||
          a[i].arrowTipY != b[i].arrowTipY ||
          a[i].arrowTipRowIndex != b[i].arrowTipRowIndex ||
          a[i].arrowHorizontal != b[i].arrowHorizontal ||
          a[i].fontSize != b[i].fontSize ||
          a[i].isBold != b[i].isBold ||
          a[i].borderColorValue != b[i].borderColorValue ||
          a[i].backgroundColorValue != b[i].backgroundColorValue ||
          a[i].textColorValue != b[i].textColorValue ||
          a[i].dashedLineColorValue != b[i].dashedLineColorValue ||
          a[i].arrowColorValue != b[i].arrowColorValue ||
          a[i].maxWidth != b[i].maxWidth ||
          a[i].maxLines != b[i].maxLines ||
          a[i].ellipsisEnabled != b[i].ellipsisEnabled ||
          a[i].placement != b[i].placement) {
        return false;
      }
    }
    return true;
  }

  /// 有効な選択範囲があるかどうかを確認します
  ///
  /// 4つのインデックスがすべて設定され、範囲内にある場合、選択は有効です：
  /// - 信号インデックスは表示信号範囲内である必要があります
  /// - 時間インデックスは信号データ範囲内である必要があります
  ///
  /// 選択が有効な場合はtrueを返し、それ以外の場合はfalseを返します
  bool get _hasValidSelection {
    if (_startSignalIndex == null ||
        _endSignalIndex == null ||
        _startTimeIndex == null ||
        _endTimeIndex == null) {
      return false;
    }
    if (signals.isEmpty) {
      return false;
    }
    final int maxLen = signals.map((e) => e.length).fold<int>(0, math.max);
    if (maxLen <= 0) {
      return false;
    }

    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    final maxTime = maxLen - 1;

    return stSig >= 0 &&
        edSig < _visibleIndexes.length &&
        stTime >= 0 &&
        edTime <= maxTime;
  }

  /// チャート上の信号編集が許可されているかどうか
  bool get _canEditChartSignals => !_isChartEditLocked;

  /// 指定表示行で IO 番号の個別表示設定が可能かどうか
  bool _canConfigureIoNumberForVisibleRow(int visibleRow) {
    if (visibleRow < 0 || visibleRow >= _visibleIndexes.length) return false;
    final int originalRow = _visibleIndexes[visibleRow];
    if (originalRow >= widget.portNumbers.length ||
        widget.portNumbers[originalRow] <= 0) {
      return false;
    }
    if (originalRow >= widget.signalTypes.length) return false;
    final type = widget.signalTypes[originalRow];
    return type == SignalType.input ||
        type == SignalType.output ||
        type == SignalType.hwTrigger;
  }

  /// 指定表示行で IO 番号プレフィックスを描画するかどうか
  bool _effectiveShowIoForOriginalRow(int originalRow) {
    if (!widget.showIoNumbers) return false;
    if (originalRow < 0 || originalRow >= widget.portNumbers.length) {
      return false;
    }
    if (widget.portNumbers[originalRow] <= 0) return false;
    if (originalRow >= widget.signalTypes.length) return false;
    final type = widget.signalTypes[originalRow];
    final bool typeSupportsIo =
        type == SignalType.input ||
        type == SignalType.output ||
        type == SignalType.hwTrigger;
    if (!typeSupportsIo) return false;
    if (originalRow < widget.showIoNumbersPerSignal.length) {
      return widget.showIoNumbersPerSignal[originalRow];
    }
    return true;
  }

  /// ウィジェット座標のX座標（dx）から時間ステップインデックスを取得します
  ///
  /// ピクセル位置を時間ステップインデックスに変換します。
  /// スクロールオフセットとラベル領域の幅を考慮します。ステップとミリ秒の両方の時間単位を処理します。
  ///
  /// [dx] - ウィジェットローカル座標のX座標
  /// 時間ステップインデックスを返します。無効な場合は-1を返します
  int _getTimeIndexFromDx(double dx) {
    final double chartX =
        dx -
        chartMarginLeft +
        (_hScrollController.hasClients ? _hScrollController.offset : 0);
    if (chartX < labelWidth) return -1;
    if (_cellWidth <= 0) return -1;

    final double relX = chartX - labelWidth;

    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    final int maxLen = signals.isEmpty
        ? 0
        : signals.map((e) => e.length).fold(0, math.max);

    return _TimePositionCalculator.getTimeIndexFromPosition(
      relX,
      _cellWidth,
      settings,
      maxLen,
      settings.stepDurationsMs,
    );
  }

  /// ウィジェット座標のY座標（dy）から信号行インデックスを取得します
  ///
  /// ピクセル位置を信号行インデックスに変換します。
  /// スクロールオフセットとチャートマージンを考慮します。表示信号インデックスを返します。
  ///
  /// [dy] - ウィジェットローカル座標のY座標
  /// 表示信号行インデックスを返します。無効な場合は-1を返します
  int _getSignalIndexFromDy(double dy) {
    final adjustedY =
        dy -
        _effectiveChartTopMargin +
        (_vScrollController.hasClients ? _vScrollController.offset : 0);
    if (_cellHeight <= 0) return -1;
    final index = (adjustedY / _cellHeight).floor();
    if (index < 0 || index >= _visibleIndexes.length) {
      return -1;
    }
    return index;
  }

  /// 現在の選択範囲をクリアします
  ///
  /// すべての選択インデックス（信号と時間）をnullにリセットします。
  /// アクティブな選択があった場合にのみ状態を更新します。
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

  /// チャート上のタップジェスチャーを処理します
  ///
  /// タップイベントを処理して、アノテーション選択、信号行選択、信号値の切り替えを行います。
  /// ラベル領域をタップすると、行全体が選択されます。
  /// 信号セルをタップすると、その値が切り替わります。
  /// 既存の選択範囲内をタップすると、その選択範囲内のすべての信号が切り替わります。
  /// 選択範囲外をタップすると、選択のみ解除されます（信号値は変更しません）。
  ///
  /// [details] - タップ位置を含むタップジェスチャーの詳細
  void _handleTap(TapUpDetails details) {
    _handleTapImpl(details);
  }

  void _onPanDown(DragDownDetails details) {
    _onPanDownImpl(details);
  }

  void _onSecondaryTapDown(TapDownDetails details) {
    _onSecondaryTapDownImpl(details);
  }

  // NOTE: 選択/編集操作（単一トグル含む）は `timing_chart_selection_ops.dart` に分離しました。

  /// パンジェスチャーの開始を処理します
  ///
  /// アノテーション、信号行の並べ替え、または選択範囲のドラッグ操作を開始します。
  /// 開始位置（アノテーション、ラベル領域、またはチャート領域）に基づいてドラッグのタイプを決定します。
  ///
  /// [details] - 初期位置を含むパンジェスチャー開始の詳細
  void _onPanStart(DragStartDetails details) {
    _onPanStartImpl(details);
  }

  /// パンジェスチャーの更新を処理します
  ///
  /// 現在のドラッグ操作を更新します。アクティブなドラッグタイプに基づいて、
  /// アノテーションのドラッグ、信号行の並べ替え、または選択範囲の拡張を処理します。
  ///
  /// [details] - 現在の位置を含むパンジェスチャー更新の詳細
  void _onPanUpdate(DragUpdateDetails details) {
    _onPanUpdateImpl(details);
  }

  /// パンジェスチャーの終了を処理します
  ///
  /// ドラッグ操作を完了します。アノテーションのドラッグの場合、位置を確定します。
  /// 信号行の並べ替えの場合、有効であれば並べ替えを適用します。
  /// 選択の場合、単一点の場合は選択をクリアします。
  ///
  /// [details] - パンジェスチャー終了の詳細
  void _onPanEnd(DragEndDetails details) {
    _onPanEndImpl(details);
  }

  // =====ステップ継続時間編集=====

  /// ステップ継続時間編集モード用のパンジェスチャー開始を処理します
  ///
  /// ステップ継続時間を編集する際、開始位置に最も近いステップ境界を見つけ、
  /// それをドラッグ用のアクティブなステップインデックスとして設定します。
  ///
  /// [details] - 初期位置を含むパンジェスチャー開始の詳細
  void _onPanStartEditSteps(DragStartDetails details) {
    _onPanStartEditStepsImpl(details);
  }

  /// ステップ継続時間編集モード用のパンジェスチャー更新を処理します
  ///
  /// 現在のドラッグ位置に基づいてアクティブなステップ境界の継続時間を更新します。
  /// ミリ秒単位で新しい継続時間を計算し、設定を更新します。
  ///
  /// [details] - 現在の位置を含むパンジェスチャー更新の詳細
  void _onPanUpdateEditSteps(DragUpdateDetails details) {
    _onPanUpdateEditStepsImpl(details);
  }

  /// ステップ継続時間編集モード用のパンジェスチャー終了を処理します
  ///
  /// ステップ継続時間編集モードを終了し、アクティブなステップインデックスをクリアします。
  /// 再計算をトリガーするためにステップ継続時間リストをリセットします。
  ///
  /// [details] - パンジェスチャー終了の詳細
  void _onPanEndEditSteps(DragEndDetails details) {
    _onPanEndEditStepsImpl(details);
  }

  void _toggleEditGridMode() {
    _toggleEditGridModeImpl();
  }

  /// スナップ距離を考慮して相対X位置から最も近いステップインデックスを見つけます
  ///
  /// 指定されたX位置に最も近い時間ステップ境界を計算します。
  /// スナップ距離内にある場合は、その境界インデックスを返します。
  /// それ以外の場合は、その位置を含むステップインデックスを返します。
  ///
  /// [relX] - 相対X位置（ピクセル、ラベル領域の開始位置から）
  /// [settings] - 時間単位設定を含む設定
  /// [maxLen] - 時間ステップの最大数
  /// [stepDurationsMs] - ステップ継続時間（ミリ秒）の配列
  /// [snapDistance] - 境界にスナップするための最大ピクセル距離
  /// 最も近いステップインデックスを返します
  int _findNearestStepIndex(
    double relX,
    SettingsNotifier settings,
    int maxLen,
    List<double> stepDurationsMs, {
    double snapDistance = 6.0,
  }) {
    return _findNearestStepIndexImpl(
      relX,
      settings,
      maxLen,
      stepDurationsMs,
      snapDistance: snapDistance,
    );
  }

  /// ステップ継続時間編集モードでのタップジェスチャーを処理します
  ///
  /// 編集モードでタップすると、近くのステップ境界にスナップするか、
  /// タップされたステップの継続時間を手動で入力するダイアログを開きます。
  ///
  /// [details] - タップ位置を含むタップジェスチャーの詳細
  void _onTapUpEditSteps(TapUpDetails details) {
    _onTapUpEditStepsImpl(details);
  }

  /// 長押しジェスチャーの開始を処理します
  ///
  /// アノテーションを長押しすると、アノテーションのドラッグを開始します。
  /// アノテーション用のドラッグ状態変数を設定します。
  ///
  /// [details] - 初期位置を含む長押しジェスチャー開始の詳細
  void _onLongPressStart(LongPressStartDetails details) {
    _onLongPressStartImpl(details);
  }

  /// 長押しジェスチャーの移動更新を処理します
  ///
  /// 長押しドラッグ中にアノテーションの位置を更新します。
  /// チャート領域の上にドラッグしないように移動をクランプします。
  ///
  /// [details] - 現在の位置を含む長押しジェスチャー移動更新の詳細
  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    _onLongPressMoveUpdateImpl(details);
  }

  /// 長押しジェスチャーの終了を処理します
  ///
  /// アノテーションのドラッグを完了し、ドラッグ状態変数をクリアします。
  ///
  /// [details] - 長押しジェスチャー終了の詳細
  void _onLongPressEnd(LongPressEndDetails details) {
    _onLongPressEndImpl(details);
  }

  /// 指定された位置にコンテキストメニューを表示します
  ///
  /// 右クリックされたものに基づいてアクションを含むコンテキストメニューを表示します：
  /// - アノテーションをクリックした場合：アノテーションの編集/削除オプション
  /// - チャート領域をクリックした場合：選択操作オプション
  /// メニュー項目の選択を処理し、対応するアクションを実行します。
  ///
  /// [context] - メニューを表示するためのビルドコンテキスト
  /// [position] - メニューが表示されるグローバル位置
  void _showContextMenu(BuildContext context, Offset position) async {
    // ignore: discarded_futures
    _showContextMenuImpl(context, position);
  }

  Widget _buildCommentColorPreview(Color color) {
    if (color.a == 0) {
      return Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '∅',
          style: TextStyle(fontSize: 10, color: Colors.black54),
        ),
      );
    }
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Future<Color?> _showBorderColorPickerDialog(
    BuildContext context, {
    required String title,
    required Color initial,
    bool allowTransparent = false,
    bool includeWhite = false,
  }) async {
    Color selected = initial;
    final List<Color> presets = [
      Colors.black,
      if (includeWhite) Colors.white,
      const Color(0xFF616161), // grey 700
      Colors.red,
      Colors.orange,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.brown,
    ];

    Widget buildColorPreview(Color color, {double size = 18}) {
      if (color.a == 0) {
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '∅',
            style: TextStyle(fontSize: size * 0.55, color: Colors.black54),
          ),
        );
      }
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    Widget contentBuilder(BuildContext ctx, StateSetter setLocalState) {
      final s = S.of(context);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (allowTransparent)
                InkWell(
                  onTap: () =>
                      setLocalState(() => selected = Colors.transparent),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      border: Border.all(
                        color: selected.a == 0 ? Colors.black : Colors.black26,
                        width: selected.a == 0 ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '∅',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ),
                ),
              ...presets.map((c) {
                final bool isSelected = c.toARGB32() == selected.toARGB32();
                return InkWell(
                  onTap: () => setLocalState(() => selected = c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.black26,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${s.color_picker_selected} '),
              buildColorPreview(selected),
              const SizedBox(width: 8),
              Text(
                selected.a == 0
                    ? s.color_picker_transparent
                    : '#${selected.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
              ),
            ],
          ),
        ],
      );
    }

    Widget dialogBuilder(BuildContext ctx) {
      return AlertDialog(
        title: Text(title),
        content: StatefulBuilder(builder: contentBuilder),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, selected),
            child: Text(S.of(context).common_ok),
          ),
        ],
      );
    }

    return showDialog<Color>(context: context, builder: dialogBuilder);
  }

  /// 信号ラベルの IO 番号表示を編集します
  void _editSignalLabelProperties(int visibleRow) async {
    if (visibleRow < 0 || visibleRow >= _visibleIndexes.length) return;
    if (!_canConfigureIoNumberForVisibleRow(visibleRow)) return;

    final int originalRow = _visibleIndexes[visibleRow];
    bool showIoNumber = originalRow < widget.showIoNumbersPerSignal.length
        ? widget.showIoNumbersPerSignal[originalRow]
        : true;

    final bool prevCanRequest = _focusNode.canRequestFocus;
    _focusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();

    final s = S.of(context);
    final String labelName = originalRow < signalNames.length
        ? signalNames[originalRow]
        : '';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          return AlertDialog(
            title: Text(s.signal_label_properties_title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(labelName, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.signal_label_properties_show_io_number),
                  subtitle: widget.showIoNumbers
                      ? null
                      : Text(s.signal_label_properties_global_io_off),
                  value: showIoNumber,
                  onChanged: widget.showIoNumbers
                      ? (v) => setLocalState(() => showIoNumber = v)
                      : null,
                ),
              ],
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
      ),
    );

    _focusNode.canRequestFocus = prevCanRequest;
    if (mounted) _focusNode.requestFocus();

    if (result == true) {
      widget.onSignalShowIoNumberChanged?.call(originalRow, showIoNumber);
    }
  }

  /// コメントボックスの見た目（フォント/太字/罫線色）を編集します
  void _editCommentProperties(String annId) async {
    final int index = annotations.indexWhere((a) => a.id == annId);
    if (index == -1) return;
    final TimingChartAnnotation ann = annotations[index];

    double fontSize = (ann.fontSize != null && ann.fontSize!.isFinite)
        ? ann.fontSize!
        : 14.0;
    bool isBold = ann.isBold == true;
    int borderColorValue =
        ann.borderColorValue ?? Colors.grey.shade600.toARGB32();
    int backgroundColorValue =
        ann.backgroundColorValue ?? const Color(0xFFFDFDFD).toARGB32();
    int textColorValue = ann.textColorValue ?? Colors.black.toARGB32();
    int dashedLineColorValue =
        ann.dashedLineColorValue ?? Colors.black.toARGB32();
    int arrowColorValue = ann.arrowColorValue ?? Colors.blue.toARGB32();
    double maxWidth = (ann.maxWidth != null && ann.maxWidth!.isFinite)
        ? ann.maxWidth!
        : 120.0;
    // 0 = 無制限として扱う（スライダーの最小値を0に割り当て）
    int maxLines = (ann.maxLines != null && ann.maxLines! > 0)
        ? ann.maxLines!
        : 0;
    bool ellipsisEnabled = ann.ellipsisEnabled ?? true;

    final bool prevCanRequest = _focusNode.canRequestFocus;
    _focusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();

    Widget dialogBuilder(BuildContext ctx) {
      final s = S.of(context);

      Widget stateBuilder(BuildContext ctx, StateSetter setLocalState) {
        void resetDefaults() {
          setLocalState(() {
            fontSize = 14.0;
            isBold = false;
            borderColorValue = Colors.grey.shade600.toARGB32();
            backgroundColorValue = const Color(0xFFFDFDFD).toARGB32();
            textColorValue = Colors.black.toARGB32();
            dashedLineColorValue = Colors.black.toARGB32();
            arrowColorValue = Colors.blue.toARGB32();
            maxWidth = 120.0;
            maxLines = 0;
            ellipsisEnabled = true;
          });
        }

        Future<void> pickBorderColor() async {
          final picked = await _showBorderColorPickerDialog(
            ctx,
            title: s.comment_properties_border_color,
            initial: Color(borderColorValue),
            allowTransparent: true,
          );
          if (picked != null) {
            setLocalState(() => borderColorValue = picked.toARGB32());
          }
        }

        Future<void> pickTextColor() async {
          final picked = await _showBorderColorPickerDialog(
            ctx,
            title: s.comment_properties_text_color,
            initial: Color(textColorValue),
            includeWhite: true,
          );
          if (picked != null) {
            setLocalState(() => textColorValue = picked.toARGB32());
          }
        }

        Future<void> pickBackgroundColor() async {
          final picked = await _showBorderColorPickerDialog(
            ctx,
            title: s.comment_properties_background_color,
            initial: Color(backgroundColorValue),
            allowTransparent: true,
          );
          if (picked != null) {
            setLocalState(() => backgroundColorValue = picked.toARGB32());
          }
        }

        Future<void> pickDashedLineColor() async {
          final picked = await _showBorderColorPickerDialog(
            ctx,
            title: s.comment_properties_dashed_color,
            initial: Color(dashedLineColorValue),
          );
          if (picked != null) {
            setLocalState(() => dashedLineColorValue = picked.toARGB32());
          }
        }

        Future<void> pickArrowColor() async {
          final picked = await _showBorderColorPickerDialog(
            ctx,
            title: s.comment_properties_arrow_color,
            initial: Color(arrowColorValue),
          );
          if (picked != null) {
            setLocalState(() => arrowColorValue = picked.toARGB32());
          }
        }

        return AlertDialog(
          title: Text(s.comment_properties_title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(s.comment_properties_font_size),
                    ),
                    Expanded(
                      child: Slider(
                        value: fontSize.clamp(8.0, 40.0),
                        min: 8.0,
                        max: 40.0,
                        divisions: 32,
                        label: fontSize.round().toString(),
                        onChanged: (v) => setLocalState(() => fontSize = v),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text(
                        fontSize.round().toString(),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: isBold,
                  onChanged: (v) => setLocalState(() => isBold = v ?? false),
                  title: Text(s.comment_properties_bold),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(s.comment_properties_text_color),
                    ),
                    _buildCommentColorPreview(Color(textColorValue)),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: pickTextColor,
                      child: Text(s.common_change),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(s.comment_properties_wrap_width),
                    ),
                    Expanded(
                      child: Slider(
                        value: maxWidth.clamp(40.0, 600.0),
                        min: 40.0,
                        max: 600.0,
                        divisions: 56,
                        label: maxWidth.round().toString(),
                        onChanged: (v) => setLocalState(() => maxWidth = v),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text(
                        maxWidth.round().toString(),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(s.comment_properties_max_lines),
                    ),
                    Expanded(
                      child: Slider(
                        value: maxLines.clamp(0, 10).toDouble(),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: maxLines <= 0
                            ? s.comment_properties_max_lines_unlimited
                            : maxLines.toString(),
                        onChanged: (v) =>
                            setLocalState(() => maxLines = v.round()),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text(
                        maxLines <= 0 ? '∞' : maxLines.toString(),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: ellipsisEnabled,
                  onChanged: maxLines <= 0
                      ? null
                      : (v) => setLocalState(() => ellipsisEnabled = v ?? true),
                  title: Text(s.comment_properties_ellipsis),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(s.comment_properties_border_color),
                    ),
                    _buildCommentColorPreview(Color(borderColorValue)),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: pickBorderColor,
                      child: Text(s.common_change),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: resetDefaults,
                      child: Text(s.common_default),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(s.comment_properties_background_color),
                    ),
                    _buildCommentColorPreview(Color(backgroundColorValue)),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: pickBackgroundColor,
                      child: Text(s.common_change),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(s.comment_properties_dashed_color),
                    ),
                    _buildCommentColorPreview(Color(dashedLineColorValue)),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: pickDashedLineColor,
                      child: Text(s.common_change),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(s.comment_properties_arrow_color),
                    ),
                    _buildCommentColorPreview(Color(arrowColorValue)),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: pickArrowColor,
                      child: Text(s.common_change),
                    ),
                  ],
                ),
              ],
            ),
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
      }

      return StatefulBuilder(builder: stateBuilder);
    }

    final result = await showDialog<bool>(
      context: context,
      builder: dialogBuilder,
    );

    _focusNode.canRequestFocus = prevCanRequest;
    if (mounted) _focusNode.requestFocus();

    if (result == true) {
      setState(() {
        final TimingChartAnnotation current = annotations[index];
        annotations[index] = current.copyWith(
          fontSize: fontSize,
          isBold: isBold,
          borderColorValue: borderColorValue,
          backgroundColorValue: backgroundColorValue,
          textColorValue: textColorValue,
          dashedLineColorValue: dashedLineColorValue,
          arrowColorValue: arrowColorValue,
          maxWidth: maxWidth,
          maxLines: maxLines,
          ellipsisEnabled: ellipsisEnabled,
        );
        _forceRepaint();
      });
      _controller?.setAnnotations(annotations);
    }
  }

  /// 新しい単一点アノテーションを追加するダイアログを表示します
  ///
  /// 最後の右クリック位置でダイアログを開き、ユーザーが特定の時間ステップで
  /// 新しいアノテーションのテキストを入力できるようにします。
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

    final bool prevCanRequest = _focusNode.canRequestFocus;
    _focusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();

    void onChanged(String val) => newComment = val;

    Widget dialogBuilder(BuildContext ctx) {
      final s = S.of(context);
      return AlertDialog(
        title: Text(s.comment_add_title),
        content: TextField(
          autofocus: true,
          onChanged: onChanged,
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
    }

    final result = await showDialog<bool>(
      context: context,
      builder: dialogBuilder,
    );

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
        annotations.add(newAnnotation);
        _highlightTimeIndices = [..._highlightTimeIndices];
        _forceRepaint();
      });
      _controller?.setAnnotations(annotations);
    }
  }
  // NOTE: 自動コメント生成は `timing_chart_auto_comments.dart` の extension へ分離しました。

  /// 新しい範囲アノテーションを追加するダイアログを表示します
  ///
  /// 現在選択されている時間範囲にまたがる新しいアノテーションのテキストを
  /// ユーザーが入力できるダイアログを開きます。
  Future<void> _showAddRangeCommentDialog() async {
    if (!_hasValidSelection) return;

    final int stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final int edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    String newComment = "";

    final bool prevCanRequest = _focusNode.canRequestFocus;
    _focusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();

    void onChanged(String val) => newComment = val;

    Widget dialogBuilder(BuildContext ctx) {
      final s = S.of(context);
      return AlertDialog(
        title: Text(s.comment_add_range_title),
        content: TextField(
          autofocus: true,
          onChanged: onChanged,
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
    }

    final result = await showDialog<bool>(
      context: context,
      builder: dialogBuilder,
    );

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
        annotations.add(newAnnotation);
        _forceRepaint();
        _clearSelection();
      });
      _controller?.setAnnotations(annotations);
    }
  }

  /// 既存のアノテーションのテキストを編集します
  ///
  /// 指定されたIDのアノテーションのテキストをユーザーが変更できるダイアログを開きます。
  /// テキストが変更された場合はアノテーションを更新します。
  ///
  /// [annId] - 編集するアノテーションのID
  void _editComment(String annId) async {
    final ann = annotations.firstWhereOrNull((a) => a.id == annId);
    if (ann == null) return;

    String newText = ann.text;

    final bool prevCanRequest = _focusNode.canRequestFocus;
    _focusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();

    Widget dialogBuilder(BuildContext ctx) {
      final controller = TextEditingController(text: ann.text);
      final s = S.of(context);
      void onOk() {
        newText = controller.text;
        Navigator.pop(ctx, true);
      }

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
          TextButton(onPressed: onOk, child: Text(s.common_ok)),
        ],
      );
    }

    final result = await showDialog<bool>(
      context: context,
      builder: dialogBuilder,
    );

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

  /// アノテーションを削除します
  ///
  /// 指定されたIDのアノテーションをチャートから削除します。
  /// このアノテーションが選択されていた場合は、選択もクリアします。
  ///
  /// [annId] - 削除するアノテーションのID
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

  // NOTE: 選択/編集操作（範囲トグル/挿入/削除/複製/省略線）は `timing_chart_selection_ops.dart` に分離しました。

  /// 可能であればズームをデフォルト（1.0）にリセットし、それ以外の場合は最小値にリセットします
  ///
  /// ズームを1.0に設定しようとしますが、1.0が許可範囲外の場合は最小ズームにフォールバックします。
  void _resetZoom() {
    _resetZoomImpl();
  }

  /// 信号タイプフィルタリングに基づいて表示可能な信号行インデックスのリストを計算します
  ///
  /// showAllSignalTypesがtrueでない限り、制御、グループ、タスク信号をフィルタリングします。
  /// チャートに表示されるべき信号のインデックスを返します。
  ///
  /// 表示可能な信号行インデックスのリストを返します
  List<int> _calculateVisibleIndexes() {
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
    return visibleIndexes;
  }

  /// 時間ステップの総数を計算します（ミリ秒単位の場合は小数になる可能性がある）
  ///
  /// ミリ秒単位を使用する場合、すべてのステップの正規化された継続時間を合計します。
  /// ステップ単位を使用する場合、ステップ数を返します。
  ///
  /// [settings] - 時間単位設定を含む設定
  /// [maxLen] - 時間ステップの最大数
  /// [durationsForLayout] - ステップ継続時間（ミリ秒）の配列
  /// 総ステップ数をdoubleとして返します（小数になる可能性がある）
  double _calculateTotalSteps(
    SettingsNotifier settings,
    int maxLen,
    List<double> durationsForLayout,
  ) {
    if (settings.timeUnitIsMs && maxLen > 0) {
      double totalSteps = 0.0;
      for (int i = 0; i < maxLen; i++) {
        final dur = (i < durationsForLayout.length)
            ? durationsForLayout[i]
            : settings.msPerStep;
        totalSteps += (settings.msPerStep > 0)
            ? (dur / settings.msPerStep)
            : 1.0;
      }
      return totalSteps;
    } else {
      return maxLen.toDouble();
    }
  }

  /// セル幅のズーム比を計算します
  double _calculateZoomByRatio(
    SettingsNotifier settings,
    int maxLen,
    List<double> durationsForLayout,
    double totalSteps,
  ) {
    if (settings.timeUnitIsMs && maxLen > 0) {
      double totalMs = 0.0;
      double minMs = double.maxFinite;
      for (int i = 0; i < maxLen; i++) {
        final dur = (i < durationsForLayout.length)
            ? durationsForLayout[i]
            : settings.msPerStep;
        if (dur.isFinite && dur > 0) {
          totalMs += dur;
          if (dur < minMs) minMs = dur;
        }
      }
      if (!minMs.isFinite || minMs <= 0) {
        minMs = (settings.msPerStep > 0) ? settings.msPerStep : 1.0;
      }
      return totalMs / (minMs * 2.0);
    } else {
      return (totalSteps > 0) ? (totalSteps / 2.0) : 1.0;
    }
  }

  /// チャートレンダリングに必要なすべてのレイアウトデータを計算します
  ///
  /// これは、現在の制約、信号データ、設定に基づいてセル寸法、ズーム係数、
  /// 表示インデックス、総チャート寸法を計算する主要なレイアウト計算メソッドです。
  ///
  /// [constraints] - 親ウィジェットからのボックス制約
  /// [settings] - 時間単位と表示設定を含む設定
  /// 計算されたすべてのレイアウト値を含む_ChartLayoutDataを返します
  _ChartLayoutData _calculateLayoutData(
    BoxConstraints constraints,
    SettingsNotifier settings,
  ) {
    final maxLen = signals.isEmpty
        ? 0
        : signals.map((e) => e.length).fold(0, math.max);
    final visibleIndexes = _calculateVisibleIndexes();

    final availableWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth - chartMarginLeft - labelWidth
        : MediaQuery.of(context).size.width - chartMarginLeft - labelWidth;

    final bool isMs = settings.timeUnitIsMs;
    final List<double> durationsForLayout = _durationsForLayout(settings);

    final totalSteps = _calculateTotalSteps(
      settings,
      maxLen,
      durationsForLayout,
    );

    // Calculate base cell width
    double baseCellWidth;
    if (widget.fitToScreen) {
      baseCellWidth = totalSteps > 0
          ? math.max(availableWidth / totalSteps, 5.0)
          : 40.0;
    } else {
      baseCellWidth = totalSteps > 0
          ? math.max(availableWidth / totalSteps, 20.0)
          : 40.0;
    }

    // Calculate min cell width for full view
    double minCellWidthForFullView = baseCellWidth;
    if (totalSteps > 0 && availableWidth.isFinite && availableWidth > 0) {
      final double perStepWidth = availableWidth / totalSteps;
      if (perStepWidth.isFinite && perStepWidth > 0) {
        minCellWidthForFullView = math.min(
          baseCellWidth,
          math.max(perStepWidth, _minZoomCellWidth),
        );
      }
    }
    minCellWidthForFullView = minCellWidthForFullView
        .clamp(_minZoomCellWidth, baseCellWidth)
        .toDouble();
    minCellWidthForFullView = math.min(
      minCellWidthForFullView,
      _maxZoomCellWidth,
    );

    // Calculate zoom ratio
    final zoomByRatio = _calculateZoomByRatio(
      settings,
      maxLen,
      durationsForLayout,
      totalSteps,
    );

    final maxCellWidthAllowed = (baseCellWidth * zoomByRatio)
        .clamp(_minZoomCellWidth, _maxZoomCellWidth)
        .toDouble();

    minCellWidthForFullView = math.min(
      minCellWidthForFullView,
      maxCellWidthAllowed,
    );

    // Calculate zoom factors
    final minZoomFactorForView = baseCellWidth <= 0
        ? 1.0
        : (minCellWidthForFullView / baseCellWidth).clamp(
            _minZoom,
            double.maxFinite,
          );

    double maxZoomFactorForView;
    if (isMs && maxLen > 0) {
      double totalMs = 0.0;
      double minMs = double.maxFinite;
      for (int i = 0; i < maxLen; i++) {
        final dur = (i < durationsForLayout.length)
            ? durationsForLayout[i]
            : settings.msPerStep;
        totalMs += dur;
        if (dur > 0 && dur < minMs) minMs = dur;
      }
      if (!minMs.isFinite || minMs <= 0) {
        minMs = (settings.msPerStep > 0) ? settings.msPerStep : 1.0;
      }
      maxZoomFactorForView = totalMs / (minMs * 2.0);
    } else {
      maxZoomFactorForView = (totalSteps > 0) ? (totalSteps / 2.0) : 1.0;
    }

    maxZoomFactorForView = math.min(
      maxZoomFactorForView,
      (baseCellWidth > 0) ? (_maxZoomCellWidth / baseCellWidth) : 1.0,
    );

    final effectiveZoomFactor = _zoomFactor.clamp(
      minZoomFactorForView,
      maxZoomFactorForView,
    );

    final cellWidth = (baseCellWidth * effectiveZoomFactor)
        .clamp(minCellWidthForFullView, maxCellWidthAllowed)
        .toDouble();

    final commentAreaHeight = _calculateCommentAreaHeight();
    final topCommentAreaHeight = _draggingAnnotationId != null
        ? math.min(_dragPreviewTopExtent, _maxTopCommentAreaHeight)
        : math.max(
            _calculateTopCommentAreaHeight(),
            math.min(_dragPreviewTopExtent, _maxTopCommentAreaHeight),
          );
    // ジェスチャー/ヒットテストの座標補正に使用するため保持
    _topCommentAreaHeight = topCommentAreaHeight;

    final constraintHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : MediaQuery.of(context).size.height;

    final verticalLayout = _VerticalLayout.calculate(
      fitToScreen: widget.fitToScreen,
      viewportHeight: constraintHeight,
      chartMarginTop: chartMarginTop,
      topCommentAreaHeight: topCommentAreaHeight,
      commentAreaHeight: commentAreaHeight,
      noCommentBottomMargin: _noCommentBottomMargin,
      visibleRowCount: visibleIndexes.length,
      minVerticalFitScale: _minVerticalFitScale,
      minCellHeight: _minCellHeight,
      defaultCellHeight: 40.0,
    );

    final totalWidth = chartMarginLeft + labelWidth + totalSteps * cellWidth;

    return _ChartLayoutData(
      visibleIndexes: visibleIndexes,
      totalSteps: totalSteps,
      baseCellWidth: baseCellWidth,
      minCellWidthForFullView: minCellWidthForFullView,
      maxCellWidthAllowed: maxCellWidthAllowed,
      minZoomFactorForView: minZoomFactorForView,
      maxZoomFactorForView: maxZoomFactorForView,
      effectiveZoomFactor: effectiveZoomFactor,
      cellWidth: cellWidth,
      cellHeight: verticalLayout.cellHeight,
      totalWidth: totalWidth,
      totalHeight: verticalLayout.totalHeight,
      commentAreaHeight: commentAreaHeight,
      topCommentAreaHeight: topCommentAreaHeight,
      maxLen: maxLen,
      needsVerticalScroll: verticalLayout.needsVerticalScroll,
    );
  }

  /// ビューポートの中心をアンカーポイントとして維持しながらズームインします
  ///
  /// 1ステップズームインし、ビューポートの中心が同じ視覚的位置に残るようにスクロールを調整します。
  void _zoomInWithAnchorAtCenter() {
    _zoomInWithAnchorAtCenterImpl();
  }

  /// ビューポートの中心をアンカーポイントとして維持しながらズームアウトします
  ///
  /// 1ステップズームアウトし、ビューポートの中心が同じ視覚的位置に残るようにスクロールを調整します。
  void _zoomOutWithAnchorAtCenter() {
    _zoomOutWithAnchorAtCenterImpl();
  }

  /// ポインター信号イベント（マウスホイールスクロール）を処理します
  ///
  /// Ctrl/Cmdが押されている場合、スクロールホイールを使用してズームイン/アウトします。
  /// カーソル位置をズームのアンカーポイントとして維持します。
  ///
  /// [event] - ポインター信号イベント（通常はスクロールホイール）
  void _handlePointerSignal(PointerSignalEvent event) {
    _handlePointerSignalImpl(event);
  }

  /// チャートコンテンツウィジェットを構築します
  Widget _buildChartContent(
    BuildContext context,
    _ChartLayoutData layoutData,
    SettingsNotifier settings,
    bool isEditingMode,
  ) {
    // Update state variables
    _cellWidth = layoutData.cellWidth;
    _cellHeight = layoutData.cellHeight;
    _minZoomFactorForView = layoutData.minZoomFactorForView;
    _maxZoomFactorForView = layoutData.maxZoomFactorForView;
    _effectiveZoomFactor = layoutData.effectiveZoomFactor;
    _visibleIndexes = layoutData.visibleIndexes;

    if (!layoutData.needsVerticalScroll &&
        _vScrollController.hasClients &&
        _vScrollController.offset != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_vScrollController.hasClients && _vScrollController.offset != 0) {
          _vScrollController.jumpTo(0);
        }
      });
    }

    // Ensure step durations length
    final settingsRW = Provider.of<SettingsNotifier>(context, listen: false);
    if (settings.stepDurationsMs.length != layoutData.maxLen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) settingsRW.ensureStepDurationsLength(layoutData.maxLen);
      });
    }

    // Build visible data lists
    final visibleSignalNames = [
      for (final i in layoutData.visibleIndexes) signalNames[i],
    ];
    final visibleSignals = [
      for (final i in layoutData.visibleIndexes)
        if (i < signals.length) signals[i],
    ];
    final visibleSignalTypes = [
      for (final i in layoutData.visibleIndexes) widget.signalTypes[i],
    ];
    final visiblePortNumbers = [
      for (final i in layoutData.visibleIndexes)
        (i < widget.portNumbers.length) ? widget.portNumbers[i] : 0,
    ];
    final visibleIoSources = [
      for (final i in layoutData.visibleIndexes)
        (i < widget.ioSources.length)
            ? widget.ioSources[i]
            : IoChannelSource.unknown,
    ];
    final visibleShowIoNumbers = [
      for (final i in layoutData.visibleIndexes)
        _effectiveShowIoForOriginalRow(i),
    ];

    final bool lockScroll =
        isEditingMode || _draggingAnnotationId != null || _isModifierPressed;
    final ScrollPhysics verticalPhysics =
        (!layoutData.needsVerticalScroll || lockScroll)
        ? const NeverScrollableScrollPhysics()
        : const ClampingScrollPhysics();

    return RepaintBoundary(
      key: _viewportBoundaryKey,
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: isEditingMode ? _onPanStartEditSteps : _onPanStart,
            onPanUpdate: isEditingMode ? _onPanUpdateEditSteps : _onPanUpdate,
            onPanEnd: isEditingMode ? _onPanEndEditSteps : _onPanEnd,
            onTapUp: isEditingMode ? _onTapUpEditSteps : _handleTap,
            onLongPressStart: isEditingMode ? null : _onLongPressStart,
            onLongPressMoveUpdate: isEditingMode
                ? null
                : _onLongPressMoveUpdate,
            onLongPressEnd: isEditingMode ? null : _onLongPressEnd,
            onPanDown: isEditingMode ? null : _onPanDown,
            onSecondaryTapDown: isEditingMode ? null : _onSecondaryTapDown,
            child: Scrollbar(
              controller: _vScrollController,
              interactive: true,
              thumbVisibility: layoutData.needsVerticalScroll,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.vertical,
              child: Scrollbar(
                controller: _hScrollController,
                interactive: true,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    controller: _hScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: lockScroll
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    child: SizedBox(
                      width: layoutData.totalWidth,
                      child: SingleChildScrollView(
                        controller: _vScrollController,
                        scrollDirection: Axis.vertical,
                        physics: verticalPhysics,
                        clipBehavior: layoutData.needsVerticalScroll
                            ? Clip.hardEdge
                            : Clip.none,
                        child: RepaintBoundary(
                          key: _repaintBoundaryKey,
                          child: CustomPaint(
                            key: _customPaintKey,
                            isComplex: true,
                            willChange: true,
                            size: Size(
                              layoutData.totalWidth,
                              layoutData.totalHeight,
                            ),
                            painter: _StepTimingChartPainter(
                              signals: visibleSignals,
                              signalNames: visibleSignalNames,
                              signalTypes: visibleSignalTypes,
                              annotations: annotations,
                              cellWidth: layoutData.cellWidth,
                              cellHeight: layoutData.cellHeight,
                              labelWidth: labelWidth,
                              commentAreaHeight: layoutData.commentAreaHeight,
                              topCommentAreaHeight:
                                  layoutData.topCommentAreaHeight,
                              chartMarginLeft: chartMarginLeft,
                              chartMarginTop: chartMarginTop,
                              startSignalIndex: isEditingMode
                                  ? null
                                  : _startSignalIndex,
                              endSignalIndex: isEditingMode
                                  ? null
                                  : _endSignalIndex,
                              startTimeIndex: isEditingMode
                                  ? null
                                  : _startTimeIndex,
                              endTimeIndex: isEditingMode
                                  ? null
                                  : _endTimeIndex,
                              highlightTimeIndices: isEditingMode
                                  ? const []
                                  : _highlightTimeIndices,
                              omissionTimeIndices: _omissionTimeIndices,
                              selectedAnnotationId: isEditingMode
                                  ? null
                                  : _selectedAnnotationId,
                              annotationRects: _annotationHitRects,
                              showAllSignalTypes: widget.showAllSignalTypes,
                              showIoNumbers: widget.showIoNumbers,
                              portNumbers: visiblePortNumbers,
                              timeUnitIsMs: settings.timeUnitIsMs,
                              msPerStep: settings.msPerStep,
                              stepDurationsMs: _durationsForLayout(settingsRW),
                              activeStepIndex:
                                  (settings.timeUnitIsMs && isEditingMode)
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
                              omissionFillColor: Theme.of(
                                context,
                              ).scaffoldBackgroundColor,
                              signalColors: Provider.of<SettingsNotifier>(
                                context,
                              ).signalColors,
                              onCommentAreaMeasured: _onCommentAreaMeasured,
                              onTopCommentAreaMeasured:
                                  _onTopCommentAreaMeasured,
                              draggingAnnotationId: isEditingMode
                                  ? null
                                  : _draggingAnnotationId,
                              draggingStartRow: isEditingMode
                                  ? null
                                  : _labelDragStartRow,
                              draggingCurrentRow: isEditingMode
                                  ? null
                                  : _labelDragCurrentRow,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _vScrollController,
            builder: (context, _) {
              return Positioned(
                // ラベル領域は常に左端に固定する（編集モードでも位置/幅を変えない）
                left: 0,
                top: 0,
                child: IgnorePointer(
                  child: ClipRect(
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        chartMarginTop +
                            layoutData.topCommentAreaHeight -
                            (_vScrollController.hasClients
                                ? _vScrollController.offset
                                : 0.0),
                      ),
                      child: SizedBox(
                        width: chartMarginLeft + labelWidth,
                        height: layoutData.totalHeight,
                        child: CustomPaint(
                          key: _labelsOverlayKey,
                          isComplex: false,
                          willChange: true,
                          size: Size(
                            chartMarginLeft + labelWidth,
                            layoutData.totalHeight,
                          ),
                          painter: _LabelsOverlayPainter(
                            signalNames: visibleSignalNames,
                            signalTypes: visibleSignalTypes,
                            showAllSignalTypes: widget.showAllSignalTypes,
                            showIoPerRow: visibleShowIoNumbers,
                            portNumbers: visiblePortNumbers,
                            ioSources: visibleIoSources,
                            plcEipMode: widget.plcEipMode,
                            labelColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                            backgroundColor: Theme.of(
                              context,
                            ).scaffoldBackgroundColor,
                            labelWidth: labelWidth,
                            chartMarginLeft: chartMarginLeft,
                            cellHeight: layoutData.cellHeight,
                            highlightStartRow: isEditingMode
                                ? null
                                : _startSignalIndex,
                            highlightEndRow: isEditingMode
                                ? null
                                : _endSignalIndex,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final settingsTop = Provider.of<SettingsNotifier>(context);
    final isEditingMode = _isEditingSteps && settingsTop.timeUnitIsMs;

    return isEditingMode
        ? Listener(
            onPointerSignal: _handlePointerSignal,
            child: _buildChartWithLayout(context, true),
          )
        : KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _onKeyEvent,
            child: Listener(
              onPointerSignal: _handlePointerSignal,
              child: _buildChartWithLayout(context, false),
            ),
          );
  }

  Widget _buildChartWithLayout(BuildContext context, bool isEditingMode) {
    final settings = Provider.of<SettingsNotifier>(context);
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layoutData = _calculateLayoutData(constraints, settings);
              return _buildChartContent(
                context,
                layoutData,
                settings,
                isEditingMode,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildZoomControls() {
    final int zoomPercent = (_effectiveZoomFactor * 100).round();
    final bool canZoomIn = _effectiveZoomFactor < _maxZoomFactorForView - 0.001;
    final bool canZoomOut =
        _effectiveZoomFactor > _minZoomFactorForView + 0.001;
    final bool canReset =
        (_effectiveZoomFactor - _minZoomFactorForView).abs() > 0.001;
    final bool canFitSelection = _hasValidSelection;

    if (_controller == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.zoom_out, size: 16),
            label: const Text('Zoom out'),
            onPressed: canZoomOut ? _zoomOutWithAnchorAtCenter : null,
          ),
          const SizedBox(width: 6),
          Text('$zoomPercent%'),
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
          const SizedBox(width: 6),
          OutlinedButton.icon(
            icon: const Icon(Icons.fit_screen_outlined, size: 16),
            label: const Text('Fit sel'),
            onPressed: canFitSelection ? _zoomToSelectionFit : null,
          ),
        ],
      );
    }

    return ListenableBuilder(
      listenable: _controller!,
      builder: _buildZoomControlsListenable,
    );
  }

  void _onUndoPressed() {
    _controller?.undo();
  }

  void _onRedoPressed() {
    _controller?.redo();
  }

  Widget _buildZoomControlsListenable(BuildContext context, Widget? _) {
    final int zoomPercent = (_effectiveZoomFactor * 100).round();
    final bool canZoomIn = _effectiveZoomFactor < _maxZoomFactorForView - 0.001;
    final bool canZoomOut =
        _effectiveZoomFactor > _minZoomFactorForView + 0.001;
    final bool canReset =
        (_effectiveZoomFactor - _minZoomFactorForView).abs() > 0.001;
    final bool canFitSelection = _hasValidSelection;
    final bool canUndo = _controller?.canUndo ?? false;
    final bool canRedo = _controller?.canRedo ?? false;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.undo, size: 16),
          label: const Text('Undo'),
          onPressed: canUndo ? _onUndoPressed : null,
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          icon: const Icon(Icons.redo, size: 16),
          label: const Text('Redo'),
          onPressed: canRedo ? _onRedoPressed : null,
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.zoom_out, size: 16),
          label: const Text('Zoom out'),
          onPressed: canZoomOut ? _zoomOutWithAnchorAtCenter : null,
        ),
        const SizedBox(width: 6),
        Text('$zoomPercent%'),
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
        const SizedBox(width: 6),
        OutlinedButton.icon(
          icon: const Icon(Icons.fit_screen_outlined, size: 16),
          label: const Text('Fit sel'),
          onPressed: canFitSelection ? _zoomToSelectionFit : null,
        ),
      ],
    );
  }

  /// 現在の選択範囲の総継続時間（ミリ秒）を計算します
  ///
  /// 選択範囲内のすべての時間ステップのステップ継続時間を合計します。
  /// 有効な選択がない場合は0.0を返します。
  ///
  /// [settings] - ステップ継続時間設定を含む設定
  /// 総継続時間（ミリ秒）を返します
  double _computeSelectionDurationMs(SettingsNotifier settings) {
    if (!_hasValidSelection) return 0.0;
    final int stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final int edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    final List<double> durations =
        (_controller?.stepDurationsMs.isNotEmpty ?? false)
        ? _controller!.stepDurationsMs
        : settings.stepDurationsMs;
    double sumMs = 0.0;
    for (int i = stTime; i <= edTime; i++) {
      final double ms = (i < durations.length && settings.msPerStep > 0)
          ? durations[i]
          : settings.msPerStep;
      sumMs += ms.isFinite && ms > 0 ? ms : 0.0;
    }
    return sumMs;
  }

  /// 現在の選択範囲内の時間ステップ数を計算します
  ///
  /// 時間ステップ単位で選択範囲の幅を計算します。
  /// 有効な選択がない場合は0を返します。
  ///
  /// 選択範囲内のステップ数を返します
  int _computeSelectionSteps() {
    if (!_hasValidSelection) return 0;
    final int stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final int edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    return (edTime - stTime + 1).clamp(0, 1 << 30);
  }

  /// 現在の選択範囲を説明するラベル文字列を構築します
  ///
  /// 現在の時間単位設定に応じて、ミリ秒単位の継続時間またはステップ数を示す
  /// フォーマットされた文字列を返します。
  ///
  /// [settings] - 時間単位設定を含む設定
  /// フォーマットされた選択ラベル文字列を返します
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

  /// 単位切り替えとコントロールパネルウィジェットを構築します
  ///
  /// 時間単位（ms/step）と下部ラベルのスイッチ、ズームコントロール、選択情報を含む
  /// コンテナを作成します。有効な場合は高度なタイミング制御を含む場合があります。
  ///
  /// [context] - ビルドコンテキスト
  /// 単位切り替えウィジェットを返します
  Widget _buildUnitToggle(BuildContext context) {
    final settings = Provider.of<SettingsNotifier>(context);
    final s = S.of(context);
    final bool isMs = settings.timeUnitIsMs;
    final String label = isMs ? 'ms' : 'step';

    void onTimeUnitChanged(bool v) {
      _onTimeUnitChanged(settings, v);
    }

    void onShowLabelsChanged(bool v) {
      settings.showBottomUnitLabels = v;
    }

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
          IconButton(
            icon: Icon(
              _isChartEditLocked ? Icons.lock : Icons.lock_open,
              size: 20,
            ),
            tooltip: _isChartEditLocked
                ? s.chart_edit_unlock_tooltip
                : s.chart_edit_lock_tooltip,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              setState(() {
                _isChartEditLocked = !_isChartEditLocked;
              });
            },
          ),
          const SizedBox(width: 4),
          Text('Unit:'),
          const SizedBox(width: 6),
          Switch(value: isMs, onChanged: onTimeUnitChanged),
          Text(label),
          const SizedBox(width: 12),
          Text('Labels:'),
          const SizedBox(width: 6),
          Switch(
            value: settings.showBottomUnitLabels,
            onChanged: onShowLabelsChanged,
          ),
          const SizedBox(width: 12),
          if (_showAdvancedTimingControls && isMs) ...[
            //Text('ms/step'),
            //const SizedBox(width: 6),
            //_buildMsPerStepField(),
            //const SizedBox(width: 12),
            //_buildEditStepDurationsButton(),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              icon: Icon(
                _isEditingSteps ? Icons.close_fullscreen : Icons.open_in_full,
                size: 16,
              ),
              label: Text(_isEditingSteps ? 'Done' : 'Edit grid'),
              onPressed: _toggleEditGridMode,
            ),
            const SizedBox(width: 8),
            const Text('（境界線をドラッグ/タップで調整）'),
          ],
          const SizedBox(width: 12),
          _buildZoomControls(),
          const SizedBox(width: 12),
          Text('Sel: ${_buildSelectionLabel(settings)}'),
        ],
      ),
    );
  }

  void _onTimeUnitChanged(SettingsNotifier settings, bool v) {
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
  }

  /// ステップあたりのミリ秒を編集するためのテキストフィールドを構築します
  ///
  /// 時間単位変換に使用される基本のステップあたりのミリ秒値をユーザーが設定できる
  /// 小さなテキスト入力フィールドを作成します。
  ///
  /// ms/step入力フィールドウィジェットを返します
  // ignore: unused_element
  Widget _buildMsPerStepField() {
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    final controller = TextEditingController(
      text: settings.msPerStep.toStringAsFixed(2),
    );

    void onSubmitted(String val) {
      _onMsPerStepSubmitted(settings, val);
    }

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
        onSubmitted: onSubmitted,
      ),
    );
  }

  void _onMsPerStepSubmitted(SettingsNotifier settings, String val) {
    final v = double.tryParse(val);
    if (v != null && v > 0) {
      settings.msPerStep = v;
    }
  }

  // NOTE: ステップ継続時間の一括編集ダイアログは `timing_chart_edit_steps.dart` に分離しました。
  Future<void> _onEditStepDurationsPressed() =>
      _onEditStepDurationsPressedImpl();

  /// ステップ継続時間を一括編集するためのボタンを構築します
  ///
  /// カンマ区切りの値を使用してすべてのステップ継続時間を一度に編集できる
  /// ダイアログを開くボタンを作成します。
  ///
  /// ステップ継続時間編集ボタンウィジェットを返します
  // ignore: unused_element
  Widget _buildEditStepDurationsButton() {
    void onPressed() {
      // ignore: discarded_futures
      _onEditStepDurationsPressed();
    }

    return OutlinedButton.icon(
      icon: const Icon(Icons.tune, size: 16),
      label: const Text('Edit steps'),
      onPressed: onPressed,
    );
  }

  /// チャートのCustomPaintウィジェットの再描画を強制します
  ///
  /// CustomPaintレンダーオブジェクトにペイントが必要であることをマークして
  /// 手動で再描画をトリガーします。状態変更が自動的に再描画をトリガーしない場合に使用されます。
  void _forceRepaint() {
    final customPaint = _customPaintKey.currentContext?.findRenderObject();
    if (customPaint is RenderCustomPaint) {
      customPaint.markNeedsPaint();
    }
  }

  /// `extension` から `setState()` を直接呼べない（@protected）ための薄いラッパー。
  void _setState(VoidCallback fn) => setState(fn);
  // NOTE: 画像エクスポート（PNG/JPEG）は `timing_chart_export.dart` に分離しました。

  List<TimingChartAnnotation> getAnnotations() => List.from(annotations);

  List<String> getSignalIdNames() => List.from(_idSignalNames);

  List<int> getOmissionTimeIndices() => List.from(_omissionTimeIndices);

  void setOmission(List<int> indices) {
    setState(() {
      _omissionTimeIndices = List<int>.from(indices);
      _forceRepaint();
    });
    _controller?.setOmissionTimeIndices(_omissionTimeIndices);
  }

  /// アノテーションの矢印の先端を特定の信号行に向けるように設定します
  ///
  /// アノテーションの矢印の先端の垂直位置を更新して、
  /// 指定された表示信号行の中心を指すようにします。
  ///
  /// [annId] - 更新するアノテーションのID
  /// [visibleRowIndex] - 指す表示信号行インデックス
  void _setAnnotationArrowToSignal(String annId, int visibleRowIndex) {
    if (visibleRowIndex < 0 || visibleRowIndex >= _visibleIndexes.length) {
      return;
    }
    setState(() {
      final idx = annotations.indexWhere((a) => a.id == annId);
      if (idx != -1) {
        // 表示行インデックスを保存しておくと、fitToScreen等でcellHeightが変動してもズレない
        final rowCenterY = (visibleRowIndex + 0.5) * _cellHeight;
        annotations[idx] = annotations[idx].copyWith(
          arrowTipRowIndex: visibleRowIndex,
          arrowTipY: rowCenterY, // 後方互換・既存処理用に残す
        );
        _forceRepaint();
      }
    });
    _controller?.setAnnotations(annotations);
  }

  late final FocusNode _focusNode = FocusNode();
  int _lastHandledGridResetNonce = 0;
  int _lastHandledGridRecomputeNonce = 0;

  @override
  void dispose() {
    suggestionLanguageVersion.removeListener(_langListener);
    HardwareKeyboard.instance.removeHandler(_handleModifierKeyEvent);
    _controller?.removeListener(_controllerListener);
    _hScrollController.dispose();
    _vScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // NOTE: キーボード処理は `timing_chart_keyboard.dart` に分離しました。

  // NOTE: 全選択/選択範囲の一括設定は `timing_chart_selection_ops.dart` に分離しました。

  /// 隣接する行と交換して信号行を上下に移動します
  ///
  /// 指定された表示インデックスの信号を（visibleIndex + direction）の信号と交換します。
  /// 関連する名前、タイプ、ポート番号、IOソース、ID名も交換します。
  ///
  /// [visibleIndex] - 移動する表示信号行インデックス
  /// [direction] - 移動方向（-1は上、+1は下）
  void _moveSignal(int visibleIndex, int direction) =>
      _moveSignalImpl(visibleIndex, direction);

  /// 1つの行を新しい位置に移動して信号行を並べ替えます
  ///
  /// fromVisibleからtoVisibleへ信号行を移動します。これは隣接する行を繰り返し交換することで行われます。
  /// 信号ラベルをドラッグして並べ替える際に使用されます。
  ///
  /// [fromVisible] - ソース表示行インデックス
  /// [toVisible] - 宛先表示行インデックス
  void _reorderSignalRows(int fromVisible, int toVisible) =>
      _reorderSignalRowsImpl(fromVisible, toVisible);
}

// NOTE: Painter は `timing_chart_painters.dart` に分離しました。
