import '../models/backup/app_config.dart';
import '../models/chart/signal_data.dart';
import '../models/chart/timing_chart_annotation.dart';

/// 結合先にだけ存在する信号の扱い
enum UnmatchedIncomingPolicy {
  /// 行を追加し、現在チャート側は 0 埋めする
  padAndAdd,

  /// 結合先にだけある信号は破棄する
  drop,
}

/// 結合前の突合結果
class ChartConcatPreview {
  final List<String> matchedNames;
  final List<String> currentOnlyNames;
  final List<String> incomingOnlyNames;
  final int currentLength;
  final int incomingLength;
  final bool timeUnitMismatch;

  const ChartConcatPreview({
    required this.matchedNames,
    required this.currentOnlyNames,
    required this.incomingOnlyNames,
    required this.currentLength,
    required this.incomingLength,
    required this.timeUnitMismatch,
  });
}

/// 時間方向の結合結果
class ChartConcatResult {
  final List<SignalData> signals;
  final List<TimingChartAnnotation> annotations;
  final List<int> omissionIndices;
  final List<double> stepDurationsMs;
  final int joinStartIndex;
  final int joinEndIndex;

  const ChartConcatResult({
    required this.signals,
    required this.annotations,
    required this.omissionIndices,
    required this.stepDurationsMs,
    required this.joinStartIndex,
    required this.joinEndIndex,
  });
}

/// 複数チャートを時間方向へ連結する
class ChartConcatService {
  ChartConcatService._();

  static int maxSignalLength(List<SignalData> signals) {
    var maxLen = 0;
    for (final signal in signals) {
      if (signal.values.length > maxLen) {
        maxLen = signal.values.length;
      }
    }
    return maxLen;
  }

  static ChartConcatPreview preview({
    required List<SignalData> currentSignals,
    required List<SignalData> incomingSignals,
    required bool currentTimeUnitIsMs,
    required bool incomingTimeUnitIsMs,
  }) {
    final currentUsable = _usableSignals(currentSignals);
    final incomingUsable = _usableSignals(incomingSignals);
    final currentKeys = currentUsable.map(_matchKey).toSet();
    final incomingKeys = incomingUsable.map(_matchKey).toSet();
    final matched =
        currentUsable
            .map(_displayName)
            .where((name) => incomingKeys.contains(_matchKeyFromName(name)))
            .toList();
    final currentOnly =
        currentUsable
            .map(_displayName)
            .where((name) => !incomingKeys.contains(_matchKeyFromName(name)))
            .toList();
    final incomingOnly =
        incomingUsable
            .map(_displayName)
            .where((name) => !currentKeys.contains(_matchKeyFromName(name)))
            .toList();

    return ChartConcatPreview(
      matchedNames: matched,
      currentOnlyNames: currentOnly,
      incomingOnlyNames: incomingOnly,
      currentLength: maxSignalLength(currentUsable),
      incomingLength: maxSignalLength(incomingUsable),
      timeUnitMismatch: currentTimeUnitIsMs != incomingTimeUnitIsMs,
    );
  }

