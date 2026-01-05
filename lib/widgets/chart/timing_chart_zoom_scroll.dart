part of 'timing_chart.dart';

/// ズーム/スクロール（アンカー補正、ホイールズーム、キーボード横スクロール）をまとめた `part` ファイル。
///
/// - **目的**: 表示スケールとスクロール補正はチャート全体に影響するため、関連ロジックを一箇所に集約する。
/// - **実装**: `extension on TimingChartState` に `*_Impl` として実装し、State 側は薄いラッパーで委譲する。
/// - **注意**:
///   - `extension` から `static` メンバー参照する場合は `TimingChartState.` 修飾が必要。
///   - スクロール補正は `WidgetsBinding.instance.addPostFrameCallback` と組み合わせる前提の箇所がある。
extension _TimingChartZoomScrollExt on TimingChartState {
  void _zoomToSelectionFitImpl() {
    if (!_hasValidSelection) return;
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    final bool isMs = settings.timeUnitIsMs;

    final int stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final int edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    if (stTime < 0 || edTime < stTime) return;

    final double viewportWaveWidth = _getViewportWaveWidthImpl();
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

    _setState(() {
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
      _applyAnchorScrollCorrectionImpl(
        anchorXInWave: 0.0,
        stepsUnitsBefore: stepsUnitsBefore,
      );
    });
  }

  void _zoomInImpl() {
    final double current = math.max(_zoomFactor, _minZoomFactorForView);
    final double next = math.min(
      current + TimingChartState._zoomStep,
      _maxZoomFactorForView,
    );
    if ((next - _zoomFactor).abs() < 1e-6) return;
    _setState(() {
      _zoomFactor = next;
    });
  }

  void _zoomOutImpl() {
    final double current = math.max(_zoomFactor, _minZoomFactorForView);
    final double next = math.max(
      current - TimingChartState._zoomStep,
      _minZoomFactorForView,
    );
    if ((next - _zoomFactor).abs() < 1e-6) return;
    _setState(() {
      _zoomFactor = next;
    });
  }

  void _resetZoomImpl() {
    final double preferred = 1.0;
    final double minAllowed = math.max(
      _minZoomFactorForView,
      TimingChartState._minZoom,
    );
    final bool preferredInRange =
        preferred >= minAllowed - 1e-6 &&
        preferred <= _maxZoomFactorForView + 1e-6;
    final double target = preferredInRange ? preferred : minAllowed;
    if ((_zoomFactor - target).abs() < 1e-6) return;
    _setState(() {
      _zoomFactor = target;
    });
  }

  double _getViewportWaveWidthImpl() {
    final double widgetWidth = MediaQuery.of(context).size.width;
    final double viewportWaveWidth = widgetWidth - chartMarginLeft - labelWidth;
    return viewportWaveWidth.isFinite ? math.max(0.0, viewportWaveWidth) : 0.0;
  }

  double _computeTotalStepUnitsImpl() {
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

  void _applyAnchorScrollCorrectionImpl({
    required double anchorXInWave,
    required double stepsUnitsBefore,
  }) {
    final double viewportWaveWidth = _getViewportWaveWidthImpl();
    final double contentWidth = _computeTotalStepUnitsImpl() * _cellWidth;
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

  void _zoomInWithAnchorAtCenterImpl() {
    final double viewportWaveWidth = _getViewportWaveWidthImpl();
    final double anchorXInWave = viewportWaveWidth / 2;
    final double scrollBefore =
        _hScrollController.hasClients ? _hScrollController.offset : 0.0;
    final double stepsUnitsBefore =
        (scrollBefore + anchorXInWave) / (_cellWidth <= 0 ? 1.0 : _cellWidth);
    _zoomInImpl();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyAnchorScrollCorrectionImpl(
        anchorXInWave: anchorXInWave,
        stepsUnitsBefore: stepsUnitsBefore,
      );
    });
  }

  void _zoomOutWithAnchorAtCenterImpl() {
    final double viewportWaveWidth = _getViewportWaveWidthImpl();
    final double anchorXInWave = viewportWaveWidth / 2;
    final double scrollBefore =
        _hScrollController.hasClients ? _hScrollController.offset : 0.0;
    final double stepsUnitsBefore =
        (scrollBefore + anchorXInWave) / (_cellWidth <= 0 ? 1.0 : _cellWidth);
    _zoomOutImpl();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyAnchorScrollCorrectionImpl(
        anchorXInWave: anchorXInWave,
        stepsUnitsBefore: stepsUnitsBefore,
      );
    });
  }

  void _handlePointerSignalImpl(PointerSignalEvent event) {
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

    double viewportWaveWidth = _getViewportWaveWidthImpl();
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
      _zoomInImpl();
    } else if (dominantDelta > 0) {
      _zoomOutImpl();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyAnchorScrollCorrectionImpl(
        anchorXInWave: anchorXInWave,
        stepsUnitsBefore: stepsUnitsBefore,
      );
    });
  }

  bool _handleHorizontalScrollKeysImpl(KeyDownEvent event) {
    // 追加: キーボードで横スクロール（パン）
    // - ←/→: 少し移動（Shiftで加速）
    // - PageUp/PageDown: 1画面分移動
    // - Home/End: 先頭/末尾
    final bool shift = HardwareKeyboard.instance.isShiftPressed;
    final double small = math.max(20.0, _cellWidth * 3);
    final double large = math.max(
      _getViewportWaveWidthImpl() * 0.9,
      small * 10,
    );

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _scrollHorizontallyByImpl(-(shift ? small * 5 : small));
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _scrollHorizontallyByImpl(shift ? small * 5 : small);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      _scrollHorizontallyByImpl(-large);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      _scrollHorizontallyByImpl(large);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      _scrollHorizontallyToImpl(0);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      if (_hScrollController.hasClients) {
        _scrollHorizontallyToImpl(_hScrollController.position.maxScrollExtent);
      }
      return true;
    }
    return false;
  }

  void _scrollHorizontallyByImpl(double deltaPx) {
    if (!_hScrollController.hasClients) return;
    final pos = _hScrollController.position;
    final next = (_hScrollController.offset + deltaPx).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    try {
      _hScrollController.jumpTo(next);
    } catch (_) {
      // ignore jump errors
    }
  }

  void _scrollHorizontallyToImpl(double offsetPx) {
    if (!_hScrollController.hasClients) return;
    final pos = _hScrollController.position;
    final next = offsetPx.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    try {
      _hScrollController.jumpTo(next);
    } catch (_) {
      // ignore jump errors
    }
  }
}
