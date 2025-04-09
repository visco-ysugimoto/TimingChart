class TimingFormState {
  final String triggerOption;
  final int ioPort;
  final int hwPort;
  final int camera;
  final int inputCount;
  final int outputCount;

  const TimingFormState({
    required this.triggerOption,
    required this.ioPort,
    required this.hwPort,
    required this.camera,
    required this.inputCount,
    required this.outputCount,
  });

  TimingFormState copyWith({
    String? triggerOption,
    int? ioPort,
    int? hwPort,
    int? camera,
    int? inputCount,
    int? outputCount,
  }) {
    return TimingFormState(
      triggerOption: triggerOption ?? this.triggerOption,
      ioPort: ioPort ?? this.ioPort,
      hwPort: hwPort ?? this.hwPort,
      camera: camera ?? this.camera,
      inputCount: inputCount ?? this.inputCount,
      outputCount: outputCount ?? this.outputCount,
    );
  }
}
