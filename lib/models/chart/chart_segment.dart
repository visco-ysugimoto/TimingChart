/// 結合したチャートの時間区間。
///
/// [startTimeIndex] は含む、[endTimeIndex] は含まない（`sublist` と同じ）。
class ChartSegment {
  final String id;
  final String label;
  final int startTimeIndex;
  final int endTimeIndex;
  final String? sourcePath;

  const ChartSegment({
    required this.id,
    required this.label,
    required this.startTimeIndex,
    required this.endTimeIndex,
    this.sourcePath,
  });

  int get length => (endTimeIndex - startTimeIndex).clamp(0, 1 << 30);

  ChartSegment copyWith({
    String? id,
    String? label,
    int? startTimeIndex,
    int? endTimeIndex,
    String? sourcePath,
    bool clearSourcePath = false,
  }) {
    return ChartSegment(
      id: id ?? this.id,
      label: label ?? this.label,
      startTimeIndex: startTimeIndex ?? this.startTimeIndex,
      endTimeIndex: endTimeIndex ?? this.endTimeIndex,
      sourcePath: clearSourcePath ? null : (sourcePath ?? this.sourcePath),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'start': startTimeIndex,
      'end': endTimeIndex,
      if (sourcePath != null) 'sourcePath': sourcePath,
    };
  }

  static ChartSegment? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final start = (json['start'] as num?)?.toInt();
    final end = (json['end'] as num?)?.toInt();
    if (id.isEmpty || start == null || end == null || end <= start) {
      return null;
    }
    return ChartSegment(
      id: id,
      label: json['label']?.toString() ?? '',
      startTimeIndex: start,
      endTimeIndex: end,
      sourcePath: json['sourcePath']?.toString(),
    );
  }

  static List<ChartSegment> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final result = <ChartSegment>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final segment = fromJson(Map<String, dynamic>.from(item));
      if (segment != null) result.add(segment);
    }
    return result;
  }

  @override
  bool operator ==(Object other) {
    return other is ChartSegment &&
        other.id == id &&
        other.label == label &&
        other.startTimeIndex == startTimeIndex &&
        other.endTimeIndex == endTimeIndex &&
        other.sourcePath == sourcePath;
  }

  @override
  int get hashCode =>
      Object.hash(id, label, startTimeIndex, endTimeIndex, sourcePath);
}
