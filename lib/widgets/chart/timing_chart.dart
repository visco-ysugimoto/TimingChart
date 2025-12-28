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

// 翻訳サポート用

/// 自動コメント生成で使用する HWトリガ立ち上がりイベント（内部専用）
class _HwTriggerEdge {
  final int rowIndex;
  final int timeIndex;
  final String name;

  const _HwTriggerEdge({
    required this.rowIndex,
    required this.timeIndex,
    required this.name,
  });
}

/// 自動コメント生成で使用する 出力信号立ち上がりイベント（内部専用）
class _OutputEdge {
  final int rowIndex;
  final int timeIndex;
  final String name;

  const _OutputEdge({
    required this.rowIndex,
    required this.timeIndex,
    required this.name,
  });
}

/// タイミングチャートのレンダリングに必要なレイアウト計算データ構造
///
/// このクラスは、タイミングチャートをレンダリングするために必要なすべての計算済みレイアウト値を保持します。
/// セルの寸法、ズーム係数、表示可能な信号インデックスなどが含まれます。
/// これらの値はレイアウトパスごとに一度計算され、レンダリング全体で再利用されます。
class _ChartLayoutData {
  /// 信号タイプでフィルタリング後の表示可能な信号行インデックスのリスト
  final List<int> visibleIndexes;

  /// 時間ステップの総数（ミリ秒単位を使用する場合は小数になる可能性がある）
  final double totalSteps;

  /// ズームが適用される前の基本セル幅
  final double baseCellWidth;

  /// ビューポート内のすべてのコンテンツを表示するために必要な最小セル幅
  final double minCellWidthForFullView;

  /// ズーム制約に基づく最大許可セル幅
  final double maxCellWidthAllowed;

  /// 現在のビューで許可される最小ズーム係数
  final double minZoomFactorForView;

  /// 現在のビューで許可される最大ズーム係数
  final double maxZoomFactorForView;

  /// 最小/最大境界にクランプされた後の実効ズーム係数
  final double effectiveZoomFactor;

  /// レンダリングに使用される実際のセル幅（baseCellWidth * effectiveZoomFactor）
  final double cellWidth;

  /// 各信号行セルの高さ
  final double cellHeight;

  /// チャートコンテンツ領域の総幅
  final double totalWidth;

  /// コメント領域を含むチャートコンテンツ領域の総高さ
  final double totalHeight;

  /// 下部に予約されているアノテーションコメント領域の高さ
  final double commentAreaHeight;

  /// すべての信号配列の最大長（最長の信号）
  final int maxLen;

  _ChartLayoutData({
    required this.visibleIndexes,
    required this.totalSteps,
    required this.baseCellWidth,
    required this.minCellWidthForFullView,
    required this.maxCellWidthAllowed,
    required this.minZoomFactorForView,
    required this.maxZoomFactorForView,
    required this.effectiveZoomFactor,
    required this.cellWidth,
    required this.cellHeight,
    required this.totalWidth,
    required this.totalHeight,
    required this.commentAreaHeight,
    required this.maxLen,
  });
}

/// タイミングチャートでの時間位置計算用のヘルパークラス
///
/// ピクセル位置と時間ステップインデックス間の変換を行う静的ユーティリティメソッドを提供します。
/// ステップベースとミリ秒ベースの両方の時間単位を処理します。
class _TimePositionCalculator {
  /// 時間単位変換用の累積ステップ位置配列を計算します
  ///
  /// ミリ秒単位を使用する場合、各ステップの継続時間が異なる可能性があります。
  /// このメソッドは、正規化されたステップ単位（1.0 = 1つの基本ステップ継続時間）で
  /// 各ステップ境界の累積位置を計算します。
  ///
  /// 長さmaxLen + 1の配列を返します。pos[i]はステップiの開始時の累積位置で、
  /// pos[maxLen]は総位置です。
  ///
  /// [settings] - msPerStepと時間単位設定を含む設定
  /// [maxLen] - 時間ステップの最大数
  /// [stepDurationsMs] - 各ステップの継続時間（ミリ秒）の配列
  /// 累積ステップ位置の配列を返します
  static List<double> calculateStepPositions(
    SettingsNotifier settings,
    int maxLen,
    List<double> stepDurationsMs,
  ) {
    final List<double> pos = List<double>.filled(maxLen + 1, 0.0);
    for (int i = 0; i < maxLen; i++) {
      final durSteps =
          (i < stepDurationsMs.length && settings.msPerStep > 0)
              ? stepDurationsMs[i] / settings.msPerStep
              : 1.0;
      pos[i + 1] = pos[i] + durSteps;
    }
    return pos;
  }

