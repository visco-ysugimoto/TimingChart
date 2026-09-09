import '../models/chart/chart_segment.dart';
import '../models/chart/timing_chart_annotation.dart';
import '../models/form/camera_table_types.dart';

/// セグメント列から組み立てたカメラ取込表
class CombinedCameraTable {
  final List<List<CellMode>> table;
  final List<String> rowModes;
  final int cameraCount;

  const CombinedCameraTable({
    required this.table,
    required this.rowModes,
    required this.cameraCount,
  });
}

/// 波形スライス操作の結果
class ChartSegmentMutation {
  final List<List<int>> signalValues;
  final List<String> signalNames;
  final List<TimingChartAnnotation> annotations;
  final List<int> omissionIndices;
  final List<double> stepDurationsMs;
  final List<ChartSegment> segments;

  const ChartSegmentMutation({
    required this.signalValues,
    required this.signalNames,
    required this.annotations,
    required this.omissionIndices,
    required this.stepDurationsMs,
    required this.segments,
  });
}

/// セグメント操作（結合後の区間並べ替え・削除、列編集に伴う境界更新）
class ChartSegmentService {
  ChartSegmentService._();

  static String _defaultId(int seq) =>
      'seg_${seq}_${DateTime.now().microsecondsSinceEpoch}';

  /// 結合後のセグメント列を作る。
  /// 既存が無ければ現在波形を1本、追加分を1本（または incoming 側の区間）にする。
  static List<ChartSegment> appendAfterConcat({
    required List<ChartSegment> currentSegments,
    required int currentLength,
    required List<ChartSegment> incomingSegments,
    required int incomingLength,
    required String currentLabel,
    required String incomingLabel,
    List<List<CellMode>> currentTable = const [],
    List<String> currentRowModes = const [],
    List<List<CellMode>> incomingTable = const [],
    List<String> incomingRowModes = const [],
    String Function()? newId,
  }) {
    var seq = 0;
    String idOf() => newId?.call() ?? _defaultId(++seq);

    final left = _distributeTable(
      _normalizedOrSingle(
        currentSegments,
        currentLength,
        currentLabel.isEmpty ? 'Chart' : currentLabel,
        idOf,
      ),
      currentTable,
      currentRowModes,
    );
    final rightBase = _distributeTable(
      _normalizedOrSingle(
        incomingSegments,
        incomingLength,
        incomingLabel.isEmpty ? 'Chart' : incomingLabel,
        idOf,
      ),
      incomingTable,
      incomingRowModes,
    );
    final right = [
      for (final segment in rightBase)
        segment.copyWith(
          id: idOf(),
          startTimeIndex: segment.startTimeIndex + currentLength,
          endTimeIndex: segment.endTimeIndex + currentLength,
        ),
    ];
    return [...left, ...right];
  }

  /// フォームの取込表をセグメントへ割り振る。
  /// 既存の行数があるときはその幅で切り、余りは末尾へ付ける。
  static List<ChartSegment> _distributeTable(
    List<ChartSegment> segments,
    List<List<CellMode>> table,
    List<String> rowModes,
  ) {
    if (segments.isEmpty) return segments;
    final compact = _compactUsedRows(table, rowModes);
    if (compact.table.isEmpty) return segments;

    final counts = [for (final segment in segments) segment.cameraTable.length];
    if (counts.every((count) => count == 0)) {
      return [
        segments.first.copyWith(
          cameraTable: compact.table,
          rowModes: compact.rowModes,
        ),
        ...segments.skip(1),
      ];
    }

    var offset = 0;
    final result = <ChartSegment>[];
    for (var i = 0; i < segments.length; i++) {
      final remaining = compact.table.length - offset;
      final take = i == segments.length - 1
          ? remaining
          : (counts[i] < remaining ? counts[i] : remaining);
      final end = offset + (take > 0 ? take : 0);
      result.add(
        segments[i].copyWith(
          cameraTable: compact.table.sublist(offset, end),
          rowModes: compact.rowModes.sublist(offset, end),
        ),
      );
      offset = end;
    }
    return result;
  }

  static CombinedCameraTable _compactUsedRows(
    List<List<CellMode>> table,
    List<String> rowModes,
  ) {
    var last = -1;
    for (var i = 0; i < table.length; i++) {
      if (table[i].any((cell) => cell != CellMode.none)) {
        last = i;
      }
    }
    if (last < 0) {
      return const CombinedCameraTable(
        table: [],
        rowModes: [],
        cameraCount: 1,
      );
    }
    return CombinedCameraTable(
      table: _copyTable(table.sublist(0, last + 1)),
      rowModes: [
        for (var i = 0; i <= last; i++)
          i < rowModes.length ? rowModes[i] : RowMode.none.name,
      ],
      cameraCount: 1,
    );
  }

