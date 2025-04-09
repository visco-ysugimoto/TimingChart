import 'package:flutter/material.dart';
import '../../models/form/form_state.dart';
import 'input_section.dart';
import 'output_section.dart';
import 'hw_trigger_section.dart';
import '../common/custom_dropdown.dart';
import '../../common_padding.dart';

// セルのモードを表す列挙型
enum CellMode { none, mode1, mode2, mode3, mode4, mode5 }

// セルモードの色とラベルのマッピング
const cellModeColors = {
  CellMode.none: Colors.white,
  CellMode.mode1: Colors.blue,
  CellMode.mode2: Colors.green,
  CellMode.mode3: Colors.amber,
  CellMode.mode4: Colors.purple,
  CellMode.mode5: Colors.orange,
};

const cellModeLabels = {
  CellMode.none: "None",
  CellMode.mode1: "Mode 1",
  CellMode.mode2: "Mode 2",
  CellMode.mode3: "Mode 3",
  CellMode.mode4: "Mode 4",
  CellMode.mode5: "Mode 5",
};

class FormTab extends StatefulWidget {
  final TimingFormState formState;
  final List<TextEditingController> inputControllers;
  final List<TextEditingController> outputControllers;
  final List<TextEditingController> hwTriggerControllers;
  final ValueChanged<String?> onTriggerOptionChanged;
  final ValueChanged<int?> onIoPortChanged;
  final ValueChanged<int?> onHwPortChanged;
  final ValueChanged<int?> onCameraChanged;
  final VoidCallback onUpdateChart;
  final VoidCallback onClearFields;

  const FormTab({
    super.key,
    required this.formState,
    required this.inputControllers,
    required this.outputControllers,
    required this.hwTriggerControllers,
    required this.onTriggerOptionChanged,
    required this.onIoPortChanged,
    required this.onHwPortChanged,
    required this.onCameraChanged,
    required this.onUpdateChart,
    required this.onClearFields,
  });

  @override
  State<FormTab> createState() => _FormTabState();
}

class _FormTabState extends State<FormTab> with AutomaticKeepAliveClientMixin {
  // --- AutomaticKeepAliveClientMixin ---
  // タブを切り替えても入力状態を保持するために true を返す
  @override
  bool get wantKeepAlive => true;

  // ボタンのスタイルを統一するための定数
  static const double _buttonHeight = 48.0;
  static const double _buttonHorizontalPadding = 16.0;
  static const double _buttonVerticalPadding = 12.0;

  // --- テーブル用の状態 ---
  // 初期行数
  int _rowCount = 5;

  // テーブルデータを保持する2次元配列（初期値はすべてnone）
  List<List<CellMode>> _tableData = [];

  @override
  void initState() {
    super.initState();
    // 初期化をここで行う
    _initializeTableData();
  }

  @override
  void didUpdateWidget(FormTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // カメラ数が変更された場合、テーブルデータを再初期化
    if (oldWidget.formState.camera != widget.formState.camera) {
      _initializeTableData();
    }
  }

  // テーブルデータの初期化
  void _initializeTableData() {
    // 安全チェック（カメラ数が0の場合に備える）
    final cameraCount =
        widget.formState.camera > 0 ? widget.formState.camera : 1;

    setState(() {
      _tableData = List.generate(
        _rowCount,
        (_) => List.generate(cameraCount, (_) => CellMode.none),
      );
    });
  }

  // 行を追加
  void _addRow() {
    setState(() {
      _tableData.add(
        List.generate(widget.formState.camera, (_) => CellMode.none),
      );
      _rowCount++;
    });
  }

  // 行を削除
  void _removeRow() {
    if (_rowCount > 1) {
      setState(() {
        _tableData.removeLast();
        _rowCount--;
      });
    }
  }

