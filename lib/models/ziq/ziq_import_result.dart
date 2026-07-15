import '../chart/signal_data.dart';
import '../chart/io_channel_source.dart';
import '../chart/timing_chart_annotation.dart';
import 'output_assignment.dart';
import '../../utils/vxvismgr_parser.dart';

/// ZIQインポート結果を保持するモデルクラス
class ZiqImportResult {
  final String? vxVisMgrIniContent;
  final String? dioMonitorLogCsvContent;
  final String? plcDioMonitorLogCsvContent;
  final String? fnlDioMonitorLogCsvContent;
  final Map<String, String> vxvisNameToSuggestionId;
  final List<String> enabledStatusSignals;
  final List<StatusSignalSetting> enabledSignalStructures;
  final List<OutputAssignment> dioOutputAssignments;
  final List<OutputAssignment> plcEipOutputAssignments;
  final String plcEipOption;
  final String triggerOption;
  final bool codeTriggerOnPlcEip;
  final bool useDioTriggerPortWithVirtualIo;
  final int? inputPorts;
  final int? outputPorts;
  final List<SignalData> chartSignals;
  final List<int> chartPortNumbers;
  final List<IoChannelSource> chartIoSources;
  final List<double> stepDurationsMs;
  /// Code Trigger 時の個別ビット変化コメント（空の場合もあり）
  final List<TimingChartAnnotation> chartAnnotations;

  const ZiqImportResult({
    required this.vxVisMgrIniContent,
    required this.dioMonitorLogCsvContent,
    required this.plcDioMonitorLogCsvContent,
    required this.fnlDioMonitorLogCsvContent,
    required this.vxvisNameToSuggestionId,
    required this.enabledStatusSignals,
    required this.enabledSignalStructures,
    required this.dioOutputAssignments,
    required this.plcEipOutputAssignments,
    required this.plcEipOption,
    required this.triggerOption,
    this.codeTriggerOnPlcEip = false,
    this.useDioTriggerPortWithVirtualIo = false,
    this.inputPorts,
    this.outputPorts,
    required this.chartSignals,
    required this.chartPortNumbers,
    required this.chartIoSources,
    required this.stepDurationsMs,
    this.chartAnnotations = const [],
  });
}
