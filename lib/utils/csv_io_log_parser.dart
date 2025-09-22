class ParsedIoLog {
  final List<List<int>> rows; // 各行: 各ポートの 0/1 配列（左が高ポート、右がPort1）
  final int portCount;

  const ParsedIoLog({required this.rows, required this.portCount});
}

class ParsedIoLogBoth {
  final List<List<int>> inRows;
  final int inPortCount;
  final List<List<int>> outRows;
  final int outPortCount;

  const ParsedIoLogBoth({
    required this.inRows,
    required this.inPortCount,
    required this.outRows,
    required this.outPortCount,
  });
}

class CsvTimelineEntry {
  final String type; // 'IN' or 'OUT'
  final String timestamp; // date+time string or time string
  final List<int> bits; // rightmost is Port1

  const CsvTimelineEntry({
    required this.type,
    required this.timestamp,
    required this.bits,
  });
}

class CsvTimeline {
  final List<CsvTimelineEntry> entries;
  final int inPortCount;
  final int outPortCount;

  const CsvTimeline({
    required this.entries,
    required this.inPortCount,
    required this.outPortCount,
  });
}

class CsvIoLogParser {
  /// IN/OUT を同時に保持する結果
  static ParsedIoLogBoth parseBoth(String csvText) {
    final lines = csvText.split(RegExp(r'\r?\n'));
    final inRows = <List<int>>[];
    final outRows = <List<int>>[];
    int inPortCount = 0;
    int outPortCount = 0;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 5) continue;
      final typeField = parts[2].trim().toUpperCase();

      final bitFields = parts.sublist(3); // 末尾の空要素も保持
      if (bitFields.isEmpty) continue;
      final bits = <int>[];
      for (final f in bitFields) {
        final s = f.trim();
        final v = s.isEmpty ? 0 : (int.tryParse(s) ?? 0);
        bits.add(v != 0 ? 1 : 0);
      }

      if (typeField == 'IN' || typeField == 'INPUT') {
        inPortCount = bits.length > inPortCount ? bits.length : inPortCount;
        inRows.add(bits);
      } else if (typeField == 'OUT' || typeField == 'OUTPUT') {
        outPortCount = bits.length > outPortCount ? bits.length : outPortCount;
        outRows.add(bits);
      }
    }

    return ParsedIoLogBoth(
      inRows: inRows,
      inPortCount: inPortCount,
      outRows: outRows,
      outPortCount: outPortCount,
    );
  }

  /// CSV テキストから OUT 行のみを抽出し、ポートビット配列の時系列を返す
  /// フォーマット想定:
  /// 日付, 時刻, 種別(IN/OUT), ビット..., (末尾はPort1)
  static ParsedIoLog parse(String csvText) {
    final lines = csvText.split(RegExp(r'\r?\n'));
    final resultRows = <List<int>>[];
    int detectedPortCount = 0;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      // 簡易CSV: カンマで分割（フィールドにカンマが含まれない前提）
      final parts = line.split(',');
      if (parts.length < 5) continue; // 最低限: 日付,時刻,種別,ビット1,ビット2...

      final typeField = parts[2].trim().toUpperCase();
      if (!(typeField == 'OUT' || typeField == 'OUTPUT')) continue;

      // 3 フィールド以降をビット配列として扱う。末尾の空要素を除去
      final bitFields = parts.sublist(3).where((s) => s.isNotEmpty).toList();
      if (bitFields.isEmpty) continue;
      detectedPortCount = bitFields.length;
      final bits = <int>[];
      for (final f in bitFields) {
        final v = int.tryParse(f.trim()) ?? 0;
        bits.add(v != 0 ? 1 : 0);
      }
      resultRows.add(bits);
    }

    return ParsedIoLog(rows: resultRows, portCount: detectedPortCount);
  }

  /// タイムライン（CSVの行順）として IN/OUT を統合して返す
  /// - entries: CSV行順（OUT/IN 含む）
  /// - bits: 右端が Port1（空欄は0）
  static CsvTimeline parseTimeline(String csvText) {
    final lines = csvText.split(RegExp(r'\r?\n'));
    final entries = <CsvTimelineEntry>[];
    int inPortCount = 0;
    int outPortCount = 0;

    // 末尾200行のみを対象（200行未満なら全行）
    final int startIndex = lines.length > 200 ? lines.length - 200 : 0;
    for (final raw in lines.sublist(startIndex)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 5) continue;
      final date = parts[0].trim();
      final time = parts[1].trim();
      final ts = '$date $time';
      final typeField = parts[2].trim().toUpperCase();
      final rawBitFields = parts.sublist(3);

      // 末尾の空要素は列としてカウントしない（Port1 は右端の数値カラム）
      int lastNonEmpty = -1;
      for (int i = rawBitFields.length - 1; i >= 0; i--) {
        if (rawBitFields[i].trim().isNotEmpty) {
          lastNonEmpty = i;
          break;
        }
      }
      if (lastNonEmpty < 0) continue;

      final bits = <int>[];
      for (int i = 0; i <= lastNonEmpty; i++) {
        final s = rawBitFields[i].trim();
        final v = int.tryParse(s) ?? 0;
        bits.add(v != 0 ? 1 : 0);
      }
      if (bits.isEmpty) continue;
      if (typeField == 'IN' || typeField == 'INPUT') {
        inPortCount = bits.length > inPortCount ? bits.length : inPortCount;
        entries.add(CsvTimelineEntry(type: 'IN', timestamp: ts, bits: bits));
      } else if (typeField == 'OUT' || typeField == 'OUTPUT') {
        outPortCount = bits.length > outPortCount ? bits.length : outPortCount;
        entries.add(CsvTimelineEntry(type: 'OUT', timestamp: ts, bits: bits));
      }
    }

    return CsvTimeline(
      entries: entries,
      inPortCount: inPortCount,
      outPortCount: outPortCount,
    );
  }
}