  static ChartConcatResult concat({
    required List<SignalData> currentSignals,
    required List<TimingChartAnnotation> currentAnnotations,
    required List<int> currentOmissions,
    required List<double> currentStepDurationsMs,
    required double currentMsPerStep,
    required bool currentTimeUnitIsMs,
    required AppConfig incoming,
    required UnmatchedIncomingPolicy unmatchedPolicy,
    required String joinLabel,
    String Function()? newId,
  }) {
    var idSeq = 0;
    String idOf() => newId?.call() ?? 'concat_${++idSeq}_${_idStamp()}';
    final currentUsable = _usableSignals(currentSignals);
    final incomingUsable = _usableSignals(incoming.signals);
    final currentLen = maxSignalLength(currentUsable);
    final incomingLen = maxSignalLength(incomingUsable);
    final currentByKey = <String, SignalData>{
      for (final signal in currentUsable) _matchKey(signal): signal,
    };
    final incomingByKey = <String, SignalData>{
      for (final signal in incomingUsable) _matchKey(signal): signal,
    };

    final ordered = <SignalData>[];
    final seen = <String>{};

    for (final signal in currentUsable) {
      if (seen.add(_matchKey(signal))) {
        ordered.add(signal);
      }
    }
    if (unmatchedPolicy == UnmatchedIncomingPolicy.padAndAdd) {
      for (final signal in incomingUsable) {
        if (seen.add(_matchKey(signal))) {
          ordered.add(signal);
        }
      }
    }

    final mergedSignals = <SignalData>[];
    for (final template in ordered) {
      final key = _matchKey(template);
      final current = currentByKey[key];
      final incomingSignal = incomingByKey[key];
      final left = _padded(current?.values ?? const [], currentLen);
      final right = _padded(incomingSignal?.values ?? const [], incomingLen);
      final source = current ?? incomingSignal!;
      mergedSignals.add(
        source.copyWith(
          name: _displayName(source),
          values: [...left, ...right],
        ),
      );
    }

    final offset = currentLen;
    final mergedAnnotations = <TimingChartAnnotation>[
      ...currentAnnotations,
    ];
    for (final ann in incoming.annotations) {
      mergedAnnotations.add(
        ann.copyWith(
          id: idOf(),
          startTimeIndex: ann.startTimeIndex + offset,
          endTimeIndex:
              ann.endTimeIndex != null ? ann.endTimeIndex! + offset : null,
        ),
      );
    }

    var joinStart = offset;
    var joinEnd = offset + incomingLen - 1;
    if (currentLen > 0 && incomingLen > 0) {
      mergedAnnotations.add(
        TimingChartAnnotation(
          id: idOf(),
          startTimeIndex: joinStart,
          endTimeIndex: joinEnd,
          text: joinLabel,
          placement: 'top',
        ),
      );
    } else {
      joinStart = 0;
      joinEnd = incomingLen > 0 ? incomingLen - 1 : -1;
    }

    final mergedOmissions = <int>[
      ...currentOmissions.where((t) => t >= 0),
      ...incoming.omissionIndices
          .where((t) => t >= 0)
          .map((t) => t + offset),
    ];

    final mergedDurations = _concatStepDurations(
      currentLen: currentLen,
      incomingLen: incomingLen,
      currentDurations: currentStepDurationsMs,
      incomingDurations: incoming.stepDurationsMs,
      currentMsPerStep: currentMsPerStep,
      incomingMsPerStep: incoming.msPerStep,
      currentTimeUnitIsMs: currentTimeUnitIsMs,
      incomingTimeUnitIsMs: incoming.timeUnitIsMs,
    );

    return ChartConcatResult(
      signals: mergedSignals,
      annotations: mergedAnnotations,
      omissionIndices: mergedOmissions,
      stepDurationsMs: mergedDurations,
      joinStartIndex: joinStart,
      joinEndIndex: joinEnd,
    );
  }

  static List<int> _padded(List<int> values, int length) {
    if (length <= 0) return const [];
    if (values.length >= length) return values.sublist(0, length);
    return [...values, ...List<int>.filled(length - values.length, 0)];
  }

  static List<double> _concatStepDurations({
    required int currentLen,
    required int incomingLen,
    required List<double> currentDurations,
    required List<double> incomingDurations,
    required double currentMsPerStep,
    required double incomingMsPerStep,
    required bool currentTimeUnitIsMs,
    required bool incomingTimeUnitIsMs,
  }) {
    if (!currentTimeUnitIsMs) return const [];
    final total = currentLen + incomingLen;
    if (total <= 0) return const [];

    final leftFill = currentMsPerStep > 0 ? currentMsPerStep : 1.0;
    final rightFill =
        incomingTimeUnitIsMs && incomingMsPerStep > 0
            ? incomingMsPerStep
            : leftFill;
    return [
      ..._paddedDurations(currentDurations, currentLen, leftFill),
      ..._paddedDurations(incomingDurations, incomingLen, rightFill),
    ];
  }

  static List<double> _paddedDurations(
    List<double> durations,
    int length,
    double fill,
  ) {
    if (length <= 0) return const [];
    if (durations.length >= length) return durations.sublist(0, length);
    return [
      ...durations,
      ...List<double>.filled(length - durations.length, fill),
    ];
  }

  static List<SignalData> _usableSignals(List<SignalData> signals) {
    final result = <SignalData>[];
    for (var i = 0; i < signals.length; i++) {
      final signal = signals[i];
      if (_displayName(signal).isNotEmpty) {
        result.add(signal);
        continue;
      }
      if (signal.values.any((v) => v != 0)) {
        result.add(signal.copyWith(name: 'Unnamed ${i + 1}'));
      }
    }
    return result;
  }

  static String _displayName(SignalData signal) => signal.name.trim();

  static String _matchKey(SignalData signal) =>
      _matchKeyFromName(_displayName(signal));

  /// `Output3: BUSY` と `BUSY` を同一信号として扱う
  static String _matchKeyFromName(String name) {
    var trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final colon = trimmed.indexOf(':');
    if (colon >= 0) {
      trimmed = trimmed.substring(colon + 1).trim();
    }
    return trimmed.replaceAll(RegExp(r'[\s_:-]+'), '').toLowerCase();
  }

  static String _idStamp() =>
      DateTime.now().microsecondsSinceEpoch.toString();
}
