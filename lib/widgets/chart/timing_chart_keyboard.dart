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

  /// グローバルキー入力。チャートタブ表示中は、フォーム側にフォーカスが残っていても
  /// 選択範囲への 0/1 設定を受け付ける。
  bool _handleHardwareKeyEventImpl(KeyEvent event) {
    _handleModifierKeyEventImpl(event);
    if (!_shortcutCaptureEnabled || !_focusNode.canRequestFocus) {
      return false;
    }
    if (event is! KeyDownEvent) return false;
    return _trySetSignalsFromDigitKey(event);
  }

  /// チャート操作のキーボードイベントを処理します。
  ///
  /// - Ctrl/Cmd+Z: アンドゥ
  /// - Ctrl/Cmd+Y: リドゥ
  /// - Ctrl/Cmd+A: すべて選択
  /// - 0/1キー: 選択範囲を 0/1 に一括設定
  KeyEventResult _onKeyEventImpl(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final bool isModifierPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (_handleHorizontalScrollKeysImpl(event)) {
      return KeyEventResult.handled;
    }

    // アンドゥ/リドゥショートカット
    if (isModifierPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        if (_controller?.canUndo ?? false) {
          _controller?.undo();
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyY) {
        if (_controller?.canRedo ?? false) {
          _controller?.redo();
        }
        return KeyEventResult.handled;
      }
    }

    if (isModifierPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
      _selectAllSignals();
      return KeyEventResult.handled;
    }

    if (_trySetSignalsFromDigitKey(event)) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 選択範囲を High(1) / Low(0) に設定するキーかどうかを判定して実行します。
  bool _trySetSignalsFromDigitKey(KeyEvent event) {
    if (!_canEditChartSignals || !_hasValidSelection) return false;
    final int? value = chartLevelValueFromKeyEvent(event);
    if (value == null) return false;
    _setSignalsInSelection(value);
    return true;
  }

  void _ensureChartKeyboardFocusImpl() {
    if (!mounted || !_focusNode.canRequestFocus) return;
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  void _setShortcutCaptureEnabledImpl(bool enabled) {
    _shortcutCaptureEnabled = enabled;
    if (enabled) {
      _ensureChartKeyboardFocusImpl();
    }
  }
}

