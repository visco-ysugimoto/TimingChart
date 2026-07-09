class TimingFormState {
  final String triggerOption;
  final int ioPort;
  final int hwPort;
  final int camera;
  final int inputCount;
  final int outputCount;
  /// Code Trigger の Control/Group/Task を PLC/EIP 側で表現する
  final bool codeTriggerOnPlcEip;
  /// UseDioTriggerPort_with_VirtualIO=1（Code 時はトリガを DIO1 に置く）
  final bool useDioTriggerPortWithVirtualIo;

  const TimingFormState({
    required this.triggerOption,
    required this.ioPort,
    required this.hwPort,
    required this.camera,
    required this.inputCount,
    required this.outputCount,
    this.codeTriggerOnPlcEip = false,
    this.useDioTriggerPortWithVirtualIo = false,
  });

  TimingFormState copyWith({
    String? triggerOption,
    int? ioPort,
    int? hwPort,
    int? camera,
    int? inputCount,
    int? outputCount,
    bool? codeTriggerOnPlcEip,
    bool? useDioTriggerPortWithVirtualIo,
  }) {
    return TimingFormState(
      triggerOption: triggerOption ?? this.triggerOption,
      ioPort: ioPort ?? this.ioPort,
      hwPort: hwPort ?? this.hwPort,
      camera: camera ?? this.camera,
      inputCount: inputCount ?? this.inputCount,
      outputCount: outputCount ?? this.outputCount,
      codeTriggerOnPlcEip:
          codeTriggerOnPlcEip ?? this.codeTriggerOnPlcEip,
      useDioTriggerPortWithVirtualIo:
          useDioTriggerPortWithVirtualIo ??
          this.useDioTriggerPortWithVirtualIo,
    );
  }
}