  /// ピクセル単位の相対X位置から時間ステップインデックスを取得します
  ///
  /// ピクセル位置（波形領域の開始位置からの相対位置）を対応する時間ステップインデックスに変換します。
  /// ステップベースとミリ秒ベースの両方の時間単位を正しく処理します。
  ///
  /// [relX] - 波形領域の開始位置からの相対X位置（ピクセル）
  /// [cellWidth] - 1つのセルの幅（ピクセル）
  /// [settings] - 時間単位設定を含む設定
  /// [maxLen] - 時間ステップの最大数
  /// [stepDurationsMs] - 各ステップの継続時間（ミリ秒）の配列
  /// 時間ステップインデックスを返します。無効な場合は-1を返します
  static int getTimeIndexFromPosition(
    double relX,
    double cellWidth,
    SettingsNotifier settings,
    int maxLen,
    List<double> stepDurationsMs,
  ) {
    if (settings.timeUnitIsMs && maxLen > 0) {
      final pos = calculateStepPositions(settings, maxLen, stepDurationsMs);
      for (int i = 0; i < maxLen; i++) {
        final double leftPx = pos[i] * cellWidth;
        final double rightPx = pos[i + 1] * cellWidth;
        if (relX >= leftPx && relX < rightPx) {
          return i;
        }
      }
      return maxLen - 1;
    }
    return (relX / cellWidth).floor();
  }
}

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

  /// 修飾キー（Ctrl/Cmd）が現在押されているかどうか
  bool _isModifierPressed = false;

  /// 左側の信号ラベル領域の幅
  final double labelWidth = 200.0;

  /// 下部のコメント領域の最小高さ
  static const double _minCommentAreaHeight = 100.0;

  /// コメントがない場合の下部マージン
  static const double _noCommentBottomMargin = 40.0;

  /// 自動生成コメント用の連番（ID重複防止）
  int _autoCommentSerial = 0;

  /// 描画結果から計測したコメント領域の高さ（null の場合は未計測）
  double? _measuredCommentAreaHeight;

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

    final double normalized =
        height < _noCommentBottomMargin ? _noCommentBottomMargin : height;

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

  /// チャートを現在選択されている時間範囲にフィットするようにズームします
  ///
  /// 選択された時間範囲がビューポートを埋めるように適切なズーム係数を計算し、
  /// その後、選択範囲が見えるようにスクロール位置を調整します。
  /// 有効な選択がある場合にのみ機能します。
  void _zoomToSelectionFit() {
    if (!_hasValidSelection) return;
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    final bool isMs = settings.timeUnitIsMs;

    final int stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final int edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    if (stTime < 0 || edTime < stTime) return;

    final double viewportWaveWidth = _getViewportWaveWidth();
    if (!(viewportWaveWidth.isFinite) || viewportWaveWidth <= 0) return;

    final int maxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);
    if (maxLen <= 0) return;

    final List<double> durationsForLayout = _durationsForLayout(settings);

    double totalStepsUnits = 0.0;
    if (isMs) {
      for (int i = 0; i < maxLen; i++) {
        final dur =
            (i < durationsForLayout.length)
                ? durationsForLayout[i]
                : settings.msPerStep;
        totalStepsUnits +=
            (settings.msPerStep > 0) ? (dur / settings.msPerStep) : 1.0;
      }
    } else {
      totalStepsUnits = maxLen.toDouble();
    }
    if (totalStepsUnits <= 0) return;

    double baseCellWidth;
    if (widget.fitToScreen) {
      baseCellWidth = math.max(viewportWaveWidth / totalStepsUnits, 5.0);
    } else {
      baseCellWidth = math.max(viewportWaveWidth / totalStepsUnits, 20.0);
    }

    double selectedUnits = 0.0;
    if (isMs) {
      for (int i = stTime; i <= edTime; i++) {
        if (i < 0 || i >= maxLen) continue;
        final dur =
            (i < durationsForLayout.length)
                ? durationsForLayout[i]
                : settings.msPerStep;
        final u = (settings.msPerStep > 0) ? (dur / settings.msPerStep) : 1.0;
        if (u.isFinite && u > 0) selectedUnits += u;
      }
    } else {
      selectedUnits = (edTime - stTime + 1).toDouble();
    }
    if (!(selectedUnits.isFinite) || selectedUnits <= 0) return;

    final double targetCellWidth = viewportWaveWidth / selectedUnits;
    final double targetZoom =
        (baseCellWidth > 0) ? (targetCellWidth / baseCellWidth) : 1.0;

    setState(() {
      _zoomFactor = targetZoom;
    });

    double stepsUnitsBefore = 0.0;
    if (isMs) {
      for (int i = 0; i < stTime; i++) {
        if (i < 0 || i >= maxLen) continue;
        final dur =
            (i < durationsForLayout.length)
                ? durationsForLayout[i]
                : settings.msPerStep;
        stepsUnitsBefore +=
            (settings.msPerStep > 0) ? (dur / settings.msPerStep) : 1.0;
      }
    } else {
      stepsUnitsBefore = stTime.toDouble();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyAnchorScrollCorrection(
        anchorXInWave: 0.0,
        stepsUnitsBefore: stepsUnitsBefore,
      );
    });
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
  Map<String, Rect> _annotationHitRects = {};

  /// 現在ドラッグされているアノテーションのID
  String? _draggingAnnotationId;

  /// アノテーションドラッグが開始されたローカル位置
  Offset? _draggingStartLocal;

  /// ドラッグ開始時のアノテーションボックスの初期左上位置
  Offset? _draggingInitialBoxTopLeft;

  /// パン/ドラッグジェスチャーが開始されたグローバル位置
  Offset? _dragStartGlobal;

  /// チャートをレンダリングするCustomPaintウィジェットのキー
  final GlobalKey _customPaintKey = GlobalKey();

  /// チャートコンテンツ周辺のRepaintBoundaryのキー
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  /// ビューポート周辺のRepaintBoundaryのキー
  final GlobalKey _viewportBoundaryKey = GlobalKey();

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

  /// ウィジェットが最初に作成されたときに状態を初期化します
  ///
  /// 信号名、翻訳、キーボードハンドラー、コントローラーを設定します。
  /// 言語変更とコントローラー更新のリスナーを登録します。
  @override
  void initState() {
    super.initState();
    _idSignalNames = List.from(widget.initialSignalNames);
    signalNames = List.from(_idSignalNames);

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
      final List<List<int>> controllerSignals =
          _controller!.signals.map((e) => List<int>.from(e)).toList();
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
      final settingsRW = Provider.of<SettingsNotifier>(context, listen: false);
      final int maxLen =
          signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);
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
    setState(() {
      _idSignalNames = List.from(newIdNames);
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

  List<List<int>> getChartData() {
    return List.from(signals);
  }

  @override
  void didUpdateWidget(covariant TimingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool namesChanged =
        !listEquals(widget.initialSignalNames, oldWidget.initialSignalNames);
    final bool signalsChanged =
        !_areSignalsEqual(widget.initialSignals, oldWidget.initialSignals);
    final bool annotationsChanged =
        !_areAnnotationsEqual(
          widget.initialAnnotations,
          oldWidget.initialAnnotations,
        );
    if (namesChanged || signalsChanged || annotationsChanged) {
      setState(() {
        if (namesChanged) {
          _idSignalNames = List.from(widget.initialSignalNames);
          signalNames = List.from(_idSignalNames);
          _translateNames();
        }
        if (signalsChanged) {
          signals =
              widget.initialSignals
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
          a[i].dashedLineColorValue != b[i].dashedLineColorValue ||
          a[i].arrowColorValue != b[i].arrowColorValue) {
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
    final int maxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);

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
        chartMarginTop +
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
  ///
  /// [details] - タップ位置を含むタップジェスチャーの詳細
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
      return;
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
      final settings = Provider.of<SettingsNotifier>(context, listen: false);
      double xStartPx;
      double xEndPx;
      if (settings.timeUnitIsMs) {
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
      final selectionRectContent = Rect.fromLTWH(
        xStartPx,
        chartMarginTop + (stSigAbs * _cellHeight).toDouble(),
        (xEndPx - xStartPx).clamp(0.0, double.infinity),
        (edSigAbs - stSigAbs + 1) * _cellHeight,
      );
      final double scrollX =
          _hScrollController.hasClients ? _hScrollController.offset : 0.0;
      final double scrollY =
          _vScrollController.hasClients ? _vScrollController.offset : 0.0;
      final Rect selectionRectViewport = selectionRectContent.translate(
        -scrollX,
        -scrollY,
      );

      if (selectionRectViewport.contains(chartLocalPos)) {
        _toggleSignalsInSelection();
      } else {
        _clearSelection();
        _toggleSingleSignal(clickSig, clickTim);
      }
    } else {
      _toggleSingleSignal(clickSig, clickTim);
    }
  }

  /// 指定された位置の単一信号値を切り替えます
  ///
  /// 指定された表示行と時間ステップインデックスで信号値を反転します（0から1、または1から0）。
  /// チャート状態を更新し、変更をコミットします。
  ///
  /// [visibleRow] - 表示信号行インデックス
  /// [time] - 時間ステップインデックス
  void _toggleSingleSignal(int visibleRow, int time) {
    if (visibleRow >= 0 && visibleRow < _visibleIndexes.length) {
      final originalRow = _visibleIndexes[visibleRow];
      if (time >= 0 && time < signals[originalRow].length) {
        setState(() {
          signals[originalRow][time] =
              (signals[originalRow][time] == 0) ? 1 : 0;
          _highlightTimeIndices = [..._highlightTimeIndices];
          _forceRepaint();
        });
        _commitSignalsFromChartEdit();
      }
    }
  }

  /// パンジェスチャーの開始を処理します
  ///
  /// アノテーション、信号行の並べ替え、または選択範囲のドラッグ操作を開始します。
  /// 開始位置（アノテーション、ラベル領域、またはチャート領域）に基づいてドラッグのタイプを決定します。
  ///
  /// [details] - 初期位置を含むパンジェスチャー開始の詳細
  void _onPanStart(DragStartDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    final chartLocalPos = Offset(localPos.dx, localPos.dy - _fixedHeaderHeight);

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

    final bool inLabelArea =
        chartLocalPos.dx >= chartMarginLeft &&
        chartLocalPos.dx <= chartMarginLeft + labelWidth;

    final sigIndex = _getSignalIndexFromDy(chartLocalPos.dy);
    if (inLabelArea && sigIndex >= 0 && sigIndex < _visibleIndexes.length) {
      setState(() {
        _isLabelDrag = true;
        _labelDragStartRow = sigIndex;
        _labelDragCurrentRow = sigIndex;
      });
      return;
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

  /// パンジェスチャーの更新を処理します
  ///
  /// 現在のドラッグ操作を更新します。アクティブなドラッグタイプに基づいて、
  /// アノテーションのドラッグ、信号行の並べ替え、または選択範囲の拡張を処理します。
  ///
  /// [details] - 現在の位置を含むパンジェスチャー更新の詳細
  void _onPanUpdate(DragUpdateDetails details) {
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
        _draggingInitialBoxTopLeft = _draggingInitialBoxTopLeft! + deltaClamped;
      }
      return;
    }
    if (_isLabelDrag) {
      final chartLocalPos = details.localPosition;
      int sig = _getSignalIndexFromDy(chartLocalPos.dy);
      sig = sig.clamp(0, _visibleIndexes.length - 1);
      if (sig != _labelDragCurrentRow) {
        setState(() {
          _labelDragCurrentRow = sig;
        });
      }
      return;
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

  /// パンジェスチャーの終了を処理します
  ///
  /// ドラッグ操作を完了します。アノテーションのドラッグの場合、位置を確定します。
  /// 信号行の並べ替えの場合、有効であれば並べ替えを適用します。
  /// 選択の場合、単一点の場合は選択をクリアします。
  ///
  /// [details] - パンジェスチャー終了の詳細
  void _onPanEnd(DragEndDetails details) {
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

  // =====ステップ継続時間編集=====

  /// ステップ継続時間編集モード用のパンジェスチャー開始を処理します
  ///
  /// ステップ継続時間を編集する際、開始位置に最も近いステップ境界を見つけ、
  /// それをドラッグ用のアクティブなステップインデックスとして設定します。
  ///
  /// [details] - 初期位置を含むパンジェスチャー開始の詳細
  void _onPanStartEditSteps(DragStartDetails details) {
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
    double cursorSteps = 0;
    int nearest = 0;
    double nearestDist = double.infinity;
    for (int i = 0; i <= maxLen; i++) {
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
  }

  /// ステップ継続時間編集モード用のパンジェスチャー更新を処理します
  ///
  /// 現在のドラッグ位置に基づいてアクティブなステップ境界の継続時間を更新します。
  /// ミリ秒単位で新しい継続時間を計算し、設定を更新します。
  ///
  /// [details] - 現在の位置を含むパンジェスチャー更新の詳細
  void _onPanUpdateEditSteps(DragUpdateDetails details) {
    if (!_isEditingSteps || _activeStepIndex == null) return;
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
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

    final List<double> list = List<double>.from(settings.stepDurationsMs);
    if (list.length < maxLen) {
      list.addAll(List.filled(maxLen - list.length, settings.msPerStep));
    }
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
    if (newDurSteps < 0.005) newDurSteps = 0.005;
    double newMs = newDurSteps * settings.msPerStep;
    if (newMs < 0.1) newMs = 0.1;
    list[idx] = newMs;
    settings.setStepDurationsMs(list);
  }

  /// ステップ継続時間編集モード用のパンジェスチャー終了を処理します
  ///
  /// ステップ継続時間編集モードを終了し、アクティブなステップインデックスをクリアします。
  /// 再計算をトリガーするためにステップ継続時間リストをリセットします。
  ///
  /// [details] - パンジェスチャー終了の詳細
  void _onPanEndEditSteps(DragEndDetails details) {
    // ドラッグ編集は「編集モード自体」を終了させず、選択中境界だけ解除する。
    // ここで stepDurationsMs を空にすると編集結果が消えてしまうため行わない。
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    _useControllerStepDurations = true;
    _controller?.setStepDurationsMs(settings.stepDurationsMs);
    setState(() {
      _activeStepIndex = null;
    });
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
    final pos = _TimePositionCalculator.calculateStepPositions(
      settings,
      maxLen,
      stepDurationsMs,
    );

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

    if (best <= snapDistance) {
      return nearest.clamp(0, math.max(0, maxLen - 1));
    }

    // Find step index from position
    for (int i = 0; i < maxLen; i++) {
      final double leftPx = pos[i] * _cellWidth;
      final double rightPx = pos[i + 1] * _cellWidth;
      if (relX >= leftPx && relX < rightPx) {
        return i;
      }
    }
    return math.max(0, maxLen - 1);
  }

  /// ステップ継続時間編集モードでのタップジェスチャーを処理します
  ///
  /// 編集モードでタップすると、近くのステップ境界にスナップするか、
  /// タップされたステップの継続時間を手動で入力するダイアログを開きます。
  ///
  /// [details] - タップ位置を含むタップジェスチャーの詳細
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

    const double snapPx = 6.0;
    final pos = _TimePositionCalculator.calculateStepPositions(
      settings,
      maxLen,
      settings.stepDurationsMs,
    );
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

    if (best <= snapPx) {
      setState(() {
        _activeStepIndex = nearest;
      });
      return;
    }

    final idx = _findNearestStepIndex(
      relX,
      settings,
      maxLen,
      settings.stepDurationsMs,
    );

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
      _useControllerStepDurations = true;
      _controller?.setStepDurationsMs(list);
      setState(() => _activeStepIndex = idx);
    });
  }

  /// 長押しジェスチャーの開始を処理します
  ///
  /// アノテーションを長押しすると、アノテーションのドラッグを開始します。
  /// アノテーション用のドラッグ状態変数を設定します。
  ///
  /// [details] - 初期位置を含む長押しジェスチャー開始の詳細
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

  /// 長押しジェスチャーの移動更新を処理します
  ///
  /// 長押しドラッグ中にアノテーションの位置を更新します。
  /// チャート領域の上にドラッグしないように移動をクランプします。
  ///
  /// [details] - 現在の位置を含む長押しジェスチャー移動更新の詳細
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

  /// 長押しジェスチャーの終了を処理します
  ///
  /// アノテーションのドラッグを完了し、ドラッグ状態変数をクリアします。
  ///
  /// [details] - 長押しジェスチャー終了の詳細
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
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    _lastRightClickPos = position;

    final RenderBox? rootBox = context.findRenderObject() as RenderBox?;
    final Offset rootLocalPos =
        rootBox != null ? rootBox.globalToLocal(position) : position;
    // 他のジェスチャー処理（_onPanStart 等）と同じく、固定ヘッダ分を差し引いた座標系で扱う
    // これを揃えないと「矢印の先端をこの行に設定」で行がずれて見える
    final Offset gestureLocalPos = Offset(
      rootLocalPos.dx,
      rootLocalPos.dy - _fixedHeaderHeight,
    );

    final RenderBox? paintBox =
        _customPaintKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset chartLocalPos =
        paintBox != null
            ? paintBox.globalToLocal(position)
            : Offset(
              rootLocalPos.dx +
                  (_hScrollController.hasClients
                      ? _hScrollController.offset
                      : 0),
              rootLocalPos.dy +
                  (_vScrollController.hasClients
                      ? _vScrollController.offset
                      : 0),
            );
    final adjustedPos = Offset(
      chartLocalPos.dx - chartMarginLeft,
      chartLocalPos.dy - chartMarginTop,
    );

    final settingsRO = Provider.of<SettingsNotifier>(context, listen: false);
    int clickedTimeIndex;
    if (settingsRO.timeUnitIsMs) {
      final int maxLen =
          signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);
      final double chartX = chartLocalPos.dx - chartMarginLeft;
      final double relX = (chartX - labelWidth).clamp(0, double.infinity);
      clickedTimeIndex = _findNearestStepIndex(
        relX,
        settingsRO,
        maxLen,
        settingsRO.stepDurationsMs,
      );
    } else {
      clickedTimeIndex = _getTimeIndexFromDx(rootLocalPos.dx);
    }

    final int clickedSig = _getSignalIndexFromDy(gestureLocalPos.dy);

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
      final bool horizontalOn = ann?.arrowHorizontal != false;
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
        PopupMenuItem(
          value: 'commentProperties',
          child: Text(s.ctx_comment_properties),
        ),
      ];
    } else {
      setState(() {
        _highlightTimeIndices.clear();
        if (_hasValidSelection) {
          final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
          final edTime = math.max(_startTimeIndex!, _endTimeIndex!);
          _highlightTimeIndices.add(stTime);
          _highlightTimeIndices.add(edTime + 1);
        } else {
          if (clickedTimeIndex >= 0) {
            _highlightTimeIndices.add(clickedTimeIndex);
          }
        }
      });

      menuItems = [
        if (_hasValidSelection)
          //PopupMenuItem(value: 'zoomSelection', child: Text('zoom selection')),
          PopupMenuItem(value: 'insert', child: Text(s.ctx_insert_zeros)),
        PopupMenuItem(value: 'duplicate', child: Text(s.ctx_duplicate_to_tail)),
        PopupMenuItem(
          value: 'selectAll',
          child: Text(s.ctx_select_all_signals),
        ),
        if (_hasValidSelection)
          PopupMenuItem(value: 'delete', child: Text(s.ctx_delete_selection)),
        if (_hasValidSelection)
          PopupMenuItem(
            value: 'deleteColumns',
            child: Text(s.ctx_delete_columns),
          ),
        // 波形から重要なイベントを検出してコメントを自動生成
        //const PopupMenuItem(value: 'autoComment', child: Text('波形からコメント自動生成')),
        PopupMenuItem(value: 'addComment', child: Text(s.ctx_add_comment)),
        PopupMenuItem(value: 'omit', child: Text(s.ctx_draw_omission)),
      ];
    }

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
        case 'commentProperties':
          if (hitAnnId != null) _editCommentProperties(hitAnnId);
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
              _controller?.setAnnotations(annotations);
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
          _insertZerosToSelection();
          break;
        case 'duplicate':
          _duplicateRange();
          break;
        case 'selectAll':
          _selectAllSignals();
          break;
        case 'delete':
          _deleteRange();
          break;
        case 'deleteColumns':
          _deleteColumns();
          break;
        case 'zoomSelection':
          _zoomToSelectionFit();
          break;
        case 'autoComment':
          await _autoGenerateCommentsForCurrentChart();
          break;
        case 'addComment':
          if (_hasValidSelection) {
            _showAddRangeCommentDialog();
          } else {
            _showAddCommentDialog();
          }
          break;
        case 'omit':
          _toggleOmissionTime(clickedTimeIndex);
          break;
      }
    }
  }

  Future<Color?> _showBorderColorPickerDialog(
    BuildContext context, {
    required String title,
    required Color initial,
  }) async {
    Color selected = initial;
    const List<Color> presets = [
      Colors.black,
      Color(0xFF616161), // grey 700
      Colors.red,
      Colors.orange,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.brown,
    ];

    return showDialog<Color>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: StatefulBuilder(
            builder: (ctx, setLocalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        presets.map((c) {
                          final bool isSelected =
                              c.toARGB32() == selected.toARGB32();
                          return InkWell(
                            onTap: () => setLocalState(() => selected = c),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: c,
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Colors.black
                                          : Colors.black26,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('${S.of(context).color_picker_selected} '),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: selected,
                          border: Border.all(color: Colors.black26),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '#${selected.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
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
      },
    );
  }

  /// コメントボックスの見た目（フォント/太字/罫線色）を編集します
  void _editCommentProperties(String annId) async {
    final int index = annotations.indexWhere((a) => a.id == annId);
    if (index == -1) return;
    final TimingChartAnnotation ann = annotations[index];

    double fontSize =
        (ann.fontSize != null && ann.fontSize!.isFinite) ? ann.fontSize! : 14.0;
    bool isBold = ann.isBold == true;
    int borderColorValue =
        ann.borderColorValue ?? Colors.grey.shade600.toARGB32();
    int dashedLineColorValue =
        ann.dashedLineColorValue ?? Colors.black.toARGB32();
    int arrowColorValue = ann.arrowColorValue ?? Colors.blue.toARGB32();

    final bool prevCanRequest = _focusNode.canRequestFocus;
    _focusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final s = S.of(context);
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
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
                      onChanged:
                          (v) => setLocalState(() => isBold = v ?? false),
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
                          child: Text(s.comment_properties_border_color),
                        ),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Color(borderColorValue),
                            border: Border.all(color: Colors.black26),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () async {
                            final picked = await _showBorderColorPickerDialog(
                              ctx,
                              title: s.comment_properties_border_color,
                              initial: Color(borderColorValue),
                            );
                            if (picked != null) {
                              setLocalState(
                                () => borderColorValue = picked.toARGB32(),
                              );
                            }
                          },
                          child: Text(s.common_change),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setLocalState(() {
                              fontSize = 14.0;
                              isBold = false;
                              borderColorValue =
                                  Colors.grey.shade600.toARGB32();
                              dashedLineColorValue = Colors.black.toARGB32();
                              arrowColorValue = Colors.blue.toARGB32();
                            });
                          },
                          child: Text(s.common_default),
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
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Color(dashedLineColorValue),
                            border: Border.all(color: Colors.black26),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () async {
                            final picked = await _showBorderColorPickerDialog(
                              ctx,
                              title: s.comment_properties_dashed_color,
                              initial: Color(dashedLineColorValue),
                            );
                            if (picked != null) {
                              setLocalState(
                                () => dashedLineColorValue = picked.toARGB32(),
                              );
                            }
                          },
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
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Color(arrowColorValue),
                            border: Border.all(color: Colors.black26),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () async {
                            final picked = await _showBorderColorPickerDialog(
                              ctx,
                              title: s.comment_properties_arrow_color,
                              initial: Color(arrowColorValue),
                            );
                            if (picked != null) {
                              setLocalState(
                                () => arrowColorValue = picked.toARGB32(),
                              );
                            }
                          },
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
          },
        );
      },
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
          dashedLineColorValue: dashedLineColorValue,
          arrowColorValue: arrowColorValue,
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

  /// 現在の波形情報から重要なイベントを検出し、コメントを自動生成して挿入します
  ///
  /// - 各信号の立ち上がり/立ち下がり
  /// - 一定以上の長さのON期間
  /// - HWトリガから出力信号までの遅延
  ///
  /// 既存の「自動生成コメント（末尾が '（自動）' のもの）」は一度削除してから再生成します。
  Future<void> _autoGenerateCommentsForCurrentChart() async {
    if (signals.isEmpty) return;

    // 自動生成対象となるコメントを構築
    final List<TimingChartAnnotation> autoComments =
        _buildAutoGeneratedCommentsFromSignals();

    if (autoComments.isEmpty) {
      // 重要とみなせるイベントが見つからなかった場合は簡単なトーストのみ表示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('自動で挿入できるコメントが見つかりませんでした'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      // 既存の自動生成コメント（IDが "auto" で始まるもの）を削除
      annotations.removeWhere((a) => a.id.startsWith('auto'));

      annotations.addAll(autoComments);
      _forceRepaint();
    });
    _controller?.setAnnotations(annotations);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('自動コメントを ${autoComments.length} 件挿入しました'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 波形からの自動コメント生成ロジック本体
  ///
  /// - 各可視信号ごとに最大数件のエッジ/長期ONを検出
  /// - HWトリガと出力信号の組み合わせから簡易な遅延コメントを生成
  List<TimingChartAnnotation> _buildAutoGeneratedCommentsFromSignals() {
    final List<TimingChartAnnotation> result = [];
    if (signals.isEmpty) return result;

    // 解析対象の時間長
    final int maxLen = signals
        .map((e) => e.length)
        .fold<int>(0, (prev, len) => math.max(prev, len));
    if (maxLen <= 1) return result;

    // 表示中の行のみを対象にする（なければ全行）
    final List<int> targetRows =
        _visibleIndexes.isNotEmpty
            ? List<int>.from(_visibleIndexes)
            : List<int>.generate(signals.length, (i) => i);

    // 各信号あたり立ち上がり/立ち下がりは「初回のみ」コメントする
    const int maxEdgesPerSignal = 1;
    const int maxTotalAnnotations = 50;
    const int longOnThresholdSteps = 5;
    const int maxTriggerDelaySteps = 20;

    // HWトリガの立ち上がりエッジを記録（後で出力信号との関連コメントに使う）
    final List<_HwTriggerEdge> hwRisingEdges = [];
    final List<_OutputEdge> outputRisingEdges = [];

    for (final rowIndex in targetRows) {
      if (rowIndex < 0 || rowIndex >= signals.length) continue;
      final values = signals[rowIndex];
      if (values.isEmpty) continue;

      final String name =
          (rowIndex < signalNames.length)
              ? signalNames[rowIndex]
              : 'Signal ${rowIndex + 1}';
      final SignalType type =
          (rowIndex < widget.signalTypes.length)
              ? widget.signalTypes[rowIndex]
              : SignalType.input;

      int prev = values.first;
      int runStart = 0;
      int risingCount = 0;
      int fallingCount = 0;

      for (
        int t = 1;
        t < values.length && result.length < maxTotalAnnotations;
        t++
      ) {
        final int v = values[t];
        if (v == prev) continue;

        // 直前までのラン区間 [runStart, t-1] を確定
        if (prev == 1) {
          final int runLength = t - runStart;
          if (runLength >= longOnThresholdSteps &&
              result.length < maxTotalAnnotations) {
            result.add(
              _createAutoAnnotation(
                startTimeIndex: runStart,
                endTimeIndex: t - 1,
                text: _buildLongOnCommentText(name, type, runLength),
              ),
            );
          }
        }

        // エッジ判定
        if (prev == 0 && v == 1) {
          // 立ち上がり
          if (type == SignalType.hwTrigger) {
            hwRisingEdges.add(
              _HwTriggerEdge(rowIndex: rowIndex, timeIndex: t, name: name),
            );
          } else if (type == SignalType.output) {
            outputRisingEdges.add(
              _OutputEdge(rowIndex: rowIndex, timeIndex: t, name: name),
            );
          }

          if (risingCount < maxEdgesPerSignal) {
            result.add(
              _createAutoAnnotation(
                startTimeIndex: t,
                text: _buildEdgeCommentText(name, type, true),
              ),
            );
            risingCount++;
          }
        } else if (prev == 1 && v == 0) {
          // 立ち下がり
          if (fallingCount < maxEdgesPerSignal) {
            result.add(
              _createAutoAnnotation(
                startTimeIndex: t,
                text: _buildEdgeCommentText(name, type, false),
              ),
            );
            fallingCount++;
          }
        }

        runStart = t;
        prev = v;
      }

      // 最後の区間も長いONならコメント
      if (prev == 1) {
        final int runLength = values.length - runStart;
        if (runLength >= longOnThresholdSteps &&
            result.length < maxTotalAnnotations) {
          result.add(
            _createAutoAnnotation(
              startTimeIndex: runStart,
              endTimeIndex: values.length - 1,
              text: _buildLongOnCommentText(name, type, runLength),
            ),
          );
        }
      }

      if (result.length >= maxTotalAnnotations) break;
    }

    // HWトリガ → 出力の遅延コメント（簡易版）
    for (final outEdge in outputRisingEdges) {
      if (result.length >= maxTotalAnnotations) break;
      _HwTriggerEdge? bestTrigger;
      int bestDt = maxTriggerDelaySteps + 1;

      for (final trig in hwRisingEdges) {
        if (trig.timeIndex > outEdge.timeIndex) continue;
        final int dt = outEdge.timeIndex - trig.timeIndex;
        if (dt >= 0 && dt <= maxTriggerDelaySteps && dt < bestDt) {
          bestDt = dt;
          bestTrigger = trig;
        }
      }

      if (bestTrigger != null) {
        result.add(
          _createAutoAnnotation(
            startTimeIndex: bestTrigger.timeIndex,
            endTimeIndex: outEdge.timeIndex,
            text: _buildDelayCommentText(
              bestTrigger.name,
              outEdge.name,
              bestDt,
            ),
          ),
        );
      }
    }

    return result;
  }

  /// エッジ（立ち上がり/立ち下がり）用のコメント文を組み立て
  String _buildEdgeCommentText(String name, SignalType type, bool rising) {
    // 1) まずドメイン固有のルールを優先（役割に沿った短いコメント）
    final String? domainText = _buildDomainSpecificEdgeComment(
      name,
      type,
      rising,
    );
    if (domainText != null) {
      return domainText;
    }

    // 2) 汎用ルールはシンプルな形式に統一
    final String dir = rising ? 'ON' : 'OFF';
    // できるだけ短く：「信号名 ON/OFF」
    return '$name $dir';
  }

  /// 長時間ONが続いた区間用のコメント文を組み立て
  String _buildLongOnCommentText(String name, SignalType type, int steps) {
    // 一部の信号は長時間ONにドメイン固有コメントを割り当て可能
    final String? domainText = _buildDomainSpecificLongOnComment(
      name,
      type,
      steps,
    );
    if (domainText != null) {
      return domainText;
    }

    // 汎用コメントはステップ数を出さず、意味だけを簡潔に
    return '$name 長時間ON';
  }

  /// HWトリガから出力までの遅延コメント文を組み立て
  String _buildDelayCommentText(
    String triggerName,
    String outputName,
    int steps,
  ) {
    // 役割に沿った特別なパターン（例: 一括露光終了 → ワーク搬送）
    final String? domainText = _buildDomainSpecificDelayComment(
      triggerName,
      outputName,
      steps,
    );
    if (domainText != null) {
      return domainText;
    }

    // 汎用コメントもシンプルに
    return '$triggerName → $outputName 遅延 $steps ステップ';
  }

  /// エッジ用のドメイン固有コメント（役割に沿った説明）
  ///
  /// 例) 「一括露光中」がOFFになったタイミングで「ワーク搬送可」など。
  String? _buildDomainSpecificEdgeComment(
    String name,
    SignalType type,
    bool rising,
  ) {
    final normalized = name.replaceAll(' ', '');

    // 一括露光中: OFF になったらワーク搬送が可能
    if (normalized.contains('一括露光中')) {
      if (!rising) {
        return '一括露光終了 → ワーク搬送可';
      } else {
        return '一括露光開始';
      }
    }

    // ここに他のルールを追加可能
    // 例:
    // if (normalized.contains('搬送許可') && rising) {
    //   return 'ワーク搬送開始可（自動）';
    // }

    return null;
  }

  /// 長時間ON用のドメイン固有コメント
  String? _buildDomainSpecificLongOnComment(
    String name,
    SignalType type,
    int steps,
  ) {
    final normalized = name.replaceAll(' ', '');

    // 一括露光中 が長く続いている場合
    if (normalized.contains('一括露光中')) {
      return '一括露光継続中';
    }

    return null;
  }

  /// トリガ→出力の遅延用ドメイン固有コメント
  String? _buildDomainSpecificDelayComment(
    String triggerName,
    String outputName,
    int steps,
  ) {
    final trig = triggerName.replaceAll(' ', '');
    final out = outputName.replaceAll(' ', '');

    // 例: 一括露光トリガ → ワーク搬送用出力 などに合わせて拡張可能
    if (trig.contains('一括露光') && out.contains('搬送')) {
      return '一括露光完了から搬送開始までの遅延 $steps ステップ';
    }

    return null;
  }

  /// 自動コメント用アノテーションインスタンスを生成
  TimingChartAnnotation _createAutoAnnotation({
    required int startTimeIndex,
    int? endTimeIndex,
    required String text,
  }) {
    final String id =
        'auto${DateTime.now().millisecondsSinceEpoch}_${_autoCommentSerial++}';
    return TimingChartAnnotation(
      id: id,
      startTimeIndex: startTimeIndex,
      endTimeIndex: endTimeIndex,
      text: text,
    );
  }

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

  /// 現在の選択範囲内のすべての信号値を切り替えます
  ///
  /// 選択されたすべての信号行について、選択範囲内のすべての信号値を反転します（0から1、または1から0）。
  /// 変更をコントローラーにコミットします。
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

  /// 選択範囲にゼロ値を挿入します
  ///
  /// 選択されたすべての信号行について、選択範囲の開始位置に選択幅に等しい数のゼロ値を挿入します。
  /// これにより、既存の値が右にシフトされます。
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

  /// 指定された範囲の時間列を削除します
  ///
  /// 指定された時間範囲内のすべての信号から時間ステップを削除します。
  /// 削除を反映するために、ステップ継続時間、省略インデックス、アノテーションも更新します。
  /// これは列全体を削除する際に使用されます。
  ///
  /// [stTime] - 開始時間インデックス（含む）
  /// [edTime] - 終了時間インデックス（含む）
  void _deleteColumnsAtRange(int stTime, int edTime) {
    debugPrint('deleteColumnsAtRange: stTime=$stTime, edTime=$edTime');
    debugPrint(
      'deleteColumnsAtRange: signals=${signals.map((e) => e.length).toList()}',
    );
    debugPrint(
      'deleteColumnsAtRange: _visibleIndexes=${_visibleIndexes.map((e) => e).toList()}',
    );
    debugPrint('deleteColumnsAtRange: _startSignalIndex=$_startSignalIndex');
    debugPrint('deleteColumnsAtRange: _endSignalIndex=$_endSignalIndex');
    debugPrint('deleteColumnsAtRange: _startTimeIndex=$_startTimeIndex');
    debugPrint('deleteColumnsAtRange: _endTimeIndex=$_endTimeIndex');
    final int oldMaxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).reduce(math.max);
    final int clampedSt = stTime.clamp(0, oldMaxLen);
    final int clampedEd = (edTime + 1).clamp(0, oldMaxLen);
    if (clampedSt >= clampedEd) return;
    final int deleteLen = clampedEd - clampedSt;

    setState(() {
      for (int i = 0; i < signals.length; i++) {
        final maxTimeForRow = signals[i].length;
        final st = clampedSt.clamp(0, maxTimeForRow);
        final ed = clampedEd.clamp(0, maxTimeForRow);
        if (st < ed) {
          signals[i].removeRange(st, ed);
        }
      }
      _normalizeSignalLengths();
      _clearSelection();
      _forceRepaint();
    });

    // Commit signals to controller first to prevent listener from overwriting with old state
    _controller?.setSignals(signals);

    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    if (settings.timeUnitIsMs && deleteLen > 0) {
      List<double> durations = List<double>.from(
        (_controller?.stepDurationsMs.isNotEmpty ?? false)
            ? _controller!.stepDurationsMs
            : settings.stepDurationsMs,
      );
      if (durations.length < oldMaxLen) {
        durations.addAll(
          List<double>.filled(oldMaxLen - durations.length, settings.msPerStep),
        );
      }
      durations.removeRange(clampedSt, clampedEd);
      settings.setStepDurationsMs(durations);
      _controller?.setStepDurationsMs(durations);
    }

    if (deleteLen > 0) {
      final List<int> newOmission = [];
      for (final t in _omissionTimeIndices) {
        if (t < clampedSt) {
          newOmission.add(t);
        } else if (t >= clampedEd) {
          newOmission.add(t - deleteLen);
        }
      }
      _omissionTimeIndices = newOmission;
      _controller?.setOmissionTimeIndices(_omissionTimeIndices);
    }

    if (deleteLen > 0) {
      final List<TimingChartAnnotation> updated = [];
      for (final ann in annotations) {
        final int aStart = ann.startTimeIndex;
        final int aEnd = ann.endTimeIndex ?? ann.startTimeIndex;

        if (aEnd < clampedSt) {
          updated.add(ann);
        } else if (aStart >= clampedEd) {
          updated.add(
            ann.copyWith(
              startTimeIndex: aStart - deleteLen,
              endTimeIndex: ann.endTimeIndex != null ? aEnd - deleteLen : null,
            ),
          );
        } else {
          final int newEnd = clampedSt - 1;
          final int newStart = math.min(aStart, newEnd);
          if (newEnd >= 0 && newStart <= newEnd) {
            updated.add(
              ann.copyWith(
                startTimeIndex: newStart,
                endTimeIndex: ann.endTimeIndex != null ? newEnd : null,
              ),
            );
          }
        }
      }
      setState(() {
        annotations = updated;
        _forceRepaint();
      });
      _controller?.setAnnotations(annotations);
    }

    _commitSignalsFromChartEdit();
  }

  /// 信号から選択範囲を削除します
  ///
  /// 選択された信号行から選択された時間範囲を削除します。
  /// すべての表示信号が選択されている場合、列削除に委譲します。
  /// それ以外の場合は、選択された行からのみ削除します。
  void _deleteRange() {
    // More tolerant: verify index existence, then safely clamp and process
    if (_startSignalIndex == null ||
        _endSignalIndex == null ||
        _startTimeIndex == null ||
        _endTimeIndex == null) {
      return;
    }
    if (_visibleIndexes.isEmpty || signals.isEmpty) return;
    final stSig = math
        .min(_startSignalIndex!, _endSignalIndex!)
        .clamp(0, _visibleIndexes.length - 1);
    final edSig = math
        .max(_startSignalIndex!, _endSignalIndex!)
        .clamp(0, _visibleIndexes.length - 1);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    final bool allVisibleSelected =
        stSig == 0 && edSig == _visibleIndexes.length - 1;
    if (allVisibleSelected) {
      _deleteColumnsAtRange(stTime, edTime);
      return;
    }

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
      _forceRepaint();
    });
    _commitSignalsFromChartEdit();
  }

  /// 選択された時間範囲の列を削除します
  ///
  /// 選択された時間範囲について、時間列全体（すべての信号にわたる）を削除します。
  /// より寛容：時間インデックスの存在のみを確認し、その後安全に範囲をクランプして処理します。
  void _deleteColumns() {
    // More tolerant: only verify time index existence, then safely clamp and process range
    if (_startTimeIndex == null || _endTimeIndex == null) {
      debugPrint('deleteColumns: _startTimeIndex=$_startTimeIndex');
      debugPrint('deleteColumns: _endTimeIndex=$_endTimeIndex');
      return;
    }
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    debugPrint('deleteColumns: stTime=$stTime, edTime=$edTime');
    debugPrint(
      'deleteColumns: signals=${signals.map((e) => e.length).toList()}',
    );
    debugPrint(
      'deleteColumns: _visibleIndexes=${_visibleIndexes.map((e) => e).toList()}',
    );
    debugPrint('deleteColumns: _startSignalIndex=$_startSignalIndex');
    debugPrint('deleteColumns: _endSignalIndex=$_endSignalIndex');
    debugPrint('deleteColumns: _startTimeIndex=$_startTimeIndex');
    debugPrint('deleteColumns: _endTimeIndex=$_endTimeIndex');
    _deleteColumnsAtRange(stTime, edTime);
  }

  /// 選択範囲を信号の末尾に複製します
  ///
  /// 選択された信号と時間範囲をコピーし、各選択信号行の末尾に追加します。
  /// 選択範囲内にあるアノテーションと省略マークも複製します。
  /// ミリ秒単位を使用している場合は、ステップ継続時間を更新します。
  void _duplicateRange() {
    if (!_hasValidSelection) return;

    // Calculate start and end signal indices and time indices
    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);

    // Verify that calculated signal indices are within valid range
    if (stSig < 0 || edSig >= _visibleIndexes.length) return;

    // Step durations: prepare step durations array for duplication
    final int oldMaxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).reduce(math.max);
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    final int selectionLength = (edTime - stTime + 1).clamp(0, 1 << 30);
    List<double>? stepDurationsAfterDup;
    if (settings.timeUnitIsMs && selectionLength > 0) {
      final double defaultMs = settings.msPerStep;
      List<double> baseDurations = List<double>.from(
        (_controller?.stepDurationsMs.isNotEmpty ?? false)
            ? _controller!.stepDurationsMs
            : settings.stepDurationsMs,
      );
      if (baseDurations.length < oldMaxLen) {
        baseDurations.addAll(
          List<double>.filled(oldMaxLen - baseDurations.length, defaultMs),
        );
      } else if (baseDurations.length > oldMaxLen) {
        baseDurations = baseDurations.sublist(0, oldMaxLen);
      }
      final int safeStart = stTime.clamp(0, baseDurations.length);
      final int safeEnd = math.min(
        baseDurations.length,
        safeStart + selectionLength,
      );
      List<double> slice = baseDurations.sublist(safeStart, safeEnd);
      if (slice.length < selectionLength) {
        slice = [
          ...slice,
          ...List<double>.filled(selectionLength - slice.length, defaultMs),
        ];
      }
      stepDurationsAfterDup = List<double>.from(baseDurations)..addAll(slice);
    }

    setState(() {
      for (int visibleRow = stSig; visibleRow <= edSig; visibleRow++) {
        final originalRow = _visibleIndexes[visibleRow];
        final maxTimeForRow = signals[originalRow].length - 1;
        final clampedStTime = stTime.clamp(0, maxTimeForRow);
        final clampedEdTime = edTime.clamp(0, maxTimeForRow);
        if (clampedStTime > clampedEdTime) continue;

        final slice = signals[originalRow].sublist(
          clampedStTime,
          clampedEdTime + 1,
        );
        signals[originalRow].addAll(slice);
      }

      final List<TimingChartAnnotation> duplicatedAnnotations = [];
      for (final ann in annotations) {
        final annStart = ann.startTimeIndex;
        final int annEnd = ann.endTimeIndex ?? annStart;

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

      final List<int> newOmissions = [];
      for (final t in _omissionTimeIndices) {
        if (t >= stTime && t <= edTime) {
          newOmissions.add(t + (oldMaxLen - stTime));
        }
      }
      _omissionTimeIndices.addAll(newOmissions);

      _normalizeSignalLengths();
      _clearSelection();

      _forceRepaint();
    });

    _commitSignalsFromChartEdit();
    _controller?.setAnnotations(annotations);
    _controller?.setOmissionTimeIndices(_omissionTimeIndices);

    if (stepDurationsAfterDup != null) {
      final int newMaxLen =
          signals.isEmpty ? 0 : signals.map((e) => e.length).reduce(math.max);
      final double defaultMs = settings.msPerStep;
      if (stepDurationsAfterDup.length < newMaxLen) {
        stepDurationsAfterDup.addAll(
          List<double>.filled(
            newMaxLen - stepDurationsAfterDup.length,
            defaultMs,
          ),
        );
      } else if (stepDurationsAfterDup.length > newMaxLen) {
        stepDurationsAfterDup = stepDurationsAfterDup.sublist(0, newMaxLen);
      }
      settings.setStepDurationsMs(stepDurationsAfterDup);
      _controller?.setStepDurationsMs(stepDurationsAfterDup);
    }
  }

  /// すべての信号の長さを最長の信号に合わせて正規化します
  ///
  /// 短い信号にゼロ値をパディングして、すべての信号が同じ長さになるようにします。
  /// これにより、すべての信号行間で一貫した時間ステップ数が確保されます。
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

  /// 指定された時間インデックスで省略マークを切り替えます
  ///
  /// 指定された時間ステップで波線（省略マーク）を追加または削除します。
  /// 省略マークは、時間ステップがスキップまたは省略されていることを示します。
  ///
  /// [timeIndex] - 省略マークを切り替える時間ステップインデックス
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
    _controller?.setOmissionTimeIndices(_omissionTimeIndices);
  }

  /// 1ステップズームインします
  ///
  /// ズーム係数を_zoomStepだけ増やし、最大許可ズームにクランプします。
  void _zoomIn() {
    final double current = math.max(_zoomFactor, _minZoomFactorForView);
    final double next = math.min(current + _zoomStep, _maxZoomFactorForView);
    if ((next - _zoomFactor).abs() < 1e-6) return;
    setState(() {
      _zoomFactor = next;
    });
  }

  /// 1ステップズームアウトします
  ///
  /// ズーム係数を_zoomStepだけ減らし、最小許可ズームにクランプします。
  void _zoomOut() {
    final double current = math.max(_zoomFactor, _minZoomFactorForView);
    final double next = math.max(current - _zoomStep, _minZoomFactorForView);
    if ((next - _zoomFactor).abs() < 1e-6) return;
    setState(() {
      _zoomFactor = next;
    });
  }

  /// 可能であればズームをデフォルト（1.0）にリセットし、それ以外の場合は最小値にリセットします
  ///
  /// ズームを1.0に設定しようとしますが、1.0が許可範囲外の場合は最小ズームにフォールバックします。
  void _resetZoom() {
    final double preferred = 1.0;
    final double minAllowed = math.max(_minZoomFactorForView, _minZoom);
    final bool preferredInRange =
        preferred >= minAllowed - 1e-6 &&
        preferred <= _maxZoomFactorForView + 1e-6;
    final double target = preferredInRange ? preferred : minAllowed;
    if ((_zoomFactor - target).abs() < 1e-6) return;
    setState(() {
      _zoomFactor = target;
    });
  }

  /// 波形表示に使用可能なビューポートの幅を取得します
  ///
  /// マージンとラベル幅を総ウィジェット幅から減算して使用可能な幅を計算します。
  ///
  /// ビューポート幅（ピクセル）を返します
  double _getViewportWaveWidth() {
    final double widgetWidth = MediaQuery.of(context).size.width;
    final double viewportWaveWidth = widgetWidth - chartMarginLeft - labelWidth;
    return viewportWaveWidth.isFinite ? math.max(0.0, viewportWaveWidth) : 0.0;
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
        final dur =
            (i < durationsForLayout.length)
                ? durationsForLayout[i]
                : settings.msPerStep;
        totalSteps +=
            (settings.msPerStep > 0) ? (dur / settings.msPerStep) : 1.0;
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
        final dur =
            (i < durationsForLayout.length)
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
    final maxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);
    final visibleIndexes = _calculateVisibleIndexes();

    final availableWidth =
        constraints.maxWidth.isFinite
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
      baseCellWidth =
          totalSteps > 0 ? math.max(availableWidth / totalSteps, 5.0) : 40.0;
    } else {
      baseCellWidth =
          totalSteps > 0 ? math.max(availableWidth / totalSteps, 20.0) : 40.0;
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
    minCellWidthForFullView =
        minCellWidthForFullView
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

    final maxCellWidthAllowed =
        (baseCellWidth * zoomByRatio)
            .clamp(_minZoomCellWidth, _maxZoomCellWidth)
            .toDouble();

    minCellWidthForFullView = math.min(
      minCellWidthForFullView,
      maxCellWidthAllowed,
    );

    // Calculate zoom factors
    final minZoomFactorForView =
        baseCellWidth <= 0
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
        final dur =
            (i < durationsForLayout.length)
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

    final cellWidth =
        (baseCellWidth * effectiveZoomFactor)
            .clamp(minCellWidthForFullView, maxCellWidthAllowed)
            .toDouble();

    final commentAreaHeight = _calculateCommentAreaHeight();

    // Calculate cell height
    double constraintHeight =
        constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height;

    double cellHeight;
    if (widget.fitToScreen) {
      final availableHeight =
          constraintHeight - chartMarginTop - commentAreaHeight;
      final visibleRowCount = visibleIndexes.length;
      if (visibleRowCount > 0) {
        cellHeight = math.max(availableHeight / visibleRowCount, 5.0);
      } else {
        cellHeight = 40.0;
      }

      // Adjust for top controls
      const double topControlsHeight = 48.0;
      final adjustedAvailableHeight =
          (constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.of(context).size.height) -
          topControlsHeight -
          chartMarginTop -
          commentAreaHeight;
      if (visibleRowCount > 0) {
        cellHeight = math.max(adjustedAvailableHeight / visibleRowCount, 5.0);
      }
    } else {
      cellHeight = 40.0;
    }

    final totalWidth = chartMarginLeft + labelWidth + totalSteps * cellWidth;
    final totalHeight =
        chartMarginTop + visibleIndexes.length * cellHeight + commentAreaHeight;

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
      cellHeight: cellHeight,
      totalWidth: totalWidth,
      totalHeight: totalHeight,
      commentAreaHeight: commentAreaHeight,
      maxLen: maxLen,
    );
  }

  /// すべての信号にわたる総時間ステップ単位を計算します
  ///
  /// 総正規化ステップ単位を計算します。ミリ秒単位の場合、正規化された継続時間を合計します。
  /// ステップ単位の場合、最大信号長を返します。
  ///
  /// 総ステップ単位をdoubleとして返します
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

  /// ズーム後にアンカーポイントを維持するためにスクロール補正を適用します
  ///
  /// ズーム後、anchorXInWaveのポイントが同じ視覚的位置に残るようにスクロール位置を調整します。
  /// stepsUnitsBeforeを使用して新しいスクロールオフセットを計算します。
  ///
  /// [anchorXInWave] - 固定を維持する波形領域内のX位置
  /// [stepsUnitsBefore] - アンカーポイントより前のステップ単位
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

  /// ビューポートの中心をアンカーポイントとして維持しながらズームインします
  ///
  /// 1ステップズームインし、ビューポートの中心が同じ視覚的位置に残るようにスクロールを調整します。
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

  /// ビューポートの中心をアンカーポイントとして維持しながらズームアウトします
  ///
  /// 1ステップズームアウトし、ビューポートの中心が同じ視覚的位置に残るようにスクロールを調整します。
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

  /// ポインター信号イベント（マウスホイールスクロール）を処理します
  ///
  /// Ctrl/Cmdが押されている場合、スクロールホイールを使用してズームイン/アウトします。
  /// カーソル位置をズームのアンカーポイントとして維持します。
  ///
  /// [event] - ポインター信号イベント（通常はスクロールホイール）
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyAnchorScrollCorrection(
        anchorXInWave: anchorXInWave,
        stepsUnitsBefore: stepsUnitsBefore,
      );
    });
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
          child: RepaintBoundary(
            key: _viewportBoundaryKey,
            child: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart:
                      isEditingMode ? _onPanStartEditSteps : _onPanStart,
                  onPanUpdate:
                      isEditingMode ? _onPanUpdateEditSteps : _onPanUpdate,
                  onPanEnd: isEditingMode ? _onPanEndEditSteps : _onPanEnd,
                  onTapUp: isEditingMode ? _onTapUpEditSteps : _handleTap,
                  onLongPressStart: isEditingMode ? null : _onLongPressStart,
                  onLongPressMoveUpdate:
                      isEditingMode ? null : _onLongPressMoveUpdate,
                  onLongPressEnd: isEditingMode ? null : _onLongPressEnd,
                  onPanDown:
                      isEditingMode
                          ? null
                          : (details) {
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
                  onSecondaryTapDown:
                      isEditingMode
                          ? null
                          : (details) =>
                              _showContextMenu(context, details.globalPosition),
                  child: SingleChildScrollView(
                    controller: _hScrollController,
                    scrollDirection: Axis.horizontal,
                    physics:
                        (isEditingMode ||
                                _draggingAnnotationId != null ||
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
                            chartMarginLeft: chartMarginLeft,
                            chartMarginTop: chartMarginTop,
                            startSignalIndex:
                                isEditingMode ? null : _startSignalIndex,
                            endSignalIndex:
                                isEditingMode ? null : _endSignalIndex,
                            startTimeIndex:
                                isEditingMode ? null : _startTimeIndex,
                            endTimeIndex: isEditingMode ? null : _endTimeIndex,
                            highlightTimeIndices:
                                isEditingMode
                                    ? const []
                                    : _highlightTimeIndices,
                            omissionTimeIndices: _omissionTimeIndices,
                            selectedAnnotationId:
                                isEditingMode ? null : _selectedAnnotationId,
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
                                Theme.of(context).brightness == Brightness.dark
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
                                Theme.of(context).scaffoldBackgroundColor,
                            signalColors:
                                Provider.of<SettingsNotifier>(
                                  context,
                                ).signalColors,
                            onCommentAreaMeasured: _onCommentAreaMeasured,
                            draggingStartRow:
                                isEditingMode ? null : _labelDragStartRow,
                            draggingCurrentRow:
                                isEditingMode ? null : _labelDragCurrentRow,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  // ラベル領域は常に左端に固定する（編集モードでも位置/幅を変えない）
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
                          height: layoutData.totalHeight,
                          child: CustomPaint(
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
                                  Theme.of(context).scaffoldBackgroundColor,
                              labelWidth: labelWidth,
                              chartMarginLeft: chartMarginLeft,
                              cellHeight: layoutData.cellHeight,
                              highlightStartRow:
                                  isEditingMode ? null : _startSignalIndex,
                              highlightEndRow:
                                  isEditingMode ? null : _endSignalIndex,
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
        ),
      ],
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final settings = Provider.of<SettingsNotifier>(context);
              final layoutData = _calculateLayoutData(constraints, settings);
              return _buildChartContent(context, layoutData, settings, true);
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
                final layoutData = _calculateLayoutData(constraints, settings);
                return _buildChartContent(context, layoutData, settings, false);
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
      builder: (context, _) {
        final bool canUndo = _controller?.canUndo ?? false;
        final bool canRedo = _controller?.canRedo ?? false;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Undo'),
              onPressed:
                  canUndo
                      ? () {
                        _controller?.undo();
                      }
                      : null,
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.redo, size: 16),
              label: const Text('Redo'),
              onPressed:
                  canRedo
                      ? () {
                        _controller?.redo();
                      }
                      : null,
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
      },
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
      final double ms =
          (i < durations.length && settings.msPerStep > 0)
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
          Text('Labels:'),
          const SizedBox(width: 6),
          Switch(
            value: settings.showBottomUnitLabels,
            onChanged: (v) => settings.showBottomUnitLabels = v,
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
              onPressed: () {
                // 編集終了時に、現在の stepDurations をコントローラにも反映しておく
                // （Undo/Redoや他処理との整合のため）
                if (_isEditingSteps) {
                  final settings = Provider.of<SettingsNotifier>(
                    context,
                    listen: false,
                  );
                  _useControllerStepDurations = true;
                  _controller?.setStepDurationsMs(settings.stepDurationsMs);
                }
                setState(() {
                  _isEditingSteps = !_isEditingSteps;
                  _activeStepIndex = null;
                });
              },
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

  /// ステップ継続時間を一括編集するためのボタンを構築します
  ///
  /// カンマ区切りの値を使用してすべてのステップ継続時間を一度に編集できる
  /// ダイアログを開くボタンを作成します。
  ///
  /// ステップ継続時間編集ボタンウィジェットを返します
  // ignore: unused_element
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
          _useControllerStepDurations = true;
          _controller?.setStepDurationsMs(settings.stepDurationsMs);
        }
      },
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

  /// チャートをPNG画像としてキャプチャします
  ///
  /// RepaintBoundaryを使用してチャートコンテンツを画像にレンダリングし、
  /// PNGバイトを返します。より良い品質のために高いピクセル比を使用します。
  ///
  /// [pixelRatio] - オプションのピクセル比（デフォルトはデバイス比または3.0）
  /// PNG画像バイトを返します。キャプチャに失敗した場合はnullを返します
  Future<Uint8List?> captureChartPng({double? pixelRatio}) async {
    try {
      RenderRepaintBoundary? boundary =
          _viewportBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      boundary ??=
          _repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      final double defaultRatio =
          kIsWeb ? 2.0 : _defaultExportPixelRatio; // Webは負荷が高いので控えめに
      final double targetRatio =
          pixelRatio ?? math.max(devicePixelRatio, defaultRatio);
      final double maxRatio = kIsWeb ? 3.0 : _maxExportPixelRatio;
      final double pr = targetRatio.clamp(1.0, maxRatio).toDouble();
      final ui.Image image = await boundary.toImage(pixelRatio: pr);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing chart PNG: $e');
      return null;
    }
  }

  /// チャートをJPEG画像としてキャプチャします
  ///
  /// チャートコンテンツを画像にレンダリングし、JPEG形式に変換します。
  /// 背景色とのアルファチャネル合成を処理します。
  ///
  /// [pixelRatio] - オプションのピクセル比（デフォルトはデバイス比または3.0）
  /// [backgroundColor] - アルファ合成用の背景色（デフォルトはテーマ）
  /// [quality] - JPEG品質0-100（デフォルトは90）
  /// JPEG画像バイトを返します。キャプチャに失敗した場合はnullを返します
  Future<Uint8List?> captureChartJpeg({
    double? pixelRatio,
    Color? backgroundColor,
    int quality = 90,
  }) async {
    try {
      RenderRepaintBoundary? boundary =
          _viewportBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      boundary ??=
          _repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      final double defaultRatio =
          kIsWeb ? 2.0 : _defaultExportPixelRatio; // Webは負荷が高いので控えめに
      final double targetRatio =
          pixelRatio ?? math.max(devicePixelRatio, defaultRatio);
      final double maxRatio = kIsWeb ? 3.0 : _maxExportPixelRatio;
      final double pr = targetRatio.clamp(1.0, maxRatio).toDouble();

      final ui.Image image = await boundary.toImage(pixelRatio: pr);

      final width = image.width;
      final height = image.height;

      final theme = Theme.of(context);
      final Color bg =
          backgroundColor ??
          (theme.brightness == Brightness.dark ? Colors.black : Colors.white);

      // WebではDart側のJPEGエンコード（package:image）が非常に重いので、
      // ブラウザネイティブのCanvasエンコードに逃がす。
      if (kIsWeb) {
        final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (pngData == null) return null;
        final jpeg = await web_jpeg.pngToJpegBytes(
          pngData.buffer.asUint8List(),
          quality: quality,
          backgroundColorValue: bg.value,
        );
        return jpeg;
      }

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;

      final rgbaBytes = byteData.buffer.asUint8List();

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
        final int outR = ((r * a + rBg * (255 - a)) / 255).round();
        final int outG = ((g * a + gBg * (255 - a)) / 255).round();
        final int outB = ((b * a + bBg * (255 - a)) / 255).round();
        rgbBytes[di] = outR;
        rgbBytes[di + 1] = outG;
        rgbBytes[di + 2] = outB;
        si += 4;
        di += 3;
      }

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
    if (visibleRowIndex < 0 || visibleRowIndex >= _visibleIndexes.length)
      return;
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
    _focusNode.dispose();
    super.dispose();
  }

  /// 修飾キー（Ctrl/Cmd）の押下/解放イベントを処理します
  ///
  /// CtrlまたはCmdキーが押されたり解放されたりしたときに_isModifierPressed状態を更新します。
  /// 特定のインタラクションモードを有効/無効にするために使用されます。
  ///
  /// [event] - キーボードイベント
  /// イベント伝播を許可するためにfalseを返します
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

  /// チャート操作のキーボードイベントを処理します
  ///
  /// キーボードショートカットを処理します：
  /// - Ctrl/Cmd+Z: アンドゥ
  /// - Ctrl/Cmd+Y: リドゥ
  /// - Ctrl/Cmd+A: すべての信号を選択
  /// - 0/1キー: 選択範囲の信号値を0または1に設定
  ///
  /// [event] - キーボードイベント
  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final bool isModifierPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // 追加: キーボードで横スクロール（パン）
    // - ←/→: 少し移動（Shiftで加速）
    // - PageUp/PageDown: 1画面分移動
    // - Home/End: 先頭/末尾
    {
      final bool shift = HardwareKeyboard.instance.isShiftPressed;
      final double small = math.max(20.0, _cellWidth * 3);
      final double large = math.max(_getViewportWaveWidth() * 0.9, small * 10);

      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _scrollHorizontallyBy(-(shift ? small * 5 : small));
        return;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _scrollHorizontallyBy(shift ? small * 5 : small);
        return;
      }
      if (event.logicalKey == LogicalKeyboardKey.pageUp) {
        _scrollHorizontallyBy(-large);
        return;
      }
      if (event.logicalKey == LogicalKeyboardKey.pageDown) {
        _scrollHorizontallyBy(large);
        return;
      }
      if (event.logicalKey == LogicalKeyboardKey.home) {
        _scrollHorizontallyTo(0);
        return;
      }
      if (event.logicalKey == LogicalKeyboardKey.end) {
        if (_hScrollController.hasClients) {
          _scrollHorizontallyTo(_hScrollController.position.maxScrollExtent);
        }
        return;
      }
    }

    // アンドゥ/リドゥショートカット
    if (isModifierPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        // Ctrl+Z または Cmd+Z = アンドゥ
        if (_controller?.canUndo ?? false) {
          _controller?.undo();
        }
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.keyY) {
        // Ctrl+Y または Cmd+Y = リドゥ
        if (_controller?.canRedo ?? false) {
          _controller?.redo();
        }
        return;
      }
    }

    if (isModifierPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
      _selectAllSignals();
      return;
    }

    // 選択範囲がある場合、1/0キーで信号を設定
    if (_hasValidSelection) {
      if (event.logicalKey == LogicalKeyboardKey.digit1) {
        _setSignalsInSelection(1);
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.digit0) {
        _setSignalsInSelection(0);
        return;
      }
    }
  }

  void _scrollHorizontallyBy(double deltaPx) {
    if (!_hScrollController.hasClients) return;
    final pos = _hScrollController.position;
    final next = (_hScrollController.offset + deltaPx)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    try {
      _hScrollController.jumpTo(next);
    } catch (_) {
      // ignore jump errors
    }
  }

  void _scrollHorizontallyTo(double offsetPx) {
    if (!_hScrollController.hasClients) return;
    final pos = _hScrollController.position;
    final next = offsetPx.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    try {
      _hScrollController.jumpTo(next);
    } catch (_) {
      // ignore jump errors
    }
  }

  /// すべての時間ステップにわたってすべての表示信号を選択します
  ///
  /// 選択範囲を時間0から最大時間ステップまでのすべての表示信号行をカバーするように設定します。
  /// チャート状態を更新して選択範囲をハイライトします。
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

  /// 選択範囲内のすべての信号値を指定された値に設定します
  ///
  /// 選択範囲内のすべての信号値を0または1に設定します。
  /// キーボードショートカット（0/1キー）で信号状態を設定するために使用されます。
  ///
  /// [value] - 設定する値（0または1）
  void _setSignalsInSelection(int value) {
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
          signals[originalRow][t] = value;
        }
      }
      _highlightTimeIndices = [..._highlightTimeIndices];
      _forceRepaint();
    });
    _commitSignalsFromChartEdit();
  }

  /// 隣接する行と交換して信号行を上下に移動します
  ///
  /// 指定された表示インデックスの信号を（visibleIndex + direction）の信号と交換します。
  /// 関連する名前、タイプ、ポート番号、IOソース、ID名も交換します。
  ///
  /// [visibleIndex] - 移動する表示信号行インデックス
  /// [direction] - 移動方向（-1は上、+1は下）
  void _moveSignal(int visibleIndex, int direction) {
    final int targetVisible = visibleIndex + direction;
    if (targetVisible < 0 || targetVisible >= _visibleIndexes.length) return;

    final int srcIdx = _visibleIndexes[visibleIndex];
    final int dstIdx = _visibleIndexes[targetVisible];

    setState(() {
      final tmpSignal = signals[srcIdx];
      signals[srcIdx] = signals[dstIdx];
      signals[dstIdx] = tmpSignal;

      final tmpName = signalNames[srcIdx];
      signalNames[srcIdx] = signalNames[dstIdx];
      signalNames[dstIdx] = tmpName;

      final tmpType = widget.signalTypes[srcIdx];
      widget.signalTypes[srcIdx] = widget.signalTypes[dstIdx];
      widget.signalTypes[dstIdx] = tmpType;

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

      final tmpId = _idSignalNames[srcIdx];
      _idSignalNames[srcIdx] = _idSignalNames[dstIdx];
      _idSignalNames[dstIdx] = tmpId;

      _forceRepaint();
    });
  }

  /// 1つの行を新しい位置に移動して信号行を並べ替えます
  ///
  /// fromVisibleからtoVisibleへ信号行を移動します。これは隣接する行を繰り返し交換することで行われます。
  /// 信号ラベルをドラッグして並べ替える際に使用されます。
  ///
  /// [fromVisible] - ソース表示行インデックス
  /// [toVisible] - 宛先表示行インデックス
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

    // 行入替は signals と signalNames の両方を更新する操作なので、
    // コントローラへ順序も含めてコミットしないと、次の setSignals() で
    // 「古い順序」が上書きされて並びが戻ってしまう。
    _controller?.setSignalsAndNames(
      signals: signals,
      signalNames: _idSignalNames,
    );
    _notifySignalsChanged();
  }
}

