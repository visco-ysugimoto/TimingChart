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

/// Layout calculation data structure for timing chart rendering.
/// 
/// This class holds all computed layout values needed to render the timing chart,
/// including cell dimensions, zoom factors, and visible signal indexes.
/// These values are calculated once per layout pass and reused throughout rendering.
class _ChartLayoutData {
  /// List of visible signal row indexes after filtering by signal type
  final List<int> visibleIndexes;
  
  /// Total number of time steps (may be fractional when using ms units)
  final double totalSteps;
  
  /// Base cell width before zoom is applied
  final double baseCellWidth;
  
  /// Minimum cell width required to show all content in viewport
  final double minCellWidthForFullView;
  
  /// Maximum allowed cell width based on zoom constraints
  final double maxCellWidthAllowed;
  
  /// Minimum zoom factor allowed for current view
  final double minZoomFactorForView;
  
  /// Maximum zoom factor allowed for current view
  final double maxZoomFactorForView;
  
  /// Effective zoom factor after clamping to min/max bounds
  final double effectiveZoomFactor;
  
  /// Actual cell width used for rendering (baseCellWidth * effectiveZoomFactor)
  final double cellWidth;
  
  /// Height of each signal row cell
  final double cellHeight;
  
  /// Total width of the chart content area
  final double totalWidth;
  
  /// Total height of the chart content area including comment area
  final double totalHeight;
  
  /// Height reserved for annotation comments at the bottom
  final double commentAreaHeight;
  
  /// Maximum length of all signal arrays (longest signal)
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

/// Helper class for time position calculations in timing charts.
/// 
/// Provides static utility methods for converting between pixel positions
/// and time step indices, handling both step-based and millisecond-based time units.
class _TimePositionCalculator {
  /// Calculate cumulative step positions array for time unit conversion.
  /// 
  /// When using millisecond units, each step may have a different duration.
  /// This method calculates the cumulative position of each step boundary
  /// in normalized step units (where 1.0 = one base step duration).
  /// 
  /// Returns an array of length maxLen + 1, where pos[i] is the cumulative
  /// position at the start of step i, and pos[maxLen] is the total position.
  /// 
  /// [settings] - Settings containing msPerStep and time unit configuration
  /// [maxLen] - Maximum number of time steps
  /// [stepDurationsMs] - Array of durations in milliseconds for each step
  /// Returns array of cumulative step positions
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

  /// Get time step index from relative X position in pixels.
  /// 
  /// Converts a pixel position (relative to the start of the wave area)
  /// into the corresponding time step index. Handles both step-based
  /// and millisecond-based time units correctly.
  /// 
  /// [relX] - X position in pixels relative to wave area start
  /// [cellWidth] - Width of one cell in pixels
  /// [settings] - Settings containing time unit configuration
  /// [maxLen] - Maximum number of time steps
  /// [stepDurationsMs] - Array of durations in milliseconds for each step
  /// Returns the time step index, or -1 if invalid
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

/// A StatefulWidget that displays an interactive timing diagram chart.
/// 
/// This widget renders a timing chart showing signal waveforms over time,
/// with support for zooming, panning, editing, annotations, and various
/// display modes. It handles both step-based and millisecond-based time units.
class TimingChart extends StatefulWidget {
  /// Initial signal names (IDs) for each signal row
  final List<String> initialSignalNames;
  
  /// Initial signal data: list of signal rows, each row is a list of 0/1 values over time
  final List<List<int>> initialSignals;
  
  /// Initial annotations (comments) to display on the chart
  final List<TimingChartAnnotation> initialAnnotations;
  
  /// Signal types for each signal row (input, output, control, etc.)
  final List<SignalType> signalTypes;
  
  /// Optional controller for managing chart state and undo/redo
  final TimingChartController? controller;
  
  /// Whether to automatically fit chart to screen size
  final bool fitToScreen;

  /// Whether to show all signal types including control/group/task signals
  final bool showAllSignalTypes;
  
  /// Whether to show IO port numbers in signal labels
  final bool showIoNumbers;
  
  /// Port numbers for each signal (used when showIoNumbers is true)
  final List<int> portNumbers;
  
  /// IO channel sources for each signal (PLC, EIP, etc.)
  final List<IoChannelSource> ioSources;
  
