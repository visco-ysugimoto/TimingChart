/*
FormTab（フォーム入力タブ）

この画面でできること
- 入出力/HW Trigger の信号名を入力・表示/非表示を切替
- カメラ数や各種ポート数、Trigger モード（Single/Code/Command）を選択
- Camera Configuration Table で取込スケジュール（各カメラのモード）を設計
- Template/Update ボタンで波形を生成し、チャートへ反映
- 設定のインポート/エクスポート（必要に応じて）

全体のデータの流れ（概略）
1) 画面上の TextEditingController 群がユーザー入力を保持
2) 「Update Chart」を押すと、現在のフォーム状態 → SignalData に反映
3) 可視フィルタやポート番号を計算して、親（MyHomePage）へ onUpdateChart で送信
4) 親側は TimingChart に表示用データを渡し、必要に応じて FormTab 側へも値を戻す

重要な設計ポイント
- AutomaticKeepAliveClientMixin によりタブ切替でも入力が消えない
- Provider(FormStateNotifier) の値と TextEditingController の長さをこまめに同期
- Post-frame（WidgetsBinding）での更新を用いて build 中の通知を避け、例外や描画ズレを回避
- 「Code/Command Trigger」時は補助信号（Control/Group/Task/CODE_OPTION 等）を自動生成
*/
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
// import '../../common_padding.dart';
// import '../chart/chart_signals.dart'; // 未使用のため一時的に無効化
import '../../providers/form_state_notifier.dart';
import 'package:provider/provider.dart';
import '../../utils/chart_template_engine.dart';
import 'dart:math' as math;
import '../../providers/locale_notifier.dart';

// セルのモードを表す列挙型
enum CellMode { none, mode1, mode2, mode3, mode4, mode5 }

// 行モード（None / 同時取込）
enum RowMode { none, simultaneous }

const rowModeColors = {
  RowMode.none: Colors.white,
  RowMode.simultaneous: Colors.teal, // 任意の色
};

const rowModeLabels = {RowMode.none: '', RowMode.simultaneous: '同時取込'};

const rowModeLabelsEn = {
  RowMode.none: '',
  RowMode.simultaneous: 'Simultaneous',
};

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
  CellMode.mode1: "順次取込",
  CellMode.mode2: "接点入力",
  CellMode.mode3: "HWトリガ",
};

const cellModeLabelsEn = {
  CellMode.none: "None",
  CellMode.mode1: "Sequential",
  CellMode.mode2: "Contact Input",
  CellMode.mode3: "HW Trigger",
};

class FormTab extends StatefulWidget {
  final List<TextEditingController> inputControllers;
  final List<TextEditingController> outputControllers;
  final List<TextEditingController> hwTriggerControllers;
  final ValueChanged<String?> onTriggerOptionChanged;
  final ValueChanged<int?> onInputPortChanged;
  final ValueChanged<int?> onOutputPortChanged;
  final ValueChanged<int?> onHwPortChanged;
  final ValueChanged<int?> onCameraChanged;
  final void Function(
    List<String>,
    List<List<int>>,
    List<SignalType>,
    List<int>,
    bool,
  )
  onUpdateChart;
  final VoidCallback onClearFields;
  final bool showImportExportButtons; // インポート/エクスポートボタンの表示制御フラグ

  const FormTab({
    super.key,
    required this.inputControllers,
    required this.outputControllers,
    required this.hwTriggerControllers,
    required this.onTriggerOptionChanged,
    required this.onInputPortChanged,
    required this.onOutputPortChanged,
    required this.onHwPortChanged,
    required this.onCameraChanged,
    required this.onUpdateChart,
    required this.onClearFields,
    this.showImportExportButtons = false, // デフォルトは非表示
  });

  @override
  State<FormTab> createState() => FormTabState();
}

class FormTabState extends State<FormTab> with AutomaticKeepAliveClientMixin {
  // --- AutomaticKeepAliveClientMixin ---
  // タブを切り替えても入力状態を保持するために true を返す
  @override
  bool get wantKeepAlive => true;

  // 言語表示（日本語/英語）に応じて UI ラベルを切り替えるヘルパ
  // LocaleNotifier から現在の言語コードを取得し、適切な文字列を返す

  String _labelForRowMode(BuildContext context, RowMode mode) {
    final String lang = context.read<LocaleNotifier>().locale.languageCode;
    if (lang == 'ja') {
      return rowModeLabels[mode] ?? '';
    }
    return rowModeLabelsEn[mode] ?? '';
  }

  String _labelForCellMode(BuildContext context, CellMode mode) {
    final String lang = context.read<LocaleNotifier>().locale.languageCode;
    if (lang == 'ja') {
      return cellModeLabels[mode] ?? '';
    }
    return cellModeLabelsEn[mode] ?? '';
  }

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

  // --- 行モード ---
  // 各行に対してセルとは独立に設定できるモードを保持（None / 同時取込）
  List<RowMode> _rowModes = [];

  // === 追加: 列モード ===
  // 各カメラ列に対する CellMode を保持（列一括変更用）
  List<CellMode> _columnModes = [];

  // 信号の表示/非表示状態を管理するリスト (以前のリストは互換性のために残しておく)
  List<bool> _inputVisibility = [];
  List<bool> _outputVisibility = [];
  List<bool> _hwTriggerVisibility = [];

  // Provider からフォーム状態を取得するゲッター
  TimingFormState get formState => context.read<FormStateNotifier>().state;

  bool _initializedWithProvider = false;

  // 前回取得した各カウントを保持し、変化を検知する
  int _prevInputCount = -1;
  int _prevOutputCount = -1;
  int _prevHwPort = -1;
  int _prevCamera = -1;

  // PLC / EIP オプション
  String _plcEipOption = 'None';

  // 外部から PLC/EIP を反映するためのセッター
  void setPlcEipOption(String value) {
    if (value != 'None' && value != 'PLC' && value != 'EIP') return;
    setState(() {
      _plcEipOption = value;
    });
  }

  // TriggerOption に基づき Input テキストフィールド名を自動設定
  // Template と同じ規則（Code Trigger 時のみ適用）
  void applyInputNamesForTriggerOption() {
    final fs = formState;
    // Single Trigger: Input1 に TRIGGER
    if (fs.triggerOption == 'Single Trigger') {
      if (widget.inputControllers.isNotEmpty) {
        widget.inputControllers[0].text = 'TRIGGER';
      }
      return;
    }

    // Code Trigger: コード割当
    if (fs.triggerOption == 'Code Trigger') {
      // 0-based index を使用
      if (fs.inputCount >= 32) {
        for (
          int i = 0;
          i < widget.inputControllers.length && i < fs.inputCount;
          i++
        ) {
          if (i >= 1 && i <= 8) {
            widget.inputControllers[i].text = 'Control Code${i}(bit)';
          } else if (i >= 9 && i <= 14) {
            widget.inputControllers[i].text = 'Group Code${i}(bit)';
          } else if (i >= 15 && i <= 20) {
            widget.inputControllers[i].text = 'Task Code${i}(bit)';
          }
        }
      } else if (fs.inputCount == 16) {
        for (
          int i = 0;
          i < widget.inputControllers.length && i < fs.inputCount;
          i++
        ) {
          if (i >= 1 && i <= 4) {
            widget.inputControllers[i].text = 'Control Code${i}(bit)';
          } else if (i >= 5 && i <= 7) {
            widget.inputControllers[i].text = 'Group Code${i}(bit)';
          } else if (i >= 8 && i <= 13) {
            widget.inputControllers[i].text = 'Task Code${i}(bit)';
          }
        }
      }
    }
    // 名前設定後、必要なら SignalData 再生成は呼び出し元で行う
  }

  // bool _hwVis(int index) =>
  //     index < _hwTriggerVisibility.length ? _hwTriggerVisibility[index] : true;

  // ===== Output マッピング: totalOutputs -> { signalId : index } =====
  static const Map<int, Map<String, int>> _outputPresetMap = {
    // 6 ポート機
    6: {
      'AUTO_MODE': 1,
      'BUSY': 2, // Output1
      'ENABLE_RESULT_SIGNAL': 3, // Output2
      'TOTAL_RESULT_OK': 4, // Output3
      'TOTAL_RESULT_NG': 5, // Output4
    },
    // 16 ポート機
    16: {
      'AUTO_MODE': 1,
      'BUSY': 2, // Output9
      'ENABLE_RESULT_SIGNAL': 6, // Output10
      'TOTAL_RESULT_OK': 9, // Output11
      'TOTAL_RESULT_NG': 10, // Output12
    },
    // 32 ポート機
    32: {
      'AUTO_MODE': 1, // Output2
      'BUSY': 2, // Output3
      'RECOVERY': 26, // Output27
      'BATCH_EXPOSURE': 27, // Output28
      'ENABLE_RESULT_SIGNAL': 28, // Output29
      'ERROR': 29, // Output30
      'ACQ_TRIGGER_WAITING': 30, // Output31
      'PC_CONTROL': 31, // Output32
    },
  };

