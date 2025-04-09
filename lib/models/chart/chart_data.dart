import 'signal_type.dart';
import 'timing_chart_annotation.dart';
import 'signal_data.dart';

class TimingChartData {
  final List<SignalData> signals;
  final List<TimingChartAnnotation> annotations;
  final int timeSteps;

  const TimingChartData({
    required this.signals,
    required this.annotations,
    required this.timeSteps,
  });

  TimingChartData copyWith({
    List<SignalData>? signals,
    List<TimingChartAnnotation>? annotations,
    int? timeSteps,
  }) {
    return TimingChartData(
      signals: signals ?? this.signals,
      annotations: annotations ?? this.annotations,
      timeSteps: timeSteps ?? this.timeSteps,
    );
  }

  bool get isEmpty => signals.isEmpty;
}