/// タイミングチャートコンテンツをレンダリングするカスタムペインター
///
/// グリッド線、信号波形、アノテーション、選択範囲、省略マークの描画を処理します。
/// レンダリングの異なる側面（グリッド、信号、アノテーション）について、
/// 専門化されたマネージャークラスに委譲します。
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
    required this.onCommentAreaMeasured,
    this.draggingStartRow,
    this.draggingCurrentRow,
  }) {
    _annotationsManager = ChartAnnotationsManager(
      annotations: annotations,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      labelWidth: labelWidth,
      highlightTimeIndices: highlightTimeIndices,
      selectedAnnotationId: selectedAnnotationId,
      dashedColor: dashedColor,
      arrowColor: arrowColor,
      showBottomUnitLabels: showBottomUnitLabels,
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
      highlightTextColor: arrowColor,
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
  final bool showBottomUnitLabels;

  final int? draggingStartRow;
  final int? draggingCurrentRow;

  /// 描画済みアノテーションからコメント領域の必要高さを親にフィードバックするコールバック
  final void Function(double) onCommentAreaMeasured;

  late final ChartAnnotationsManager _annotationsManager;
  late final ChartGridManager _gridManager;
  late final ChartSignalsManager _signalsManager;

  @override
  void paint(Canvas canvas, Size size) {
    final double drawAreaWidth = size.width - chartMarginLeft;

    canvas.save();
    canvas.translate(chartMarginLeft, chartMarginTop);

    final rowCount = signals.length;

    final double maskHeight = rowCount * cellHeight + commentAreaHeight;
    final Paint labelMaskPaint =
        Paint()
          ..color = omissionFillColor
          ..style = PaintingStyle.fill;
    final double maskWidth = (labelWidth - 1).clamp(0.0, double.infinity);
    canvas.drawRect(Rect.fromLTWH(0, 0, maskWidth, maskHeight), labelMaskPaint);

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

    final maxTimeSteps =
        signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);
    _gridManager.drawGridLines(canvas, size, rowCount, maxTimeSteps);

    _gridManager.drawHighlightedLines(canvas, highlightTimeIndices, size);

    canvas.save();
    final double clipHeight = rowCount * cellHeight + commentAreaHeight;
    canvas.clipRect(
      Rect.fromLTWH(
        labelWidth + 1,
        0,
        drawAreaWidth - (labelWidth + 1),
        clipHeight,
      ),
    );
    _signalsManager.drawSignalWaveforms(canvas, signals);

    _drawOmissionLines(canvas, rowCount);
    canvas.restore();
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

    // 下部時間ラベル（単位）を先に描画し、その上にコメントボックスを重ねる
    _gridManager.drawTimeLabels(canvas, size, rowCount, maxTimeSteps);

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

    // --- コメント領域の実際の必要高さを計測してStateに通知 ---
    try {
      final double chartBottomY = rowCount * cellHeight;
      double maxBottom = chartBottomY;
      for (final rect in _annotationsManager.annotationRects.values) {
        if (rect.bottom > maxBottom) {
          maxBottom = rect.bottom;
        }
      }
      final double extra = math.max(0.0, maxBottom - chartBottomY);
      // コメントボックスの下に少し余白（20px）を付ける
      final double measuredHeight = math.max(40.0, extra + 20.0);
      onCommentAreaMeasured(measuredHeight);
    } catch (_) {
      // 計測に失敗しても描画自体には影響させない
    }

    annotationRects.clear();
    annotationRects.addAll(_annotationsManager.getAnnotationRects());

    canvas.restore();
  }

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
    bool signalsChanged = signals.length != oldDelegate.signals.length;

    if (!signalsChanged) {
      for (int i = 0; i < signals.length; i++) {
        if (signals[i].length != oldDelegate.signals[i].length) {
          signalsChanged = true;
          break;
        }

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
        timeUnitIsMs != oldDelegate.timeUnitIsMs ||
        msPerStep != oldDelegate.msPerStep ||
        !listEquals(stepDurationsMs, oldDelegate.stepDurationsMs) ||
        activeStepIndex != oldDelegate.activeStepIndex;
  }
}

/// 信号ラベルオーバーレイをレンダリングするカスタムペインター
///
/// 左マージン領域に信号名ラベルを描画します。
/// IOポート番号、プレフィックス、選択された行のハイライトを含みます。
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
    final bgPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.fill;
    final double overlayWidth = (chartMarginLeft + labelWidth - 1).clamp(
      0.0,
      double.infinity,
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, overlayWidth, size.height), bgPaint);

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