  /// PLC/EIP mode setting ('PLC', 'EIP', or 'None')
  final String plcEipMode;
  
  /// Callback invoked when signal values are changed by user interaction
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

/// State class for the TimingChart widget.
/// 
/// Manages all chart state including signals, annotations, zoom, selection,
/// and user interactions. Uses AutomaticKeepAliveClientMixin to preserve
/// state when widget is not visible.
class TimingChartState extends State<TimingChart>
    with AutomaticKeepAliveClientMixin {
  /// Controller for managing chart state and undo/redo operations
  TimingChartController? _controller;
  
  /// Callback listener for controller state changes
  late final VoidCallback _controllerListener;
  
  /// Signal names in their original ID form (before translation)
  late List<String> _idSignalNames;
  
  /// Callback listener for language changes (for signal name translation)
  late final VoidCallback _langListener;

  @override
  bool get wantKeepAlive => true;

  /// Signal data: list of rows, each row contains 0/1 values for each time step
  late List<List<int>> signals;
  
  /// Display names for signals (may be translated from IDs)
  late List<String> signalNames;
  
  /// Annotations (comments) displayed on the chart
  late List<TimingChartAnnotation> annotations;
  
  /// Time step indices to highlight with special visual styling
  List<int> _highlightTimeIndices = [];
  
  /// Time step indices where omission marks (wavy lines) should be drawn
  List<int> _omissionTimeIndices = [];
  
  /// List of signal row indexes that are currently visible (after filtering)
  List<int> _visibleIndexes = [];

  /// Whether user is currently dragging a signal label to reorder rows
  bool _isLabelDrag = false;
  
  /// Starting row index when dragging a label
  int? _labelDragStartRow;
  
  /// Current row index during label drag operation
  int? _labelDragCurrentRow;

  /// Width of each time step cell in pixels
  double _cellWidth = 40;
  
  /// Height of each signal row cell in pixels
  double _cellHeight = 40;
  
  /// Horizontal zoom factor (1.0 = no zoom, >1.0 = zoomed in)
  double _zoomFactor = 1.0;
  
  /// Effective zoom factor after clamping to min/max bounds
  double _effectiveZoomFactor = 1.0;
  
  /// Minimum zoom factor allowed for current view
  double _minZoomFactorForView = 1.0;
  
  /// Maximum zoom factor allowed for current view
  double _maxZoomFactorForView = 10.0;
  
  /// Absolute minimum zoom factor (hard limit)
  static const double _minZoom = 0.1;
  
  /// Step size for zoom in/out operations
  static const double _zoomStep = 0.25;
  
  /// Minimum allowed cell width in pixels
  static const double _minZoomCellWidth = 2.0;
  
  /// Maximum allowed cell width in pixels
  static const double _maxZoomCellWidth = 20000.0;
  
  /// Default pixel ratio for chart export/capture
  static const double _defaultExportPixelRatio = 3.0;
  
  /// Maximum pixel ratio for chart export/capture
  static const double _maxExportPixelRatio = 6.0;

  /// Whether modifier key (Ctrl/Cmd) is currently pressed
  bool _isModifierPressed = false;
  
  /// Width of the signal label area on the left side
  final double labelWidth = 200.0;
  
  /// Minimum height for the comment area at bottom
  static const double _minCommentAreaHeight = 100.0;

  /// Bottom margin when no comments are present
  static const double _noCommentBottomMargin = 40.0;

  /// Whether to show advanced timing controls (currently always false)
  bool get _showAdvancedTimingControls => false;

  /// Calculate the height needed for the comment area at the bottom of the chart.
  /// 
  /// The height is based on the number of annotations, with a minimum height
  /// to ensure readability. Returns a fixed margin if there are no annotations.
  /// 
  /// Returns the calculated height in pixels
  double _calculateCommentAreaHeight() {
    if (annotations.isEmpty) return _noCommentBottomMargin;

    const double baseHeight = 40.0;
    const double stepHeight = 20.0;
    final int layers = annotations.length - 1;
    final double estimated = baseHeight + stepHeight * layers;

    final double expanded = estimated * 1.5;

    return math.max(_minCommentAreaHeight, expanded);
  }

  /// Zoom the chart to fit the currently selected time range.
  /// 
  /// Calculates the appropriate zoom factor to make the selected time range
  /// fill the viewport, then adjusts scroll position to keep the selection visible.
  /// Only works when there is a valid selection.
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

    final List<double> durationsForLayout =
        (_controller?.stepDurationsMs.isNotEmpty ?? false)
            ? _controller!.stepDurationsMs
            : settings.stepDurationsMs;

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

  /// Starting signal row index of selection (in visible index space)
  int? _startSignalIndex;
  
  /// Ending signal row index of selection (in visible index space)
  int? _endSignalIndex;
  
  /// Starting time step index of selection
  int? _startTimeIndex;
  
  /// Ending time step index of selection
  int? _endTimeIndex;

  /// Last right-click position for context menu
  Offset? _lastRightClickPos;

  /// ID of currently selected annotation (if any)
  String? _selectedAnnotationId;

  /// Map of annotation IDs to their hit test rectangles
  Map<String, Rect> _annotationHitRects = {};
  
  /// ID of annotation currently being dragged
  String? _draggingAnnotationId;
  
  /// Local position where annotation drag started
  Offset? _draggingStartLocal;
  
  /// Initial top-left position of annotation box when drag started
  Offset? _draggingInitialBoxTopLeft;

  /// Global position where pan/drag gesture started
  Offset? _dragStartGlobal;

  /// Key for the CustomPaint widget that renders the chart
  final GlobalKey _customPaintKey = GlobalKey();
  
  /// Key for the RepaintBoundary around the chart content
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  
  /// Key for the RepaintBoundary around the viewport
  final GlobalKey _viewportBoundaryKey = GlobalKey();
  
  /// Horizontal scroll controller for chart content
  final ScrollController _hScrollController = ScrollController();
  
  /// Vertical scroll controller for chart content
  final ScrollController _vScrollController = ScrollController();

  /// Whether step duration editing mode is active
  bool _isEditingSteps = false;
  
  /// Index of the step boundary currently being edited (when editing mode is on)
  int? _activeStepIndex;

  /// Initialize the state when the widget is first created.
  /// 
  /// Sets up signal names, translations, keyboard handlers, and controller.
  /// Registers listeners for language changes and controller updates.
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
      if (settingsRW.stepDurationsMs.length != maxLen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) settingsRW.ensureStepDurationsLength(maxLen);
        });
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

