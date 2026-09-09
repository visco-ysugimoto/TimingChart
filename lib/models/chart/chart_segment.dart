import '../form/camera_table_types.dart';

/// 結合したチャートの時間区間。
///
/// [startTimeIndex] は含む、[endTimeIndex] は含まない（`sublist` と同じ）。
class ChartSegment {
  final String id;
  final String label;
  final int startTimeIndex;
  final int endTimeIndex;
  final String? sourcePath;
  final List<List<CellMode>> cameraTable;
  final List<String> rowModes;

  const ChartSegment({
    required this.id,
    required this.label,
    required this.startTimeIndex,
    required this.endTimeIndex,
    this.sourcePath,
    this.cameraTable = const [],
    this.rowModes = const [],
  });

  int get length => (endTimeIndex - startTimeIndex).clamp(0, 1 << 30);

  ChartSegment copyWith({
    String? id,
    String? label,
    int? startTimeIndex,
    int? endTimeIndex,
    String? sourcePath,
    bool clearSourcePath = false,
    List<List<CellMode>>? cameraTable,
    List<String>? rowModes,
  }) {
    return ChartSegment(
      id: id ?? this.id,
      label: label ?? this.label,
      startTimeIndex: startTimeIndex ?? this.startTimeIndex,
      endTimeIndex: endTimeIndex ?? this.endTimeIndex,
      sourcePath: clearSourcePath ? null : (sourcePath ?? this.sourcePath),
      cameraTable: cameraTable ?? this.cameraTable,
      rowModes: rowModes ?? this.rowModes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'start': startTimeIndex,
      'end': endTimeIndex,
      if (sourcePath != null) 'sourcePath': sourcePath,
      if (cameraTable.isNotEmpty)
        'cameraTable':
            cameraTable
                .map((row) => row.map((cell) => cell.index).toList())
                .toList(),
      if (rowModes.isNotEmpty) 'rowModes': rowModes,
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
      cameraTable: _tableFromJson(json['cameraTable']),
      rowModes:
          (json['rowModes'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  static List<List<CellMode>> _tableFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final table = <List<CellMode>>[];
    for (final row in raw) {
      if (row is! List) continue;
      table.add(
        row.map((cell) {
          final index = (cell as num?)?.toInt() ?? 0;
          if (index < 0 || index >= CellMode.values.length) {
            return CellMode.none;
          }
          return CellMode.values[index];
        }).toList(),
      );
    }
    return table;
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
