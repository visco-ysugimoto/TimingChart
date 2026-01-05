import 'package:flutter/material.dart';

import '../../models/form/camera_table_types.dart';

/// Camera Configuration Table（カメラ設定テーブル）
///
/// - `FormTab` から UI 構築ロジックを分離するためのウィジェット
/// - 状態（tableData/rowModes/columnModes/rowCount）は親が保持し、このウィジェットは描画と操作イベントの通知のみ担当
/// - このWidget自体は状態を持たず、UIの責務だけに限定します（テスト/保守性向上のため）
class CameraConfigurationTable extends StatelessWidget {
  final int cameraCount;
  final int rowCount;
  final List<List<CellMode>> tableData;
  final List<RowMode> rowModes;
  final List<CellMode> columnModes;
  final bool canSelectHwTrigger;

  final void Function(int row) onToggleRowMode;
  final void Function(int row, int col, CellMode mode) onChangeCellMode;
  final void Function(int col, CellMode mode) onChangeColumnMode;

  const CameraConfigurationTable({
    super.key,
    required this.cameraCount,
    required this.rowCount,
    required this.tableData,
    required this.rowModes,
    required this.columnModes,
    required this.canSelectHwTrigger,
    required this.onToggleRowMode,
    required this.onChangeCellMode,
    required this.onChangeColumnMode,
  });

  static const Map<RowMode, Color> rowModeColors = {
    RowMode.none: Colors.white,
    RowMode.simultaneous: Colors.teal, // 青緑色
  };

  static const Map<RowMode, String> rowModeLabelsJa = {
    RowMode.none: '',
    RowMode.simultaneous: '同時取込',
  };

  static const Map<RowMode, String> rowModeLabelsEn = {
    RowMode.none: '',
    RowMode.simultaneous: 'Simultaneous',
  };

  static const Map<CellMode, Color> cellModeColors = {
    CellMode.none: Colors.white,
    CellMode.mode1: Colors.blue,
    CellMode.mode2: Colors.green,
    CellMode.mode3: Colors.amber,
    CellMode.mode4: Colors.purple,
    CellMode.mode5: Colors.orange,
  };

  static const Map<CellMode, String> cellModeLabelsJa = {
    CellMode.none: "None",
    CellMode.mode1: "順次取込",
    CellMode.mode2: "接点入力",
    CellMode.mode3: "HWトリガ",
  };

  static const Map<CellMode, String> cellModeLabelsEn = {
    CellMode.none: "None",
    CellMode.mode1: "Sequential",
    CellMode.mode2: "Contact Input",
    CellMode.mode3: "HW Trigger",
  };

  String _labelForRowMode(BuildContext context, RowMode mode) {
    // Locale に応じて行モード表記（日本語/英語）を切り替える
    final String lang = Localizations.localeOf(context).languageCode;
    return (lang == 'ja' ? rowModeLabelsJa : rowModeLabelsEn)[mode] ?? '';
  }