  /// Reset all grid adjustments including zoom, selection, and scroll position.
  /// 
  /// Called when the grid is reset from the controller. Resets zoom to 1.0,
  /// clears selection and highlights, and scrolls to top-left.
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

  /// Update signal data from external source.
  /// 
  /// [newSignals] - New signal data to replace current signals
  void updateSignals(List<List<int>> newSignals) {
    setState(() {
      signals = newSignals.map((list) => List<int>.from(list)).toList();
      _forceRepaint();
    });
    _controller?.setSignals(signals);
  }

  /// Notify parent widget that signals have changed.
  /// 
  /// Invokes the onSignalsChanged callback if provided.
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

  /// Commit signal changes from chart editing to controller and notify parent.
  /// 
  /// Called after user edits signals directly on the chart.
  void _commitSignalsFromChartEdit() {
    _controller?.setSignals(signals);
    _notifySignalsChanged();
  }

  /// Update annotations from external source.
  /// 
  /// [newAnnotations] - New annotations to replace current ones
  void updateAnnotations(List<TimingChartAnnotation> newAnnotations) {
    setState(() {
      annotations = List.from(newAnnotations);
      _forceRepaint();
    });
    _controller?.setAnnotations(annotations);
  }

  /// Update signal names from external source.
  /// 
  /// [newIdNames] - New signal ID names to replace current ones
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

