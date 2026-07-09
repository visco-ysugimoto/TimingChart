/// `FormTab` 周辺で使用する定数群（UI/ロジック）
///
/// 目的:
/// - `form_tab.dart` の巨大化を防ぐため、純粋な定数を集約する
/// - UI/サービス層からも参照されうる値（文字列ID等）を一箇所に置く
class FormTabConstants {
  // 波形長
  static const int defaultWaveLength = 32;

  // ポート数
  static const int minInputPorts = 6;
  static const int standardInputPorts = 16;
  static const int maxInputPorts = 32;
  static const int extendedInputPorts = 64;
  static const int standardOutputPorts = 32;

  // 出力ポートの予約範囲
  static const int reservedOutputStart = 3; // 0-based indexで Output4 からが予約扱い

  // UI定数
  static const double alphaBlendValue = 0.3;
  static const int defaultRowCount = 6;

  // Code Trigger設定（32ポート）
  static const int codeTrigger32ControlStart = 1;
  static const int codeTrigger32ControlEnd = 8;
  static const int codeTrigger32GroupStart = 9;
  static const int codeTrigger32GroupEnd = 14;
  static const int codeTrigger32TaskStart = 15;
  static const int codeTrigger32TaskEnd = 20;

  // Code Trigger設定（16ポート）
  static const int codeTrigger16ControlStart = 1;
  static const int codeTrigger16ControlEnd = 4;
  static const int codeTrigger16GroupStart = 5;
  static const int codeTrigger16GroupEnd = 7;
  static const int codeTrigger16TaskStart = 8;
  static const int codeTrigger16TaskEnd = 13;

  // CONTACT_INPUT_WAITINGの配置（32ポート時）
  static const int contactInputWaitingIndex32 = 29; // Input30 (0-based index)
}

/// 信号名定数
///
/// NOTE: ここでの文字列はチャート上の信号ID/ラベルとして利用されます。
class SignalNames {
  static const String codeOption = 'CODE_OPTION';
  static const String commandOption = 'Command Option';
  static const String autoMode = 'AUTO_MODE';
  static const String busy = 'BUSY';
  static const String trigger = 'TRIGGER';
  static const String contactInputWaiting = 'CONTACT_INPUT_WAITING';
  static const String acqTriggerWaiting = 'ACQ_TRIGGER_WAITING';
  static const String enableResultSignal = 'ENABLE_RESULT_SIGNAL';
  static const String totalResultOk = 'TOTAL_RESULT_OK';
  static const String totalResultNg = 'TOTAL_RESULT_NG';
  static const String batchExposure = 'BATCH_EXPOSURE';
  static const String batchExposureComplete = 'BATCH_EXPOSURE_COMPLETE';
  static const String recovery = 'RECOVERY';
  static const String pcControl = 'PC_CONTROL';
  static const String systemKeepRunningSignal =
      'SYSTEM_KEEP_RUNNING_SIGNAL';
}

/// トリガーオプション定数
///
/// NOTE: 画面のDropdown表示値と一致させています（互換性維持）。
class TriggerOptions {
  static const String single = 'Single Trigger';
  static const String code = 'Code Trigger';
  static const String command = 'Command Trigger';
}

/// PLC/EIPオプション定数
///
/// NOTE: 画面のDropdown表示値と一致させています（互換性維持）。
class PlcEipOptions {
  static const String none = 'None';
  static const String plc = 'PLC';
  static const String eip = 'EIP';
}
