import 'package:flutter/material.dart';

// ★ 他のファイルをインポート
import 'generated/l10n.dart'; // l10n
import 'common_padding.dart';
import 'custom_dropdown.dart';
import 'input_suggestion_text_field.dart';
import 'output_suggestion_text_field.dart';
import 'controller_list.dart';

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
  // --- MyHomePageから渡される状態とコールバック ---
  final String selectedTriggerOption;
  final ValueChanged<String?> onTriggerOptionChanged;

  final int selectedIoPort;
  final ValueChanged<int?> onIoPortChanged;

  final int selectedHwPort;
  final ValueChanged<int?> onHwPortChanged;

  final int selectedCamera;
  final ValueChanged<int?> onCameraChanged;

  final List<TextEditingController> inputControllers;
  final List<TextEditingController> outputControllers;
  final List<TextEditingController> hwTriggerControllers;

  // ★ チャート更新ボタンを押したときに呼び出すコールバック関数
  final VoidCallback onUpdateChart;

  // ★ クリアボタンを押したときに呼び出すコールバック関数を追加
  final VoidCallback onClearFields;

  // ★ 表示すべきInput/Outputの数 (コントローラーリストの長さとは別に管理)
  final int inputCount;
  final int outputCount;
  // ------------------------------------------

  const FormTab({
    super.key,
    required this.selectedTriggerOption,
    required this.onTriggerOptionChanged,
    required this.selectedIoPort,
    required this.onIoPortChanged,
    required this.selectedHwPort,
    required this.onHwPortChanged,
    required this.selectedCamera,
    required this.onCameraChanged,
    required this.inputControllers,
    required this.outputControllers,
    required this.hwTriggerControllers,
    required this.onUpdateChart,
    required this.onClearFields, // ★ 追加
    required this.inputCount,
    required this.outputCount,
  });

  @override
  State<FormTab> createState() => _FormTabState();
}

class _FormTabState extends State<FormTab> with AutomaticKeepAliveClientMixin {
  // --- AutomaticKeepAliveClientMixin ---
  // ★ タブを切り替えても入力状態を保持するために true を返す
  @override
  bool get wantKeepAlive => true;
  // ------------------------------------

  // ボタンのスタイルを統一するための定数
  static const double _buttonHeight = 48.0;
  static const double _buttonHorizontalPadding = 16.0;
  static const double _buttonVerticalPadding = 12.0;