  // セルの値を変更
  void _changeCellMode(int row, int col, CellMode newMode) {
    setState(() {
      _tableData[row][col] = newMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    // AutomaticKeepAliveClientMixin を使う場合は super.build(context) が必要
    super.build(context);

    // 共通ボタンスタイルを作成
    final clearButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.red.shade100,
      foregroundColor: Colors.red.shade900,
      minimumSize: Size(120, _buttonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: _buttonHorizontalPadding,
        vertical: _buttonVerticalPadding,
      ),
    );

    final updateButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.blue.shade100,
      foregroundColor: Colors.blue.shade900,
      minimumSize: Size(120, _buttonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: _buttonHorizontalPadding,
        vertical: _buttonVerticalPadding,
      ),
    );

    final addRowButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.green.shade100,
      foregroundColor: Colors.green.shade900,
      minimumSize: Size(120, _buttonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: _buttonHorizontalPadding,
        vertical: _buttonVerticalPadding,
      ),
    );

    final removeRowButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.red.shade100,
      foregroundColor: Colors.red.shade900,
      minimumSize: Size(120, _buttonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: _buttonHorizontalPadding,
        vertical: _buttonVerticalPadding,
      ),
    );

    // セクションヘッダーのスタイルを定義
    final headerDecoration = BoxDecoration(
      color: Colors.grey.shade200,
      border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.shade300,
          offset: const Offset(0, 1),
          blurRadius: 2,
        ),
      ],
    );

    // 非アクティブなヘッダー用のスタイル
    final inactiveHeaderDecoration = BoxDecoration(
      color: Colors.grey.shade100,
      border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
    );

    const headerPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    const headerHeight = 48.0; // ヘッダーの高さ

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 上部のドロップダウンセクション
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: CustomDropdown<String>(
                  value: widget.formState.triggerOption,
                  items: const ['Single', 'Multiple'],
                  onChanged: widget.onTriggerOptionChanged,
                  label: 'Trigger Option',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDropdown<int>(
                  value: widget.formState.ioPort,
                  items: List.generate(12, (index) => index + 1),
                  onChanged: widget.onIoPortChanged,
                  label: 'IO Port',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDropdown<int>(
                  value: widget.formState.hwPort,
                  items: List.generate(4, (index) => index),
                  onChanged: widget.onHwPortChanged,
                  label: 'HW Port',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDropdown<int>(
                  value: widget.formState.camera,
                  items: List.generate(4, (index) => index + 1),
                  onChanged: widget.onCameraChanged,
                  label: 'Camera',
                ),
              ),
            ],
          ),
        ),

        // メインコンテンツエリア
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左側のカラム - 信号名入力フィールド群
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 連続したヘッダーバー
                        Row(
                          children: [
                            // Input Signals ヘッダー
                            Expanded(
                              child: Container(
                                decoration: headerDecoration,
                                padding: headerPadding,
                                alignment: Alignment.centerLeft,
                                height: headerHeight,
                                child: const Text(
                                  'Input Signals',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            // Output Signals ヘッダー
                            Expanded(
                              child: Container(
                                decoration: headerDecoration,
                                padding: headerPadding,
                                alignment: Alignment.centerLeft,
                                height: headerHeight,
                                child: const Text(
                                  'Output Signals',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            // HW Trigger ヘッダー（3列目）
                            Expanded(
                              child: Container(
                                decoration:
                                    widget.formState.hwPort > 0
                                        ? headerDecoration
                                        : inactiveHeaderDecoration,
                                padding: headerPadding,
                                alignment: Alignment.centerLeft,
                                height: headerHeight,
                                child: Text(
                                  'HW Trigger Signals',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color:
                                        widget.formState.hwPort > 0
                                            ? null
                                            : Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // フィールド部分
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Input Signals セクション
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: InputSection(
                                  controllers: widget.inputControllers,
                                  count: widget.formState.inputCount,
                                ),
                              ),
                            ),

                            // Output Signals セクション
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: OutputSection(
                                  controllers: widget.outputControllers,
                                  count: widget.formState.outputCount,
                                ),
                              ),
                            ),

                            // HW Trigger セクション
                            Expanded(
                              child:
                                  widget.formState.hwPort > 0
                                      ? HwTriggerSection(
                                        controllers:
                                            widget.hwTriggerControllers,
                                        count: widget.formState.hwPort,
                                      )
                                      : const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 16.0,
                                          ),
                                          child: Text(
                                            "HW Trigger Ports are not available.",
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 列の間隔
                const SizedBox(width: 32),

                // 右側のカラム - Camera Configuration Table
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // テーブルヘッダー
                      Container(
                        decoration: headerDecoration,
                        padding: headerPadding,
                        alignment: Alignment.centerLeft,
                        height: headerHeight,
                        child: const Text(
                          'Camera Configuration Table',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ボタン行を追加
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _addRow,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Row'),
                            style: addRowButtonStyle,
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _rowCount > 1 ? _removeRow : null,
                            icon: const Icon(Icons.remove),
                            label: const Text('Remove Row'),
                            style: removeRowButtonStyle,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // テーブルコンテナ
                      Expanded(child: _buildInteractiveTable()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ボタン
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: widget.onClearFields,
                style: clearButtonStyle,
                child: const Text('Clear'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: widget.onUpdateChart,
                style: updateButtonStyle,
                child: const Text('Update Chart'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // インタラクティブなテーブルを構築
  Widget _buildInteractiveTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal, // 横方向のスクロールを追加
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth, // 最小幅を親の幅に設定
              ),
              child: Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: _generateColumnWidths(),
                children: _buildTableRows(),
              ),
            ),
          ),
        );
      },
    );
  }

  // カメラ数に基づいてカラム幅を生成
  Map<int, TableColumnWidth> _generateColumnWidths() {
    final Map<int, TableColumnWidth> columnWidths = {
      0: const FixedColumnWidth(60), // 行番号列は固定幅
    };

    // カメラ数に応じて適切な幅を設定
    double columnWidth = 100.0; // デフォルト幅

    // カメラ数が多い場合は列幅を縮小
    if (widget.formState.camera > 6) {
      columnWidth = 80.0;
    } else if (widget.formState.camera > 4) {
      columnWidth = 90.0;
    }

    // すべてのカメラ列に同じ固定幅を適用
    for (int i = 1; i <= widget.formState.camera; i++) {
      columnWidths[i] = FixedColumnWidth(columnWidth);
    }

    return columnWidths;
  }

  // テーブルの行を構築
  List<TableRow> _buildTableRows() {
    List<TableRow> rows = [];

    // ヘッダー行を追加
    rows.add(
      TableRow(
        decoration: BoxDecoration(color: Colors.grey.shade200),
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
          // カメラ数に基づいてヘッダーを生成
          for (int i = 0; i < widget.formState.camera; i++)
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    'Camera ${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // データ行を追加
    for (int row = 0; row < _rowCount; row++) {
      rows.add(
        TableRow(
          children: [
            // 行番号セル
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(child: Text('${row + 1}')),
              ),
            ),
            // カメラ列のセルを生成
            for (int col = 0; col < widget.formState.camera; col++)
              TableCell(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: _buildModeDropdown(row, col),
                ),
              ),
          ],
        ),
      );
    }

    return rows;
  }

  // モード選択ドロップダウンを構築
  Widget _buildModeDropdown(int row, int col) {
    // Flutterの内部定義値を使用
    const double kMinInteractiveDimension = 48.0; // Flutterの内部値

    return Container(
      height: kMinInteractiveDimension,
      decoration: BoxDecoration(
        color: cellModeColors[_tableData[row][col]]?.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4.0), // パディングを縮小
      child: DropdownButton<CellMode>(
        value: _tableData[row][col],
        isExpanded: true,
        isDense: true, // よりコンパクトなドロップダウン
        underline: Container(), // 下線を非表示
        // 明示的にFlutterの最小値を設定
        itemHeight: kMinInteractiveDimension,
        onChanged: (CellMode? newValue) {
          if (newValue != null) {
            _changeCellMode(row, col, newValue);
          }
        },
        items:
            CellMode.values.map((CellMode mode) {
              return DropdownMenuItem<CellMode>(
                value: mode,
                // コンテンツの高さを調整して全体の高さを確保
                child: SizedBox(
                  height: kMinInteractiveDimension - 16, // パディングの分を考慮
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 12, // サイズ縮小
                        height: 12, // サイズ縮小
                        decoration: BoxDecoration(
                          color: cellModeColors[mode],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 4), // 間隔縮小
                      Flexible(
                        child: Text(
                          cellModeLabels[mode] ?? '',
                          overflow: TextOverflow.ellipsis, // テキストがはみ出す場合は省略
                          style: const TextStyle(fontSize: 12), // フォントサイズを小さく
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
}