  static List<List<CellMode>> _copyTable(List<List<CellMode>> table) {
    return [for (final row in table) List<CellMode>.from(row)];
  }

  /// セグメント順にカメラ取込表を連結する。列数は最大カメラ数に揃える。
  static CombinedCameraTable combineCameraTables(
    List<ChartSegment> segments, {
    int minCameraCount = 1,
  }) {
    var cameras = minCameraCount > 0 ? minCameraCount : 1;
    for (final segment in segments) {
      for (final row in segment.cameraTable) {
        if (row.length > cameras) cameras = row.length;
      }
    }
    final table = <List<CellMode>>[];
    final modes = <String>[];
    for (final segment in segments) {
      for (var i = 0; i < segment.cameraTable.length; i++) {
        table.add(_padRow(segment.cameraTable[i], cameras));
        modes.add(
          i < segment.rowModes.length
              ? segment.rowModes[i]
              : RowMode.none.name,
        );
      }
    }
    return CombinedCameraTable(
      table: table,
      rowModes: modes,
      cameraCount: cameras,
    );
  }

  static List<CellMode> _padRow(List<CellMode> row, int cameras) {
    if (row.length >= cameras) return List<CellMode>.from(row.take(cameras));
    return [...row, ...List<CellMode>.filled(cameras - row.length, CellMode.none)];
  }

  static List<ChartSegment> _normalizedOrSingle(
    List<ChartSegment> segments,
    int length,
    String fallbackLabel,
    String Function() newId,
  ) {
    if (length <= 0) return const [];
    if (segments.isEmpty) {
      return [
        ChartSegment(
          id: newId(),
          label: fallbackLabel,
          startTimeIndex: 0,
          endTimeIndex: length,
        ),
      ];
    }
    return clampToLength(segments, length);
  }

  /// 長さに合わせてクランプし、区間が途切れないように整える。
  static List<ChartSegment> clampToLength(
    List<ChartSegment> segments,
    int length,
  ) {
    if (length <= 0 || segments.isEmpty) return const [];
    final kept = <ChartSegment>[];
    for (final segment in segments) {
      final start = segment.startTimeIndex.clamp(0, length);
      final end = segment.endTimeIndex.clamp(start, length);
      if (end > start) {
        kept.add(segment.copyWith(startTimeIndex: start, endTimeIndex: end));
      }
    }
    if (kept.isEmpty) return const [];
    return _ensureContiguous(kept, length);
  }

  static List<ChartSegment> _ensureContiguous(
    List<ChartSegment> segments,
    int length,
  ) {
    final sorted = [...segments]
      ..sort((a, b) => a.startTimeIndex.compareTo(b.startTimeIndex));
    final result = <ChartSegment>[];
    var cursor = 0;
    for (final original in sorted) {
      if (cursor >= length) break;
      final start = cursor;
      var end = original.endTimeIndex;
      if (end <= start) end = start + 1;
      if (end > length) end = length;
      if (end <= start) continue;
      result.add(original.copyWith(startTimeIndex: start, endTimeIndex: end));
      cursor = end;
    }
    if (result.isEmpty) return const [];
    if (result.last.endTimeIndex < length) {
      result[result.length - 1] = result.last.copyWith(endTimeIndex: length);
    }
    return result;
  }

  /// 列削除後に境界をずらす。[deleteStart, deleteEnd) を除去する。
  static List<ChartSegment> shiftAfterDelete({
    required List<ChartSegment> segments,
    required int deleteStart,
    required int deleteEnd,
  }) {
    final deleteLen = deleteEnd - deleteStart;
    if (deleteLen <= 0 || segments.isEmpty) return segments;
    final result = <ChartSegment>[];
    for (final segment in segments) {
      var newStart = -1;
      var surviving = 0;
      for (var t = segment.startTimeIndex; t < segment.endTimeIndex; t++) {
        if (t >= deleteStart && t < deleteEnd) continue;
        final mapped = t < deleteStart ? t : t - deleteLen;
        if (newStart < 0) newStart = mapped;
        surviving++;
      }
      if (surviving <= 0 || newStart < 0) continue;
      result.add(
        segment.copyWith(
          startTimeIndex: newStart,
          endTimeIndex: newStart + surviving,
        ),
      );
    }
    return result;
  }

  /// 列挿入後に境界をずらす。
  static List<ChartSegment> shiftAfterInsert({
    required List<ChartSegment> segments,
    required int insertAt,
    required int insertCount,
  }) {
    if (insertCount <= 0 || segments.isEmpty) return segments;
    return [
      for (final segment in segments)
        if (segment.endTimeIndex <= insertAt)
          segment
        else if (segment.startTimeIndex >= insertAt)
          segment.copyWith(
            startTimeIndex: segment.startTimeIndex + insertCount,
            endTimeIndex: segment.endTimeIndex + insertCount,
          )
        else
          segment.copyWith(endTimeIndex: segment.endTimeIndex + insertCount),
    ];
  }