  // --- 追加: テーブル用の状態 ---
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
    if (oldWidget.selectedCamera != widget.selectedCamera) {
      _initializeTableData();
    }
  }

  // テーブルデータの初期化
  void _initializeTableData() {
    // 安全チェック（カメラ数が0の場合に備える）
    final cameraCount = widget.selectedCamera > 0 ? widget.selectedCamera : 1;

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
        List.generate(widget.selectedCamera, (_) => CellMode.none),
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
    // ★ AutomaticKeepAliveClientMixin を使う場合は super.build(context) が必要
    super.build(context);

    final s = S.of(context); // l10n用

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
      // 角丸を除去して直線的なデザインに
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
      // 角丸を除去して直線的なデザインに
      border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
    );

    const headerPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    const headerHeight = 48.0; // ヘッダーの高さ

    // --- UI構築 ---
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // --- チャート名入力とボタンエリア ---
          Row(
            children: [
              // チャート名入力フィールド
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: s.chartNameLabel, // 'チャート名'
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // クリアボタン
              ElevatedButton.icon(
                onPressed: () {
                  // クリアボタンが押された時にフォームの状態を強制的に更新するためのコード
                  widget.onClearFields();
                  // クリア後に各フィールドの状態を更新するために少し遅延させる
                  Future.delayed(Duration.zero, () {
                    setState(() {
                      // テーブルデータを初期化
                      _initializeTableData();
                    });
                  });
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear'),
                style: clearButtonStyle,
              ),
              const SizedBox(width: 16),
              // チャート更新ボタン
              ElevatedButton.icon(
                onPressed: widget.onUpdateChart,
                icon: const Icon(Icons.update),
                label: Text(s.updateChartButton),
                style: updateButtonStyle,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- ドロップダウン設定群 ---
          Row(
            children: [
              // 画面幅に応じて折り返すように Wrap を使用
              Expanded(
                child: CustomDropdown<String>(
                  label: s.triggerOptionLabel, // 'Trigger Option'
                  value: widget.selectedTriggerOption,
                  items: ['Single', 'Code'], // ダミーデータ
                  onChanged: widget.onTriggerOptionChanged,
                  itemToString: (item) => item,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDropdown<int>(
                  label: s.ioPortLabel, // 'Total I/O Port'
                  value: widget.selectedIoPort,
                  items: [6, 16, 32, 64],
                  onChanged: widget.onIoPortChanged,
                  itemToString: (item) => item.toString(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDropdown(
                  label: s.hwPortLabel, // 'Total HW Port'
                  value: widget.selectedHwPort,
                  items: [0, 1, 2, 3, 4],
                  onChanged: widget.onHwPortChanged,
                  itemToString: (item) => item.toString(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDropdown<int>(
                  label: s.cameraLabel, // 'Total Camera'
                  value: widget.selectedCamera,
                  items: [1, 2, 3, 4, 5, 6, 7, 8],
                  onChanged: widget.onCameraChanged,
                  itemToString: (item) => item.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24), // 少し間隔を空ける
          // --- 信号名入力セクション ---
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左側に入力フィールドを配置（画面の半分のスペースを使用）
                Expanded(
                  flex: 5, // 左半分のスペースを使用
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
                              child: Text(
                                s.inputSignalSectionTitle,
                                style: Theme.of(context).textTheme.titleMedium,
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
                              child: Text(
                                s.outputSignalSectionTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                          // HW Trigger ヘッダー
                          Expanded(
                            child: Container(
                              decoration:
                                  widget.selectedHwPort > 0
                                      ? headerDecoration
                                      : inactiveHeaderDecoration,
                              padding: headerPadding,
                              alignment: Alignment.centerLeft,
                              height: headerHeight,
                              child: Text(
                                s.hwTriggerSectionTitle,
                                style:
                                    widget.selectedHwPort > 0
                                        ? Theme.of(
                                          context,
                                        ).textTheme.titleMedium
                                        : Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          color: Colors.grey.shade500,
                                        ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 入力フィールド部分
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- Input Signals ---
                            Expanded(
                              child: ListView.builder(
                                shrinkWrap: true, // Column内でListViewを使うため
                                physics:
                                    const AlwaysScrollableScrollPhysics(), // このリストはスクロール可能に
                                itemCount: widget.inputCount,
                                itemBuilder: (context, index) {
                                  // ★ 安全にコントローラーにアクセス
                                  if (index < widget.inputControllers.length) {
                                    return CommonPadding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4.0,
                                      ),
                                      child: AsyncInputSuggestionTextField(
                                        label:
                                            '${s.inputSignalPrefix} ${index + 1}', // 'Input N'
                                        controller:
                                            widget.inputControllers[index],
                                      ),
                                    );
                                  } else {
                                    // コントローラーが不足している場合 (通常は発生しないはず)
                                    return SizedBox.shrink();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16), // InputとOutputの間隔
                            // --- Output Signals ---
                            Expanded(
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics:
                                    const AlwaysScrollableScrollPhysics(), // このリストはスクロール可能に
                                itemCount: widget.outputCount,
                                itemBuilder: (context, index) {
                                  // ★ 安全にコントローラーにアクセス
                                  if (index < widget.outputControllers.length) {
                                    return CommonPadding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4.0,
                                      ),
                                      child: AsyncOutputSuggestionTextField(
                                        label:
                                            '${s.outputSignalPrefix} ${index + 1}',
                                        controller:
                                            widget.outputControllers[index],
                                      ),
                                    );
                                  } else {
                                    return SizedBox.shrink();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16), // OutputとHW Triggerの間隔
                            // --- HW Trigger Signals ---
                            // ★ HWポートが選択されている場合のみ表示
                            Expanded(
                              child:
                                  widget.selectedHwPort > 0
                                      ? ControllerList(
                                        controllers:
                                            widget.hwTriggerControllers,
                                        labelPrefix:
                                            s.hwTriggerPrefix, // 'HW Trigger'
                                      )
                                      : const Center(
                                        child: Text(
                                          "HWTrigger Ports are not available.",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16), // 左右のセクション間の間隔
                // 右側にテーブルを配置
                Expanded(
                  flex: 5, // 右半分のスペース
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, // 幅を最大に広げる
                    children: [
                      // テーブルヘッダー
                      Container(
                        decoration: headerDecoration,
                        padding: headerPadding,
                        alignment: Alignment.centerLeft,
                        height: headerHeight,
                        child: Text(
                          'Camera Configuration Table',
                          style: Theme.of(context).textTheme.titleMedium,
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
                      // テーブルコンテナ - 親の幅いっぱいに広げる
                      Expanded(child: _buildInteractiveTable()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    if (widget.selectedCamera > 6) {
      columnWidth = 80.0;
    } else if (widget.selectedCamera > 4) {
      columnWidth = 90.0;
    }

    // すべてのカメラ列に同じ固定幅を適用
    for (int i = 1; i <= widget.selectedCamera; i++) {
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
          for (int i = 0; i < widget.selectedCamera; i++)
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
            for (int col = 0; col < widget.selectedCamera; col++)
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