  String _labelForCellMode(BuildContext context, CellMode mode) {
    // Locale に応じてセルモード表記（日本語/英語）を切り替える
    final String lang = Localizations.localeOf(context).languageCode;
    return (lang == 'ja' ? cellModeLabelsJa : cellModeLabelsEn)[mode] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    // 横/縦スクロール可能な Table として描画
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: _generateColumnWidths(),
                children: _buildTableRows(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Map<int, TableColumnWidth> _generateColumnWidths() {
    // 画面幅に応じて列幅を少し詰める（カメラ数が多いほど狭く）
    final Map<int, TableColumnWidth> columnWidths = {
      0: const FixedColumnWidth(60),
    };

    double columnWidth = 100.0;
    if (cameraCount > 6) {
      columnWidth = 80.0;
    } else if (cameraCount > 4) {
      columnWidth = 90.0;
    }

    for (int i = 1; i <= cameraCount; i++) {
      columnWidths[i] = FixedColumnWidth(columnWidth);
    }

    return columnWidths;
  }

  List<TableRow> _buildTableRows(BuildContext context) {
    // 先頭: ヘッダー行（Row / Camera1..）
    final List<TableRow> rows = [];

    rows.add(
      TableRow(
        decoration: BoxDecoration(
          color:
              (Theme.of(context).brightness == Brightness.dark)
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                      .withAlpha((0.3 * 255).round())
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        children: [
          const TableCell(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  'Row',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          for (int i = 0; i < cameraCount; i++)
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(child: _buildColumnHeader(context, i)),
              ),
            ),
        ],
      ),
    );

    for (int row = 0; row < rowCount; row++) {
      // データ行: 左端は Row番号＋行モード表示、各セルはモードドロップダウン
      rows.add(
        TableRow(
          children: [
            TableCell(
              child: InkWell(
                onTap: () => onToggleRowMode(row),
                child: Container(
                  color: (rowModeColors[rowModes[row]] ?? Colors.white)
                      .withAlpha((0.3 * 255).round()),
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${row + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (rowModes[row] != RowMode.none)
                          Text(
                            _labelForRowMode(context, rowModes[row]),
                            style: const TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            for (int col = 0; col < cameraCount; col++)
              TableCell(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: _buildModeDropdown(context, row, col),
                ),
              ),
          ],
        ),
      );
    }

    return rows;
  }

  Widget _buildModeDropdown(BuildContext context, int row, int col) {
    const double kMinInteractiveDimension = 48.0;

    // HWトリガが無効な場合は mode3 を選択肢から除外する
    final List<CellMode> allowedModes =
        CellMode.values
            .where((m) => m != CellMode.mode4 && m != CellMode.mode5)
            .where((m) => canSelectHwTrigger || m != CellMode.mode3)
            .toList();

    final CellMode currentValue =
        allowedModes.contains(tableData[row][col])
            ? tableData[row][col]
            : CellMode.none;

    return Container(
      height: kMinInteractiveDimension,
      decoration: BoxDecoration(
        color: (cellModeColors[tableData[row][col]] ?? Colors.transparent)
            .withAlpha((0.3 * 255).round()),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: DropdownButton<CellMode>(
        value: currentValue,
        isExpanded: true,
        isDense: true,
        underline: Container(),
        itemHeight: kMinInteractiveDimension,
        onChanged: (CellMode? newValue) {
          if (newValue == null) return;
          if (!canSelectHwTrigger && newValue == CellMode.mode3) return;
          if (newValue == CellMode.mode4 || newValue == CellMode.mode5) return;
          onChangeCellMode(row, col, newValue);
        },
        items:
            allowedModes.map((CellMode mode) {
              return DropdownMenuItem<CellMode>(
                value: mode,
                child: SizedBox(
                  height: kMinInteractiveDimension - 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: cellModeColors[mode],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _labelForCellMode(context, mode),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildColumnHeader(BuildContext context, int col) {
    // カラムヘッダー: PopupMenu で列一括変更
    final Color? bgColor = cellModeColors[columnModes.isNotEmpty
            ? columnModes[col]
            : CellMode.none]
        ?.withAlpha((0.3 * 255).round());

    final List<CellMode> allowedModes =
        CellMode.values
            .where((m) => m != CellMode.mode4 && m != CellMode.mode5)
            .toList();

    return PopupMenuButton<CellMode>(
      onSelected: (CellMode mode) {
        if (!canSelectHwTrigger && mode == CellMode.mode3) return;
        if (mode == CellMode.mode4 || mode == CellMode.mode5) return;
        onChangeColumnMode(col, mode);
      },
      itemBuilder: (context) {
        final modes =
            canSelectHwTrigger
                ? allowedModes
                : allowedModes.where((m) => m != CellMode.mode3).toList();
        return modes
            .map(
              (mode) => PopupMenuItem<CellMode>(
                value: mode,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: cellModeColors[mode],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(_labelForCellMode(context, mode)),
                  ],
                ),
              ),
            )
            .toList();
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Camera ${col + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }
}
