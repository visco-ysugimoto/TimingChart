import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../models/form/form_state.dart';
import '../../models/chart/chart_data_generator.dart'; // 新しいジェネレータをインポート
import '../../models/chart/signal_type.dart'; // SignalTypeのインポートを追加
import '../../models/chart/signal_data.dart'; // SignalDataクラスをインポート
import '../../models/backup/app_config.dart'; // AppConfigをインポート
import '../../utils/file_utils.dart'; // FileUtilsをインポート
import 'input_section.dart';
import 'output_section.dart';
import 'hw_trigger_section.dart';
import '../common/custom_dropdown.dart';
import '../../common_padding.dart';
import '../chart/chart_signals.dart'; // チャート信号関連のクラスをインポート

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
  final Function(List<String>, List<List<int>>, List<SignalType>) onUpdateChart;
  final VoidCallback onClearFields;
  final bool showImportExportButtons; // インポート/エクスポートボタンの表示制御フラグ

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
    this.showImportExportButtons = true, // デフォルトは表示
  });

  @override
  State<FormTab> createState() => FormTabState();
}

class FormTabState extends State<FormTab> with AutomaticKeepAliveClientMixin {
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
  int _rowCount = 6;

  // テーブルデータを保持する2次元配列（初期値はすべてnone）
  List<List<CellMode>> _tableData = [];

  // SignalDataのリストを保持
  List<SignalData> _signalDataList = [];

  // 実際のチャートデータを保持（更新時に保存）
  List<List<int>> _actualChartData = [];

  // 信号の表示/非表示状態を管理するリスト (以前のリストは互換性のために残しておく)
  List<bool> _inputVisibility = [];
  List<bool> _outputVisibility = [];
  List<bool> _hwTriggerVisibility = [];

  @override
  void initState() {
    super.initState();
    // 初期化をここで行う
    _initializeTableData();
    _initializeSignalVisibility();
    _initializeSignalDataList();
  }

  // SignalDataリストを初期化
  void _initializeSignalDataList() {
    _signalDataList = [];

    // 入力信号
    for (int i = 0; i < widget.formState.inputCount; i++) {
      SignalType signalType = SignalType.input;
      bool isVisible = true;

      // Code Triggerの場合、totalIOポートの値に応じてSignalTypeを設定
      if (widget.formState.triggerOption == 'Code Trigger') {
        if (widget.formState.ioPort >= 32) {
          if (i >= 1 && i <= 8) {
            // Input2~9
            signalType = SignalType.control;
            isVisible = false;
            // Control信号の名前を自動設定
            widget.inputControllers[i].text = 'Control Code${i}(bit)';
          } else if (i >= 9 && i <= 14) {
            // Input10~15
            signalType = SignalType.group;
            isVisible = false;
          } else if (i >= 15 && i <= 20) {
            // Input16~21
            signalType = SignalType.task;
            isVisible = false;
          }
        } else if (widget.formState.ioPort == 16) {
          if (i >= 1 && i <= 4) {
            // Input2~5
            signalType = SignalType.control;
            isVisible = false;
            // Control信号の名前を自動設定
            widget.inputControllers[i].text = 'Control Code${i}(bit)';
          } else if (i >= 5 && i <= 7) {
            // Input6~8
            signalType = SignalType.group;
            isVisible = false;
          } else if (i >= 8 && i <= 13) {
            // Input9~14
            signalType = SignalType.task;
            isVisible = false;
          }
        }
      }

      _signalDataList.add(
        SignalData(
          name:
              widget.inputControllers[i].text.isNotEmpty
                  ? widget.inputControllers[i].text
                  : "Input ${i + 1}",
          signalType: signalType,
          values: List.filled(32, 0), // 初期値は0で埋める
          isVisible: isVisible,
        ),
      );
    }

    // HWトリガー信号
    for (int i = 0; i < widget.formState.hwPort; i++) {
      _signalDataList.add(
        SignalData(
          name:
              widget.hwTriggerControllers[i].text.isNotEmpty
                  ? widget.hwTriggerControllers[i].text
                  : "HW Trigger ${i + 1}",
          signalType: SignalType.hwTrigger,
          values: List.filled(32, 0),
          isVisible: _hwTriggerVisibility[i],
        ),
      );
    }

    // 出力信号
    for (int i = 0; i < widget.formState.outputCount; i++) {
      _signalDataList.add(
        SignalData(
          name:
              widget.outputControllers[i].text.isNotEmpty
                  ? widget.outputControllers[i].text
                  : "Output ${i + 1}",
          signalType: SignalType.output,
          values: List.filled(32, 0),
          isVisible: _outputVisibility[i],
        ),
      );
    }
  }

