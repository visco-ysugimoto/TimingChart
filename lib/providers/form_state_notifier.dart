import 'package:flutter/material.dart';

import '../models/form/form_state.dart';

/// アプリ全体で共有するフォームの状態を管理する [ChangeNotifier]
///
/// 今後は `Provider` / `Consumer` を介して状態を読み書きすることで、
/// `GlobalKey` や `setState` の乱用を避け、UI とロジックを分離します。
///
/// まずは既存コードと併用できるよう、最低限の getter / updater のみ実装しています。
class FormStateNotifier extends ChangeNotifier {
  // 初期値は従来の `MyHomePage.initState` と同一にしておく
  TimingFormState _state = const TimingFormState(
    triggerOption: 'Single Trigger',
    ioPort: 32,
    hwPort: 0,
    camera: 1,
    inputCount: 32,
    outputCount: 32,
  );

  /// 現在の状態を取得
  TimingFormState get state => _state;

  /// `TimingFormState.copyWith` 相当の更新 API
  void update({
    String? triggerOption,
    int? ioPort,
    int? hwPort,
    int? camera,
    int? inputCount,
    int? outputCount,
  }) {
    _state = _state.copyWith(
      triggerOption: triggerOption,
      ioPort: ioPort,
      hwPort: hwPort,
      camera: camera,
      inputCount: inputCount,
      outputCount: outputCount,
    );
    notifyListeners();
  }

  /// 完全に別の `TimingFormState` へ置き換える場合はこちらを使用
  void replace(TimingFormState newState) {
    _state = newState;
    notifyListeners();
  }

  void _safeUpdate(
    FormStateNotifier notifier,
    void Function(FormStateNotifier) edit,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) => edit(notifier));
  }
}