  // プリセットマッピングからインデックスを取得（無ければ -1）
  int _selectOutputIndex(String signalId, int totalOutputs, int totalCameras) {
    // --- 動的割付: 32 ポート機で CAM_EXPOSURE / ACQUISITION を配置 ---
    if (totalOutputs == 32) {
      final expReg = RegExp(r'^CAMERA_(\d+)_IMAGE_EXPOSURE');
      final acqReg = RegExp(r'^CAMERA_(\d+)_IMAGE_ACQUISITION');

      RegExpMatch? m = expReg.firstMatch(signalId);
      if (m != null) {
        final cam = int.parse(m.group(1)!);
        if (cam >= 1 && cam <= totalCameras) {
          // Output4(index3) から順に配置
          return 3 + (cam - 1);
        }
      }

      m = acqReg.firstMatch(signalId);
      if (m != null) {
        final cam = int.parse(m.group(1)!);
        if (cam >= 1 && cam <= totalCameras) {
          // Exposure の後に続けて配置 (Acquisition)
          return 3 + totalCameras + (cam - 1);
        }
      }

      // ---- TOTAL_RESULT_OK を Acquisition 群の 2 つ後に配置 ----
      if (signalId == 'TOTAL_RESULT_OK') {
        // 最後の Acquisition インデックス = 3 + totalCameras*2 - 1
        // そこから 2 つ後 ( +2 )
        return 3 + totalCameras * 2 + 1;
      }
      if (signalId == 'TOTAL_RESULT_NG') {
        // 最後の Acquisition インデックス = 3 + totalCameras*2 - 1
        // そこから 2 つ後 ( +2 )
        return 3 + totalCameras * 2 + 2;
      }
    }

    // 静的プリセット
    final preset = _outputPresetMap[totalOutputs];
    if (preset == null) return -1;
    return preset[signalId] ?? -1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final fs = formState;

    // 初回初期化
    if (!_initializedWithProvider) {
      _initializeTableData();
      _initializeSignalVisibility();
      _initializeSignalDataList();
      _initializedWithProvider = true;
    }

    // カメラ数が変わった場合はテーブル再初期化
    if (_prevCamera != -1 && _prevCamera != fs.camera) {
      _initializeTableData();

      // HW Port が 0 またはカメラ数以外の場合は、自動的にカメラ数へ更新
      if (fs.hwPort != 0 && fs.hwPort != fs.camera) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          widget.onHwPortChanged(fs.camera);
        });
      }
    }

    // 入出力/HWTrigger の数が変わった場合に Visibility リストを更新
    if (_prevInputCount != -1 && _prevInputCount != fs.inputCount) {
      _updateVisibilityList(_inputVisibility, fs.inputCount);
    }
    if (_prevOutputCount != -1 && _prevOutputCount != fs.outputCount) {
      _updateVisibilityList(_outputVisibility, fs.outputCount);
    }
    if (_prevHwPort != -1 && _prevHwPort != fs.hwPort) {
      _updateVisibilityList(_hwTriggerVisibility, fs.hwPort);
    }

    // 必要であれば SignalData を再生成
    if (_prevInputCount != fs.inputCount ||
        _prevOutputCount != fs.outputCount ||
        _prevHwPort != fs.hwPort ||
        _prevCamera != fs.camera) {
      _initializeSignalDataList();
    }

    // IO ポート = 6 のときは Code Trigger を強制的に Single Trigger へ変更
    if (fs.inputCount == 6 && fs.triggerOption == 'Code Trigger') {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        widget.onTriggerOptionChanged('Single Trigger');
      });
    }

    // 現在値を保存
    _prevInputCount = fs.inputCount;
    _prevOutputCount = fs.outputCount;
    _prevHwPort = fs.hwPort;
    _prevCamera = fs.camera;
  }

  // SignalDataリストを初期化
  void _initializeSignalDataList() {
    final formState = context.read<FormStateNotifier>().state;
    _signalDataList = [];

    // 入力信号
    for (int i = 0; i < formState.inputCount; i++) {
      SignalType signalType = SignalType.input;
      bool isVisible = _inputVisibility[i];

      // Code Triggerの場合、totalIOポートの値に応じてSignalTypeを設定
      if (formState.triggerOption == 'Code Trigger') {
        if (formState.inputCount >= 32) {
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
            widget.inputControllers[i].text = 'Group Code${i}(bit)';
          } else if (i >= 15 && i <= 20) {
            // Input16~21
            signalType = SignalType.task;
            isVisible = false;
            widget.inputControllers[i].text = 'Task Code${i}(bit)';
          }
        } else if (formState.inputCount == 16) {
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
            widget.inputControllers[i].text = 'Group Code${i}(bit)';
          } else if (i >= 8 && i <= 13) {
            // Input9~14
            signalType = SignalType.task;
            isVisible = false;
            widget.inputControllers[i].text = 'Task Code${i}(bit)';
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

    // HWトリガー信号 (Input の次に追加)
    for (int i = 0; i < formState.hwPort; i++) {
      if (widget.hwTriggerControllers[i].text.isNotEmpty) {
        _signalDataList.add(
          SignalData(
            name: widget.hwTriggerControllers[i].text,
            signalType: SignalType.hwTrigger,
            values: List.filled(32, 0),
            isVisible:
                i < _hwTriggerVisibility.length
                    ? _hwTriggerVisibility[i]
                    : true,
          ),
        );
      }
    }

    // 出力信号 (最後に追加)
    for (int i = 0; i < formState.outputCount; i++) {
      if (i < widget.outputControllers.length &&
          widget.outputControllers[i].text.isNotEmpty) {
        _signalDataList.add(
          SignalData(
            name: widget.outputControllers[i].text,
            signalType: SignalType.output,
            values: List.filled(32, 0),
            isVisible:
                i < _outputVisibility.length ? _outputVisibility[i] : true,
          ),
        );
      }
    }

    // === CODE_OPTION 追加 (Code Trigger モード専用) ===
    if (formState.triggerOption == 'Code Trigger') {
      final exists = _signalDataList.any((s) => s.name == 'CODE_OPTION');
      if (!exists) {
        _signalDataList.insert(
          0,
          SignalData(
            name: 'CODE_OPTION',
            signalType: SignalType.input,
            values: List.filled(32, 0),
            isVisible: true,
          ),
        );
      }
    }

    // === Command Option 追加 (Command Trigger モード専用) ===
    if (formState.triggerOption == 'Command Trigger') {
      final exists = _signalDataList.any((s) => s.name == 'Command Option');
      if (!exists) {
        _signalDataList.insert(
          0,
          SignalData(
            name: 'Command Option',
            signalType: SignalType.input,
            values: List.filled(32, 0),
            isVisible: true,
          ),
        );
      }
    }
  }

  // 信号の表示/非表示状態を初期化
  void _initializeSignalVisibility() {
    setState(() {
      _inputVisibility = List.generate(formState.inputCount, (_) => true);
      _outputVisibility = List.generate(formState.outputCount, (_) => true);
      _hwTriggerVisibility = List.generate(formState.hwPort, (_) => true);
    });
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
    final cameraCount = formState.camera > 0 ? formState.camera : 1;

    setState(() {
      _tableData = List.generate(
        _rowCount,
        (_) => List.generate(cameraCount, (_) => CellMode.none),
      );

      // 行モードも同時に初期化
      _rowModes = List.generate(_rowCount, (_) => RowMode.none);

      // === 追加: 列モードも初期化 ===
      _columnModes = List.generate(cameraCount, (_) => CellMode.none);
    });
  }

  // 行を追加
  void _addRow() {
    setState(() {
      _tableData.add(List.generate(formState.camera, (_) => CellMode.none));
      _rowCount++;

      // 行モードリストにも追加
      _rowModes.add(RowMode.none);
    });
  }

  // 行を削除
  void _removeRow() {
    if (_rowCount > 1) {
      setState(() {
        _tableData.removeLast();
        _rowCount--;

        // 行モードリストも同期
        _rowModes.removeLast();
      });
    }
  }

  // セルの値を変更
  void _changeCellMode(int row, int col, CellMode newMode) {
    setState(() {
      _tableData[row][col] = newMode;
    });
  }

  // === 追加: 列モードを一括変更 ===
  void _changeColumnMode(int col, CellMode newMode) {
    setState(() {
      for (int row = 0; row < _tableData.length; row++) {
        _tableData[row][col] = newMode;
      }
      // 選択状態を保存してヘッダーの色表示に利用
      if (col < _columnModes.length) {
        _columnModes[col] = newMode;
      }
    });
  }

  // 行モードを変更
  void _changeRowMode(int row) {
    setState(() {
      final current = _rowModes[row];
      _rowModes[row] =
          current == RowMode.none ? RowMode.simultaneous : RowMode.none;
    });
  }

  // 信号の表示/非表示を切り替え
  void _toggleSignalVisibility(int index, SignalType type) {
    setState(() {
      // 1. チェックボックスの状態を更新
      switch (type) {
        case SignalType.input:
          _inputVisibility[index] = !_inputVisibility[index];
          break;
        case SignalType.output:
          _outputVisibility[index] = !_outputVisibility[index];
          break;
        case SignalType.hwTrigger:
          if (index < _hwTriggerVisibility.length) {
            _hwTriggerVisibility[index] = !_hwTriggerVisibility[index];
          }
          break;
        default:
          break;
      }

      // 2. SignalData 側を名前ベースで更新（位置ズレ対策）
      String? targetName;
      switch (type) {
        case SignalType.input:
          if (index < widget.inputControllers.length) {
            targetName = widget.inputControllers[index].text;
          }
          break;
        case SignalType.output:
          if (index < widget.outputControllers.length) {
            targetName = widget.outputControllers[index].text;
          }
          break;
        case SignalType.hwTrigger:
          if (index < widget.hwTriggerControllers.length) {
            targetName = widget.hwTriggerControllers[index].text;
          }
          break;
        default:
          break;
      }

      if (targetName != null && targetName.isNotEmpty) {
        final sigIdx = _signalDataList.indexWhere(
          (s) => s.name == targetName && s.signalType == type,
        );
        if (sigIdx != -1) {
          _signalDataList[sigIdx] = _signalDataList[sigIdx].toggleVisibility();
        }
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

      // 行モードもリセット
      for (int i = 0; i < _rowModes.length; i++) {
        _rowModes[i] = RowMode.none;
      }
    });
  }

  // インポート前に Clear 相当の処理を外部から実行するための公開メソッド
  void clearAllForImport() {
    _clearTableData();
    widget.onClearFields();
  }

  // SignalDataリストを更新（位置情報を保持）
  void _updateSignalDataList() {
    setState(() {
      // === 追加: 既存の値をマッピング ===
      final Map<String, List<int>> prevValueMap = {
        for (final sig in _signalDataList) sig.name: List<int>.from(sig.values),
      };
      final int defaultWaveLength =
          prevValueMap.isNotEmpty ? prevValueMap.values.first.length : 32;

      // 既存順序を保持するためのリスト
      final List<String> prevOrder =
          _signalDataList.map((s) => s.name).toList();

      _signalDataList = [];

      // 各タイプごとに位置情報付きでSignalDataを作成
      Map<int, SignalData> inputSignalMap = {};
      Map<int, SignalData> outputSignalMap = {};
      Map<int, SignalData> hwTriggerSignalMap = {};

      // 入力信号（位置を保持）
      for (int i = 0; i < formState.inputCount; i++) {
        if (i < widget.inputControllers.length &&
            widget.inputControllers[i].text.isNotEmpty) {
          SignalType signalType = SignalType.input;
          bool isVisible =
              i < _inputVisibility.length ? _inputVisibility[i] : true;

          // Code Triggerの場合、totalIOポートの値に応じてSignalTypeを設定
          if (formState.triggerOption == 'Code Trigger') {
            if (formState.inputCount >= 32) {
              if (i >= 1 && i <= 8) {
                signalType = SignalType.control;
                isVisible = false;
                widget.inputControllers[i].text = 'Control Code${i}(bit)';
              } else if (i >= 9 && i <= 14) {
                signalType = SignalType.group;
                isVisible = false;
              } else if (i >= 15 && i <= 20) {
                signalType = SignalType.task;
                isVisible = false;
              }
            } else if (formState.inputCount == 16) {
              if (i >= 1 && i <= 4) {
                signalType = SignalType.control;
                isVisible = false;
                widget.inputControllers[i].text = 'Control Code${i}(bit)';
              } else if (i >= 5 && i <= 7) {
                signalType = SignalType.group;
                isVisible = false;
              } else if (i >= 8 && i <= 13) {
                signalType = SignalType.task;
                isVisible = false;
              }
            }
          }

          final String name = widget.inputControllers[i].text;
          inputSignalMap[i] = SignalData(
            name: name,
            signalType: signalType,
            values: prevValueMap[name] ?? List.filled(defaultWaveLength, 0),
            isVisible: isVisible,
          );
        }
      }

      // HWトリガー信号（位置を保持）
      for (int i = 0; i < formState.hwPort; i++) {
        if (widget.hwTriggerControllers[i].text.isNotEmpty) {
          final String name = widget.hwTriggerControllers[i].text;
          hwTriggerSignalMap[i] = SignalData(
            name: name,
            signalType: SignalType.hwTrigger,
            values: prevValueMap[name] ?? List.filled(defaultWaveLength, 0),
            isVisible:
                i < _hwTriggerVisibility.length
                    ? _hwTriggerVisibility[i]
                    : true,
          );
        }
      }

      // 出力信号（位置を保持）
      for (int i = 0; i < formState.outputCount; i++) {
        if (i < widget.outputControllers.length &&
            widget.outputControllers[i].text.isNotEmpty) {
          final String name = widget.outputControllers[i].text;
          outputSignalMap[i] = SignalData(
            name: name,
            signalType: SignalType.output,
            values: prevValueMap[name] ?? List.filled(defaultWaveLength, 0),
            isVisible:
                i < _outputVisibility.length ? _outputVisibility[i] : true,
          );
        }
      }

      // 位置情報付きでチャートデータを生成 (現在は未使用だが呼び出しを維持)
      generateTimingChartDataWithPositions(
        inputSignalMap,
        outputSignalMap,
        hwTriggerSignalMap,
        timeLength: defaultWaveLength,
      );

      // SignalDataリストを順序通りに構築（Input -> HWTrigger -> Output）
      for (int i = 0; i < formState.inputCount; i++) {
        if (inputSignalMap.containsKey(i)) {
          _signalDataList.add(inputSignalMap[i]!);
        }
      }
      for (int i = 0; i < formState.hwPort; i++) {
        if (hwTriggerSignalMap.containsKey(i)) {
          _signalDataList.add(hwTriggerSignalMap[i]!);
        }
      }
      for (int i = 0; i < formState.outputCount; i++) {
        if (outputSignalMap.containsKey(i)) {
          _signalDataList.add(outputSignalMap[i]!);
        }
      }

      // ---- 旧順序に基づいて並べ替え ----
      if (prevOrder.isNotEmpty) {
        _signalDataList.sort((a, b) {
          int ia = prevOrder.indexOf(a.name);
          int ib = prevOrder.indexOf(b.name);
          if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
          if (ia >= 0) return -1;
          if (ib >= 0) return 1;
          return 0;
        });
      }

      // === CODE_OPTION / Command Option を必ず含める ===
      if (formState.triggerOption == 'Code Trigger' &&
          !_signalDataList.any((s) => s.name == 'CODE_OPTION')) {
        _signalDataList.insert(
          0,
          SignalData(
            name: 'CODE_OPTION',
            signalType: SignalType.input,
            values:
                prevValueMap['CODE_OPTION'] ??
                List.filled(defaultWaveLength, 0),
            isVisible: true,
          ),
        );
      }

      if (formState.triggerOption == 'Command Trigger' &&
          !_signalDataList.any((s) => s.name == 'Command Option')) {
        _signalDataList.insert(
          0,
          SignalData(
            name: 'Command Option',
            signalType: SignalType.input,
            values:
                prevValueMap['Command Option'] ??
                List.filled(defaultWaveLength, 0),
            isVisible: true,
          ),
        );
      }
    });
  }

  // カメラテーブルの情報に基づいて時系列データを生成
  List<List<int>> generateTimingChartData({int timeLength = 32}) {
    final chartData = ChartDataGenerator.generateTimingChart(
      formState: formState,
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

  // 位置情報を保持してチャートデータを生成
  List<List<int>> generateTimingChartDataWithPositions(
    Map<int, SignalData> inputSignalMap,
    Map<int, SignalData> outputSignalMap,
    Map<int, SignalData> hwTriggerSignalMap, {
    int timeLength = 32,
  }) {
    List<List<int>> chartData = [];

    // Input信号のデータを位置順に追加
    for (int i = 0; i < formState.inputCount; i++) {
      if (inputSignalMap.containsKey(i)) {
        chartData.add(List.filled(timeLength, 0));
      }
    }

    // HWTrigger信号のデータを位置順に追加
    for (int i = 0; i < formState.hwPort; i++) {
      if (hwTriggerSignalMap.containsKey(i)) {
        chartData.add(List.filled(timeLength, 0));
      }
    }

    // Output信号のデータを位置順に追加
    for (int i = 0; i < formState.outputCount; i++) {
      if (outputSignalMap.containsKey(i)) {
        chartData.add(List.filled(timeLength, 0));
      }
    }

    return chartData;
  }

  // SignalDataリストから表示用の信号名リストを生成
  List<String> generateSignalNames() {
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

  // SignalDataリストから元ポート番号リストを生成 (Input/Output/HWTrigger のインデックス+1)
  List<int> generatePortNumbers() {
    List<int> ports = [];

    for (var signal in _signalDataList) {
      if (!signal.isVisible) continue;

      int idx;
      switch (signal.signalType) {
        case SignalType.input:
          idx = widget.inputControllers.indexWhere(
            (c) => c.text == signal.name,
          );
          ports.add(idx >= 0 ? idx + 1 : 0);
          break;
        case SignalType.hwTrigger:
          idx = widget.hwTriggerControllers.indexWhere(
            (c) => c.text == signal.name,
          );
          ports.add(idx >= 0 ? idx + 1 : 0);
          break;
        case SignalType.output:
          idx = widget.outputControllers.indexWhere(
            (c) => c.text == signal.name,
          );
          ports.add(idx >= 0 ? idx + 1 : 0);
          break;
        default:
          ports.add(0);
      }
    }
    return ports;
  }

  // 更新ボタンクリック時の処理
  Future<void> _onUpdateChart() async {
    _updateSignalDataList();

    // チャートデータを生成
    List<String> names = generateSignalNames();
    final chartData = generateFilteredChartData();
    List<SignalType> types = generateSignalTypes();
    List<int> ports = generatePortNumbers();

    // === CODE_OPTION 波形生成 ===
    if (formState.triggerOption == 'Code Trigger') {
      final autoIdx = names.indexOf('AUTO_MODE');
      final codeIdx = names.indexOf('CODE_OPTION');

      int waveLength = chartData.isNotEmpty ? chartData[0].length : 32;
      List<int> codeWave = List<int>.filled(waveLength, 0);

      if (autoIdx != -1) {
        final autoWave = chartData[autoIdx];
        codeWave = _generateCodeOptionWave(autoWave, waveLength);
      }

      if (codeIdx != -1) {
        chartData[codeIdx] = codeWave;
      } else {
        // 先頭に追加して 1番目の行に表示する
        names.insert(0, 'CODE_OPTION');
        types.insert(0, SignalType.input);
        ports.insert(0, 0);
        chartData.insert(0, codeWave);
      }

      // BUSY/TRIGGER/EXPOSURE 調整（共通ルール）
      _applyOptionPostRules(names, chartData, types, ports, 'CODE_OPTION');
    }

    // === Command Option 波形生成 ===
    if (formState.triggerOption == 'Command Trigger') {
      final autoIdx = names.indexOf('AUTO_MODE');
      final cmdIdx = names.indexOf('Command Option');

      int waveLength = chartData.isNotEmpty ? chartData[0].length : 32;
      List<int> cmdWave = List<int>.filled(waveLength, 0);

      if (autoIdx != -1) {
        final autoWave = chartData[autoIdx];
        cmdWave = _generateCodeOptionWave(autoWave, waveLength);
      }

      if (cmdIdx != -1) {
        chartData[cmdIdx] = cmdWave;
      } else {
        // 先頭に追加して 1番目の行に表示する
        names.insert(0, 'Command Option');
        types.insert(0, SignalType.input);
        ports.insert(0, 0);
        chartData.insert(0, cmdWave);
      }

      // BUSY/TRIGGER/EXPOSURE 調整（共通ルール）
      _applyOptionPostRules(names, chartData, types, ports, 'Command Option');
    }

    // === 可視状態で最終フィルタ ===
    final visibleNameSet =
        _signalDataList.where((s) => s.isVisible).map((s) => s.name).toSet();

    List<String> outNames = [];
    List<SignalType> outTypes = [];
    List<List<int>> outChartData = [];

    for (int i = 0; i < names.length; i++) {
      if (visibleNameSet.contains(names[i])) {
        outNames.add(names[i]);
        outTypes.add(types[i]);
        outChartData.add(chartData[i]);
      }
    }

    // チャートデータを保存（エクスポート用）
    _actualChartData = List.from(outChartData);

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

    // チャートを更新 (ID → ラベルへ変換)
    // names と types の順序に合わせたポート番号リストを生成（可視フィルタ後）
    ports = [];
    for (int i = 0; i < outNames.length; i++) {
      int idx;
      switch (outTypes[i]) {
        case SignalType.input:
          idx = widget.inputControllers.indexWhere(
            (c) => c.text == outNames[i],
          );
          ports.add(idx >= 0 ? idx + 1 : 0);
          break;
        case SignalType.hwTrigger:
          idx = widget.hwTriggerControllers.indexWhere(
            (c) => c.text == outNames[i],
          );
          ports.add(idx >= 0 ? idx + 1 : 0);
          break;
        case SignalType.output:
          idx = widget.outputControllers.indexWhere(
            (c) => c.text == outNames[i],
          );
          ports.add(idx >= 0 ? idx + 1 : 0);
          break;
        default:
          ports.add(0);
      }
    }

    widget.onUpdateChart(outNames, outChartData, outTypes, ports, false);

    // --- 追加: 完了通知 ---
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('チャートを更新しました。')));
  }

  // Template ボタンクリック時の処理
  Future<void> _onTemplatePressed() async {
    // 取込スケジュールから必要なサンプル長を推定し、ChartTemplateEngine に渡す
    // 最後の取込タイムスタンプに十分なバッファ(10ステップ)を加える
    // 32 未満にならないように最低長を確保する

    // ---------- Exposure スケジューリング ----------
    const int minGap = 4; // x=2 -> min_gap_seq=4 (露光間隔 5 サンプル)
    int currentTime = 6; // TRIGGER index3 High→Low で fall4 +2 =6

    // exposureTimes[camIndex] = List<timeIndex>
    Map<int, List<int>> exposureTimes = {
      for (int c = 1; c <= formState.camera; c++) c: [],
    };

    // モード別タイムスタンプ
    Map<int, List<int>> contactWaitTimes = {
      for (int c = 1; c <= formState.camera; c++) c: [],
    };
    Map<int, List<int>> hwTriggerTimes = {
      for (int c = 1; c <= formState.camera; c++) c: [],
    };

    final bool hasSimultaneous = _rowModes.any(
      (mode) => mode == RowMode.simultaneous,
    );

    if (hasSimultaneous) {
      // --- 元ロジック: 同時取込行を優先的に処理し、その他は行単位でカメラ順 ---
      for (int row = 0; row < _tableData.length; row++) {
        bool isSimul = _rowModes[row] == RowMode.simultaneous;
        if (isSimul) {
          bool any = false;
          for (int cam = 0; cam < formState.camera; cam++) {
            if (_tableData[row][cam] == CellMode.mode1 ||
                _tableData[row][cam] == CellMode.mode2 ||
                _tableData[row][cam] == CellMode.mode3) {
              exposureTimes[cam + 1]!.add(currentTime);
              if (_tableData[row][cam] == CellMode.mode2) {
                contactWaitTimes[cam + 1]!.add(currentTime);
              } else if (_tableData[row][cam] == CellMode.mode3) {
                hwTriggerTimes[cam + 1]!.add(currentTime);
              }
              any = true;
            }
          }
          if (any) currentTime += minGap + 1;
        } else {
          // rowMode.none 行はカメラごとに順次処理 (従来通り)
          for (int cam = 0; cam < formState.camera; cam++) {
            if (_tableData[row][cam] == CellMode.mode1 ||
                _tableData[row][cam] == CellMode.mode2 ||
                _tableData[row][cam] == CellMode.mode3) {
              exposureTimes[cam + 1]!.add(currentTime);
              if (_tableData[row][cam] == CellMode.mode2) {
                contactWaitTimes[cam + 1]!.add(currentTime);
              } else if (_tableData[row][cam] == CellMode.mode3) {
                hwTriggerTimes[cam + 1]!.add(currentTime);
              }
              currentTime += minGap + 1;
            }
          }
        }
      }
    } else {
      // --- 同時取込が無い場合: カメラ1の全取込 → カメラ2 → ... の順に処理 ---
      for (int cam = 0; cam < formState.camera; cam++) {
        for (int row = 0; row < _tableData.length; row++) {
          if (_tableData[row][cam] == CellMode.mode1 ||
              _tableData[row][cam] == CellMode.mode2 ||
              _tableData[row][cam] == CellMode.mode3) {
            exposureTimes[cam + 1]!.add(currentTime);
            if (_tableData[row][cam] == CellMode.mode2) {
              contactWaitTimes[cam + 1]!.add(currentTime);
            } else if (_tableData[row][cam] == CellMode.mode3) {
              hwTriggerTimes[cam + 1]!.add(currentTime);
            }
            currentTime += minGap + 1;
          }
        }
      }
    }

    // ---------- 必要サンプル長を計算 ----------
    int maxTimeIndex = exposureTimes.values
        .expand((list) => list)
        .fold<int>(0, (prev, element) => math.max(prev, element));

    // 最後のExposureから各種派生信号（Acquisition, BUSY, RESULT等）が生成されることを考慮し
    // 安全側に +32 ステップのバッファを確保する。
    int requiredSampleLength = math.max(32, maxTimeIndex + 32);

    // ChartTemplateEngine を動的サンプル長で生成
    final engine = ChartTemplateEngine(sampleLength: requiredSampleLength);

    final generatedSignals = await engine.generateSingleTriggerSignals(
      cameraCount: formState.camera,
      exposureTimes: exposureTimes,
      contactWaitTimes: contactWaitTimes,
      hwTriggerTimes: hwTriggerTimes,
    );

    if (generatedSignals.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('対応するテンプレートがありません。')));
      return;
    }

    // === 追加: HWポートが 0 の場合は HW Trigger 信号を除外 ===
    List<SignalData> filteredSignals = generatedSignals;
    if (formState.hwPort == 0) {
      filteredSignals =
          generatedSignals
              .where((sig) => sig.signalType != SignalType.hwTrigger)
              .toList();
    }

    // --- Camera Configuration Table から Mode 有無を判定 ---
    bool hasContactInputMode = false; // Mode2
    bool hasHwTriggerMode = false; // Mode3
    for (int r = 0; r < _tableData.length; r++) {
      for (int c = 0; c < _tableData[r].length; c++) {
        if (_tableData[r][c] == CellMode.mode2) hasContactInputMode = true;
        if (_tableData[r][c] == CellMode.mode3) hasHwTriggerMode = true;
      }
    }

    // --- Mode が無い場合は不要な信号を除外 ---
    if (!hasContactInputMode) {
      filteredSignals =
          filteredSignals
              .where((sig) => sig.name != 'CONTACT_INPUT_WAITING')
              .toList();
    }
    if (!(hasContactInputMode || hasHwTriggerMode)) {
      filteredSignals =
          filteredSignals
              .where((sig) => sig.name != 'ACQ_TRIGGER_WAITING')
              .toList();
    }

    // 生成された信号をフォームのテキストフィールドおよび内部状態へ反映
    updateSignalDataFromChartData(
      filteredSignals.map((e) => e.values).toList(),
      filteredSignals.map((e) => e.name).toList(),
      filteredSignals.map((e) => e.signalType).toList(),
    );

    // チャートを更新 (ID→ラベル変換)
    final List<String> names = filteredSignals.map((e) => e.name).toList();
    final values = filteredSignals.map((e) => e.values).toList();
    final types = filteredSignals.map((e) => e.signalType).toList();

    // Port番号リストをここで初期化 (後で再計算で上書き)
    List<int> ports = [];

    // === CODE_OPTION 波形生成 (Template) ===
    if (formState.triggerOption == 'Code Trigger') {
      final autoIdx = names.indexOf('AUTO_MODE');
      int waveLength = values.isNotEmpty ? values[0].length : 32;

      List<int> codeWave = List<int>.filled(waveLength, 0);

      if (autoIdx != -1) {
        final autoWave = values[autoIdx];
        codeWave = _generateCodeOptionWave(autoWave, waveLength);
      }

      // 先頭に追加
      names.insert(0, 'CODE_OPTION');
      types.insert(0, SignalType.input);
      values.insert(0, codeWave);

      // BUSY/TRIGGER/EXPOSURE 調整
      _applyOptionPostRules(names, values, types, ports, 'CODE_OPTION');
    }

    // === Command Option 波形生成 (Template) ===
    if (formState.triggerOption == 'Command Trigger') {
      final autoIdx = names.indexOf('AUTO_MODE');
      int waveLength = values.isNotEmpty ? values[0].length : 32;

      List<int> commandWave = List<int>.filled(waveLength, 0);

      if (autoIdx != -1) {
        final autoWave = values[autoIdx];
        // Code Trigger と同様の波形生成を適用
        commandWave = _generateCodeOptionWave(autoWave, waveLength);
      }

      // 先頭に追加（仮想的に Input0 として扱う）
      names.insert(0, 'Command Option');
      types.insert(0, SignalType.input);
      values.insert(0, commandWave);

      // BUSY/TRIGGER/EXPOSURE 調整（Code Trigger と同様）
      _applyOptionPostRules(names, values, types, ports, 'Command Option');
    }

    // === 追加: ポート番号リストを CODE_OPTION を含む形で再生成 ===
    // updateSignalDataFromChartData の時点では CODE_OPTION を含まない
    // _signalDataList が再構築されている可能性があるため、ここで
    // _updateSignalDataList() を呼び出して CODE_OPTION を確実に追加し、
    // その後 generatePortNumbers() で長さを揃えたリストを取得する。
    if (formState.triggerOption == 'Code Trigger') {
      _updateSignalDataList();
    }

    // === 可視状態で最終フィルタ（Template経路） ===
    final visibleNameSet =
        _signalDataList.where((s) => s.isVisible).map((s) => s.name).toSet();

    List<String> outNames = [];
    List<SignalType> outTypes = [];
    List<List<int>> outValues = [];
    List<int> outPorts = [];

    for (int i = 0; i < names.length; i++) {
      if (visibleNameSet.contains(names[i])) {
        outNames.add(names[i]);
        outTypes.add(types[i]);
        outValues.add(values[i]);
      }
    }

    // ports 再計算（可視フィルタ後）
    for (int i = 0; i < outNames.length; i++) {
      int idx;
      switch (outTypes[i]) {
        case SignalType.input:
          idx = widget.inputControllers.indexWhere(
            (c) => c.text == outNames[i],
          );
          outPorts.add(idx >= 0 ? idx + 1 : 0);
          break;
        case SignalType.hwTrigger:
          idx = widget.hwTriggerControllers.indexWhere(
            (c) => c.text == outNames[i],
          );
          outPorts.add(idx >= 0 ? idx + 1 : 0);
          break;
        case SignalType.output:
          idx = widget.outputControllers.indexWhere(
            (c) => c.text == outNames[i],
          );
          outPorts.add(idx >= 0 ? idx + 1 : 0);
          break;
        default:
          outPorts.add(0);
      }
    }

    widget.onUpdateChart(outNames, outValues, outTypes, outPorts, true);

    // --- 追加: ユーザーへ完了通知 ---
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('テンプレート信号を生成しました。')));
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
    print('  formState.inputCount: ${formState.inputCount}');
    print('  formState.outputCount: ${formState.outputCount}');
    print('  formState.hwPort: ${formState.hwPort}');
    print('  formState.camera: ${formState.camera}');
    print('  テーブルデータ行数: ${_tableData.length}');
    if (_tableData.isNotEmpty) {
      print('  最初の行のモード: ${_tableData[0].map((c) => c.toString()).join(', ')}');
    }

    // 更新されたSignalDataリストを作成
    List<SignalData> updatedSignals = [];
    int dataIndex = 0;

    // 入力信号
    for (int i = 0; i < formState.inputCount; i++) {
      if (widget.inputControllers[i].text.isNotEmpty) {
        List<int> values;
        if (dataIndex < _actualChartData.length) {
          values = List.from(_actualChartData[dataIndex]);
          dataIndex++;
        } else {
          values = List.filled(32, 0);
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

        // indexは未使用のため削除済み
      }
    }

    // 出力信号
    for (int i = 0; i < formState.outputCount; i++) {
      if (i < widget.outputControllers.length &&
          widget.outputControllers[i].text.isNotEmpty) {
        List<int> values;
        if (dataIndex < _actualChartData.length) {
          values = List.from(_actualChartData[dataIndex]);
          dataIndex++;
        } else {
          values = List.filled(32, 0);
        }

        print('出力信号 $i の値: $values');

        updatedSignals.add(
          SignalData(
            name: widget.outputControllers[i].text,
            signalType: SignalType.output,
            values: values,
            isVisible:
                i < _outputVisibility.length ? _outputVisibility[i] : true,
          ),
        );

        // indexは未使用のため削除済み
      }
    }

    // HWトリガー信号
    for (int i = 0; i < formState.hwPort; i++) {
      if (widget.hwTriggerControllers[i].text.isNotEmpty) {
        List<int> values;
        if (dataIndex < _actualChartData.length) {
          values = List.from(_actualChartData[dataIndex]);
          dataIndex++;
        } else {
          values = List.filled(32, 0);
        }

        print('HWトリガー信号 $i の値: $values');

        updatedSignals.add(
          SignalData(
            name: widget.hwTriggerControllers[i].text,
            signalType: SignalType.hwTrigger,
            values: values,
            isVisible:
                i < _hwTriggerVisibility.length
                    ? _hwTriggerVisibility[i]
                    : true,
          ),
        );

        // indexは未使用のため削除済み
      }
    }

    print('作成された信号の数: ${updatedSignals.length}');
    if (updatedSignals.isNotEmpty) {
      print('最初の信号の値: ${updatedSignals[0].values}');
    }
    print('=============================================');

    return AppConfig.fromCurrentState(
      formState: formState,
      signals: updatedSignals, // 更新されたSignalDataリストを使用
      tableData: _tableData,
      inputControllers: widget.inputControllers,
      outputControllers: widget.outputControllers,
      hwTriggerControllers: widget.hwTriggerControllers,
      inputVisibility: _inputVisibility,
      outputVisibility: _outputVisibility,
      hwTriggerVisibility: _hwTriggerVisibility,
      rowModes: _rowModes.map((e) => e.name).toList(),
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
    final success = await FileUtils.exportWaveDrom(config);

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
      widget.onInputPortChanged(config.formState.inputCount);
      widget.onOutputPortChanged(config.formState.outputCount);
      widget.onHwPortChanged(config.formState.hwPort);
      widget.onCameraChanged(config.formState.camera);

      // テーブルデータを更新
      if (config.tableData.isNotEmpty) {
        _tableData = List.from(config.tableData);
        _rowCount = _tableData.length;
      }

      // --- RowMode を復元 ---
      _rowModes =
          config.rowModes
              .map(
                (name) => RowMode.values.firstWhere(
                  (e) => e.name == name,
                  orElse: () => RowMode.none,
                ),
              )
              .toList();

      // 行数との差を調整
      if (_rowModes.length < _rowCount) {
        _rowModes.addAll(
          List.filled(_rowCount - _rowModes.length, RowMode.none),
        );
      } else if (_rowModes.length > _rowCount) {
        _rowModes = _rowModes.sublist(0, _rowCount);
      }

      // 表示/非表示状態を更新
      _inputVisibility = List.from(config.inputVisibility);
      _outputVisibility = List.from(config.outputVisibility);
      _hwTriggerVisibility = List.from(config.hwTriggerVisibility);

      // SignalDataを更新
      _signalDataList = List.from(config.signals);

      // --- チャートデータを復元 (可視信号のみ) ---
      _actualChartData =
          _signalDataList
              .where((s) => s.isVisible)
              .map((s) => List<int>.from(s.values))
              .toList();

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
    await _onUpdateChart();

    // 結果メッセージを表示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('インポートが完了しました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 外部からアクセスできるようにするメソッド（位置関係を保持）
  List<SignalData> getSignalDataList() {
    // _actualChartDataがあれば、それを優先して使用
    if (_actualChartData.isNotEmpty &&
        _actualChartData.any((row) => row.any((val) => val != 0))) {
      print("getSignalDataList: _actualChartDataから非ゼロデータを検出");

      // 位置関係を保持してSignalDataを構築
      List<SignalData> result = [];
      int dataIndex = 0;

      // 入力信号（位置を保持）
      for (int i = 0; i < formState.inputCount; i++) {
        if (widget.inputControllers[i].text.isNotEmpty) {
          SignalType signalType = SignalType.input;
          // Code Triggerの場合のタイプ判定
          if (formState.triggerOption == 'Code Trigger') {
            if (formState.inputCount >= 32) {
              if (i >= 1 && i <= 8) {
                signalType = SignalType.control;
              } else if (i >= 9 && i <= 14) {
                signalType = SignalType.group;
              } else if (i >= 15 && i <= 20) {
                signalType = SignalType.task;
              }
            } else if (formState.inputCount == 16) {
              if (i >= 1 && i <= 4) {
                signalType = SignalType.control;
              } else if (i >= 5 && i <= 7) {
                signalType = SignalType.group;
              } else if (i >= 8 && i <= 13) {
                signalType = SignalType.task;
              }
            }
          }

          List<int> values;
          if (dataIndex < _actualChartData.length) {
            values = List.from(_actualChartData[dataIndex]);
            dataIndex++;
          } else {
            values = List.filled(32, 0);
          }

          result.add(
            SignalData(
              name: widget.inputControllers[i].text,
              signalType: signalType,
              values: values,
              isVisible:
                  i < _inputVisibility.length ? _inputVisibility[i] : true,
            ),
          );
        }
      }

      // HWトリガー信号（位置を保持）
      for (int i = 0; i < formState.hwPort; i++) {
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

      // 出力信号（位置を保持）
      for (int i = 0; i < formState.outputCount; i++) {
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

      // --- RowMode を復元 ---
      _rowModes =
          config.rowModes
              .map(
                (name) => RowMode.values.firstWhere(
                  (e) => e.name == name,
                  orElse: () => RowMode.none,
                ),
              )
              .toList();

      // 行数との差を調整
      if (_rowModes.length < _rowCount) {
        _rowModes.addAll(
          List.filled(_rowCount - _rowModes.length, RowMode.none),
        );
      } else if (_rowModes.length > _rowCount) {
        _rowModes = _rowModes.sublist(0, _rowCount);
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

      // --- チャートデータを復元 ---
      _actualChartData =
          _signalDataList
              .where((s) => s.isVisible)
              .map((s) => List<int>.from(s.values))
              .toList();

      // チャートを更新
      _onUpdateChart();
    });
  }

  // チャートデータを強制的に更新するメソッド
  Future<void> updateChartData() async {
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

    // チャートを更新（ID → ラベルへ変換）
    final List<String> names = generateSignalNames();
    widget.onUpdateChart(
      names,
      generateFilteredChartData(),
      generateSignalTypes(),
      generatePortNumbers(),
      false,
    );
  }

  // チャートタブから値のみを更新（名前位置は変更しない）
  void setChartDataOnly(List<List<int>> chartData) {
    if (chartData.isEmpty) return;
    setState(() {
      _actualChartData = List.from(chartData);
    });
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

      // 既存のコントローラーの値を保存（元の位置を保持するため）
      Map<String, int> existingInputMap = {};
      Map<String, int> existingOutputMap = {};
      Map<String, int> existingHwTriggerMap = {};

      // 既存の値とその位置を記録
      for (int i = 0; i < widget.inputControllers.length; i++) {
        if (widget.inputControllers[i].text.isNotEmpty) {
          existingInputMap[widget.inputControllers[i].text] = i;
        }
      }
      for (int i = 0; i < widget.outputControllers.length; i++) {
        if (widget.outputControllers[i].text.isNotEmpty) {
          existingOutputMap[widget.outputControllers[i].text] = i;
        }
      }
      for (int i = 0; i < widget.hwTriggerControllers.length; i++) {
        if (widget.hwTriggerControllers[i].text.isNotEmpty) {
          existingHwTriggerMap[widget.hwTriggerControllers[i].text] = i;
        }
      }

      // 全てのコントローラーをクリア
      for (var c in widget.inputControllers) c.text = '';
      for (var c in widget.outputControllers) c.text = '';
      for (var c in widget.hwTriggerControllers) c.text = '';

      for (int i = 0; i < chartData.length; i++) {
        final name = i < signalNames.length ? signalNames[i] : 'Signal $i';
        final type = i < signalTypes.length ? signalTypes[i] : SignalType.input;
        final values = List<int>.from(chartData[i]); // 以後の書き込みで使用するため保持

        // コントローラーへ反映（既存の位置を優先使用）
        if (type == SignalType.input ||
            type == SignalType.control ||
            type == SignalType.group ||
            type == SignalType.task) {
          int targetIndex = existingInputMap[name] ?? -1;

          // --- Custom mapping: Place CONTACT_INPUT_WAITING at Input30 when input ports >= 32 ---
          if (targetIndex == -1 && name == 'CONTACT_INPUT_WAITING') {
            final fs = context.read<FormStateNotifier>().state;
            if (fs.inputCount >= 32 && widget.inputControllers.length >= 30) {
              targetIndex = 29; // 0-based index for Input30
            }
          }

          if (targetIndex == -1) {
            // 既存位置がない場合は最初の空いている位置を使用
            for (int j = 0; j < widget.inputControllers.length; j++) {
              if (widget.inputControllers[j].text.isEmpty) {
                targetIndex = j;
                break;
              }
            }
          }
          if (targetIndex >= 0 &&
              targetIndex < widget.inputControllers.length) {
            widget.inputControllers[targetIndex].text = name;
          }
        } else if (type == SignalType.output) {
          // 1) 既存の位置（INI の Port.No 反映済み）を最優先
          final fs = context.read<FormStateNotifier>().state;
          int targetIndex = existingOutputMap[name] ?? -1;

          if (targetIndex != -1) {
            // カメラ用予約ブロックを非カメラ信号で使用しない制約
            if (fs.outputCount == 32) {
              final int reservedStart = 3; // Output4 から
              final int reservedEnd = 3 + fs.camera * 2 - 1; // Exposure/Acq の末尾
              final bool isInReserved =
                  targetIndex >= reservedStart && targetIndex <= reservedEnd;
              final bool isCameraSignal = RegExp(
                r'^CAMERA_(\d+)_IMAGE_(EXPOSURE|ACQUISITION)',
              ).hasMatch(name);
              if (!isCameraSignal && isInReserved) {
                targetIndex = -1; // 予約ブロックは使わせない
              }
            }
          }

          // 2) 既存位置が無ければ、プリセット位置を使用
          if (targetIndex == -1) {
            targetIndex = _selectOutputIndex(name, fs.outputCount, fs.camera);
          }

          // 3) それでも見つからなければ、空いている欄を探す
          if (targetIndex == -1) {
            int startIdx = 0;
            if (fs.outputCount == 32) {
              // TOTAL_RESULT_NG の直後から配置したい
              int reservedEnd = 3 + fs.camera * 2 + 2; // TOT_NG index
              startIdx = reservedEnd + 1;
              if (startIdx >= widget.outputControllers.length) {
                startIdx = 0; // フォールバック（念のため）
              }
            }

            for (int j = startIdx; j < widget.outputControllers.length; j++) {
              if (widget.outputControllers[j].text.isEmpty) {
                targetIndex = j;
                break;
              }
            }
            // 前方検索で見つからなければ先頭から再検索
            if (targetIndex == -1) {
              for (int j = 0; j < startIdx; j++) {
                if (widget.outputControllers[j].text.isEmpty) {
                  targetIndex = j;
                  break;
                }
              }
            }
          }

          // 4) 決定した欄に書き込む
          if (targetIndex >= 0 &&
              targetIndex < widget.outputControllers.length) {
            widget.outputControllers[targetIndex].text = name;
          }
        } else if (type == SignalType.hwTrigger) {
          int targetIndex = existingHwTriggerMap[name] ?? -1;
          if (targetIndex == -1) {
            // 既存位置がない場合は最初の空いている位置を使用
            for (int j = 0; j < widget.hwTriggerControllers.length; j++) {
              if (widget.hwTriggerControllers[j].text.isEmpty) {
                targetIndex = j;
                break;
              }
            }
          }
          if (targetIndex >= 0 &&
              targetIndex < widget.hwTriggerControllers.length) {
            widget.hwTriggerControllers[targetIndex].text = name;
          }
        }

        newSignalList.add(
          SignalData(
            name: name,
            signalType: type,
            values: values,
            isVisible: true,
          ),
        );
      }

      if (newSignalList.isNotEmpty) {
        _signalDataList = newSignalList;
      }
    });
  }

  // RowMode のリストを取得
  List<String> getRowModes() => _rowModes.map((e) => e.name).toList();

  // ----------------- 追加: CODE_OPTION 波形生成ヘルパ -----------------
  List<int> _generateCodeOptionWave(List<int> autoWave, int waveLength) {
    // AUTO_MODE の立上り検出 (0→非0)
    int riseIdx = -1;
    for (int t = 1; t < autoWave.length; t++) {
      if (autoWave[t - 1] == 0 && autoWave[t] != 0) {
        riseIdx = t;
        break;
      }
    }
    List<int> wave = List<int>.filled(waveLength, 0);
    if (riseIdx == -1) return wave;

    int start = riseIdx + 1; // 1 ステップ後
    for (int idx = start; idx < waveLength; idx++) {
      int offset = idx - start;
      if (offset < 3) {
        wave[idx] = 1; // 1st 3 High
      } else if (offset < 5) {
        // 2 Low
        wave[idx] = 0;
      } else if (offset < 8) {
        wave[idx] = 1; // 2nd 3 High
      } else if (offset < 10) {
        wave[idx] = 0; // 2 Low
      } else {
        wave[idx] = 1; // High forever
      }
    }
    return wave;
  }

  // （削除）Code Trigger 専用ポスト処理は _applyOptionPostRules に統合

  // --- 追加: オプション信号（CODE_OPTION / Command Option）共通のポスト処理 ---
  void _applyOptionPostRules(
    List<String> names,
    List<List<int>> values,
    List<SignalType> types,
    List<int> ports,
    String optionSignalName,
  ) {
    final waveLen = values.isNotEmpty ? values[0].length : 0;
    if (waveLen == 0) return;

    final codeIdx = names.indexOf(optionSignalName);
    if (codeIdx == -1) return;

    final codeWave = values[codeIdx];

    // --- TRIGGER: 全ての立上り検出 ---
    int triggerIdx = names.indexOf('TRIGGER');
    if (triggerIdx == -1) {
      // 存在しなければ追加
      names.insert(0, 'TRIGGER');
      values.insert(0, List<int>.filled(waveLen, 0));
      types.insert(0, SignalType.input);
      ports.insert(0, 0);
      triggerIdx = 0;
    } else {
      // zero fill
      values[triggerIdx] = List<int>.filled(waveLen, 0);
    }

    for (int t = 1; t < waveLen; t++) {
      if (codeWave[t - 1] == 0 && codeWave[t] != 0) {
        if (t + 1 < waveLen) {
          values[triggerIdx][t + 1] = 1;
        }
      }
    }

    // ---------- BUSY: オプション波形と同じ High 区間 ----------
    int busyIdx = names.indexOf('BUSY');
    if (busyIdx != -1) {
      values[busyIdx] = List<int>.from(codeWave);
    }

    // ---------- EXPOSURE: 3 回 rise 後に開始 ----------
    int riseCnt = 0;
    int thirdRise = -1;
    for (int t = 1; t < waveLen; t++) {
      if (codeWave[t - 1] == 0 && codeWave[t] != 0) {
        riseCnt++;
        if (riseCnt == 3) {
          thirdRise = t;
          break;
        }
      }
    }
    if (thirdRise != -1) {
      // ---------- スケジュール全体を3回目rise後にシフト ----------
      final signalsToShift = [
        RegExp(r'^CAMERA_(\d+)_IMAGE_EXPOSURE'),
        RegExp(r'^CAMERA_(\d+)_IMAGE_ACQUISITION'),
        RegExp(r'^BATCH_EXPOSURE'),
        RegExp(r'^BATCH_EXPOSURE_COMPLETE'),
        RegExp(r'^CONTACT_INPUT_WAITING'),
        RegExp(r'^HW_TRIGGER\d+'),
        RegExp(r'^ACQ_TRIGGER_WAITING'),
        RegExp(r'^ENABLE_RESULT_SIGNAL'),
        RegExp(r'^TOTAL_RESULT_OK'),
        RegExp(r'^TOTAL_RESULT_NG'),
      ];

      if (thirdRise != -1) {
        int globalFirstPulse = -1;

        // --- 全シフト対象から最速のパルス位置を検出 ---
        for (int i = 0; i < names.length; i++) {
          if (signalsToShift.any((re) => re.hasMatch(names[i]))) {
            final wave = values[i];
            final firstPulseInWave = wave.indexWhere((v) => v != 0);
            if (firstPulseInWave != -1) {
              if (globalFirstPulse == -1 ||
                  firstPulseInWave < globalFirstPulse) {
                globalFirstPulse = firstPulseInWave;
              }
            }
          }
        }

        // --- シフト量を計算し、全対象に適用 ---
        if (globalFirstPulse != -1) {
          const int offset = 4;
          final shift = (thirdRise + offset) - globalFirstPulse;

          if (shift > 0) {
            for (int i = 0; i < names.length; i++) {
              if (signalsToShift.any((re) => re.hasMatch(names[i]))) {
                final original = values[i];
                List<int> newWave = List<int>.filled(waveLen, 0);
                for (int p = 0; p < original.length; p++) {
                  if (original[p] != 0 && p + shift < waveLen) {
                    newWave[p + shift] = original[p];
                  }
                }
                values[i] = newWave;
              }
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // AutomaticKeepAliveClientMixin を使う場合は super.build(context) が必要
    super.build(context);

    // UI 更新用に Provider を購読（ビルドと依存関係更新をトリガ）
    final watchedState = context.watch<FormStateNotifier>().state;

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
    // Update Chart ボタン用スタイル
    final updateButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.blue.shade100,
      foregroundColor: Colors.blue.shade900,
      minimumSize: Size(120, _buttonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: _buttonHorizontalPadding,
        vertical: _buttonVerticalPadding,
      ),
    );

    // Template ボタン用スタイル
    final templateButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.orange.shade100,
      foregroundColor: Colors.orange.shade900,
      minimumSize: Size(120, _buttonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: _buttonHorizontalPadding,
        vertical: _buttonVerticalPadding,
      ),
    );
    // Add Row ボタン用スタイル
    final addRowButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.green.shade100,
      foregroundColor: Colors.green.shade900,
      minimumSize: Size(120, _buttonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: _buttonHorizontalPadding,
        vertical: _buttonVerticalPadding,
      ),
    );
    // Remove Row ボタン用スタイル
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color headerBg =
        isDark
            ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3)
            : Theme.of(context).colorScheme.surfaceVariant;
    final Color borderColor =
        isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    final headerDecoration = BoxDecoration(
      color: headerBg,
      border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      boxShadow: [
        BoxShadow(
          color: borderColor,
          offset: const Offset(0, 1),
          blurRadius: 2,
        ),
      ],
    );

    // 非アクティブなヘッダー用のスタイル
    final inactiveHeaderDecoration = BoxDecoration(
      color: headerBg.withOpacity(0.2),
      border: Border(bottom: BorderSide(color: borderColor, width: 1)),
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
              // 1 行に 6 つのドロップダウンを配置
              Row(
                children: [
                  // Trigger Option
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final List<String> triggerItems =
                            formState.inputCount == 6
                                ? ['Single Trigger', 'Command Trigger']
                                : [
                                  'Single Trigger',
                                  'Code Trigger',
                                  'Command Trigger',
                                ];

                        final String dropdownValue =
                            triggerItems.contains(formState.triggerOption)
                                ? formState.triggerOption
                                : 'Single Trigger';

                        return CustomDropdown<String>(
                          value: dropdownValue,
                          items: triggerItems,
                          onChanged: widget.onTriggerOptionChanged,
                          label: 'Trigger Option',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // PLC / EIP
                  Expanded(
                    child: CustomDropdown<String>(
                      value: _plcEipOption,
                      items: const ['None', 'PLC', 'EIP'],
                      onChanged: (String? newValue) {
                        if (newValue == null) return;
                        setState(() {
                          _plcEipOption = newValue;
                        });
                      },
                      label: 'PLC / EIP',
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Input Port
                  Expanded(
                    child: CustomDropdown<int>(
                      value:
                          const [6, 16, 32, 64].contains(formState.inputCount)
                              ? formState.inputCount
                              : const [6, 16, 32, 64].firstWhere(
                                (v) => v >= formState.inputCount,
                                orElse: () => 64,
                              ),
                      items: const [6, 16, 32, 64],
                      onChanged: widget.onInputPortChanged,
                      label: 'Input Port',
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Output Port
                  Expanded(
                    child: CustomDropdown<int>(
                      value:
                          const [6, 16, 32, 64].contains(formState.outputCount)
                              ? formState.outputCount
                              : const [6, 16, 32, 64].firstWhere(
                                (v) => v >= formState.outputCount,
                                orElse: () => 64,
                              ),
                      items: const [6, 16, 32, 64],
                      onChanged: widget.onOutputPortChanged,
                      label: 'Output Port',
                    ),
                  ),
                  const SizedBox(width: 16),

                  // HW Port
                  Expanded(
                    child: CustomDropdown<int>(
                      value:
                          (formState.hwPort == 0 ||
                                  formState.hwPort == formState.camera)
                              ? formState.hwPort
                              : formState.camera,
                      // HW Port は 0 または Camera 数と同じ値のみ選択可能
                      items: [0, formState.camera],
                      onChanged: widget.onHwPortChanged,
                      label: 'HW Port',
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Camera
                  Expanded(
                    child: CustomDropdown<int>(
                      value: watchedState.camera,
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
                  // Template ボタン
                  ElevatedButton(
                    onPressed: _onTemplatePressed,
                    style: templateButtonStyle,
                    child: const Text('Template'),
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
                                  formState.hwPort > 0
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
                                            formState.hwPort > 0
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
                                  padding: const EdgeInsets.only(bottom: 640.0),
                                  child: InputSection(
                                    controllers: widget.inputControllers,
                                    count: formState.inputCount,
                                    visibilityList: _inputVisibility,
                                    onVisibilityChanged:
                                        (index) => _toggleSignalVisibility(
                                          index,
                                          SignalType.input,
                                        ),
                                    triggerOption: formState.triggerOption,
                                  ),
                                ),
                              ),
                            ),

                            // Output Signals セクション
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(bottom: 640.0),
                                  child: OutputSection(
                                    controllers: widget.outputControllers,
                                    count: formState.outputCount,
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
                                  formState.hwPort > 0
                                      ? SingleChildScrollView(
                                        padding: const EdgeInsets.only(
                                          bottom: 640.0,
                                        ),
                                        child: HwTriggerSection(
                                          controllers:
                                              widget.hwTriggerControllers,
                                          count: formState.hwPort,
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
    if (formState.camera > 6) {
      columnWidth = 80.0;
    } else if (formState.camera > 4) {
      columnWidth = 90.0;
    }

    // すべてのカメラ列に同じ固定幅を適用
    for (int i = 1; i <= formState.camera; i++) {
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
        decoration: BoxDecoration(
          // ダークモードでも Camera Configuration Table と同じ外観に合わせる
          color:
              (Theme.of(context).brightness == Brightness.dark)
                  ? Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.3)
                  : Theme.of(context).colorScheme.surfaceVariant,
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
          // カメラ数に基づいてヘッダーを生成
          for (int i = 0; i < formState.camera; i++)
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(child: _buildColumnHeader(i)),
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
              child: InkWell(
                onTap: () => _changeRowMode(row),
                child: Container(
                  color: rowModeColors[_rowModes[row]]?.withOpacity(0.3),
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${row + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_rowModes[row] != RowMode.none)
                          Text(
                            _labelForRowMode(context, _rowModes[row]),
                            style: const TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // カメラ列のセルを生成
            for (int col = 0; col < formState.camera; col++)
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

    // HW Trigger 用ポートが 0 の場合は HW トリガ (mode3) を無効化
    final bool _canSelectHwTrigger = formState.hwPort > 0;

    // 許可するモード（mode4, mode5 を除外し、必要なら mode3 も除外）
    final List<CellMode> allowedModes =
        CellMode.values
            .where((m) => m != CellMode.mode4 && m != CellMode.mode5)
            .where((m) => _canSelectHwTrigger || m != CellMode.mode3)
            .toList();

    final CellMode currentValue =
        allowedModes.contains(_tableData[row][col])
            ? _tableData[row][col]
            : CellMode.none;

    return Container(
      height: kMinInteractiveDimension,
      decoration: BoxDecoration(
        color: cellModeColors[_tableData[row][col]]?.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4.0), // パディングを縮小
      child: DropdownButton<CellMode>(
        value: currentValue,
        isExpanded: true,
        isDense: true, // よりコンパクトなドロップダウン
        underline: Container(), // 下線を非表示
        // 明示的にFlutterの最小値を設定
        itemHeight: kMinInteractiveDimension,
        onChanged: (CellMode? newValue) {
          if (newValue != null) {
            // HW ポートが 0 の場合は mode3 への変更を無視
            if (!_canSelectHwTrigger && newValue == CellMode.mode3) {
              // 必要に応じて SnackBar などでユーザーへ通知することも可能
              return;
            }
            // mode4, mode5 は無効化
            if (newValue == CellMode.mode4 || newValue == CellMode.mode5) {
              return;
            }
            _changeCellMode(row, col, newValue);
          }
        },
        items:
            allowedModes.map((CellMode mode) {
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
                          _labelForCellMode(context, mode),
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

  // === 追加: カラムヘッダー（カメラ列）ウィジェット ===
  Widget _buildColumnHeader(int col) {
    // HW Trigger 用ポートが 0 の場合は HW トリガ (mode3) を無効化
    final bool _canSelectHwTrigger = formState.hwPort > 0;

    // 現在のモード色
    final Color? bgColor = cellModeColors[_columnModes.isNotEmpty
            ? _columnModes[col]
            : CellMode.none]
        ?.withOpacity(0.3);

    // 許可するモード（mode4, mode5 を除外）
    final List<CellMode> allowedModes =
        CellMode.values
            .where((m) => m != CellMode.mode4 && m != CellMode.mode5)
            .toList();

    return PopupMenuButton<CellMode>(
      onSelected: (CellMode mode) {
        // HWポートが無い場合は mode3 を無視
        if (!_canSelectHwTrigger && mode == CellMode.mode3) return;
        if (mode == CellMode.mode4 || mode == CellMode.mode5) return;
        _changeColumnMode(col, mode);
      },
      itemBuilder: (context) {
        final modes =
            _canSelectHwTrigger
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
