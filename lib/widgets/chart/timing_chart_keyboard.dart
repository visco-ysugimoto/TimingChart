part of 'timing_chart.dart';

/// キーボード/フォーカス関連（ショートカット、修飾キー状態）をまとめた `part` ファイル。
///
/// - **目的**: `TimingChartState` 本体から、入力処理の分岐（Undo/Redo/SelectAll等）を切り離して見通しを良くする。
/// - **実装**: `extension on TimingChartState` に `*_Impl` として実装し、
///   `TimingChartState` 側は handler から呼ぶ薄いラッパーのみを残す。
extension _TimingChartKeyboardExt on TimingChartState {
  /// 修飾キー（Ctrl/Cmd）の押下/解放イベントを処理します。
  ///
  /// CtrlまたはCmdキーが押されたり解放されたりしたときに `_isModifierPressed` 状態を更新します。
  /// イベント伝播を許可するために `false` を返します。
  bool _handleModifierKeyEventImpl(KeyEvent event) {
    final bool pressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (pressed != _isModifierPressed) {
      _setState(() {
        _isModifierPressed = pressed;
      });
    }
    return false;
  }

  /// チャート操作のキーボードイベントを処理します。
  ///
  /// - Ctrl/Cmd+Z: アンドゥ
  /// - Ctrl/Cmd+Y: リドゥ
  /// - Ctrl/Cmd+A: すべて選択
  /// - 0/1キー: 選択範囲を 0/1 に一括設定
  void _onKeyEventImpl(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final bool isModifierPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (_handleHorizontalScrollKeysImpl(event)) return;

    // アンドゥ/リドゥショートカット
    if (isModifierPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        if (_controller?.canUndo ?? false) {
          _controller?.undo();
        }
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.keyY) {
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
}

