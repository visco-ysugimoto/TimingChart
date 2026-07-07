part of 'timing_chart.dart';

/// 行の並べ替え（ラベルドラッグ等）関連をまとめた `part` ファイル。
///
/// - **目的**: signals/names/types/ports/ioSources の同時更新は読み手に負荷が高いので、
///   まとまった責務として切り出して流れを追いやすくする。
/// - **注意**: 行入替は controller へ「順序込み」でコミットしないと、次の setSignals() 等で順序が戻る。
extension _TimingChartRowReorderExt on TimingChartState {
  /// 隣接する行と交換して信号行を上下に移動します。
  void _moveSignalImpl(int visibleIndex, int direction) {
    final int targetVisible = visibleIndex + direction;
    if (targetVisible < 0 || targetVisible >= _visibleIndexes.length) return;

    final int srcIdx = _visibleIndexes[visibleIndex];
    final int dstIdx = _visibleIndexes[targetVisible];

    _setState(() {
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

      if (widget.showIoNumbersPerSignal.length > srcIdx &&
          widget.showIoNumbersPerSignal.length > dstIdx) {
        final tmpShowIo = widget.showIoNumbersPerSignal[srcIdx];
        widget.showIoNumbersPerSignal[srcIdx] =
            widget.showIoNumbersPerSignal[dstIdx];
        widget.showIoNumbersPerSignal[dstIdx] = tmpShowIo;
      }

      if (widget.ioSources.length > srcIdx && widget.ioSources.length > dstIdx) {
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

  /// 1つの行を新しい位置に移動して信号行を並べ替えます。
  void _reorderSignalRowsImpl(int fromVisible, int toVisible) {
    if (!_canEditChartSignals) return;
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