  /// Translate signal names from IDs to display names based on current language.
  /// 
  /// Asynchronously loads translations for all signal names and updates
  /// the display names. Handles names with colon prefixes (e.g., "Type: id").
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
          a[i].text != b[i].text) {
        return false;
      }
    }
    return true;
  }

  /// Check if there is a valid selection range.
  /// 
  /// A selection is valid if all four indices are set and within bounds:
  /// - Signal indices must be within visible signal range
  /// - Time indices must be within signal data range
  /// 
  /// Returns true if selection is valid, false otherwise
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

  /// Get time step index from X coordinate (dx) in widget coordinates.
  /// 
  /// Converts a pixel position to a time step index, accounting for
  /// scroll offset and label area width. Handles both step and ms time units.
  /// 
  /// [dx] - X coordinate in widget local coordinates
  /// Returns time step index, or -1 if invalid
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

  /// Get signal row index from Y coordinate (dy) in widget coordinates.
  /// 
  /// Converts a pixel position to a signal row index, accounting for
  /// scroll offset and chart margin. Returns the visible signal index.
  /// 
  /// [dy] - Y coordinate in widget local coordinates
  /// Returns visible signal row index, or -1 if invalid
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

  /// Clear the current selection range.
  /// 
  /// Resets all selection indices (signal and time) to null.
  /// Only updates state if there was an active selection.
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

  /// Handle tap gesture on the chart.
  /// 
  /// Processes tap events to handle annotation selection, signal row selection,
  /// and signal value toggling. If tapping on a label area, selects the entire row.
  /// If tapping on a signal cell, toggles its value. If tapping within an existing
  /// selection, toggles all signals in that selection.
  /// 
  /// [details] - Tap gesture details containing tap position
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

  /// Toggle a single signal value at the specified position.
  /// 
  /// Flips the signal value (0 to 1, or 1 to 0) at the given visible row
  /// and time step index. Updates the chart state and commits changes.
  /// 
  /// [visibleRow] - Visible signal row index
  /// [time] - Time step index
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

  /// Handle pan gesture start.
  /// 
  /// Initiates drag operations for annotations, signal row reordering,
  /// or selection range. Determines the type of drag based on the starting
  /// position (annotation, label area, or chart area).
  /// 
  /// [details] - Pan gesture start details containing initial position
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

  /// Handle pan gesture update.
  /// 
  /// Updates the current drag operation. Handles annotation dragging,
  /// signal row reordering, or selection range expansion based on the
  /// active drag type.
  /// 
  /// [details] - Pan gesture update details containing current position
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

  /// Handle pan gesture end.
  /// 
  /// Completes the drag operation. For annotation dragging, finalizes position.
  /// For signal row reordering, applies the reorder if valid. For selection,
  /// clears selection if it's a single point.
  /// 
  /// [details] - Pan gesture end details
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

  // =====step duration editing =====
  
  /// Handle pan gesture start for step duration editing mode.
  /// 
  /// When editing step durations, finds the nearest step boundary to the
  /// starting position and sets it as the active step index for dragging.
  /// 
  /// [details] - Pan gesture start details containing initial position
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

  /// Handle pan gesture update for step duration editing mode.
  /// 
  /// Updates the duration of the active step boundary based on the current
  /// drag position. Calculates new duration in milliseconds and updates settings.
  /// 
  /// [details] - Pan gesture update details containing current position
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

  /// Handle pan gesture end for step duration editing mode.
  /// 
  /// Exits step duration editing mode and clears the active step index.
  /// Resets step durations list to trigger recalculation.
  /// 
  /// [details] - Pan gesture end details
  void _onPanEndEditSteps(DragEndDetails details) {
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    settings.setStepDurationsMs([]);
    setState(() {
      _isEditingSteps = false;
      _activeStepIndex = null;
    });
  }

  /// Find nearest step index from relative X position with snap distance.
  /// 
  /// Calculates which time step boundary is closest to the given X position.
  /// If within snap distance, returns that boundary index. Otherwise, returns
  /// the step index containing that position.
  /// 
  /// [relX] - Relative X position in pixels (from label area start)
  /// [settings] - Settings containing time unit configuration
  /// [maxLen] - Maximum number of time steps
  /// [stepDurationsMs] - Array of step durations in milliseconds
  /// [snapDistance] - Maximum pixel distance for snapping to boundary
  /// Returns the nearest step index
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

  /// Handle tap gesture in step duration editing mode.
  /// 
  /// When tapping in edit mode, either snaps to a nearby step boundary
  /// or opens a dialog to manually enter the duration for the tapped step.
  /// 
  /// [details] - Tap gesture details containing tap position
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
      setState(() => _activeStepIndex = idx);
    });
  }

  /// Handle long press gesture start.
  /// 
  /// Initiates annotation dragging when long pressing on an annotation.
  /// Sets up drag state variables for the annotation.
  /// 
  /// [details] - Long press gesture start details containing initial position
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

  /// Handle long press gesture move update.
  /// 
  /// Updates annotation position during long press drag. Clamps movement
  /// to prevent dragging above the chart area.
  /// 
  /// [details] - Long press gesture move update details containing current position
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

  /// Handle long press gesture end.
  /// 
  /// Completes annotation dragging and clears drag state variables.
  /// 
  /// [details] - Long press gesture end details
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

  /// Show context menu at the specified position.
  /// 
  /// Displays a context menu with actions based on what was right-clicked:
  /// - If clicking on an annotation: edit/delete annotation options
  /// - If clicking on chart area: selection manipulation options
  /// Handles menu item selection and executes the corresponding action.
  /// 
  /// [context] - Build context for showing the menu
  /// [position] - Global position where the menu should appear
  void _showContextMenu(BuildContext context, Offset position) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    _lastRightClickPos = position;

    final RenderBox? rootBox = context.findRenderObject() as RenderBox?;
    final Offset rootLocalPos =
        rootBox != null ? rootBox.globalToLocal(position) : position;

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

    final int clickedSig = _getSignalIndexFromDy(rootLocalPos.dy);

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

  /// Show dialog to add a new single-point annotation.
  /// 
  /// Opens a dialog at the last right-click position allowing the user
  /// to enter text for a new annotation at a specific time step.
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

  /// Show dialog to add a new range annotation.
  /// 
  /// Opens a dialog allowing the user to enter text for a new annotation
  /// that spans the currently selected time range.
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

  /// Edit an existing annotation's text.
  /// 
  /// Opens a dialog allowing the user to modify the text of the annotation
  /// with the given ID. Updates the annotation if text is changed.
  /// 
  /// [annId] - ID of the annotation to edit
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

  /// Delete an annotation.
  /// 
  /// Removes the annotation with the given ID from the chart.
  /// Also clears selection if this annotation was selected.
  /// 
  /// [annId] - ID of the annotation to delete
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

  /// Toggle all signal values within the current selection.
  /// 
  /// Flips all signal values (0 to 1, or 1 to 0) in the selected range
  /// for all selected signal rows. Commits changes to controller.
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

  /// Insert zero values into the selected range.
  /// 
  /// Inserts a number of zero values equal to the selection width at the
  /// start of the selection for all selected signal rows. This effectively
  /// shifts existing values to the right.
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

  /// Delete time columns at the specified range.
  /// 
  /// Removes time steps from all signals within the given time range.
  /// Also updates step durations, omission indices, and annotations to
  /// reflect the deletion. This is used when deleting entire columns.
  /// 
  /// [stTime] - Start time index (inclusive)
  /// [edTime] - End time index (inclusive)
  void _deleteColumnsAtRange(int stTime, int edTime) {
    debugPrint('deleteColumnsAtRange: stTime=$stTime, edTime=$edTime');
    debugPrint('deleteColumnsAtRange: signals=${signals.map((e) => e.length).toList()}');
    debugPrint('deleteColumnsAtRange: _visibleIndexes=${_visibleIndexes.map((e) => e).toList()}');
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

  /// Delete the selected range from signals.
  /// 
  /// Removes the selected time range from the selected signal rows.
  /// If all visible signals are selected, delegates to column deletion.
  /// Otherwise, removes only from the selected rows.
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

  /// Delete columns at the selected time range.
  /// 
  /// Removes entire time columns (across all signals) for the selected
  /// time range. More tolerant: only verifies time index existence,
  /// then safely clamps and processes the range.
  void _deleteColumns() {
    // More tolerant: only verify time index existence, then safely clamp and process range
    if (_startTimeIndex == null || _endTimeIndex == null){
      debugPrint('deleteColumns: _startTimeIndex=$_startTimeIndex');
      debugPrint('deleteColumns: _endTimeIndex=$_endTimeIndex');
      return;
    }
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    debugPrint('deleteColumns: stTime=$stTime, edTime=$edTime');
    debugPrint('deleteColumns: signals=${signals.map((e) => e.length).toList()}');
    debugPrint('deleteColumns: _visibleIndexes=${_visibleIndexes.map((e) => e).toList()}');
    debugPrint('deleteColumns: _startSignalIndex=$_startSignalIndex');
    debugPrint('deleteColumns: _endSignalIndex=$_endSignalIndex');
    debugPrint('deleteColumns: _startTimeIndex=$_startTimeIndex');
    debugPrint('deleteColumns: _endTimeIndex=$_endTimeIndex');
    _deleteColumnsAtRange(stTime, edTime);
  }

  /// Duplicate the selected range to the end of signals.
  /// 
  /// Copies the selected signal and time range, appending it to the end
  /// of each selected signal row. Also duplicates annotations and omission
  /// marks that fall within the selection. Updates step durations if using ms units.
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

  /// Normalize all signal lengths to match the longest signal.
  /// 
  /// Pads shorter signals with zero values so all signals have the same length.
  /// This ensures consistent time step counts across all signal rows.
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

  /// Toggle omission mark at the specified time index.
  /// 
  /// Adds or removes a wavy line (omission mark) at the given time step.
  /// Omission marks indicate that time steps are skipped or omitted.
  /// 
  /// [timeIndex] - Time step index to toggle omission mark
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

  /// Zoom in by one step.
  /// 
  /// Increases zoom factor by _zoomStep, clamped to maximum allowed zoom.
  void _zoomIn() {
    final double current = math.max(_zoomFactor, _minZoomFactorForView);
    final double next = math.min(current + _zoomStep, _maxZoomFactorForView);
    if ((next - _zoomFactor).abs() < 1e-6) return;
    setState(() {
      _zoomFactor = next;
    });
  }

  /// Zoom out by one step.
  /// 
  /// Decreases zoom factor by _zoomStep, clamped to minimum allowed zoom.
  void _zoomOut() {
    final double current = math.max(_zoomFactor, _minZoomFactorForView);
    final double next = math.max(current - _zoomStep, _minZoomFactorForView);
    if ((next - _zoomFactor).abs() < 1e-6) return;
    setState(() {
      _zoomFactor = next;
    });
  }

  /// Reset zoom to default (1.0) if possible, otherwise to minimum.
  /// 
  /// Attempts to set zoom to 1.0, but falls back to minimum zoom if
  /// 1.0 is outside the allowed range.
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

  /// Get the width of the viewport available for wave display.
  /// 
  /// Calculates available width by subtracting margins and label width
  /// from total widget width.
  /// 
  /// Returns viewport width in pixels
  double _getViewportWaveWidth() {
    final double widgetWidth = MediaQuery.of(context).size.width;
    final double viewportWaveWidth = widgetWidth - chartMarginLeft - labelWidth;
    return viewportWaveWidth.isFinite ? math.max(0.0, viewportWaveWidth) : 0.0;
  }

  /// Calculate list of visible signal row indexes based on signal type filtering.
  /// 
  /// Filters out control, group, and task signals unless showAllSignalTypes is true.
  /// Returns indexes of signals that should be displayed in the chart.
  /// 
  /// Returns list of visible signal row indexes
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

  /// Calculate total number of time steps (may be fractional for ms units).
  /// 
  /// When using millisecond units, sums up the normalized durations of all steps.
  /// When using step units, returns the count of steps.
  /// 
  /// [settings] - Settings containing time unit configuration
  /// [maxLen] - Maximum number of time steps
  /// [durationsForLayout] - Array of step durations in milliseconds
  /// Returns total steps as a double (may be fractional)
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

  /// Calculate zoom ratio for cell width
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

  /// Calculate all layout data needed for chart rendering.
  /// 
  /// This is the main layout calculation method that computes cell dimensions,
  /// zoom factors, visible indexes, and total chart dimensions based on
  /// current constraints, signal data, and settings.
  /// 
  /// [constraints] - Box constraints from parent widget
  /// [settings] - Settings containing time unit and display configuration
  /// Returns _ChartLayoutData containing all computed layout values
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
    final List<double> durationsForLayout =
        (_controller?.stepDurationsMs.isNotEmpty ?? false)
            ? _controller!.stepDurationsMs
            : settings.stepDurationsMs;

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

  /// Compute total time step units across all signals.
  /// 
  /// Calculates the total normalized step units. For ms units, sums up
  /// normalized durations. For step units, returns the maximum signal length.
  /// 
  /// Returns total step units as a double
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

  /// Apply scroll correction to maintain anchor point after zoom.
  /// 
  /// After zooming, adjusts scroll position so that the point at anchorXInWave
  /// remains at the same visual position. Uses stepsUnitsBefore to calculate
  /// the new scroll offset.
  /// 
  /// [anchorXInWave] - X position in wave area to keep fixed
  /// [stepsUnitsBefore] - Step units before the anchor point
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

  /// Zoom in while maintaining center of viewport as anchor point.
  /// 
  /// Zooms in by one step and adjusts scroll to keep the center of the
  /// viewport at the same visual position.
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

  /// Zoom out while maintaining center of viewport as anchor point.
  /// 
  /// Zooms out by one step and adjusts scroll to keep the center of the
  /// viewport at the same visual position.
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

  /// Handle pointer signal events (mouse wheel scrolling).
  /// 
  /// When Ctrl/Cmd is pressed, uses scroll wheel to zoom in/out.
  /// Maintains the cursor position as the zoom anchor point.
  /// 
  /// [event] - Pointer signal event (typically scroll wheel)
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

  /// Build chart content widget
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
                            stepDurationsMs: settingsRW.stepDurationsMs,
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
                  left: isEditingMode ? chartMarginLeft : 0,
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
                          width:
                              isEditingMode
                                  ? labelWidth
                                  : chartMarginLeft + labelWidth,
                          height: layoutData.totalHeight,
                          child: CustomPaint(
                            isComplex: false,
                            willChange: true,
                            size: Size(
                              isEditingMode
                                  ? labelWidth
                                  : chartMarginLeft + labelWidth,
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

  /// Compute total duration in milliseconds for the current selection.
  /// 
  /// Sums up the step durations for all time steps within the selection range.
  /// Returns 0.0 if there is no valid selection.
  /// 
  /// [settings] - Settings containing step duration configuration
  /// Returns total duration in milliseconds
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

  /// Compute number of time steps in the current selection.
  /// 
  /// Calculates the width of the selection in time steps.
  /// Returns 0 if there is no valid selection.
  /// 
  /// Returns number of steps in selection
  int _computeSelectionSteps() {
    if (!_hasValidSelection) return 0;
    final int stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final int edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    return (edTime - stTime + 1).clamp(0, 1 << 30);
  }

  /// Build a label string describing the current selection.
  /// 
  /// Returns a formatted string showing either the duration in milliseconds
  /// or the number of steps, depending on the current time unit setting.
  /// 
  /// [settings] - Settings containing time unit configuration
  /// Returns formatted selection label string
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

  /// Build the unit toggle and control panel widget.
  /// 
  /// Creates a container with switches for time unit (ms/step) and bottom labels,
  /// along with zoom controls and selection information. May include advanced
  /// timing controls if enabled.
  /// 
  /// [context] - Build context
  /// Returns the unit toggle widget
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

  /// Build text field for editing milliseconds per step.
  /// 
  /// Creates a small text input field that allows users to set the base
  /// milliseconds per step value used for time unit conversion.
  /// 
  /// Returns the ms/step input field widget
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

  /// Build button for editing step durations in bulk.
  /// 
  /// Creates a button that opens a dialog allowing users to edit all step
  /// durations at once using comma-separated values.
  /// 
  /// Returns the edit step durations button widget
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
        }
      },
    );
  }

  /// Force a repaint of the chart CustomPaint widget.
  /// 
  /// Manually triggers a repaint by marking the CustomPaint render object
  /// as needing paint. Used when state changes don't automatically trigger repaint.
  void _forceRepaint() {
    final customPaint = _customPaintKey.currentContext?.findRenderObject();
    if (customPaint is RenderCustomPaint) {
      customPaint.markNeedsPaint();
    }
  }

  /// Capture the chart as a PNG image.
  /// 
  /// Renders the chart content to an image using RepaintBoundary and returns
  /// the PNG bytes. Uses high pixel ratio for better quality.
  /// 
  /// [pixelRatio] - Optional pixel ratio (defaults to device ratio or 3.0)
  /// Returns PNG image bytes, or null if capture fails
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
      final double targetRatio =
          pixelRatio ?? math.max(devicePixelRatio, _defaultExportPixelRatio);
      final double pr = targetRatio.clamp(1.0, _maxExportPixelRatio).toDouble();
      final ui.Image image = await boundary.toImage(pixelRatio: pr);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing chart PNG: $e');
      return null;
    }
  }

  /// Capture the chart as a JPEG image.
  /// 
  /// Renders the chart content to an image and converts to JPEG format.
  /// Handles alpha channel compositing with background color.
  /// 
  /// [pixelRatio] - Optional pixel ratio (defaults to device ratio or 3.0)
  /// [backgroundColor] - Background color for alpha compositing (defaults to theme)
  /// [quality] - JPEG quality 0-100 (defaults to 90)
  /// Returns JPEG image bytes, or null if capture fails
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
      final double targetRatio =
          pixelRatio ?? math.max(devicePixelRatio, _defaultExportPixelRatio);
      final double pr = targetRatio.clamp(1.0, _maxExportPixelRatio).toDouble();

      final ui.Image image = await boundary.toImage(pixelRatio: pr);

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;

      final width = image.width;
      final height = image.height;
      final rgbaBytes = byteData.buffer.asUint8List();

      final theme = Theme.of(context);
      final Color bg =
          backgroundColor ??
          (theme.brightness == Brightness.dark ? Colors.black : Colors.white);

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

  /// Set annotation arrow tip to point at a specific signal row.
  /// 
  /// Updates the vertical position of an annotation's arrow tip to point
  /// at the center of the specified visible signal row.
  /// 
  /// [annId] - ID of the annotation to update
  /// [visibleRowIndex] - Visible signal row index to point at
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

  /// Handle modifier key (Ctrl/Cmd) press/release events.
  /// 
  /// Updates the _isModifierPressed state when Ctrl or Cmd keys are pressed
  /// or released. Used to enable/disable certain interaction modes.
  /// 
  /// [event] - Keyboard event
  /// Returns false to allow event propagation
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

  /// Handle keyboard events for chart interactions.
  /// 
  /// Processes keyboard shortcuts:
  /// - Ctrl/Cmd+Z: Undo
  /// - Ctrl/Cmd+Y: Redo
  /// - Ctrl/Cmd+A: Select all signals
  /// - 0/1 keys: Set signal values in selection to 0 or 1
  /// 
  /// [event] - Keyboard event
  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final bool isModifierPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // Undo/Redoショートカット
    if (isModifierPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        // Ctrl+Z または Cmd+Z = Undo
        if (_controller?.canUndo ?? false) {
          _controller?.undo();
        }
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.keyY) {
        // Ctrl+Y または Cmd+Y = Redo
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

  /// Select all visible signals across all time steps.
  /// 
  /// Sets selection to cover all visible signal rows from time 0 to the
  /// maximum time step. Updates chart state to highlight the selection.
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

  /// Set all signal values in selection to the specified value.
  /// 
  /// Sets all signal values within the selected range to either 0 or 1.
  /// Used for keyboard shortcuts (0/1 keys) to set signal states.
  /// 
  /// [value] - Value to set (0 or 1)
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

  /// Move a signal row up or down by swapping with adjacent row.
  /// 
  /// Swaps the signal at the given visible index with the signal at
  /// (visibleIndex + direction). Also swaps associated names, types,
  /// port numbers, IO sources, and ID names.
  /// 
  /// [visibleIndex] - Visible signal row index to move
  /// [direction] - Direction to move (-1 for up, +1 for down)
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

  /// Reorder signal rows by moving one row to a new position.
  /// 
  /// Moves the signal row from fromVisible to toVisible by repeatedly
  /// swapping adjacent rows. Used when dragging signal labels to reorder.
  /// 
  /// [fromVisible] - Source visible row index
  /// [toVisible] - Destination visible row index
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

/// Custom painter for rendering the timing chart content.
/// 
/// Handles drawing of grid lines, signal waveforms, annotations, selections,
/// and omission marks. Delegates to specialized manager classes for different
/// aspects of rendering (grid, signals, annotations).
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

    _gridManager.drawTimeLabels(canvas, size, rowCount, maxTimeSteps);

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

/// Custom painter for rendering signal labels overlay.
/// 
/// Draws the signal name labels in the left margin area, including
/// IO port numbers, prefixes, and highlighting for selected rows.
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
