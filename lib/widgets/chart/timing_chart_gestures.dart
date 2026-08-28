part of 'timing_chart.dart';

/// ジェスチャー処理（Tap/Pan/LongPress/ContextMenu）をまとめた `part` ファイル。
///
/// - **目的**: 入力/ジェスチャー処理は分岐と状態更新が多いため、`TimingChartState` から切り離して見通しを良くする。
/// - **実装**: `*_Impl` メソッドを `extension on TimingChartState` に集約し、
///   `TimingChartState` 側には GestureDetector から参照する薄いラッパーだけを残す。
/// - **注意**:
///   - `extension` から `setState()` は直接呼べないため、`TimingChartState._setState()` 経由で更新する。
///   - `onSecondaryTapDown` など `async void` にしづらい箇所は `discarded_futures` を明示して呼び出す。
extension _TimingChartGesturesExt on TimingChartState {
  void _onPanDownImpl(DragDownDetails details) {
    final chartLocalPos = details.localPosition;
    for (final entry in _annotationHitRects.entries) {
      final rect = entry.value;
      final adjustedPos = Offset(
        chartLocalPos.dx -
            chartMarginLeft +
            (_hScrollController.hasClients ? _hScrollController.offset : 0),
        chartLocalPos.dy -
            _effectiveChartTopMargin +
            (_vScrollController.hasClients ? _vScrollController.offset : 0),
      );
      if (rect.contains(adjustedPos)) {
        _setState(() {
          _beginAnnotationDrag(entry.key, chartLocalPos, rect);
        });
        break;
      }
    }
  }

  void _onSecondaryTapDownImpl(TapDownDetails details) {
    // NOTE: build の context をそのまま渡すと analyzer 上は別メソッド扱いになるため、
    // ここでは State の context を使って従来どおりメニューを出す。
    // ignore: discarded_futures
    _showContextMenu(context, details.globalPosition);
  }

