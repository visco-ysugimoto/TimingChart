part of 'timing_chart.dart';

/// ステップ継続時間編集（Edit grid）関連をまとめた `part` ファイル。
///
/// - **目的**: Edit grid は通常モードと別の入力/状態を持つため、編集モードのロジックを分離して可読性を上げる。
/// - **内容**: Edit grid の Pan/Tap 処理、スナップ計算、編集モード切替など。
/// - **注意**:
///   - `extension` から `setState()` は直接呼べないため、`TimingChartState._setState()` 経由で更新する。
///   - controller/settings の同期は Undo/Redo 整合のため重要なので、移動時も挙動を変えない。
extension _TimingChartEditStepsExt on TimingChartState {
  void _toggleEditGridModeImpl() {
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
    _setState(() {
      _isEditingSteps = !_isEditingSteps;
      _activeStepIndex = null;
    });
  }

  void _onPanStartEditStepsImpl(DragStartDetails details) {
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
    _setState(() => _activeStepIndex = nearest);
  }

  void _onPanUpdateEditStepsImpl(DragUpdateDetails details) {
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

  void _onPanEndEditStepsImpl(DragEndDetails details) {
    // ドラッグ編集は「編集モード自体」を終了させず、選択中境界だけ解除する。
    // ここで stepDurationsMs を空にすると編集結果が消えてしまうため行わない。
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    _useControllerStepDurations = true;
    _controller?.setStepDurationsMs(settings.stepDurationsMs);
    _setState(() {
      _activeStepIndex = null;
    });
  }

  int _findNearestStepIndexImpl(
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

  void _onTapUpEditStepsImpl(TapUpDetails details) {
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
      _setState(() {
        _activeStepIndex = nearest;
      });
      return;
    }

    final idx = _findNearestStepIndexImpl(
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
      _setState(() => _activeStepIndex = idx);
    });
  }

  /// ステップ継続時間をカンマ区切りで一括編集するダイアログを開きます。
  ///
  /// `TimingChartState` 側ではフォーカス制御（ショートカット衝突回避）を行うため、
  /// `_focusNode` を一時的に `canRequestFocus=false` にしてからダイアログを表示します。
  Future<void> _onEditStepDurationsPressedImpl() async {
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    final maxLen =
        signals.isEmpty ? 0 : signals.map((e) => e.length).fold(0, math.max);
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
              builder: _buildEditStepDurationsDialogImpl(controller),
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
  }

  Widget Function(BuildContext) _buildEditStepDurationsDialogImpl(
    TextEditingController controller,
  ) {
    return (ctx) => AlertDialog(
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
        );
  }
}