  // 信号の表示/非表示状態を初期化
  void _initializeSignalVisibility() {
    setState(() {
      _inputVisibility = List.generate(
        widget.formState.inputCount,
        (_) => true,
      );
      _outputVisibility = List.generate(
        widget.formState.outputCount,
        (_) => true,
      );
      _hwTriggerVisibility = List.generate(
        widget.formState.hwPort,
        (_) => true,
      );
    });
  }

  @override
  void didUpdateWidget(FormTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // カメラ数が変更された場合、テーブルデータを再初期化
    if (oldWidget.formState.camera != widget.formState.camera) {
      _initializeTableData();

      // カメラ数変更時にHW Portの値を調整（次のフレームでスケジュール）
      if (widget.formState.hwPort > widget.formState.camera) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          widget.onHwPortChanged(widget.formState.camera);
        });
      }
    }

    // 入力/出力/HWトリガーの数が変更された場合の処理
    bool needsUpdateSignalData = false;

    if (oldWidget.formState.inputCount != widget.formState.inputCount) {
      _updateVisibilityList(_inputVisibility, widget.formState.inputCount);
      needsUpdateSignalData = true;
    }
    if (oldWidget.formState.outputCount != widget.formState.outputCount) {
      _updateVisibilityList(_outputVisibility, widget.formState.outputCount);
      needsUpdateSignalData = true;
    }
    if (oldWidget.formState.hwPort != widget.formState.hwPort) {
      _updateVisibilityList(_hwTriggerVisibility, widget.formState.hwPort);
      needsUpdateSignalData = true;
    }

    if (needsUpdateSignalData) {
      _initializeSignalDataList();
    }
  }

  // 表示/非表示リストを更新
  void _updateVisibilityList(List<bool> list, int newCount) {
    setState(() {
      if (list.length < newCount) {
        // 増加した場合、新しい要素をtrueで追加
        list.addAll(List.generate(newCount - list.length, (_) => true));
      } else if (list.length > newCount) {
        // 減少した場合、余分な要素を削除
        list.removeRange(newCount, list.length);
      }
    });
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

  // 信号の表示/非表示を切り替え
  void _toggleSignalVisibility(int index, SignalType type) {
    setState(() {
      switch (type) {
        case SignalType.input:
          _inputVisibility[index] = !_inputVisibility[index];

          // SignalDataも更新
          int signalIndex = index;
          if (signalIndex < _signalDataList.length &&
              _signalDataList[signalIndex].signalType == SignalType.input) {
            _signalDataList[signalIndex] =
                _signalDataList[signalIndex].toggleVisibility();
          }
          break;

        case SignalType.output:
          _outputVisibility[index] = !_outputVisibility[index];

          // SignalDataも更新
          int signalIndex = widget.formState.inputCount + index;
          if (signalIndex < _signalDataList.length &&
              _signalDataList[signalIndex].signalType == SignalType.output) {
            _signalDataList[signalIndex] =
                _signalDataList[signalIndex].toggleVisibility();
          }
          break;

        case SignalType.hwTrigger:
          _hwTriggerVisibility[index] = !_hwTriggerVisibility[index];

          // SignalDataも更新
          int signalIndex =
              widget.formState.inputCount +
              widget.formState.outputCount +
              index;
          if (signalIndex < _signalDataList.length &&
              _signalDataList[signalIndex].signalType == SignalType.hwTrigger) {
            _signalDataList[signalIndex] =
                _signalDataList[signalIndex].toggleVisibility();
          }
          break;

        default:
          break;
      }
    });
  }

  // テーブルデータをクリアするメソッド
  void _clearTableData() {
    setState(() {
      // 全てのセルをnoneに設定
      for (int row = 0; row < _tableData.length; row++) {
        for (int col = 0; col < _tableData[row].length; col++) {
          _tableData[row][col] = CellMode.none;
        }
      }
    });
  }

  // SignalDataリストを更新
  void _updateSignalDataList() {
    setState(() {
      _signalDataList = [];

      // 入力信号
      for (int i = 0; i < widget.formState.inputCount; i++) {
        SignalType signalType = SignalType.input;
        bool isVisible = true;

        // Code Triggerの場合、totalIOポートの値に応じてSignalTypeを設定
        if (widget.formState.triggerOption == 'Code Trigger') {
          if (widget.formState.ioPort >= 32) {
            if (i >= 1 && i <= 8) {
              // Input2~9
              signalType = SignalType.control;
              isVisible = false;
              // Control信号の名前を自動設定
              widget.inputControllers[i].text = 'Control Code${i}(bit)';
            } else if (i >= 9 && i <= 14) {
              // Input10~15
              signalType = SignalType.group;
              isVisible = false;
            } else if (i >= 15 && i <= 20) {
              // Input16~21
              signalType = SignalType.task;
              isVisible = false;
            }
          } else if (widget.formState.ioPort == 16) {
            if (i >= 1 && i <= 4) {
              // Input2~5
              signalType = SignalType.control;
              isVisible = false;
              // Control信号の名前を自動設定
              widget.inputControllers[i].text = 'Control Code${i}(bit)';
            } else if (i >= 5 && i <= 7) {
              // Input6~8
              signalType = SignalType.group;
              isVisible = false;
            } else if (i >= 8 && i <= 13) {
              // Input9~14
              signalType = SignalType.task;
              isVisible = false;
            }
          }
        }

        if (widget.inputControllers[i].text.isNotEmpty) {
          _signalDataList.add(
            SignalData(
              name: widget.inputControllers[i].text,
              signalType: signalType,
              values: List.filled(32, 0), // あとでチャートデータで置き換え
              isVisible: isVisible,
            ),
          );
        }
      }

      // HWトリガー信号
      for (int i = 0; i < widget.formState.hwPort; i++) {
        if (widget.hwTriggerControllers[i].text.isNotEmpty) {
          _signalDataList.add(
            SignalData(
              name: widget.hwTriggerControllers[i].text,
              signalType: SignalType.hwTrigger,
              values: List.filled(32, 0),
              isVisible: _hwTriggerVisibility[i],
            ),
          );
        }
      }

      // 出力信号
      for (int i = 0; i < widget.formState.outputCount; i++) {
        if (widget.outputControllers[i].text.isNotEmpty) {
          _signalDataList.add(
            SignalData(
              name: widget.outputControllers[i].text,
              signalType: SignalType.output,
              values: List.filled(32, 0),
              isVisible: _outputVisibility[i],
            ),
          );
        }
      }

      // 生成したチャートデータをSignalDataに設定
      final chartData = generateTimingChartData();
      int dataIndex = 0;
      int signalIndex = 0;

      // 入力信号
      for (int i = 0; i < widget.formState.inputCount; i++) {
        if (widget.inputControllers[i].text.isNotEmpty) {
          if (signalIndex < _signalDataList.length &&
              dataIndex < chartData.length) {
            _signalDataList[signalIndex] = _signalDataList[signalIndex]
                .copyWith(values: List<int>.from(chartData[dataIndex]));
            signalIndex++;
          }
        }
        dataIndex++;
      }

      // HWトリガー信号
      for (int i = 0; i < widget.formState.hwPort; i++) {
        if (widget.hwTriggerControllers[i].text.isNotEmpty) {
          if (signalIndex < _signalDataList.length &&
              dataIndex < chartData.length) {
            _signalDataList[signalIndex] = _signalDataList[signalIndex]
                .copyWith(values: List<int>.from(chartData[dataIndex]));
            signalIndex++;
          }
        }
        dataIndex++;
      }

      // 出力信号
      for (int i = 0; i < widget.formState.outputCount; i++) {
        if (widget.outputControllers[i].text.isNotEmpty) {
          if (signalIndex < _signalDataList.length &&
              dataIndex < chartData.length) {
            _signalDataList[signalIndex] = _signalDataList[signalIndex]
                .copyWith(values: List<int>.from(chartData[dataIndex]));
            signalIndex++;
          }
        }
        dataIndex++;
      }
    });
  }

  // カメラテーブルの情報に基づいて時系列データを生成
  List<List<int>> generateTimingChartData({int timeLength = 32}) {
    final chartData = ChartDataGenerator.generateTimingChart(
      formState: widget.formState,
      inputControllers: widget.inputControllers,
      outputControllers: widget.outputControllers,
      hwTriggerControllers: widget.hwTriggerControllers,
      tableData: _tableData,
      timeLength: timeLength,
    );

    // デバッグ出力
    print('ChartDataGenerator.generateTimingChart の結果:');
    print('  返却されたデータ行数: ${chartData.length}');
    if (chartData.isNotEmpty) {
      print('  最初の行のデータ例: ${chartData[0]}');
      print(
        '  データにゼロ以外の値が含まれているか: ${chartData.any((row) => row.any((value) => value != 0))}',
      );
    }

    return chartData;
  }

  // SignalDataリストから表示用の信号名リストを生成
  List<String> generateSignalNames() {
    _updateSignalDataList(); // SignalDataを最新の状態に更新

    List<String> names = [];
    for (var signal in _signalDataList) {
      if (signal.isVisible) {
        names.add(signal.name);
      }
    }
    return names;
  }

  // SignalDataリストから表示用の信号タイプリストを生成
  List<SignalType> generateSignalTypes() {
    List<SignalType> types = [];
    for (var signal in _signalDataList) {
      if (signal.isVisible) {
        types.add(signal.signalType);
      }
    }
    return types;
  }

  // チャート更新時の表示/非表示対応のデータを生成
  List<List<int>> generateFilteredChartData() {
    List<List<int>> filteredData = [];
    for (var signal in _signalDataList) {
      if (signal.isVisible) {
        filteredData.add(List<int>.from(signal.values));
      }
    }
    return filteredData;
  }

  // 更新ボタンクリック時の処理
  void _onUpdateChart() {
    _updateSignalDataList();

    // チャートデータを生成
    final names = generateSignalNames();
    final chartData = generateFilteredChartData();
    final types = generateSignalTypes();

    // チャートデータを保存（エクスポート用）
    _actualChartData = List.from(chartData);

    // デバッグ出力
    print('チャート更新時のデータ:');
    print('  信号名: $names');
    print('  信号タイプ: $types');
    print('  チャートデータ行数: ${chartData.length}');
    if (chartData.isNotEmpty) {
      print('  最初の行のデータ例: ${chartData[0]}');
      print(
        '  データにゼロ以外の値が含まれているか: ${chartData.any((row) => row.any((value) => value != 0))}',
      );
    }

    // チャートを更新
    widget.onUpdateChart(names, chartData, types);
  }

  // AppConfigを現在の状態から作成
  AppConfig _createAppConfig() {
    // デバッグ情報を出力
    print('===== デバッグ情報: エクスポート時のチャートデータ =====');
    print('保存されたチャートデータの行数: ${_actualChartData.length}');
    if (_actualChartData.isNotEmpty) {
      print('最初の行のデータ例: ${_actualChartData[0]}');
      print(
        'データにゼロ以外の値が含まれているか: ${_actualChartData.any((row) => row.any((value) => value != 0))}',
      );
    }

    // ChartDataGeneratorの実装を確認
    print('FormState情報:');
    print('  formState.inputCount: ${widget.formState.inputCount}');
    print('  formState.outputCount: ${widget.formState.outputCount}');
    print('  formState.hwPort: ${widget.formState.hwPort}');
    print('  formState.camera: ${widget.formState.camera}');
    print('  テーブルデータ行数: ${_tableData.length}');
    if (_tableData.isNotEmpty) {
      print('  最初の行のモード: ${_tableData[0].map((c) => c.toString()).join(', ')}');
    }

    // 更新されたSignalDataリストを作成
    List<SignalData> updatedSignals = [];
    int inputIndex = 0;
    int outputIndex = 0;
    int hwTriggerIndex = 0;
    int chartDataIndex = 0;

    // 入力信号
    for (int i = 0; i < widget.formState.inputCount; i++) {
      if (widget.inputControllers[i].text.isNotEmpty) {
        List<int> values;

        // 実際のチャートデータを使用
        if (chartDataIndex < _actualChartData.length) {
          values = List.from(_actualChartData[chartDataIndex]);
          chartDataIndex++;
        } else {
          values = List.filled(32, 0); // デフォルト値
        }

        print('入力信号 $i の値: $values');

        updatedSignals.add(
          SignalData(
            name: widget.inputControllers[i].text,
            signalType: SignalType.input,
            values: values,
            isVisible: _inputVisibility[i],
          ),
        );

        inputIndex++;
      }
    }

    // 出力信号
    for (int i = 0; i < widget.formState.outputCount; i++) {
      if (widget.outputControllers[i].text.isNotEmpty) {
        List<int> values;

        // 実際のチャートデータを使用
        if (chartDataIndex < _actualChartData.length) {
          values = List.from(_actualChartData[chartDataIndex]);
          chartDataIndex++;
        } else {
          values = List.filled(32, 0); // デフォルト値
        }

        print('出力信号 $i の値: $values');

        updatedSignals.add(
          SignalData(
            name: widget.outputControllers[i].text,
            signalType: SignalType.output,
            values: values,
            isVisible: _outputVisibility[i],
          ),
        );

        outputIndex++;
      }
    }

    // HWトリガー信号
    for (int i = 0; i < widget.formState.hwPort; i++) {
      if (widget.hwTriggerControllers[i].text.isNotEmpty) {
        List<int> values;

        // 実際のチャートデータを使用
        if (chartDataIndex < _actualChartData.length) {
          values = List.from(_actualChartData[chartDataIndex]);
          chartDataIndex++;
        } else {
          values = List.filled(32, 0); // デフォルト値
        }

        print('HWトリガー信号 $i の値: $values');

        updatedSignals.add(
          SignalData(
            name: widget.hwTriggerControllers[i].text,
            signalType: SignalType.hwTrigger,
            values: values,
            isVisible: _hwTriggerVisibility[i],
          ),
        );

        hwTriggerIndex++;
      }
    }

    print('作成された信号の数: ${updatedSignals.length}');
    if (updatedSignals.isNotEmpty) {
      print('最初の信号の値: ${updatedSignals[0].values}');
    }
    print('=============================================');

    return AppConfig.fromCurrentState(
      formState: widget.formState,
      signals: updatedSignals, // 更新されたSignalDataリストを使用
      tableData: _tableData,
      inputControllers: widget.inputControllers,
      outputControllers: widget.outputControllers,
      hwTriggerControllers: widget.hwTriggerControllers,
      inputVisibility: _inputVisibility,
      outputVisibility: _outputVisibility,
      hwTriggerVisibility: _hwTriggerVisibility,
    );
  }

  // エクスポート前に「Update Chart」ボタンを自動的に押すことを推奨するダイアログを表示
  Future<bool> _confirmExport() async {
    if (_actualChartData.isEmpty ||
        !_actualChartData.any((row) => row.any((value) => value != 0))) {
      final shouldUpdate =
          await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('チャートデータが見つかりません'),
                  content: const Text(
                    'エクスポートする前に「Update Chart」ボタンをクリックしてチャートを更新することをお勧めします。\n\n'
                    'このまま進めますか？',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('このまま進める'),
                    ),
                  ],
                ),
          ) ??
          false;

      return shouldUpdate;
    }

    return true;
  }

  // 設定をエクスポート
  Future<void> _exportConfig() async {
    // エクスポート前の確認
    final shouldContinue = await _confirmExport();
    if (!shouldContinue) return;

    final config = _createAppConfig();
    final success = await FileUtils.exportAppConfig(config);

    if (!mounted) return;

    // 結果メッセージを表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'JSONファイルを保存しました' : 'ファイルの保存がキャンセルされました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 設定をインポート
  Future<void> _importConfig() async {
    final config = await FileUtils.importAppConfig();

    if (config == null || !mounted) return;

    // 状態を更新
    setState(() {
      // フォーム状態を更新
      widget.onTriggerOptionChanged(config.formState.triggerOption);
      widget.onIoPortChanged(config.formState.ioPort);
      widget.onHwPortChanged(config.formState.hwPort);
      widget.onCameraChanged(config.formState.camera);

      // テーブルデータを更新
      if (config.tableData.isNotEmpty) {
        _tableData = List.from(config.tableData);
        _rowCount = _tableData.length;
      }

      // 表示/非表示状態を更新
      _inputVisibility = List.from(config.inputVisibility);
      _outputVisibility = List.from(config.outputVisibility);
      _hwTriggerVisibility = List.from(config.hwTriggerVisibility);

      // SignalDataを更新
      _signalDataList = List.from(config.signals);

      // コントローラーを更新
      for (
        int i = 0;
        i < config.inputNames.length && i < widget.inputControllers.length;
        i++
      ) {
        widget.inputControllers[i].text = config.inputNames[i];
      }

      for (
        int i = 0;
        i < config.outputNames.length && i < widget.outputControllers.length;
        i++
      ) {
        widget.outputControllers[i].text = config.outputNames[i];
      }

      for (
        int i = 0;
        i < config.hwTriggerNames.length &&
            i < widget.hwTriggerControllers.length;
        i++
      ) {
        widget.hwTriggerControllers[i].text = config.hwTriggerNames[i];
      }
    });

    // チャートを更新
    _onUpdateChart();

    // 結果メッセージを表示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('インポートが完了しました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 外部からアクセスできるようにするメソッド
  List<SignalData> getSignalDataList() {
    // _actualChartDataがあれば、それを優先して使用
    if (_actualChartData.isNotEmpty &&
        _actualChartData.any((row) => row.any((val) => val != 0))) {
      print("getSignalDataList: _actualChartDataから非ゼロデータを検出");

      // 最新のデータに基づいてSignalDataを構築
      List<SignalData> result = [];
      int dataIndex = 0;

      // 入力信号
      for (int i = 0; i < widget.formState.inputCount; i++) {
        if (widget.inputControllers[i].text.isNotEmpty) {
          if (dataIndex < _actualChartData.length) {
            result.add(
              SignalData(
                name: widget.inputControllers[i].text,
                signalType: SignalType.input,
                values: List.from(_actualChartData[dataIndex]),
                isVisible:
                    i < _inputVisibility.length ? _inputVisibility[i] : true,
              ),
            );
            print(
              "Input[$i] の値: ${_actualChartData[dataIndex].take(10)}..., 非ゼロ値: ${_actualChartData[dataIndex].any((v) => v != 0)}",
            );
            dataIndex++;
          }
        }
      }

      // 出力信号
      for (int i = 0; i < widget.formState.outputCount; i++) {
        if (widget.outputControllers[i].text.isNotEmpty) {
          if (dataIndex < _actualChartData.length) {
            result.add(
              SignalData(
                name: widget.outputControllers[i].text,
                signalType: SignalType.output,
                values: List.from(_actualChartData[dataIndex]),
                isVisible:
                    i < _outputVisibility.length ? _outputVisibility[i] : true,
              ),
            );
            print(
              "Output[$i] の値: ${_actualChartData[dataIndex].take(10)}..., 非ゼロ値: ${_actualChartData[dataIndex].any((v) => v != 0)}",
            );
            dataIndex++;
          }
        }
      }

      // HWトリガー信号
      for (int i = 0; i < widget.formState.hwPort; i++) {
        if (widget.hwTriggerControllers[i].text.isNotEmpty) {
          if (dataIndex < _actualChartData.length) {
            result.add(
              SignalData(
                name: widget.hwTriggerControllers[i].text,
                signalType: SignalType.hwTrigger,
                values: List.from(_actualChartData[dataIndex]),
                isVisible:
                    i < _hwTriggerVisibility.length
                        ? _hwTriggerVisibility[i]
                        : true,
              ),
            );
            print(
              "HWTrigger[$i] の値: ${_actualChartData[dataIndex].take(10)}..., 非ゼロ値: ${_actualChartData[dataIndex].any((v) => v != 0)}",
            );
            dataIndex++;
          }
        }
      }

      if (result.isNotEmpty) {
        print("getSignalDataList: 構築したSignalDataList: ${result.length}個");
        return result;
      }
    }

    // データがない場合は既存のリストをコピーして返す
    _updateSignalDataList();
    print(
      "getSignalDataList: 既存のSignalDataListを使用: ${_signalDataList.length}個",
    );
    return List.from(_signalDataList);
  }

  List<List<CellMode>> getTableData() {
    return _tableData;
  }

  List<bool> getInputVisibility() {
    return _inputVisibility;
  }

  List<bool> getOutputVisibility() {
    return _outputVisibility;
  }

  List<bool> getHwTriggerVisibility() {
    return _hwTriggerVisibility;
  }

  // AppConfigからのデータ更新
  void updateFromAppConfig(AppConfig config) {
    setState(() {
      // テーブルデータを更新
      if (config.tableData.isNotEmpty) {
        _tableData = List.from(config.tableData);
        _rowCount = _tableData.length;
      }

      // 表示/非表示状態を更新
      if (config.inputVisibility.length == _inputVisibility.length) {
        _inputVisibility = List.from(config.inputVisibility);
      }

      if (config.outputVisibility.length == _outputVisibility.length) {
        _outputVisibility = List.from(config.outputVisibility);
      }

      if (config.hwTriggerVisibility.length == _hwTriggerVisibility.length) {
        _hwTriggerVisibility = List.from(config.hwTriggerVisibility);
      }

      // SignalDataの更新
      _signalDataList = List.from(config.signals);

      // チャートを更新
      _onUpdateChart();
    });
  }

  // チャートデータを強制的に更新するメソッド
  void updateChartData() {
    _updateSignalDataList();

    // 既存のチャートデータを保存
    List<List<int>> existingChartData = _actualChartData;
    bool hasExistingNonZeroData =
        existingChartData.isNotEmpty &&
        existingChartData.any((row) => row.any((val) => val != 0));

    if (hasExistingNonZeroData) {
      print("既存の非ゼロチャートデータが見つかりました - データを保持します");
    }

    // 新しいチャートデータを生成
    final newChartData = generateTimingChartData();

    if (hasExistingNonZeroData &&
        existingChartData.length == newChartData.length) {
      // 既存データと新しいデータの長さが同じ場合、非ゼロ値を保持する
      print("既存のチャートデータと新しいチャートデータをマージします");
      List<List<int>> mergedData = [];

      for (int i = 0; i < existingChartData.length; i++) {
        List<int> rowData = List<int>.from(newChartData[i]);

        // 既存データの長さを新しいデータに合わせる
        List<int> existingRow = existingChartData[i];
        if (existingRow.length > rowData.length) {
          existingRow = existingRow.sublist(0, rowData.length);
        } else if (existingRow.length < rowData.length) {
          existingRow = [
            ...existingRow,
            ...List<int>.filled(rowData.length - existingRow.length, 0),
          ];
        }

        // 非ゼロ値を保持
        for (int j = 0; j < rowData.length; j++) {
          if (j < existingRow.length && existingRow[j] != 0) {
            rowData[j] = existingRow[j];
          }
        }

        mergedData.add(rowData);
      }

      _actualChartData = mergedData;
    } else {
      // 長さが違う場合や既存データがない場合は新しいデータを使用
      _actualChartData = newChartData;
    }

    // チャートを更新
    widget.onUpdateChart(
      generateSignalNames(),
      generateFilteredChartData(),
      generateSignalTypes(),
    );
  }

  // チャートタブからのデータでSignalDataを更新
  void updateSignalDataFromChartData(
    List<List<int>> chartData,
    List<String> signalNames,
    List<SignalType> signalTypes,
  ) {
    if (chartData.isEmpty) return;

    setState(() {
      _actualChartData = List.from(chartData);
      List<SignalData> newSignalList = [];

      // コントローラーもクリア
      for (var c in widget.inputControllers) c.text = '';
      for (var c in widget.outputControllers) c.text = '';
      for (var c in widget.hwTriggerControllers) c.text = '';

      int inputIdx = 0, outputIdx = 0, hwIdx = 0;

      for (int i = 0; i < chartData.length; i++) {
        final name = i < signalNames.length ? signalNames[i] : 'Signal $i';
        final type = i < signalTypes.length ? signalTypes[i] : SignalType.input;
        final values = List.from(chartData[i]);

        // コントローラーへ反映
        if (type == SignalType.input ||
            type == SignalType.control ||
            type == SignalType.group ||
            type == SignalType.task) {
          if (inputIdx < widget.inputControllers.length) {
            widget.inputControllers[inputIdx].text = name;
          }
          inputIdx++;
        } else if (type == SignalType.output) {
          if (outputIdx < widget.outputControllers.length) {
            widget.outputControllers[outputIdx].text = name;
          }
          outputIdx++;
        } else if (type == SignalType.hwTrigger) {
          if (hwIdx < widget.hwTriggerControllers.length) {
            widget.hwTriggerControllers[hwIdx].text = name;
          }
          hwIdx++;
        }

        newSignalList.add(
          SignalData(
            name: name,
            signalType: type,
            values: List<int>.from(chartData[i]),
            isVisible: true,
          ),
        );
      }

      if (newSignalList.isNotEmpty) {
        _signalDataList = newSignalList;
      }
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
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: CustomDropdown<String>(
                      value: widget.formState.triggerOption,
                      items: const ['Single Trigger', 'Code Trigger'],
                      onChanged: widget.onTriggerOptionChanged,
                      label: 'Trigger Option',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomDropdown<int>(
                      value: widget.formState.ioPort,
                      items: const [6, 16, 32, 64],
                      onChanged: widget.onIoPortChanged,
                      label: 'IO Port',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomDropdown<int>(
                      value:
                          widget.formState.hwPort > widget.formState.camera
                              ? widget.formState.camera
                              : widget.formState.hwPort,
                      items: List.generate(
                        widget.formState.camera + 1,
                        (index) => index,
                      ),
                      onChanged: widget.onHwPortChanged,
                      label: 'HW Port',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomDropdown<int>(
                      value: widget.formState.camera,
                      items: List.generate(8, (index) => index + 1),
                      onChanged: widget.onCameraChanged,
                      label: 'Camera',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ボタン行
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // インポート/エクスポートボタンは条件付きで表示
                  if (widget.showImportExportButtons) ...[
                    ElevatedButton.icon(
                      onPressed: _importConfig,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('インポート'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade100,
                        foregroundColor: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _exportConfig,
                      icon: const Icon(Icons.download),
                      label: const Text('エクスポート'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                        foregroundColor: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  ElevatedButton(
                    onPressed: () {
                      // テーブルデータをクリア
                      _clearTableData();
                      // テキストフィールドをクリア
                      widget.onClearFields();
                    },
                    style: clearButtonStyle,
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _onUpdateChart(),
                    style: updateButtonStyle,
                    child: const Text('Update Chart'),
                  ),
                ],
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
                              child: Row(
                                children: [
                                  const Text(
                                    'Input Signals',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
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
                              child: Row(
                                children: [
                                  const Text(
                                    'Output Signals',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
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
                              child: Row(
                                children: [
                                  Expanded(
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
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // フィールド部分
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Input Signals セクション
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: SingleChildScrollView(
                                  child: InputSection(
                                    controllers: widget.inputControllers,
                                    count: widget.formState.inputCount,
                                    visibilityList: _inputVisibility,
                                    onVisibilityChanged:
                                        (index) => _toggleSignalVisibility(
                                          index,
                                          SignalType.input,
                                        ),
                                    triggerOption:
                                        widget.formState.triggerOption,
                                    ioPort: widget.formState.ioPort,
                                  ),
                                ),
                              ),
                            ),

                            // Output Signals セクション
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: SingleChildScrollView(
                                  child: OutputSection(
                                    controllers: widget.outputControllers,
                                    count: widget.formState.outputCount,
                                    visibilityList: _outputVisibility,
                                    onVisibilityChanged:
                                        (index) => _toggleSignalVisibility(
                                          index,
                                          SignalType.output,
                                        ),
                                  ),
                                ),
                              ),
                            ),

                            // HW Trigger セクション
                            Expanded(
                              child:
                                  widget.formState.hwPort > 0
                                      ? SingleChildScrollView(
                                        child: HwTriggerSection(
                                          controllers:
                                              widget.hwTriggerControllers,
                                          count: widget.formState.hwPort,
                                          visibilityList: _hwTriggerVisibility,
                                          onVisibilityChanged:
                                              (index) =>
                                                  _toggleSignalVisibility(
                                                    index,
                                                    SignalType.hwTrigger,
                                                  ),
                                        ),
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
                      ),
                    ],
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