  void _handleTapImpl(TapUpDetails details) {
    final chartLocalPos = details.localPosition;
    final adjustedPos = Offset(
      chartLocalPos.dx -
          chartMarginLeft +
          (_hScrollController.hasClients ? _hScrollController.offset : 0),
      chartLocalPos.dy -
          _effectiveChartTopMargin +
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
      _setState(() {
        _selectedAnnotationId = hitAnnId;
      });
      _clearSelection();
      return;
    } else {
      if (_selectedAnnotationId != null) {
        _setState(() {
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
          _setState(() {
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
        _effectiveChartTopMargin + (stSigAbs * _cellHeight).toDouble(),
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
      }
    } else {
      _toggleSingleSignal(clickSig, clickTim);
    }
  }

  void _onPanStartImpl(DragStartDetails details) {
    final chartLocalPos = details.localPosition;

    final adjustedPosForAnn = Offset(
      chartLocalPos.dx -
          chartMarginLeft +
          (_hScrollController.hasClients ? _hScrollController.offset : 0),
      chartLocalPos.dy -
          _effectiveChartTopMargin +
          (_vScrollController.hasClients ? _vScrollController.offset : 0),
    );
    for (final entry in _annotationHitRects.entries) {
      final rect = entry.value;
      if (rect.contains(adjustedPosForAnn)) {
        _setState(() {
          _beginAnnotationDrag(entry.key, chartLocalPos, rect);
        });
        _dragStartGlobal = null;
        return;
      }
    }

    final bool inLabelArea =
        chartLocalPos.dx >= chartMarginLeft &&
        chartLocalPos.dx <= chartMarginLeft + labelWidth;

    final sigIndex = _getSignalIndexFromDy(chartLocalPos.dy);
    if (inLabelArea &&
        !_isChartEditLocked &&
        sigIndex >= 0 &&
        sigIndex < _visibleIndexes.length) {
      _setState(() {
        _isLabelDrag = true;
        _labelDragStartRow = sigIndex;
        _labelDragCurrentRow = sigIndex;
      });
      return;
    }

    if (chartLocalPos.dy >
        _effectiveChartTopMargin + _visibleIndexes.length * _cellHeight) {
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

    _setState(() {
      _dragStartGlobal = details.globalPosition;
      _startSignalIndex = sig;
      _endSignalIndex = sig;
      _startTimeIndex = tim;
      _endTimeIndex = tim;
      _selectedAnnotationId = null;
    });
  }

  void _onPanUpdateImpl(DragUpdateDetails details) {
    if (_draggingAnnotationId != null &&
        _draggingInitialBoxTopLeft != null &&
        _draggingStartFingerLocalY != null) {
      _applyAnnotationDragFromChartLocalPos(details.localPosition);
      return;
    }
    if (_isLabelDrag) {
      final chartLocalPos = details.localPosition;
      int sig = _getSignalIndexFromDy(chartLocalPos.dy);
      sig = sig.clamp(0, _visibleIndexes.length - 1);
      if (sig != _labelDragCurrentRow) {
        _setState(() {
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

    _setState(() {
      _endSignalIndex = clampedSig;
      _endTimeIndex = clampedTim;
    });
  }

  void _onPanEndImpl(DragEndDetails details) {
    if (_draggingAnnotationId != null) {
      _setState(() {
        _clearAnnotationDragState();
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
      _setState(() {
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

    _setState(() {
      _dragStartGlobal = null;
    });
  }

  void _onLongPressStartImpl(LongPressStartDetails details) {
    final chartLocalPos = details.localPosition;
    final adjustedPos = Offset(
      chartLocalPos.dx -
          chartMarginLeft +
          (_hScrollController.hasClients ? _hScrollController.offset : 0),
      chartLocalPos.dy -
          _effectiveChartTopMargin +
          (_vScrollController.hasClients ? _vScrollController.offset : 0),
    );
    for (final entry in _annotationHitRects.entries) {
      final rect = entry.value;
      if (rect.contains(adjustedPos)) {
        _setState(() {
          _beginAnnotationDrag(entry.key, chartLocalPos, rect);
        });
        return;
      }
    }
  }

  void _onLongPressMoveUpdateImpl(LongPressMoveUpdateDetails details) {
    if (_draggingAnnotationId == null ||
        _draggingInitialBoxTopLeft == null ||
        _draggingStartFingerLocalY == null) {
      return;
    }
    _applyAnnotationDragFromChartLocalPos(details.localPosition);
  }

  void _onLongPressEndImpl(LongPressEndDetails details) {
    if (_draggingAnnotationId != null) {
      _setState(() {
        _clearAnnotationDragState();
      });
      _forceRepaint();
    }
  }

  Future<void> _showContextMenuImpl(
    BuildContext context,
    Offset position,
  ) async {
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
      chartLocalPos.dy - _effectiveChartTopMargin,
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
    int? menuLabelRow;

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
      final bool inLabelArea =
          chartLocalPos.dx >= chartMarginLeft &&
          chartLocalPos.dx <= chartMarginLeft + labelWidth;
      final int labelRow = _getSignalIndexFromDy(chartLocalPos.dy);

      if (inLabelArea) {
        if (labelRow >= 0 &&
            labelRow < _visibleIndexes.length &&
            _canEditSignalLabelForVisibleRow(labelRow)) {
          menuLabelRow = labelRow;
          menuItems = [
            PopupMenuItem(
              value: 'signalProperties',
              child: Text(s.ctx_signal_properties),
            ),
          ];
        } else {
          return;
        }
      } else {
        _setState(() {
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
          if (_canEditChartSignals && _hasValidSelection)
            PopupMenuItem(value: 'insert', child: Text(s.ctx_insert_zeros)),
          if (_canEditChartSignals)
            PopupMenuItem(
              value: 'duplicate',
              child: Text(s.ctx_duplicate_to_tail),
            ),
          PopupMenuItem(
            value: 'selectAll',
            child: Text(s.ctx_select_all_signals),
          ),
          if (_canEditChartSignals && _hasValidSelection)
            PopupMenuItem(value: 'delete', child: Text(s.ctx_delete_selection)),
          if (_canEditChartSignals && _hasValidSelection)
            PopupMenuItem(
              value: 'deleteColumns',
              child: Text(s.ctx_delete_columns),
            ),
          PopupMenuItem(value: 'addComment', child: Text(s.ctx_add_comment)),
          PopupMenuItem(value: 'omit', child: Text(s.ctx_draw_omission)),
        ];
      }
    }

    final selectedValue = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: menuItems,
    );

    _setState(() {
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
        case 'signalProperties':
          if (menuLabelRow != null) {
            _editSignalLabelProperties(menuLabelRow);
          }
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
              _setState(() {
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

  /// 上部クリップ内にコメントボックス全体が収まる最小の top（チャートローカルY）
  double _minAllowedCommentTop(double boxHeight) {
    const double topPadding = 8.0;
    const double maxTop = TimingChartState._maxTopCommentAreaHeight;
    final double minTopFlush = -(maxTop - topPadding);
    if (boxHeight <= 0) return minTopFlush;
    final double minTopFullBox = -(maxTop - topPadding - boxHeight);
    if (minTopFullBox <= 0 && minTopFullBox > minTopFlush) {
      return minTopFullBox;
    }
    return minTopFlush;
  }

  /// ドラッグ中の上部余白プレビュー（ペインター計測と同じ +8px パディング）
  double _computeDragPreviewTopExtent({
    required String? draggingId,
    double? draggingBoxTop,
  }) {
    const double topPadding = 8.0;
    const maxTop = TimingChartState._maxTopCommentAreaHeight;
    double extent = 0.0;

    void consider(double top) {
      if (top < 0) {
        extent = math.max(extent, math.min(-top + topPadding, maxTop));
      }
    }

    for (final entry in _annotationHitRects.entries) {
      if (entry.key == draggingId) continue;
      consider(entry.value.top);
    }
    if (draggingBoxTop != null) {
      consider(draggingBoxTop);
    }
    return extent;
  }

  /// コメントドラッグ開始時の状態を初期化
  void _beginAnnotationDrag(
    String annId,
    Offset chartLocalPos,
    Rect rect,
  ) {
    _draggingAnnotationId = annId;
    _draggingInitialBoxTopLeft = rect.topLeft;
    _draggingBoxSize = Size(rect.width, rect.height);
    _selectedAnnotationId = annId;

    final hScroll =
        _hScrollController.hasClients ? _hScrollController.offset : 0.0;
    _draggingStartFingerChartX =
        chartLocalPos.dx - chartMarginLeft + hScroll;
    _draggingStartFingerLocalY = chartLocalPos.dy;

    _dragPreviewTopExtent = _topCommentAreaHeight;
  }

  /// ドラッグ中の指位置（CustomPaint ローカル）から placement / offset を更新する
  void _applyAnnotationDragFromChartLocalPos(Offset chartLocalPos) {
    if (_draggingAnnotationId == null ||
        _draggingInitialBoxTopLeft == null ||
        _draggingBoxSize == null ||
        _draggingStartFingerLocalY == null ||
        _draggingStartFingerChartX == null) {
      return;
    }

    const double topPadding = 8.0;
    const double maxTop = TimingChartState._maxTopCommentAreaHeight;
    final double boxHeight = _draggingBoxSize!.height;
    final double minAllowedTop = _minAllowedCommentTop(boxHeight);

    final hScroll =
        _hScrollController.hasClients ? _hScrollController.offset : 0.0;
    final currentChartX = chartLocalPos.dx - chartMarginLeft + hScroll;
    final fingerDeltaY = chartLocalPos.dy - _draggingStartFingerLocalY!;

    var proposedTopLeft = Offset(
      _draggingInitialBoxTopLeft!.dx +
          (currentChartX - _draggingStartFingerChartX!),
      _draggingInitialBoxTopLeft!.dy + fingerDeltaY,
    );

    if (proposedTopLeft.dy < minAllowedTop) {
      proposedTopLeft = Offset(proposedTopLeft.dx, minAllowedTop);
    }

    var newPreview = _computeDragPreviewTopExtent(
      draggingId: _draggingAnnotationId,
      draggingBoxTop:
          proposedTopLeft.dy < 0 ? proposedTopLeft.dy : null,
    );

    // 描画クリップ（-topCommentAreaHeight）内に必ず収まるよう余白を位置と同期
    if (proposedTopLeft.dy < 0) {
      final double neededExtent = math.min(
        -proposedTopLeft.dy + topPadding,
        maxTop,
      );
      newPreview = math.max(newPreview, neededExtent);
    }

    final String newPlacement =
        proposedTopLeft.dy < 0 ? 'top' : 'bottom';

    final annIndex = annotations.indexWhere(
      (a) => a.id == _draggingAnnotationId,
    );
    if (annIndex == -1) return;

    final current = annotations[annIndex];
    final baseTopLeft = _computeCommentBaseTopLeft(
      current,
      newPlacement,
      _draggingBoxSize!,
    );
    final double newOffsetX = proposedTopLeft.dx - baseTopLeft.dx;
    final double newOffsetY = proposedTopLeft.dy - baseTopLeft.dy;

    _dragPreviewTopExtent = newPreview;
    _setState(() {
      annotations[annIndex] = current.copyWith(
        placement: newPlacement,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
      );
      _highlightTimeIndices = [..._highlightTimeIndices];
      _forceRepaint();
    });
    _controller?.setAnnotations(annotations);
  }

  void _clearAnnotationDragState() {
    final lastPreview = _dragPreviewTopExtent;
    _draggingAnnotationId = null;
    _draggingInitialBoxTopLeft = null;
    _draggingBoxSize = null;
    _draggingStartFingerLocalY = null;
    _draggingStartFingerChartX = null;
    _dragPreviewTopExtent = 0.0;
    if (lastPreview > 0) {
      _measuredTopCommentAreaHeight = lastPreview;
    }
  }

  /// コメント配置の境界 index → チャートローカル X（chart_annotations と同等）
  double _commentBoundaryX(int boundaryIndex, SettingsNotifier settings) {
    if (!settings.timeUnitIsMs) {
      return labelWidth + boundaryIndex * _cellWidth;
    }
    final durations = _durationsForLayout(settings);
    final double msPerStep = settings.msPerStep;
    double steps = 0.0;
    for (int t = 0; t < boundaryIndex; t++) {
      final durSteps =
          (t < durations.length && msPerStep > 0)
              ? durations[t] / msPerStep
              : 1.0;
      steps += durSteps;
    }
    return labelWidth + steps * _cellWidth;
  }

  /// 衝突回避なしの既定コメントボックス左上（placement 別）
  Offset _computeCommentBaseTopLeft(
    TimingChartAnnotation ann,
    String placement,
    Size boxSize,
  ) {
    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    final double chartBottomY = _visibleIndexes.length * _cellHeight;
    const double bottomLabelAvoidOffset = 20.0;
    final double labelExtraY =
        settings.showBottomUnitLabels ? bottomLabelAvoidOffset : 0.0;
    final double boxWidth = boxSize.width;
    final double boxHeight = boxSize.height;
    final double startX = _commentBoundaryX(ann.startTimeIndex, settings);

    if (placement == 'top') {
      const double topArrowGap = 12.0;
      final double arrowBaseY = -topArrowGap;
      if (ann.endTimeIndex != null) {
        final double arrowStartX = startX;
        final double arrowEndX =
            _commentBoundaryX(ann.endTimeIndex! + 1, settings);
        const double arrowThickness = 4;
        final Rect arrowRect = Rect.fromLTWH(
          arrowStartX,
          arrowBaseY - arrowThickness / 2,
          arrowEndX - arrowStartX,
          arrowThickness,
        );
        double commentY;
        if (boxWidth <= arrowRect.width) {
          commentY = arrowRect.center.dy - boxHeight / 2;
          if (commentY + boxHeight > 0) {
            commentY = arrowRect.top - boxHeight - 5;
          }
        } else {
          commentY = arrowRect.top - boxHeight - 5;
        }
        final double commentX = arrowRect.center.dx - boxWidth / 2;
        return Offset(commentX, commentY);
      }
      final double commentY = -topArrowGap - 6 - boxHeight;
      return Offset(startX, commentY);
    }

    if (ann.endTimeIndex != null) {
      final double arrowBaseY = chartBottomY + 10 + labelExtraY;
      final double arrowStartX = startX;
      final double arrowEndX =
          _commentBoundaryX(ann.endTimeIndex! + 1, settings);
      const double arrowThickness = 4;
      final Rect arrowRect = Rect.fromLTWH(
        arrowStartX,
        arrowBaseY - arrowThickness / 2,
        arrowEndX - arrowStartX,
        arrowThickness,
      );
      double commentX;
      double commentY;
      if (boxWidth <= arrowRect.width) {
        commentY = arrowRect.center.dy - boxHeight / 2;
        if (commentY < 0) {
          commentY = arrowRect.bottom + 5;
        }
      } else {
        commentY = arrowRect.bottom + 5;
      }
      commentX = arrowRect.center.dx - boxWidth / 2;
      return Offset(commentX, commentY);
    }

    final double baseCommentY = chartBottomY + 20 + labelExtraY;
    return Offset(startX, baseCommentY);
  }
}