  /// 指定セグメントの波形スライスを削除する。
  static ChartSegmentMutation? deleteSegment({
    required List<List<int>> signalValues,
    required List<String> signalNames,
    required List<TimingChartAnnotation> annotations,
    required List<int> omissionIndices,
    required List<double> stepDurationsMs,
    required List<ChartSegment> segments,
    required String segmentId,
  }) {
    if (segments.length < 2) return null;
    final index = segments.indexWhere((s) => s.id == segmentId);
    if (index < 0) return null;
    final target = segments[index];
    return _removeRange(
      signalValues: signalValues,
      signalNames: signalNames,
      annotations: annotations,
      omissionIndices: omissionIndices,
      stepDurationsMs: stepDurationsMs,
      segments: segments,
      start: target.startTimeIndex,
      end: target.endTimeIndex,
    );
  }

  /// セグメントを並べ替える（波形スライスの入れ替え）。
  static ChartSegmentMutation? reorderSegments({
    required List<List<int>> signalValues,
    required List<String> signalNames,
    required List<TimingChartAnnotation> annotations,
    required List<int> omissionIndices,
    required List<double> stepDurationsMs,
    required List<ChartSegment> segments,
    required int fromIndex,
    required int toIndex,
  }) {
    if (segments.length < 2) return null;
    if (fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= segments.length ||
        toIndex >= segments.length ||
        fromIndex == toIndex) {
      return null;
    }

    final order = List<int>.generate(segments.length, (i) => i);
    final moved = order.removeAt(fromIndex);
    order.insert(toIndex, moved);

    final maxLen = _maxLength(signalValues);
    final oldToNew = List<int>.filled(maxLen, -1);
    final newSegments = <ChartSegment>[];
    var cursor = 0;
    for (final i in order) {
      final segment = segments[i];
      final len = segment.length;
      for (var t = 0; t < len; t++) {
        final old = segment.startTimeIndex + t;
        if (old >= 0 && old < maxLen) {
          oldToNew[old] = cursor + t;
        }
      }
      newSegments.add(
        segment.copyWith(startTimeIndex: cursor, endTimeIndex: cursor + len),
      );
      cursor += len;
    }

    return ChartSegmentMutation(
      signalValues: [
        for (final row in signalValues)
          _reorderRowBySlices(row, segments, order),
      ],
      signalNames: List<String>.from(signalNames),
      annotations: _remapAnnotations(annotations, oldToNew),
      omissionIndices: _remapOmissions(omissionIndices, oldToNew),
      stepDurationsMs: _reorderDurationsBySlices(
        stepDurationsMs,
        segments,
        order,
        maxLen,
      ),
      segments: newSegments,
    );
  }

  static ChartSegmentMutation _removeRange({
    required List<List<int>> signalValues,
    required List<String> signalNames,
    required List<TimingChartAnnotation> annotations,
    required List<int> omissionIndices,
    required List<double> stepDurationsMs,
    required List<ChartSegment> segments,
    required int start,
    required int end,
  }) {
    final maxLen = _maxLength(signalValues);
    final st = start.clamp(0, maxLen);
    final ed = end.clamp(st, maxLen);
    final deleteLen = ed - st;

    final newOmissions = <int>[];
    for (final t in omissionIndices) {
      if (t < st) {
        newOmissions.add(t);
      } else if (t >= ed) {
        newOmissions.add(t - deleteLen);
      }
    }

    return ChartSegmentMutation(
      signalValues: [
        for (final row in signalValues) _removeRowRange(row, st, ed),
      ],
      signalNames: List<String>.from(signalNames),
      annotations: _clipAnnotationsAfterDelete(annotations, st, ed, deleteLen),
      omissionIndices: newOmissions,
      stepDurationsMs: _removeDurationRange(stepDurationsMs, st, ed, maxLen),
      segments: shiftAfterDelete(
        segments: segments,
        deleteStart: st,
        deleteEnd: ed,
      ),
    );
  }

  static List<TimingChartAnnotation> _clipAnnotationsAfterDelete(
    List<TimingChartAnnotation> annotations,
    int st,
    int ed,
    int deleteLen,
  ) {
    final result = <TimingChartAnnotation>[];
    for (final ann in annotations) {
      final aStart = ann.startTimeIndex;
      final aEnd = ann.endTimeIndex ?? ann.startTimeIndex;
      if (aEnd < st) {
        result.add(ann);
        continue;
      }
      if (aStart >= ed) {
        result.add(
          ann.copyWith(
            startTimeIndex: aStart - deleteLen,
            endTimeIndex: ann.endTimeIndex != null ? aEnd - deleteLen : null,
          ),
        );
        continue;
      }
      if (aStart >= st && aEnd < ed) {
        continue;
      }

      final newStart = aStart < st
          ? aStart
          : (aStart >= ed ? aStart - deleteLen : st);
      final newEnd = aEnd < st
          ? aEnd
          : (aEnd >= ed ? aEnd - deleteLen : st - 1);
      if (newEnd < newStart || newStart < 0) continue;
      result.add(
        ann.copyWith(
          startTimeIndex: newStart,
          endTimeIndex: ann.endTimeIndex != null ? newEnd : null,
        ),
      );
    }
    return result;
  }

