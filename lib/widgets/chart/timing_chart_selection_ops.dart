part of 'timing_chart.dart';

/// 選択/編集操作（波形変更・列削除・複製・省略線など）をまとめた `part` ファイル。
///
/// - **目的**: `TimingChartState` の中でも副作用が多い編集操作群を分離し、見通しを良くする。
/// - **実装**: `extension on TimingChartState` にまとめ、同一ライブラリ内で private 状態へアクセスする。
/// - **注意**: `extension` から `setState()` は直接呼べないため、`TimingChartState._setState()` 経由で更新する。
extension _TimingChartSelectionOpsExt on TimingChartState {
  /// 指定された位置の単一信号値を切り替えます
  ///
  /// 指定された表示行と時間ステップインデックスで信号値を反転します（0から1、または1から0）。
  /// チャート状態を更新し、変更をコミットします。
  ///
  /// [visibleRow] - 表示信号行インデックス
  /// [time] - 時間ステップインデックス
  void _toggleSingleSignal(int visibleRow, int time) {
    if (!_canEditChartSignals) return;
    if (visibleRow >= 0 && visibleRow < _visibleIndexes.length) {
      final originalRow = _visibleIndexes[visibleRow];
      if (time >= 0 && time < signals[originalRow].length) {
        _setState(() {
          signals[originalRow][time] =
              (signals[originalRow][time] == 0) ? 1 : 0;
          _highlightTimeIndices = [..._highlightTimeIndices];
          _forceRepaint();
        });
        _commitSignalsFromChartEdit();
      }
    }
  }

  /// 現在の選択範囲内のすべての信号値を切り替えます
  ///
  /// 選択されたすべての信号行について、選択範囲内のすべての信号値を反転します（0から1、または1から0）。
  /// 変更をコントローラーにコミットします。
  void _toggleSignalsInSelection() {
    if (!_canEditChartSignals) return;
    if (!_hasValidSelection) return;
    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    if (stSig < 0 || edSig >= _visibleIndexes.length) return;
    _setState(() {
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
    if (!_canEditChartSignals) return;
    if (!_hasValidSelection) return;
    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    if (stSig < 0 || edSig >= _visibleIndexes.length) return;
    final lengthToInsert = (edTime - stTime + 1);
    if (lengthToInsert <= 0) return;
    _setState(() {
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

    _setState(() {
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
      _setState(() {
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
    if (!_canEditChartSignals) return;
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

    _setState(() {
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
    if (!_canEditChartSignals) return;
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
    if (!_canEditChartSignals) return;
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

    _setState(() {
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
    _setState(() {
      if (_omissionTimeIndices.contains(timeIndex)) {
        _omissionTimeIndices.remove(timeIndex);
      } else {
        _omissionTimeIndices.add(timeIndex);
      }
      _forceRepaint();
    });
    _controller?.setOmissionTimeIndices(_omissionTimeIndices);
  }

  /// すべての時間ステップにわたってすべての表示信号を選択します
  ///
  /// 選択範囲を時間0から最大時間ステップまでのすべての表示信号行をカバーするように設定します。
  /// チャート状態を更新して選択範囲をハイライトします。
  void _selectAllSignals() {
    if (signals.isEmpty || _visibleIndexes.isEmpty) return;
    _setState(() {
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
    if (!_canEditChartSignals) return;
    if (!_hasValidSelection) return;
    final stSig = math.min(_startSignalIndex!, _endSignalIndex!);
    final edSig = math.max(_startSignalIndex!, _endSignalIndex!);
    final stTime = math.min(_startTimeIndex!, _endTimeIndex!);
    final edTime = math.max(_startTimeIndex!, _endTimeIndex!);
    if (stSig < 0 || edSig >= _visibleIndexes.length) return;

    _setState(() {
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
}