  static List<int> _removeRowRange(List<int> row, int start, int end) {
    if (start >= end) return List<int>.from(row);
    final st = start.clamp(0, row.length);
    final ed = end.clamp(st, row.length);
    if (st >= ed) return List<int>.from(row);
    return [...row.sublist(0, st), ...row.sublist(ed)];
  }

  static List<double> _removeDurationRange(
    List<double> durations,
    int start,
    int end,
    int maxLen,
  ) {
    if (durations.isEmpty || start >= end) {
      return List<double>.from(durations);
    }
    final padded = _paddedDurations(durations, maxLen);
    final st = start.clamp(0, padded.length);
    final ed = end.clamp(st, padded.length);
    if (st >= ed) return padded;
    return [...padded.sublist(0, st), ...padded.sublist(ed)];
  }

  static List<int> _reorderRowBySlices(
    List<int> row,
    List<ChartSegment> segments,
    List<int> order,
  ) {
    final out = <int>[];
    for (final i in order) {
      out.addAll(
        _slicePadded(row, segments[i].startTimeIndex, segments[i].endTimeIndex),
      );
    }
    return out;
  }

  static List<double> _reorderDurationsBySlices(
    List<double> durations,
    List<ChartSegment> segments,
    List<int> order,
    int maxLen,
  ) {
    if (durations.isEmpty) return const [];
    final padded = _paddedDurations(durations, maxLen);
    final out = <double>[];
    for (final i in order) {
      out.addAll(
        _slicePaddedDouble(
          padded,
          segments[i].startTimeIndex,
          segments[i].endTimeIndex,
        ),
      );
    }
    return out;
  }

  static List<int> _slicePadded(List<int> values, int start, int end) {
    final len = end - start;
    if (len <= 0) return const [];
    if (start >= values.length) return List<int>.filled(len, 0);
    if (end <= values.length) return values.sublist(start, end);
    return [
      ...values.sublist(start),
      ...List<int>.filled(end - values.length, 0),
    ];
  }

  static List<double> _slicePaddedDouble(
    List<double> values,
    int start,
    int end,
  ) {
    final len = end - start;
    if (len <= 0) return const [];
    final fill = values.isEmpty ? 1.0 : values.last;
    if (start >= values.length) return List<double>.filled(len, fill);
    if (end <= values.length) return values.sublist(start, end);
    return [
      ...values.sublist(start),
      ...List<double>.filled(end - values.length, fill),
    ];
  }

  static List<double> _paddedDurations(List<double> durations, int length) {
    if (length <= 0) return const [];
    if (durations.length >= length) return durations.sublist(0, length);
    final fill = durations.isEmpty ? 1.0 : durations.last;
    return [
      ...durations,
      ...List<double>.filled(length - durations.length, fill),
    ];
  }

  static List<TimingChartAnnotation> _remapAnnotations(
    List<TimingChartAnnotation> annotations,
    List<int> oldToNew,
  ) {
    final result = <TimingChartAnnotation>[];
    for (final ann in annotations) {
      final start = _mapTime(oldToNew, ann.startTimeIndex);
      if (start == null) continue;
      int? end;
      if (ann.endTimeIndex != null) {
        end = _mapTime(oldToNew, ann.endTimeIndex!);
        if (end == null) continue;
      }
      var newStart = start;
      var newEnd = end;
      if (newEnd != null && newEnd < newStart) {
        final tmp = newStart;
        newStart = newEnd;
        newEnd = tmp;
      }
      result.add(ann.copyWith(startTimeIndex: newStart, endTimeIndex: newEnd));
    }
    return result;
  }

  static List<int> _remapOmissions(List<int> omissions, List<int> oldToNew) {
    final result = <int>[];
    for (final t in omissions) {
      final mapped = _mapTime(oldToNew, t);
      if (mapped != null) result.add(mapped);
    }
    return result;
  }

  static int? _mapTime(List<int> oldToNew, int t) {
    if (t < 0 || t >= oldToNew.length) return null;
    final mapped = oldToNew[t];
    return mapped >= 0 ? mapped : null;
  }

  static int _maxLength(List<List<int>> signalValues) {
    var maxLen = 0;
    for (final row in signalValues) {
      if (row.length > maxLen) maxLen = row.length;
    }
    return maxLen;
  }
}
