/*
FormTab - タイミングチャートのフォーム入力画面

【主な機能】
- 入力/出力/HW Trigger の信号設定を管理
- カメラ設定とトリガーオプション（Single/Code/Command）の選択
- Camera Configuration Table によるカメラ設定の管理
- Template/Update ボタンによる設定の適用と更新
- 設定のインポート/エクスポート機能

【データの流れ】
1) ユーザー入力 → TextEditingController に保存
2) "Update Chart"ボタンが押される → 現在の設定からSignalData を生成
3) 生成されたデータは onUpdateChart コールバックでMyHomePage に送信
4) 最終的に TimingChart に送信され、チャートが更新される

【技術的な特徴】
- AutomaticKeepAliveClientMixin により、タブが非表示でも状態を保持
- Provider(FormStateNotifier) と TextEditingController の連携で状態管理
- Post-frame コールバック（WidgetsBinding）により、build 後の処理を安全に実行
- Code/Command Trigger では、Control/Group/Task/CODE_OPTION の設定を自動生成
*/
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:collection/collection.dart';
import '../../models/form/form_state.dart';
import '../../models/chart/chart_data_generator.dart'; // chart_data_generator.dartをインポート
import '../../models/chart/signal_type.dart'; // SignalTypeをインポート
import '../../models/chart/signal_data.dart'; // SignalDataをインポート
import '../../models/chart/io_channel_source.dart'; // IoChannelSourceをインポート
import '../../models/backup/app_config.dart'; // AppConfigをインポート
import '../../utils/file_utils.dart'; // FileUtilsをインポート
import 'input_section.dart';
import 'output_section.dart';
import 'hw_trigger_section.dart';
import '../common/custom_dropdown.dart';
// import '../../common_padding.dart';
import '../../providers/form_state_notifier.dart';
import 'package:provider/provider.dart';
import '../../utils/chart_template_engine.dart';
import 'dart:math' as math;
import '../../providers/locale_notifier.dart';
import '../../providers/form_controllers_notifier.dart';

// 定数クラス
class FormTabConstants {
  // 波形長
  static const int defaultWaveLength = 32;

  // ポート数
  static const int minInputPorts = 6;
  static const int standardInputPorts = 16;
  static const int maxInputPorts = 32;
  static const int extendedInputPorts = 64;
  static const int standardOutputPorts = 32;

  // 出力ポートの予約範囲
  static const int reservedOutputStart = 3; // Output4から

  // UI定数
  static const double alphaBlendValue = 0.3;
  static const int defaultRowCount = 6;

  // Code Trigger設定（32ポート）
  static const int codeTrigger32ControlStart = 1;
  static const int codeTrigger32ControlEnd = 8;
  static const int codeTrigger32GroupStart = 9;
  static const int codeTrigger32GroupEnd = 14;
  static const int codeTrigger32TaskStart = 15;
  static const int codeTrigger32TaskEnd = 20;

  // Code Trigger設定（16ポート）
  static const int codeTrigger16ControlStart = 1;
  static const int codeTrigger16ControlEnd = 4;
  static const int codeTrigger16GroupStart = 5;
  static const int codeTrigger16GroupEnd = 7;
  static const int codeTrigger16TaskStart = 8;
  static const int codeTrigger16TaskEnd = 13;

  // CONTACT_INPUT_WAITINGの配置（32ポート時）
  static const int contactInputWaitingIndex32 = 29; // Input30 (0-based)
}

// 信号名定数
class SignalNames {
  static const String codeOption = 'CODE_OPTION';
  static const String commandOption = 'Command Option';
  static const String autoMode = 'AUTO_MODE';
  static const String busy = 'BUSY';
  static const String trigger = 'TRIGGER';
  static const String contactInputWaiting = 'CONTACT_INPUT_WAITING';
  static const String acqTriggerWaiting = 'ACQ_TRIGGER_WAITING';
  static const String enableResultSignal = 'ENABLE_RESULT_SIGNAL';
  static const String totalResultOk = 'TOTAL_RESULT_OK';
  static const String totalResultNg = 'TOTAL_RESULT_NG';
  static const String batchExposure = 'BATCH_EXPOSURE';
  static const String batchExposureComplete = 'BATCH_EXPOSURE_COMPLETE';
  static const String recovery = 'RECOVERY';
  static const String pcControl = 'PC_CONTROL';
}

// トリガーオプション定数
class TriggerOptions {
  static const String single = 'Single Trigger';
  static const String code = 'Code Trigger';
  static const String command = 'Command Trigger';
}

// PLC/EIPオプション定数
class PlcEipOptions {
  static const String none = 'None';
  static const String plc = 'PLC';
  static const String eip = 'EIP';
}

// セルのモードを表す列挙型
enum CellMode { none, mode1, mode2, mode3, mode4, mode5 }

// 行モード：none / 同時取込

// 行モード（none / 同時取込）
enum RowMode { none, simultaneous }

const rowModeColors = {
  RowMode.none: Colors.white,
  RowMode.simultaneous: Colors.teal, // 青緑色
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
  final List<TextEditingController> plcEipInputControllers;
  final List<TextEditingController> outputControllers;
  final List<TextEditingController> plcEipOutputControllers;
  final List<TextEditingController> hwTriggerControllers;
  final FormControllersNotifier controllersNotifier;
  final ValueChanged<String?> onTriggerOptionChanged;
  final ValueChanged<String?> onPlcEipOptionChanged;
  final ValueChanged<int?> onInputPortChanged;
  final ValueChanged<int?> onOutputPortChanged;
  final ValueChanged<int?> onHwPortChanged;
  final ValueChanged<int?> onCameraChanged;
  final void Function(
    List<String>,
    List<List<int>>,
    List<SignalType>,
    List<int>,
    List<IoChannelSource>,
    bool,
  )
  onUpdateChart;
  final VoidCallback onClearFields;
  final bool showImportExportButtons; // インポート・エクスポートボタンの表示制御フラグ
  final Future<void> Function(
    List<TextEditingController> src,
    List<TextEditingController> dst,
  )
  onTransferInputs;

  final Future<void> Function(
    List<TextEditingController> src,
    List<TextEditingController> dst,
  )
  onTransferOutputs;

  const FormTab({
    super.key,
    required this.inputControllers,
    required this.plcEipInputControllers,
    required this.outputControllers,
    required this.plcEipOutputControllers,
    required this.hwTriggerControllers,
    required this.controllersNotifier,
    required this.onTriggerOptionChanged,
    required this.onPlcEipOptionChanged,
    required this.onInputPortChanged,
    required this.onOutputPortChanged,
    required this.onHwPortChanged,
    required this.onCameraChanged,
    required this.onUpdateChart,
    required this.onClearFields,
    required this.onTransferInputs,
    required this.onTransferOutputs,
    this.showImportExportButtons = false, // デフォルトで非表示
  });

  @override
  State<FormTab> createState() => FormTabState();
}

// FormTab の状態を管理するクラス
class FormTabState extends State<FormTab>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  // AutomaticKeepAliveClientMixin により、タブ切り替え後も状態を保持するため true を返す
  @override
  // タブ切り替え後も状態を保持するため true を返す
  @override
  bool get wantKeepAlive => true;

  // 現在の言語設定に応じて行モードのラベルを返す
  String _labelForRowMode(BuildContext context, RowMode mode) {
    final String lang = context.read<LocaleNotifier>().locale.languageCode;
    if (lang == 'ja') {
      return rowModeLabels[mode] ?? '';
    }
    return rowModeLabelsEn[mode] ?? '';
  }

  // 現在の言語設定に応じてセルモードのラベルを返す
  String _labelForCellMode(BuildContext context, CellMode mode) {
    final String lang = context.read<LocaleNotifier>().locale.languageCode;
    if (lang == 'ja') {
      return cellModeLabels[mode] ?? '';
    }
    return cellModeLabelsEn[mode] ?? '';
  }

  static const double _buttonHeight = 48.0;
  static const double _buttonHorizontalPadding = 16.0;
  static const double _buttonVerticalPadding = 12.0;

  // テーブルデータ用の状態変数
  // 初期行数

  // テーブルの行数（初期値6）
  int _rowCount = FormTabConstants.defaultRowCount;

  // テーブルデータを保持する2次元配列
  List<List<CellMode>> _tableData = [];

  // SignalDataのリストを保持

  // SignalData のリストを保持
  List<SignalData> _signalDataList = [];
  Map<String, List<int>> _portValues = {};

  // 実際のチャートデータを保持（更新時に使用）

  // 実際のチャートデータを保持
  List<List<int>> _actualChartData = [];

  // 行モード：各行に対してセルとは独立に設定できるモード（none / 同時取込）

  // 各行の行モード設定を保持
  List<RowMode> _rowModes = [];

  // 各カラムの一括変更用モード設定を保持
  List<CellMode> _columnModes = [];

  // 入力信号の表示/非表示状態を管理
  List<bool> _inputVisibility = [];
  List<bool> _outputVisibility = [];
  List<bool> _hwTriggerVisibility = [];

  // Provider からフォーム状態を取得するゲッター
  TimingFormState get formState => context.read<FormStateNotifier>().state;

  bool _initializedWithProvider = false;

  int _prevInputCount = -1;
  int _prevOutputCount = -1;
  int _prevHwPort = -1;
  int _prevCamera = -1;

  // PLC / EIP オプション
  String _plcEipOption = PlcEipOptions.none;
  Map<String, List<int>> _externalSignalValues = {};

  // 出力用のサブタブ（IO / PLC-EIP）
  TabController? _outputTabController;
  int _outputTabIndex = 0;
  // 入力用のサブタブ（IO / PLC-EIP）
  TabController? _inputTabController;
  int _inputTabIndex = 0;

  // 外部から PLC/EIP オプションを制御するためのセッター
  void setPlcEipOption(String value) {
    if (value != PlcEipOptions.none &&
        value != PlcEipOptions.plc &&
        value != PlcEipOptions.eip)
      return;
    setState(() {
      _plcEipOption = value;
    });
    _ensureOutputTabController();
    _ensureInputTabController();
  }

  // 出力タブコントローラーを初期化または破棄する
  void _ensureOutputTabController() {
    if (_plcEipOption == PlcEipOptions.none) {
      _outputTabController?.dispose();
      _outputTabController = null;
      _outputTabIndex = 0;
      return;
    }
    if (_outputTabController == null) {
      _outputTabController = TabController(length: 2, vsync: this);
      _outputTabController!.index = _outputTabIndex;
      _outputTabController!.addListener(() {
        if (_outputTabController!.indexIsChanging) return;
        if (mounted) {
          FocusScope.of(context).unfocus();
        }
        setState(() {
          _outputTabIndex = _outputTabController!.index;
        });
      });
    }
  }

  // 入力タブコントローラーを初期化または破棄する
  void _ensureInputTabController() {
    if (_plcEipOption == PlcEipOptions.none) {
      _inputTabController?.dispose();
      _inputTabController = null;
      _inputTabIndex = 0;
      return;
    }
    if (_inputTabController == null) {
      _inputTabController = TabController(length: 2, vsync: this);
      _inputTabController!.index = _inputTabIndex;
      _inputTabController!.addListener(() {
        if (_inputTabController!.indexIsChanging) return;
        if (mounted) {
          FocusScope.of(context).unfocus();
        }
        setState(() {
          _inputTabIndex = _inputTabController!.index;
        });
      });
    }
  }

  Future<void> _transferInputControllers(
    List<TextEditingController> source,
    List<TextEditingController> destination,
  ) async {
    await widget.onTransferInputs(source, destination);
    if (!mounted) return;
    setState(() {
      _updateSignalDataList();
    });
  }

  Future<void> _transferOutputControllers(
    List<TextEditingController> source,
    List<TextEditingController> destination,
  ) async {
    await widget.onTransferOutputs(source, destination);
    if (!mounted) return;
    setState(() {
      _updateSignalDataList();
    });
  }

  // 外部から呼び出して信号データリストを更新する
  void refreshSignalDataList() {
    _updateSignalDataList();
  }

  // 外部から追加の信号値を登録する
  void registerExternalSignalValues(Map<String, List<int>> values) {
    _externalSignalValues = {
      for (final entry in values.entries)
        entry.key: List<int>.from(entry.value),
    };
  }

  @override
  void dispose() {
    _outputTabController?.dispose();
    _inputTabController?.dispose();
    super.dispose();
  }

  // トリガーオプションに応じて入力名を自動設定する
  void applyInputNamesForTriggerOption() {
    final fs = formState;
    if (fs.triggerOption == TriggerOptions.single) {
      if (widget.inputControllers.isNotEmpty) {
        widget.controllersNotifier.setInputText(0, SignalNames.trigger);
      }
      return;
    }

    if (fs.triggerOption == TriggerOptions.code) {
      _assignCodeTriggerInputNames(fs);
    }
  }

  // Code Trigger モード用の入力名を設定する
  void _assignCodeTriggerInputNames(TimingFormState fs) {
    final controllers = widget.inputControllers;
    String? nameForIndex(int index) {
      if (fs.inputCount >= FormTabConstants.maxInputPorts) {
        if (index >= FormTabConstants.codeTrigger32ControlStart &&
            index <= FormTabConstants.codeTrigger32ControlEnd) {
          return 'Control Code${index}(bit)';
        }
        if (index >= FormTabConstants.codeTrigger32GroupStart &&
            index <= FormTabConstants.codeTrigger32GroupEnd) {
          return 'Group Code${index}(bit)';
        }
        if (index >= FormTabConstants.codeTrigger32TaskStart &&
            index <= FormTabConstants.codeTrigger32TaskEnd) {
          return 'Task Code${index}(bit)';
        }
      } else if (fs.inputCount == FormTabConstants.standardInputPorts) {
        if (index >= FormTabConstants.codeTrigger16ControlStart &&
            index <= FormTabConstants.codeTrigger16ControlEnd) {
          return 'Control Code${index}(bit)';
        }
        if (index >= FormTabConstants.codeTrigger16GroupStart &&
            index <= FormTabConstants.codeTrigger16GroupEnd) {
          return 'Group Code${index}(bit)';
        }
        if (index >= FormTabConstants.codeTrigger16TaskStart &&
            index <= FormTabConstants.codeTrigger16TaskEnd) {
          return 'Task Code${index}(bit)';
        }
      }
      return null;
    }

    for (int i = 0; i < fs.inputCount && i < controllers.length; i++) {
      final newName = nameForIndex(i);
      if (newName != null && controllers[i].text != newName) {
        controllers[i].text = newName;
      }
    }
  }

  // bool _hwVis(int index) =>
  //     index < _hwTriggerVisibility.length ? _hwTriggerVisibility[index] : true;

  static const Map<int, Map<String, int>> _outputPresetMap = {
    6: {
      'AUTO_MODE': 1,
      'BUSY': 2, // Output1
      'ENABLE_RESULT_SIGNAL': 3, // Output2
      'TOTAL_RESULT_OK': 4, // Output3
      'TOTAL_RESULT_NG': 5, // Output4
    },
    16: {
      'AUTO_MODE': 1,
      'BUSY': 2, // Output9
      'ENABLE_RESULT_SIGNAL': 6, // Output10
      'TOTAL_RESULT_OK': 9, // Output11
      'TOTAL_RESULT_NG': 10, // Output12
    },
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

  int _selectOutputIndex(String signalId, int totalOutputs, int totalCameras) {
    // 従来仕様：32 ポート構成で CAM_EXPOSURE / ACQUISITION を配置
    if (totalOutputs == 32) {
      final expReg = RegExp(r'^CAMERA_(\d+)_IMAGE_EXPOSURE');
      final acqReg = RegExp(r'^CAMERA_(\d+)_IMAGE_ACQUISITION');

      RegExpMatch? m = expReg.firstMatch(signalId);
      if (m != null) {
        final cam = int.parse(m.group(1)!);
        if (cam >= 1 && cam <= totalCameras) {
          return 3 + (cam - 1);
        }
      }

      m = acqReg.firstMatch(signalId);
      if (m != null) {
        final cam = int.parse(m.group(1)!);
        if (cam >= 1 && cam <= totalCameras) {
          return 3 + totalCameras + (cam - 1);
        }
      }

      if (signalId == 'TOTAL_RESULT_OK') {
        return 3 + totalCameras * 2 + 1;
      }
      if (signalId == 'TOTAL_RESULT_NG') {
        return 3 + totalCameras * 2 + 2;
      }
    }

    final preset = _outputPresetMap[totalOutputs];
    if (preset == null) return -1;
    return preset[signalId] ?? -1;
  }

  @override
  // 依存関係が変更されたときに呼ばれる（初期化と状態同期）
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

    if (_prevCamera != -1 && _prevCamera != fs.camera) {
      _initializeTableData();

      // HW Port が0またはカメラ数以外の場合、自動的にカメラ数へ更新
      if (fs.hwPort != 0 && fs.hwPort != fs.camera) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          widget.onHwPortChanged(fs.camera);
        });
      }
    }

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

    // IO ポート数 = 6 のときは Code Trigger を強制的に Single Trigger へ変更
    if (fs.inputCount == FormTabConstants.minInputPorts &&
        fs.triggerOption == TriggerOptions.code) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        widget.onTriggerOptionChanged(TriggerOptions.single);
      });
    }

    // 現在値を保存
    _prevInputCount = fs.inputCount;
    _prevOutputCount = fs.outputCount;
    _prevHwPort = fs.hwPort;
    _prevCamera = fs.camera;
  }

  // SignalDataリストを初期化する

  // SignalData リストを初期化する
  void _initializeSignalDataList() {
    final formState = context.read<FormStateNotifier>().state;
    _signalDataList = [];

    // 入力信号を追加
    for (int i = 0; i < formState.inputCount; i++) {
      final signalType = _inferSignalType(formState, i);
      final isVisible = _inferVisibility(formState, i);
      final name =
          (i < widget.inputControllers.length &&
                  widget.inputControllers[i].text.isNotEmpty)
              ? widget.inputControllers[i].text
              : 'Input ${i + 1}';

      _signalDataList.add(
        SignalData(
          name: name,
          signalType: signalType,
          values: List.filled(FormTabConstants.defaultWaveLength, 0),
          isVisible: isVisible,
        ),
      );
    }

    for (int i = 0; i < formState.hwPort; i++) {
      if (widget.hwTriggerControllers[i].text.isNotEmpty) {
        _signalDataList.add(
          SignalData(
            name: widget.hwTriggerControllers[i].text,
            signalType: SignalType.hwTrigger,
            values: List.filled(FormTabConstants.defaultWaveLength, 0),
            isVisible:
                i < _hwTriggerVisibility.length
                    ? _hwTriggerVisibility[i]
                    : true,
          ),
        );
      }
    }

    for (int i = 0; i < formState.outputCount; i++) {
      if (i < widget.outputControllers.length &&
          widget.outputControllers[i].text.isNotEmpty) {
        _signalDataList.add(
          SignalData(
            name: widget.outputControllers[i].text,
            signalType: SignalType.output,
            values: List.filled(FormTabConstants.defaultWaveLength, 0),
            isVisible:
                i < _outputVisibility.length ? _outputVisibility[i] : true,
          ),
        );
      }
    }

    if (_plcEipOption != PlcEipOptions.none) {
      for (int i = 0; i < formState.outputCount; i++) {
        if (i < widget.plcEipOutputControllers.length &&
            widget.plcEipOutputControllers[i].text.isNotEmpty) {
          final base =
              _plcEipOption == PlcEipOptions.plc
                  ? 'PLO${i + 1}'
                  : 'ESO${i + 1}';
          final user = widget.plcEipOutputControllers[i].text;
          final label = '$base: $user';
          _signalDataList.add(
            SignalData(
              name: label,
              signalType: SignalType.output,
              values: List.filled(FormTabConstants.defaultWaveLength, 0),
              isVisible:
                  i < _outputVisibility.length ? _outputVisibility[i] : true,
            ),
          );
        }
      }
    }

    if (formState.triggerOption == TriggerOptions.code) {
      final exists = _signalDataList.any(
        (s) => s.name == SignalNames.codeOption,
      );
      if (!exists) {
        _signalDataList.insert(
          0,
          SignalData(
            name: SignalNames.codeOption,
            signalType: SignalType.input,
            values: List.filled(FormTabConstants.defaultWaveLength, 0),
            isVisible: true,
          ),
        );
      }
    }

    if (formState.triggerOption == TriggerOptions.command) {
      final exists = _signalDataList.any(
        (s) => s.name == SignalNames.commandOption,
      );
      if (!exists) {
        _signalDataList.insert(
          0,
          SignalData(
            name: SignalNames.commandOption,
            signalType: SignalType.input,
            values: List.filled(FormTabConstants.defaultWaveLength, 0),
            isVisible: true,
          ),
        );
      }
    }
  }

  // 信号の表示/非表示状態を初期化する

  // 信号の表示/非表示状態を初期化する
  void _initializeSignalVisibility() {
    setState(() {
      _inputVisibility = List.generate(formState.inputCount, (_) => true);
      _outputVisibility = List.generate(formState.outputCount, (_) => true);
      _hwTriggerVisibility = List.generate(formState.hwPort, (_) => true);
    });
  }

  // 表示/非表示リストを更新する

  // 表示/非表示リストのサイズを調整する
  void _updateVisibilityList(List<bool> list, int newCount) {
    setState(() {
      if (list.length < newCount) {
        list.addAll(List.generate(newCount - list.length, (_) => true));
      } else if (list.length > newCount) {
        list.removeRange(newCount, list.length);
      }
    });
  }

  // テーブルデータを初期化する

  // テーブルデータを初期化する（カメラ数に応じて）
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

      _columnModes = List.generate(cameraCount, (_) => CellMode.none);
    });
  }

  // 行を追加する

  // テーブルに行を追加する
  void _addRow() {
    setState(() {
      _tableData.add(List.generate(formState.camera, (_) => CellMode.none));
      _rowCount++;

      // 行モードリストにも追加
      _rowModes.add(RowMode.none);
    });
  }

  // 行を削除する

  // テーブルから行を削除する（最低1行は残す）
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

  // セルの値を変更する

  // 特定のセルのモードを変更する
  void _changeCellMode(int row, int col, CellMode newMode) {
    setState(() {
      _tableData[row][col] = newMode;
    });
  }

  // カラム全体のモードを一括変更する
  void _changeColumnMode(int col, CellMode newMode) {
    setState(() {
      for (int row = 0; row < _tableData.length; row++) {
        _tableData[row][col] = newMode;
      }
      if (col < _columnModes.length) {
        _columnModes[col] = newMode;
      }
    });
  }

  // 行モードを切り替える
  void _changeRowMode(int row) {
    setState(() {
      final current = _rowModes[row];
      _rowModes[row] =
          current == RowMode.none ? RowMode.simultaneous : RowMode.none;
    });
  }

  // 信号の表示/非表示を切り替える
  void _toggleSignalVisibility(int index, SignalType type) {
    setState(() {
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

  // テーブルデータをクリアする
  void _clearTableData() {
    setState(() {
      for (int row = 0; row < _tableData.length; row++) {
        for (int col = 0; col < _tableData[row].length; col++) {
          _tableData[row][col] = CellMode.none;
        }
      }

      for (int i = 0; i < _rowModes.length; i++) {
        _rowModes[i] = RowMode.none;
      }
    });
  }

  // インポート前に全データをクリアする
  void clearAllForImport() {
    _clearTableData();
    widget.onClearFields();
  }

  // 信号値を解決する（前のデータから値を取得）
  List<int> _resolveSignalValues({
    required Map<String, List<int>> prevPortValues,
    required Map<String, List<int>> prevValueMap,
    required String primaryKey,
    String? alternateKey,
    required String name,
    List<String> additionalNames = const [],
    required int defaultWaveLength,
  }) {
    final List<int>? fromPort =
        prevPortValues[primaryKey] ??
        (alternateKey != null ? prevPortValues[alternateKey] : null);
    if (fromPort != null) {
      return List<int>.from(fromPort);
    }

    final List<int>? direct = prevValueMap[name];
    if (direct != null) {
      return List<int>.from(direct);
    }

    for (final fallbackName in additionalNames) {
      if (fallbackName.isEmpty) continue;
      final List<int>? fallback = prevValueMap[fallbackName];
      if (fallback != null) {
        return List<int>.from(fallback);
      }
    }

    final String normalized = _normalizeSignalName(name);
    final MapEntry<String, List<int>>? normalizedEntry = prevValueMap.entries
        .firstWhereOrNull(
          (entry) => _normalizeSignalName(entry.key) == normalized,
        );
    if (normalizedEntry != null) {
      return List<int>.from(normalizedEntry.value);
    }

    for (final fallbackName in additionalNames) {
      if (fallbackName.isEmpty) continue;
      final String fallbackNormalized = _normalizeSignalName(fallbackName);
      final MapEntry<String, List<int>>? fallbackEntry = prevValueMap.entries
          .firstWhereOrNull(
            (entry) => _normalizeSignalName(entry.key) == fallbackNormalized,
          );
      if (fallbackEntry != null) {
        return List<int>.from(fallbackEntry.value);
      }
    }

    return List.filled(defaultWaveLength, 0);
  }

  // ポートキーを生成するヘルパーメソッド
  String _dioInputKey(int index) => 'dio-input:$index';
  String _plcInputKey(int index) => 'plc-input:$index';
  String _hwKey(int index) => 'hw:$index';
  String _dioOutputKey(int index) => 'dio-output:$index';
  String _plcOutputKey(int index) => 'plc-output:$index';

  // 入力信号のフォールバック名を生成
  List<String> _inputFallbackNames(int index) => <String>[
    'Input${index + 1}',
    'Input ${index + 1}',
    'PLI${index + 1}',
    'ESI${index + 1}',
  ];

  // 出力信号のフォールバック名を生成
  List<String> _outputFallbackNames(int index) => <String>[
    'Output${index + 1}',
    'Output ${index + 1}',
    'PLO${index + 1}',
    'ESO${index + 1}',
  ];

  // Code Trigger用の信号タイプと可視性を決定
  void _determineCodeTriggerSignalType(
    TimingFormState fs,
    int index,
    Function(int, String) setInputText,
  ) {
    if (fs.inputCount >= FormTabConstants.maxInputPorts) {
      if (index >= FormTabConstants.codeTrigger32ControlStart &&
          index <= FormTabConstants.codeTrigger32ControlEnd) {
        setInputText(index, 'Control Code${index}(bit)');
      }
    } else if (fs.inputCount == FormTabConstants.standardInputPorts) {
      if (index >= FormTabConstants.codeTrigger16ControlStart &&
          index <= FormTabConstants.codeTrigger16ControlEnd) {
        setInputText(index, 'Control Code${index}(bit)');
      }
    }
  }

  // Code Trigger用の信号タイプを取得
  SignalType _getCodeTriggerSignalType(TimingFormState fs, int index) {
    if (fs.inputCount >= FormTabConstants.maxInputPorts) {
      if (index >= FormTabConstants.codeTrigger32ControlStart &&
          index <= FormTabConstants.codeTrigger32ControlEnd) {
        return SignalType.control;
      } else if (index >= FormTabConstants.codeTrigger32GroupStart &&
          index <= FormTabConstants.codeTrigger32GroupEnd) {
        return SignalType.group;
      } else if (index >= FormTabConstants.codeTrigger32TaskStart &&
          index <= FormTabConstants.codeTrigger32TaskEnd) {
        return SignalType.task;
      }
    } else if (fs.inputCount == FormTabConstants.standardInputPorts) {
      if (index >= FormTabConstants.codeTrigger16ControlStart &&
          index <= FormTabConstants.codeTrigger16ControlEnd) {
        return SignalType.control;
      } else if (index >= FormTabConstants.codeTrigger16GroupStart &&
          index <= FormTabConstants.codeTrigger16GroupEnd) {
        return SignalType.group;
      } else if (index >= FormTabConstants.codeTrigger16TaskStart &&
          index <= FormTabConstants.codeTrigger16TaskEnd) {
        return SignalType.task;
      }
    }
    return SignalType.input;
  }

  // Code Trigger用の可視性を取得
  bool _getCodeTriggerVisibility(TimingFormState fs, int index) {
    if (fs.inputCount >= FormTabConstants.maxInputPorts) {
      return index == 0 || index > FormTabConstants.codeTrigger32TaskEnd;
    } else if (fs.inputCount == FormTabConstants.standardInputPorts) {
      return index == 0 || index > FormTabConstants.codeTrigger16TaskEnd;
    }
    return true;
  }

  // 入力信号マップを構築
  Map<int, SignalData> _buildInputSignalMap({
    required Map<String, List<int>> prevPortValues,
    required Map<String, List<int>> prevValueMap,
    required int defaultWaveLength,
  }) {
    final Map<int, SignalData> inputSignalMap = {};
    final fs = formState;

    for (int i = 0; i < fs.inputCount; i++) {
      if (i < widget.inputControllers.length &&
          widget.inputControllers[i].text.isNotEmpty) {
        SignalType signalType = SignalType.input;
        bool isVisible =
            i < _inputVisibility.length ? _inputVisibility[i] : true;

        if (fs.triggerOption == TriggerOptions.code) {
          signalType = _getCodeTriggerSignalType(fs, i);
          isVisible = _getCodeTriggerVisibility(fs, i);
          _determineCodeTriggerSignalType(
            fs,
            i,
            (idx, text) => widget.controllersNotifier.setInputText(idx, text),
          );
        }

        final String name = widget.inputControllers[i].text;
        final List<int> values = _resolveSignalValues(
          prevPortValues: prevPortValues,
          prevValueMap: prevValueMap,
          primaryKey: _dioInputKey(i),
          alternateKey: _plcInputKey(i),
          name: name,
          additionalNames: _inputFallbackNames(i),
          defaultWaveLength: defaultWaveLength,
        );

        inputSignalMap[i] = SignalData(
          name: name,
          signalType: signalType,
          values: values,
          isVisible: isVisible,
        );
      }
    }

    // PLC/EIP入力信号を追加
    if (_plcEipOption != PlcEipOptions.none) {
      for (int i = 0; i < fs.inputCount; i++) {
        if (i < widget.plcEipInputControllers.length &&
            widget.plcEipInputControllers[i].text.isNotEmpty) {
          final String name = widget.plcEipInputControllers[i].text;
          final int key = fs.inputCount + i;
          final List<int> values = _resolveSignalValues(
            prevPortValues: prevPortValues,
            prevValueMap: prevValueMap,
            primaryKey: _plcInputKey(i),
            alternateKey: _dioInputKey(i),
            name: name,
            additionalNames: _inputFallbackNames(i),
            defaultWaveLength: defaultWaveLength,
          );
          inputSignalMap[key] = SignalData(
            name: name,
            signalType: SignalType.input,
            values: values,
            isVisible: i < _inputVisibility.length ? _inputVisibility[i] : true,
          );
        }
      }
    }

    return inputSignalMap;
  }

  // HWトリガー信号マップを構築
  Map<int, SignalData> _buildHwTriggerSignalMap({
    required Map<String, List<int>> prevPortValues,
    required Map<String, List<int>> prevValueMap,
    required int defaultWaveLength,
  }) {
    final Map<int, SignalData> hwTriggerSignalMap = {};
    final fs = formState;

    for (int i = 0; i < fs.hwPort; i++) {
      if (widget.hwTriggerControllers[i].text.isNotEmpty) {
        final String name = widget.hwTriggerControllers[i].text;
        final List<int> values = _resolveSignalValues(
          prevPortValues: prevPortValues,
          prevValueMap: prevValueMap,
          primaryKey: _hwKey(i),
          name: name,
          defaultWaveLength: defaultWaveLength,
        );
        hwTriggerSignalMap[i] = SignalData(
          name: name,
          signalType: SignalType.hwTrigger,
          values: values,
          isVisible:
              i < _hwTriggerVisibility.length ? _hwTriggerVisibility[i] : true,
        );
      }
    }

    return hwTriggerSignalMap;
  }

  // 出力信号マップを構築
  Map<int, SignalData> _buildOutputSignalMap({
    required Map<String, List<int>> prevPortValues,
    required Map<String, List<int>> prevValueMap,
    required int defaultWaveLength,
  }) {
    final Map<int, SignalData> outputSignalMap = {};
    final fs = formState;

    // DIO出力信号
    for (int i = 0; i < fs.outputCount; i++) {
      if (i < widget.outputControllers.length &&
          widget.outputControllers[i].text.isNotEmpty) {
        final String name = widget.outputControllers[i].text;
        String displayName = name;
        if (name.startsWith('Output') && name.length > 6) {
          final String portStr = name.substring(6);
          final int? port = int.tryParse(portStr);
          if (port != null && port > 0) {
            displayName = name;
          }
        }

        final List<int> values = _resolveSignalValues(
          prevPortValues: prevPortValues,
          prevValueMap: prevValueMap,
          primaryKey: _dioOutputKey(i),
          alternateKey: _plcOutputKey(i),
          name: displayName,
          additionalNames: _outputFallbackNames(i),
          defaultWaveLength: defaultWaveLength,
        );

        outputSignalMap[i] = SignalData(
          name: displayName,
          signalType: SignalType.output,
          values: values,
          isVisible: i < _outputVisibility.length ? _outputVisibility[i] : true,
        );
      }
    }

    // PLC/EIP出力信号
    if (_plcEipOption != PlcEipOptions.none) {
      for (int i = 0; i < fs.outputCount; i++) {
        if (i < widget.plcEipOutputControllers.length &&
            widget.plcEipOutputControllers[i].text.isNotEmpty) {
          final String prefix =
              _plcEipOption == PlcEipOptions.plc ? 'PLO' : 'ESO';
          final String base = '$prefix${i + 1}';
          final String user = widget.plcEipOutputControllers[i].text;

          String label;
          if ((user.startsWith('PLO') || user.startsWith('ESO')) &&
              user.length > 3) {
            final String portStr = user.substring(3);
            final int? port = int.tryParse(portStr);
            if (port != null && port > 0) {
              label = user;
            } else {
              label = user.isNotEmpty ? '$base: $user' : base;
            }
          } else {
            label = user.isNotEmpty ? '$base: $user' : base;
          }

          final int key = fs.outputCount + i;
          final String fallbackBase = 'Output ${i + 1}';
          final List<String> additionalNames =
              <String>[
                user,
                base,
                'Output${i + 1}',
                fallbackBase,
                ..._outputFallbackNames(i),
              ].where((element) => element.trim().isNotEmpty).toSet().toList();

          final List<int> values = _resolveSignalValues(
            prevPortValues: prevPortValues,
            prevValueMap: prevValueMap,
            primaryKey: _plcOutputKey(i),
            alternateKey: _dioOutputKey(i),
            name: label,
            additionalNames: additionalNames,
            defaultWaveLength: defaultWaveLength,
          );

          outputSignalMap[key] = SignalData(
            name: label,
            signalType: SignalType.output,
            values: values,
            isVisible:
                i < _outputVisibility.length ? _outputVisibility[i] : true,
          );
        }
      }
    }

    return outputSignalMap;
  }

  // 信号データリストを構築（信号マップから）
  void _populateSignalDataList({
    required Map<int, SignalData> inputSignalMap,
    required Map<int, SignalData> outputSignalMap,
    required Map<int, SignalData> hwTriggerSignalMap,
    required List<String> prevOrder,
    required Map<String, List<int>> prevValueMap,
    required int defaultWaveLength,
  }) {
    _signalDataList = [];

    // 入力信号を追加
    for (int i = 0; i < formState.inputCount; i++) {
      if (inputSignalMap.containsKey(i)) {
        _signalDataList.add(inputSignalMap[i]!);
      }
    }

    // PLC/EIP入力信号を追加
    if (_plcEipOption != PlcEipOptions.none) {
      for (int i = 0; i < formState.inputCount; i++) {
        final int key = formState.inputCount + i;
        if (inputSignalMap.containsKey(key)) {
          _signalDataList.add(inputSignalMap[key]!);
        }
      }
    }

    // HWトリガー信号を追加
    for (int i = 0; i < formState.hwPort; i++) {
      if (hwTriggerSignalMap.containsKey(i)) {
        _signalDataList.add(hwTriggerSignalMap[i]!);
      }
    }

    // 出力信号を追加
    for (int i = 0; i < formState.outputCount; i++) {
      if (outputSignalMap.containsKey(i)) {
        _signalDataList.add(outputSignalMap[i]!);
      }
    }

    // 追加の出力信号を追加
    final List<int> extraOutputKeys =
        outputSignalMap.keys.where((k) => k >= formState.outputCount).toList()
          ..sort();
    for (final int k in extraOutputKeys) {
      _signalDataList.add(outputSignalMap[k]!);
    }

    // 順序を保持
    if (prevOrder.isNotEmpty) {
      _signalDataList.sort((a, b) {
        final int ia = prevOrder.indexOf(a.name);
        final int ib = prevOrder.indexOf(b.name);
        if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
        if (ia >= 0) return -1;
        if (ib >= 0) return 1;
        return 0;
      });
    }

    // Code/Command Trigger用の信号を追加
    if (formState.triggerOption == TriggerOptions.code &&
        !_signalDataList.any((s) => s.name == SignalNames.codeOption)) {
      _signalDataList.insert(
        0,
        SignalData(
          name: SignalNames.codeOption,
          signalType: SignalType.input,
          values:
              prevValueMap[SignalNames.codeOption] ??
              List.filled(defaultWaveLength, 0),
          isVisible: true,
        ),
      );
    }

    if (formState.triggerOption == TriggerOptions.command &&
        !_signalDataList.any((s) => s.name == SignalNames.commandOption)) {
      _signalDataList.insert(
        0,
        SignalData(
          name: SignalNames.commandOption,
          signalType: SignalType.input,
          values:
              prevValueMap[SignalNames.commandOption] ??
              List.filled(defaultWaveLength, 0),
          isVisible: true,
        ),
      );
    }
  }

  // 現在の設定から信号データリストを生成・更新する（メイン処理）
  void _updateSignalDataList() {
    final Map<String, List<int>> prevPortValues = {
      for (final entry in _portValues.entries)
        entry.key: List<int>.from(entry.value),
    };

    setState(() {
      // 前の値を収集
      final Map<String, List<int>> prevValueMap = {
        for (final sig in _signalDataList) sig.name: List<int>.from(sig.values),
      };
      if (_externalSignalValues.isNotEmpty) {
        for (final entry in _externalSignalValues.entries) {
          prevValueMap[entry.key] = List<int>.from(entry.value);
        }
        _externalSignalValues.clear();
      }

      // デフォルト波形長を計算
      int defaultWaveLength = 0;
      for (final values in prevValueMap.values) {
        defaultWaveLength = math.max(defaultWaveLength, values.length);
      }
      for (final values in prevPortValues.values) {
        defaultWaveLength = math.max(defaultWaveLength, values.length);
      }
      if (defaultWaveLength == 0) {
        defaultWaveLength = FormTabConstants.defaultWaveLength;
      }

      final List<String> prevOrder =
          _signalDataList.map((s) => s.name).toList();

      // 信号マップを構築
      final inputSignalMap = _buildInputSignalMap(
        prevPortValues: prevPortValues,
        prevValueMap: prevValueMap,
        defaultWaveLength: defaultWaveLength,
      );

      final hwTriggerSignalMap = _buildHwTriggerSignalMap(
        prevPortValues: prevPortValues,
        prevValueMap: prevValueMap,
        defaultWaveLength: defaultWaveLength,
      );

      final outputSignalMap = _buildOutputSignalMap(
        prevPortValues: prevPortValues,
        prevValueMap: prevValueMap,
        defaultWaveLength: defaultWaveLength,
      );

      // ポート値を更新
      final Map<String, List<int>> newPortValues = {};
      for (final entry in inputSignalMap.entries) {
        if (entry.key < formState.inputCount) {
          newPortValues[_dioInputKey(entry.key)] = List<int>.from(
            entry.value.values,
          );
        } else {
          final plcIndex = entry.key - formState.inputCount;
          newPortValues[_plcInputKey(plcIndex)] = List<int>.from(
            entry.value.values,
          );
        }
      }
      for (final entry in hwTriggerSignalMap.entries) {
        newPortValues[_hwKey(entry.key)] = List<int>.from(entry.value.values);
      }
      for (final entry in outputSignalMap.entries) {
        if (entry.key < formState.outputCount) {
          newPortValues[_dioOutputKey(entry.key)] = List<int>.from(
            entry.value.values,
          );
        } else {
          final plcIndex = entry.key - formState.outputCount;
          newPortValues[_plcOutputKey(plcIndex)] = List<int>.from(
            entry.value.values,
          );
        }
      }

      // チャートデータを生成
      generateTimingChartDataWithPositions(
        inputSignalMap,
        outputSignalMap,
        hwTriggerSignalMap,
        timeLength: defaultWaveLength,
      );

      // 信号データリストを構築
      _populateSignalDataList(
        inputSignalMap: inputSignalMap,
        outputSignalMap: outputSignalMap,
        hwTriggerSignalMap: hwTriggerSignalMap,
        prevOrder: prevOrder,
        prevValueMap: prevValueMap,
        defaultWaveLength: defaultWaveLength,
      );

      _portValues = newPortValues;
    });
  }

  String _normalizeSignalName(String name) {
    var trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final int colonIndex = trimmed.indexOf(':');
    if (colonIndex >= 0) {
      trimmed = trimmed.substring(colonIndex + 1).trim();
    }
    return trimmed.replaceAll(RegExp(r'[\s_:-]+'), '').toLowerCase();
  }

  // タイミングチャートデータを生成する
  List<List<int>> generateTimingChartData({int timeLength = 32}) {
    final chartData = ChartDataGenerator.generateTimingChart(
      formState: formState,
      inputControllers: widget.inputControllers,
      outputControllers: widget.outputControllers,
      hwTriggerControllers: widget.hwTriggerControllers,
      tableData: _tableData,
      timeLength: timeLength,
    );

    debugPrint('ChartDataGenerator.generateTimingChart 縺ｮ邨先棡:');
    debugPrint('  霑泌唆縺輔ｌ縺溘ョ繝ｼ繧ｿ陦梧焚: ${chartData.length}');
    if (chartData.isNotEmpty) {
      debugPrint('  譛蛻昴・陦後・繝・・繧ｿ萓・ ${chartData[0]}');
      debugPrint('  譛蛻昴・菫｡蜿ｷ蜷・ ${_signalDataList.firstOrNull?.name ?? 'N/A'}');
    }

    return chartData;
  }

  List<List<int>> generateTimingChartDataWithPositions(
    Map<int, SignalData> inputSignalMap,
    Map<int, SignalData> outputSignalMap,
    Map<int, SignalData> hwTriggerSignalMap, {
    int timeLength = 32,
  }) {
    List<List<int>> chartData = [];

    for (int i = 0; i < formState.inputCount; i++) {
      if (inputSignalMap.containsKey(i)) {
        chartData.add(List.filled(timeLength, 0));
      }
    }

    for (int i = 0; i < formState.hwPort; i++) {
      if (hwTriggerSignalMap.containsKey(i)) {
        chartData.add(List.filled(timeLength, 0));
      }
    }

    final outputKeys = outputSignalMap.keys.toList()..sort();
    for (int i = 0; i < outputKeys.length; i++) {
      chartData.add(List.filled(timeLength, 0));
    }

    return chartData;
  }

  // 信号名のリストを生成する
  List<String> generateSignalNames() {
    List<String> names = [];
    for (var signal in _signalDataList) {
      if (signal.isVisible) {
        names.add(signal.name);
      }
    }
    return names;
  }

  // 信号タイプのリストを生成する
  List<SignalType> generateSignalTypes() {
    List<SignalType> types = [];
    for (var signal in _signalDataList) {
      if (signal.isVisible) {
        types.add(signal.signalType);
      }
    }
    return types;
  }

  // フィルタ済みチャートデータを生成する
  List<List<int>> generateFilteredChartData() {
    List<List<int>> filteredData = [];
    for (var signal in _signalDataList) {
      if (signal.isVisible) {
        filteredData.add(List<int>.from(signal.values));
      }
    }
    return filteredData;
  }

  // ポート番号のリストを生成する
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
          if (idx == -1) {
            idx = widget.plcEipInputControllers.indexWhere(
              (c) => c.text == signal.name,
            );
          }
          ports.add(idx >= 0 ? idx + 1 : 0);
          break;
        case SignalType.hwTrigger:
          idx = widget.hwTriggerControllers.indexWhere(
            (c) => c.text == signal.name,
          );
          ports.add(idx >= 0 ? idx + 1 : 0);
          break;
        case SignalType.output:
          // DIO 蜃ｺ蜉・
          idx = widget.outputControllers.indexWhere(
            (c) => c.text == signal.name,
          );
          if (idx >= 0) {
            ports.add(idx + 1);
            break;
          }
          if (signal.name.startsWith('PLO')) {
            final String raw = signal.name.substring(3);
            final numStr = raw.contains(':') ? raw.split(':').first : raw;
            final port = int.tryParse(numStr) ?? 0;
            ports.add(port);
          } else if (signal.name.startsWith('ESO')) {
            final String raw = signal.name.substring(3);
            final numStr = raw.contains(':') ? raw.split(':').first : raw;
            final port = int.tryParse(numStr) ?? 0;
            ports.add(port);
          } else {
            ports.add(0);
          }
          break;
        default:
          ports.add(0);
      }
    }
    return ports;
  }

  // IO チャネルソースのリストを生成する
  List<IoChannelSource> generateIoChannelSources() {
    List<IoChannelSource> sources = [];

    for (var signal in _signalDataList) {
      if (!signal.isVisible) continue;

      switch (signal.signalType) {
        case SignalType.input:
          final isPlcEipInput = widget.plcEipInputControllers.any(
            (c) => c.text == signal.name,
          );
          if (isPlcEipInput) {
            sources.add(
              _plcEipOption == 'PLC'
                  ? IoChannelSource.plc
                  : IoChannelSource.eip,
            );
          } else {
            sources.add(IoChannelSource.dio);
          }
          break;
        case SignalType.hwTrigger:
          sources.add(IoChannelSource.dio);
          break;
        case SignalType.output:
          final isPlcEipOutput = widget.plcEipOutputControllers.any(
            (c) => c.text == signal.name,
          );
          if (isPlcEipOutput) {
            sources.add(
              _plcEipOption == 'PLC'
                  ? IoChannelSource.plc
                  : IoChannelSource.eip,
            );
          } else {
            sources.add(IoChannelSource.dio);
          }
          break;
        default:
          sources.add(IoChannelSource.unknown);
      }
    }
    return sources;
  }

  // Code/Command Option波形を適用する共通メソッド
  void _applyOptionWave({
    required List<String> names,
    required List<List<int>> chartData,
    required List<SignalType> types,
    required List<int> ports,
    required String optionSignalName,
  }) {
    final autoIdx = names.indexOf(SignalNames.autoMode);
    final optionIdx = names.indexOf(optionSignalName);

    int waveLength =
        chartData.isNotEmpty
            ? chartData[0].length
            : FormTabConstants.defaultWaveLength;
    List<int> optionWave = List<int>.filled(waveLength, 0);

    if (autoIdx != -1) {
      final autoWave = chartData[autoIdx];
      optionWave = _generateCodeOptionWave(autoWave, waveLength);
    }

    if (optionIdx != -1) {
      chartData[optionIdx] = optionWave;
    } else {
      names.insert(0, optionSignalName);
      types.insert(0, SignalType.input);
      ports.insert(0, 0);
      chartData.insert(0, optionWave);
    }

    // BUSY/TRIGGER/EXPOSURE 調整（共通ルール）
    _applyOptionPostRules(names, chartData, types, ports, optionSignalName);
  }

  // "Update Chart" ボタンが押されたときの処理
  Future<void> _onUpdateChart() async {
    _updateSignalDataList();

    // チャートデータを生成
    List<String> names = generateSignalNames();
    final chartData = generateFilteredChartData();
    List<SignalType> types = generateSignalTypes();
    List<int> ports = generatePortNumbers();

    // CODE_OPTION 波形を生成
    if (formState.triggerOption == TriggerOptions.code) {
      _applyOptionWave(
        names: names,
        chartData: chartData,
        types: types,
        ports: ports,
        optionSignalName: SignalNames.codeOption,
      );
    }

    // Command Option 波形を生成
    if (formState.triggerOption == TriggerOptions.command) {
      _applyOptionWave(
        names: names,
        chartData: chartData,
        types: types,
        ports: ports,
        optionSignalName: SignalNames.commandOption,
      );
    }

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

    // 信号データを更新する
    _actualChartData = List.from(outChartData);

    // 信号データの確認（デバッグ用）
    debugPrint('信号データの確認:');
    debugPrint('  信号名: $names');
    debugPrint('  信号タイプ: $types');
    debugPrint('  信号データの数: ${chartData.length}');
    if (chartData.isNotEmpty) {
      debugPrint('  信号データ: ${chartData[0]}');
      debugPrint('  信号データ: ${chartData[0].firstOrNull ?? 'N/A'}');
    }

    // 信号データを更新する
    // names 信号名, types 信号タイプ, ports 信号ポート
    ports = [];
    for (int i = 0; i < outNames.length; i++) {
      int idx;
      switch (outTypes[i]) {
        case SignalType.input:
          idx = widget.inputControllers.indexWhere(
            (c) => c.text == outNames[i],
          );
          if (idx == -1) {
            // PLC/EIP信号の確認
            idx = widget.plcEipInputControllers.indexWhere(
              (c) => c.text == outNames[i],
            );
          }
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

    widget.onUpdateChart(
      outNames,
      outChartData,
      outTypes,
      ports,
      generateIoChannelSources(),
      false,
    );

    // --- 信号データの更新 ---
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('信号データの更新が完了しました')));
  }

  // Template 信号データの更新

  // "Template" ボタンが押されたときの処理（テンプレートエンジンを使用）
  Future<void> _onTemplatePressed() async {
    // 信号データを更新する
    // 32 信号データの更新

    // ---------- Exposure 信号データの更新 ----------
    const int minGap = 4;
    int currentTime = 6;

    // exposureTimes[camIndex] = List<timeIndex>
    Map<int, List<int>> exposureTimes = {
      for (int c = 1; c <= formState.camera; c++) c: [],
    };

    // 信号データを更新する
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
      // --- 信号データの更新 ---
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

    int maxTimeIndex = exposureTimes.values
        .expand((list) => list)
        .fold<int>(0, (prev, element) => math.max(prev, element));

    int requiredSampleLength = math.max(32, maxTimeIndex + 32);

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
      ).showSnackBar(const SnackBar(content: Text('信号データの更新が完了しました')));
      return;
    }

    // === 信号データの更新 ===
    List<SignalData> filteredSignals = generatedSignals;
    if (formState.hwPort == 0) {
      filteredSignals =
          generatedSignals
              .where((sig) => sig.signalType != SignalType.hwTrigger)
              .toList();
    }

    bool hasContactInputMode = false; // Mode2
    bool hasHwTriggerMode = false; // Mode3
    for (int r = 0; r < _tableData.length; r++) {
      for (int c = 0; c < _tableData[r].length; c++) {
        if (_tableData[r][c] == CellMode.mode2) hasContactInputMode = true;
        if (_tableData[r][c] == CellMode.mode3) hasHwTriggerMode = true;
      }
    }

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

    updateSignalDataFromChartData(
      filteredSignals.map((e) => e.values).toList(),
      filteredSignals.map((e) => e.name).toList(),
      filteredSignals.map((e) => e.signalType).toList(),
    );

    final List<String> names = filteredSignals.map((e) => e.name).toList();
    final values = filteredSignals.map((e) => e.values).toList();
    final types = filteredSignals.map((e) => e.signalType).toList();

    List<int> ports = [];

    if (formState.triggerOption == TriggerOptions.code) {
      _applyOptionWave(
        names: names,
        chartData: values,
        types: types,
        ports: ports,
        optionSignalName: SignalNames.codeOption,
      );
    }

    if (formState.triggerOption == TriggerOptions.command) {
      _applyOptionWave(
        names: names,
        chartData: values,
        types: types,
        ports: ports,
        optionSignalName: SignalNames.commandOption,
      );
    }

    if (formState.triggerOption == TriggerOptions.code) {
      _updateSignalDataList();
    }

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

    widget.onUpdateChart(
      outNames,
      outValues,
      outTypes,
      outPorts,
      generateIoChannelSources(),
      true,
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('信号データの更新が完了しました')));
  }

  AppConfig _createAppConfig() {
    // 信号データの確認（デバッグ用）
    debugPrint('===== 信号データの確認:=====');
    debugPrint('信号データの数: ${_actualChartData.length}');
    if (_actualChartData.isNotEmpty) {
      debugPrint('信号データ: ${_actualChartData[0]}');
      debugPrint(
        '信号データに0が含まれているか: ${_actualChartData.any((row) => row.any((value) => value != 0))}',
      );
    }

    debugPrint('FormState諠・ｱ:');
    debugPrint('  formState.inputCount: ${formState.inputCount}');
    debugPrint('  formState.outputCount: ${formState.outputCount}');
    debugPrint('  formState.hwPort: ${formState.hwPort}');
    debugPrint('  formState.camera: ${formState.camera}');
    debugPrint('  繝・・繝悶Ν繝・・繧ｿ陦梧焚: ${_tableData.length}');
    if (_tableData.isNotEmpty) {
      debugPrint(
        '  信号データ: ${_tableData[0].map((c) => c.toString()).join(', ')}',
      );
    }

    List<SignalData> updatedSignals = [];
    int dataIndex = 0;

    // 入力信号を追加
    for (int i = 0; i < formState.inputCount; i++) {
      if (widget.inputControllers[i].text.isNotEmpty) {
        List<int> values;
        if (dataIndex < _actualChartData.length) {
          values = List.from(_actualChartData[dataIndex]);
          dataIndex++;
        } else {
          values = List.filled(32, 0);
        }

        updatedSignals.add(
          SignalData(
            name: widget.inputControllers[i].text,
            signalType: SignalType.input,
            values: values,
            isVisible: _inputVisibility[i],
          ),
        );
      }
    }

    // 蜃ｺ蜉帑ｿ｡蜿ｷ
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

        debugPrint('信号データ: $i 信号データ: $values');

        updatedSignals.add(
          SignalData(
            name: widget.outputControllers[i].text,
            signalType: SignalType.output,
            values: values,
            isVisible:
                i < _outputVisibility.length ? _outputVisibility[i] : true,
          ),
        );
      }
    }

    for (int i = 0; i < formState.hwPort; i++) {
      if (widget.hwTriggerControllers[i].text.isNotEmpty) {
        List<int> values;
        if (dataIndex < _actualChartData.length) {
          values = List.from(_actualChartData[dataIndex]);
          dataIndex++;
        } else {
          values = List.filled(32, 0);
        }

        debugPrint('信号データ: $i 信号データ: $values');

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
      }
    }

    debugPrint('信号データの数: ${updatedSignals.length}');
    if (updatedSignals.isNotEmpty) {
      debugPrint('信号データ: ${updatedSignals[0].values}');
    }
    debugPrint('=============================================');

    return AppConfig.fromCurrentState(
      formState: formState,
      signals: updatedSignals, // 譖ｴ譁ｰ縺輔ｌ縺欖ignalData繝ｪ繧ｹ繝医ｒ菴ｿ逕ｨ
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

  // エクスポート前の確認ダイアログを表示
  Future<bool> _confirmExport() async {
    if (_actualChartData.isEmpty ||
        !_actualChartData.any((row) => row.any((value) => value != 0))) {
      final shouldUpdate =
          await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('信号データが見つかりません'),
                  content: const Text(
                    'エクスポートする前に「Update Chart」ボタンをクリックして信号データを更新することをお勧めします。\n\n'
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

  // 信号データを更新する

  // 設定をファイルにエクスポートする
  Future<void> _exportConfig() async {
    // 信号データを更新する
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

  // ファイルから設定をインポートする
  Future<void> _importConfig() async {
    final config = await FileUtils.importAppConfig();

    if (config == null || !mounted) return;

    setState(() {
      // 信号データを更新する
      widget.onTriggerOptionChanged(config.formState.triggerOption);
      widget.onInputPortChanged(config.formState.inputCount);
      widget.onOutputPortChanged(config.formState.outputCount);
      widget.onHwPortChanged(config.formState.hwPort);
      widget.onCameraChanged(config.formState.camera);

      // チャートデータの更新
      if (config.tableData.isNotEmpty) {
        _tableData = List.from(config.tableData);
        _rowCount = _tableData.length;
      }

      // --- RowMode 信号データの更新 ---
      _rowModes =
          config.rowModes
              .map(
                (name) => RowMode.values.firstWhere(
                  (e) => e.name == name,
                  orElse: () => RowMode.none,
                ),
              )
              .toList();

      // 信号データを更新する
      if (_rowModes.length < _rowCount) {
        _rowModes.addAll(
          List.filled(_rowCount - _rowModes.length, RowMode.none),
        );
      } else if (_rowModes.length > _rowCount) {
        _rowModes = _rowModes.sublist(0, _rowCount);
      }

      _inputVisibility = List.from(config.inputVisibility);
      _outputVisibility = List.from(config.outputVisibility);
      _hwTriggerVisibility = List.from(config.hwTriggerVisibility);

      // SignalData繧呈峩譁ｰ
      _signalDataList = List.from(config.signals);

      _actualChartData =
          _signalDataList
              .where((s) => s.isVisible)
              .map((s) => List<int>.from(s.values))
              .toList();

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

    await _onUpdateChart();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('繧､繝ｳ繝昴・繝医′螳御ｺ・＠縺ｾ縺励◆'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 信号データリストを取得する（外部アクセス用）
  List<SignalData> getSignalDataList() {
    if (_actualChartData.isNotEmpty &&
        _actualChartData.any((row) => row.any((val) => val != 0))) {
      debugPrint("getSignalDataList: _actualChartData縺九ｉ髱槭ぞ繝ｭ繝・・繧ｿ繧呈､懷・");

      List<SignalData> result = [];
      int dataIndex = 0;

      // 入力信号を追加・井ｽ咲ｽｮ繧剃ｿ晄戟・・
      for (int i = 0; i < formState.inputCount; i++) {
        if (widget.inputControllers[i].text.isNotEmpty) {
          SignalType signalType = SignalType.input;
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
            debugPrint(
              "HWTrigger[$i] 信号データ: ${_actualChartData[dataIndex].take(10)}..., 信号データに0が含まれているか: ${_actualChartData[dataIndex].any((v) => v != 0)}",
            );
            dataIndex++;
          }
        }
      }

      // 蜃ｺ蜉帑ｿ｡蜿ｷ・井ｽ咲ｽｮ繧剃ｿ晄戟・・
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
            debugPrint(
              "Output[$i] 信号データ: ${_actualChartData[dataIndex].take(10)}..., 信号データに0が含まれているか: ${_actualChartData[dataIndex].any((v) => v != 0)}",
            );
            dataIndex++;
          }
        }
      }

      if (_plcEipOption != 'None') {
        for (int i = 0; i < formState.outputCount; i++) {
          if (i >= widget.plcEipOutputControllers.length) continue;
          final text = widget.plcEipOutputControllers[i].text;
          if (text.isEmpty) continue;

          final String prefix = _plcEipOption == 'PLC' ? 'PLO' : 'ESO';
          final String name = '$prefix${i + 1}: $text';

          if (dataIndex < _actualChartData.length) {
            result.add(
              SignalData(
                name: name,
                signalType: SignalType.output,
                values: List.from(_actualChartData[dataIndex]),
                isVisible:
                    i < _outputVisibility.length ? _outputVisibility[i] : true,
              ),
            );
            dataIndex++;
          } else {
            result.add(
              SignalData(
                name: name,
                signalType: SignalType.output,
                values: List.filled(FormTabConstants.defaultWaveLength, 0),
                isVisible:
                    i < _outputVisibility.length ? _outputVisibility[i] : true,
              ),
            );
          }
        }
      }

      if (result.isNotEmpty) {
        debugPrint("getSignalDataList: 信号データの数: ${result.length}");
        return result;
      }
    }

    _updateSignalDataList();
    debugPrint("getSignalDataList: 信号データの数: ${_signalDataList.length}");
    return List.from(_signalDataList);
  }

  // テーブルデータを取得する（外部アクセス用）
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

  // AppConfig から設定を復元する
  void updateFromAppConfig(AppConfig config) {
    setState(() {
      if (config.tableData.isNotEmpty) {
        _tableData = List.from(config.tableData);
        _rowCount = _tableData.length;
      }

      _rowModes =
          config.rowModes
              .map(
                (name) => RowMode.values.firstWhere(
                  (e) => e.name == name,
                  orElse: () => RowMode.none,
                ),
              )
              .toList();

      if (_rowModes.length < _rowCount) {
        _rowModes.addAll(
          List.filled(_rowCount - _rowModes.length, RowMode.none),
        );
      } else if (_rowModes.length > _rowCount) {
        _rowModes = _rowModes.sublist(0, _rowCount);
      }

      if (config.inputVisibility.length == _inputVisibility.length) {
        _inputVisibility = List.from(config.inputVisibility);
      }

      if (config.outputVisibility.length == _outputVisibility.length) {
        _outputVisibility = List.from(config.outputVisibility);
      }

      if (config.hwTriggerVisibility.length == _hwTriggerVisibility.length) {
        _hwTriggerVisibility = List.from(config.hwTriggerVisibility);
      }

      _signalDataList = List.from(config.signals);

      _actualChartData =
          _signalDataList
              .where((s) => s.isVisible)
              .map((s) => List<int>.from(s.values))
              .toList();

      _onUpdateChart();
    });
  }

  // チャートデータを更新する（外部呼び出し用）
  Future<void> updateChartData() async {
    _updateSignalDataList();

    List<List<int>> existingChartData = _actualChartData;
    bool hasExistingNonZeroData =
        existingChartData.isNotEmpty &&
        existingChartData.any((row) => row.any((val) => val != 0));

    if (hasExistingNonZeroData) {
      debugPrint("既存の信号データに0が含まれています");
    }

    final newChartData = generateTimingChartData();

    if (hasExistingNonZeroData &&
        existingChartData.length == newChartData.length) {
      debugPrint("既存チャートデータと新チャートデータの行数が一致しています");
      List<List<int>> mergedData = [];

      for (int i = 0; i < existingChartData.length; i++) {
        List<int> rowData = List<int>.from(newChartData[i]);

        // 既存データの行数が新データの行数より多い場合は新データの行数に合わせる
        List<int> existingRow = existingChartData[i];
        if (existingRow.length > rowData.length) {
          existingRow = existingRow.sublist(0, rowData.length);
        } else if (existingRow.length < rowData.length) {
          existingRow = [
            ...existingRow,
            ...List<int>.filled(rowData.length - existingRow.length, 0),
          ];
        }

        // 非0の値がある場合は既存の値を優先
        for (int j = 0; j < rowData.length; j++) {
          if (j < existingRow.length && existingRow[j] != 0) {
            rowData[j] = existingRow[j];
          }
        }

        mergedData.add(rowData);
      }

      _actualChartData = mergedData;
    } else {
      _actualChartData = newChartData;
    }

    final List<String> names = generateSignalNames();
    widget.onUpdateChart(
      names,
      generateFilteredChartData(),
      generateSignalTypes(),
      generatePortNumbers(),
      generateIoChannelSources(),
      false,
    );
  }

  void setChartDataOnly(List<List<int>> chartData) {
    if (chartData.isEmpty) return;
    setState(() {
      _actualChartData = List.from(chartData);
    });
  }

  // 既存のコントローラーマップを構築
  Map<String, Map<String, int>> _buildExistingControllerMaps() {
    final Map<String, int> existingInputMap = {};
    final Map<String, int> existingOutputMap = {};
    final Map<String, int> existingHwTriggerMap = {};
    final Map<String, int> existingPlcMap = {};
    final Map<String, int> existingPlcInputMap = {};

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
    for (int i = 0; i < widget.plcEipOutputControllers.length; i++) {
      if (widget.plcEipOutputControllers[i].text.isNotEmpty) {
        existingPlcMap[widget.plcEipOutputControllers[i].text] = i;
      }
    }
    for (int i = 0; i < widget.plcEipInputControllers.length; i++) {
      if (widget.plcEipInputControllers[i].text.isNotEmpty) {
        existingPlcInputMap[widget.plcEipInputControllers[i].text] = i;
      }
    }

    return {
      'input': existingInputMap,
      'output': existingOutputMap,
      'hwTrigger': existingHwTriggerMap,
      'plc': existingPlcMap,
      'plcInput': existingPlcInputMap,
    };
  }

  // すべてのコントローラーをクリア
  void _clearAllControllers() {
    for (var c in widget.inputControllers) {
      c.text = '';
    }
    for (var c in widget.outputControllers) {
      c.text = '';
    }
    for (var c in widget.hwTriggerControllers) {
      c.text = '';
    }
    for (var c in widget.plcEipInputControllers) {
      c.text = '';
    }
  }

  // 入力信号のターゲットインデックスを見つける
  int _findInputTargetIndex(
    String name,
    Map<String, int> existingInputMap,
    Map<String, int> existingPlcInputMap,
  ) {
    int targetIndex = existingInputMap[name] ?? -1;

    // CONTACT_INPUT_WAITINGをInput30に配置（32ポート時）
    if (targetIndex == -1 && name == SignalNames.contactInputWaiting) {
      final fs = context.read<FormStateNotifier>().state;
      if (fs.inputCount >= FormTabConstants.maxInputPorts &&
          widget.inputControllers.length >= 30) {
        targetIndex = FormTabConstants.contactInputWaitingIndex32;
      }
    }

    if (targetIndex == -1) {
      for (int j = 0; j < widget.inputControllers.length; j++) {
        if (widget.inputControllers[j].text.isEmpty) {
          targetIndex = j;
          break;
        }
      }
    }

    return targetIndex;
  }

  // 出力信号のターゲットインデックスを見つける
  int _findOutputTargetIndex(
    String name,
    Map<String, int> existingOutputMap,
    Map<String, int> existingPlcMap,
  ) {
    final fs = context.read<FormStateNotifier>().state;
    int targetIndex = existingOutputMap[name] ?? -1;

    // 32ポート構成での予約範囲チェック
    if (targetIndex != -1 &&
        fs.outputCount == FormTabConstants.standardOutputPorts) {
      final int reservedStart = FormTabConstants.reservedOutputStart;
      final int reservedEnd = reservedStart + fs.camera * 2 - 1;
      final bool isInReserved =
          targetIndex >= reservedStart && targetIndex <= reservedEnd;
      final bool isCameraSignal = RegExp(
        r'^CAMERA_(\d+)_IMAGE_(EXPOSURE|ACQUISITION)',
      ).hasMatch(name);
      if (!isCameraSignal && isInReserved) {
        targetIndex = -1;
      }
    }

    // OutputN形式からインデックスを取得
    if (targetIndex == -1) {
      final m = RegExp(r'^Output(\d+)$').firstMatch(name);
      if (m != null) {
        final portNum = int.tryParse(m.group(1)!);
        if (portNum != null && portNum >= 1 && portNum <= fs.outputCount) {
          int candidate = portNum - 1;
          if (fs.outputCount == FormTabConstants.standardOutputPorts) {
            final int reservedStart = FormTabConstants.reservedOutputStart;
            final int reservedEnd = reservedStart + fs.camera * 2 - 1;
            final bool isInReserved =
                candidate >= reservedStart && candidate <= reservedEnd;
            final bool isCameraSignal = RegExp(
              r'^CAMERA_(\d+)_IMAGE_(EXPOSURE|ACQUISITION)',
            ).hasMatch(name);
            if (!isCameraSignal && isInReserved) {
              candidate = -1;
            }
          }
          if (candidate != -1) {
            targetIndex = candidate;
          }
        }
      }
    }

    // プリセットマップから検索
    if (targetIndex == -1) {
      targetIndex = _selectOutputIndex(name, fs.outputCount, fs.camera);
    }

    // 空きスロットを検索
    if (targetIndex == -1) {
      int startIdx = 0;
      if (fs.outputCount == FormTabConstants.standardOutputPorts) {
        int reservedEnd =
            FormTabConstants.reservedOutputStart +
            fs.camera * 2 +
            2; // TOT_NG index
        startIdx = reservedEnd + 1;
        if (startIdx >= widget.outputControllers.length) {
          startIdx = 0;
        }
      }

      for (int j = startIdx; j < widget.outputControllers.length; j++) {
        if (widget.outputControllers[j].text.isEmpty) {
          targetIndex = j;
          break;
        }
      }
      if (targetIndex == -1) {
        for (int j = 0; j < startIdx; j++) {
          if (widget.outputControllers[j].text.isEmpty) {
            targetIndex = j;
            break;
          }
        }
      }
    }

    return targetIndex;
  }

  // 入力信号を割り当て
  void _assignInputSignal(
    String name,
    List<int> values,
    Map<String, int> existingInputMap,
    Map<String, int> existingPlcInputMap,
  ) {
    final targetIndex = _findInputTargetIndex(
      name,
      existingInputMap,
      existingPlcInputMap,
    );

    if (existingPlcInputMap.containsKey(name)) {
      final plcTargetIndex = existingPlcInputMap[name]!;
      if (plcTargetIndex >= 0 &&
          plcTargetIndex < widget.plcEipInputControllers.length) {
        widget.plcEipInputControllers[plcTargetIndex].text = name;
      }
    } else {
      if (targetIndex >= 0 && targetIndex < widget.inputControllers.length) {
        widget.inputControllers[targetIndex].text = name;
      }
    }
  }

  // 出力信号を割り当て
  void _assignOutputSignal(
    String name,
    List<int> values,
    Map<String, int> existingOutputMap,
    Map<String, int> existingPlcMap,
  ) {
    final targetIndex = _findOutputTargetIndex(
      name,
      existingOutputMap,
      existingPlcMap,
    );

    if (!existingPlcMap.containsKey(name)) {
      if (targetIndex >= 0 && targetIndex < widget.outputControllers.length) {
        widget.outputControllers[targetIndex].text = name;
      }
    }
  }

  // HWトリガー信号を割り当て
  void _assignHwTriggerSignal(
    String name,
    List<int> values,
    Map<String, int> existingHwTriggerMap,
  ) {
    int targetIndex = existingHwTriggerMap[name] ?? -1;
    if (targetIndex == -1) {
      for (int j = 0; j < widget.hwTriggerControllers.length; j++) {
        if (widget.hwTriggerControllers[j].text.isEmpty) {
          targetIndex = j;
          break;
        }
      }
    }
    if (targetIndex >= 0 && targetIndex < widget.hwTriggerControllers.length) {
      widget.hwTriggerControllers[targetIndex].text = name;
    }
  }

  void updateSignalDataFromChartData(
    List<List<int>> chartData,
    List<String> signalNames,
    List<SignalType> signalTypes,
  ) {
    if (chartData.isEmpty) return;

    setState(() {
      _actualChartData = List.from(chartData);
      List<SignalData> newSignalList = [];

      // 既存のコントローラーマップを構築
      final existingMaps = _buildExistingControllerMaps();
      final existingInputMap = existingMaps['input']!;
      final existingOutputMap = existingMaps['output']!;
      final existingHwTriggerMap = existingMaps['hwTrigger']!;
      final existingPlcMap = existingMaps['plc']!;
      final existingPlcInputMap = existingMaps['plcInput']!;

      // すべてのコントローラーをクリア
      _clearAllControllers();

      // チャートデータから信号を各コントローラーに割り当て
      for (int i = 0; i < chartData.length; i++) {
        final name = i < signalNames.length ? signalNames[i] : 'Signal $i';
        final type = i < signalTypes.length ? signalTypes[i] : SignalType.input;
        final values = List<int>.from(chartData[i]);

        if (type == SignalType.input ||
            type == SignalType.control ||
            type == SignalType.group ||
            type == SignalType.task) {
          _assignInputSignal(
            name,
            values,
            existingInputMap,
            existingPlcInputMap,
          );
        } else if (type == SignalType.output) {
          _assignOutputSignal(name, values, existingOutputMap, existingPlcMap);
        } else if (type == SignalType.hwTrigger) {
          _assignHwTriggerSignal(name, values, existingHwTriggerMap);
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

  List<String> getRowModes() => _rowModes.map((e) => e.name).toList();

  // CODE_OPTION / Command Option の波形を生成する
  List<int> _generateCodeOptionWave(List<int> autoWave, int waveLength) {
    // AUTO_MODE の立ち上がり検出（0→1の遷移）
    int riseIdx = -1;
    for (int t = 1; t < autoWave.length; t++) {
      if (autoWave[t - 1] == 0 && autoWave[t] != 0) {
        riseIdx = t;
        break;
      }
    }
    List<int> wave = List<int>.filled(waveLength, 0);
    if (riseIdx == -1) return wave;

    int start = riseIdx + 1; // 1 繧ｹ繝・ャ繝怜ｾ・
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

  // BUSY/TRIGGER/EXPOSURE の調整ルールを適用する
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

    int triggerIdx = names.indexOf('TRIGGER');
    if (triggerIdx == -1) {
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

    int busyIdx = names.indexOf('BUSY');
    if (busyIdx != -1) {
      values[busyIdx] = List<int>.from(codeWave);
    }

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
  // UI を構築する（メインビルドメソッド）
  @override
  Widget build(BuildContext context) {
    super.build(context);

    // UI 更新用に Provider を監視（ビルドと状態更新をトリガー）
    final watchedState = context.watch<FormStateNotifier>().state;

    // ボタンスタイルを定義
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color headerBg =
        Theme.of(context).colorScheme.surfaceContainerHighest;
    final Color background = headerBg.withAlpha((0.3 * 255).round());
    final Color borderColor =
        isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    // final Color tableBackground = Theme.of(context)
    //     .colorScheme
    //     .surfaceContainerHighest
    //     .withAlpha((0.3 * 255).round());

    final headerDecoration = BoxDecoration(
      color: background,
      border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      boxShadow: [
        BoxShadow(
          color: borderColor,
          offset: const Offset(0, 1),
          blurRadius: 2,
        ),
      ],
    );

    final inactiveHeaderDecoration = BoxDecoration(
      color: Color.alphaBlend(
        Colors.black.withAlpha((0.2 * 255).round()),
        background,
      ),
      border: Border(bottom: BorderSide(color: borderColor, width: 1)),
    );

    const headerPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    const headerHeight = 48.0; // 繝倥ャ繝繝ｼ縺ｮ鬮倥＆

    _ensureOutputTabController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
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
                        widget.onPlcEipOptionChanged(newValue);
                        _ensureOutputTabController();
                        _ensureInputTabController();
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

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_plcEipOption != 'None') ...[
                    ElevatedButton.icon(
                      onPressed:
                          () => _transferInputControllers(
                            widget.inputControllers,
                            widget.plcEipInputControllers,
                          ),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('DI⇔PLI/ESI'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed:
                          () => _transferOutputControllers(
                            widget.outputControllers,
                            widget.plcEipOutputControllers,
                          ),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('DO⇔PLO/ESO'),
                    ),
                    const SizedBox(width: 16),
                  ],
                  /*if (widget.showImportExportButtons) ...[
                    ElevatedButton.icon(
                      onPressed: _importConfig,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('繧､繝ｳ繝昴・繝・),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade100,
                        foregroundColor: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _exportConfig,
                      icon: const Icon(Icons.download),
                      label: const Text('繧ｨ繧ｯ繧ｹ繝昴・繝・),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                        foregroundColor: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],*/
                  ElevatedButton(
                    onPressed: () {
                      _clearTableData();
                      widget.onClearFields();
                    },
                    style: clearButtonStyle,
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 16),
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

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
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
                                  const SizedBox(width: 12),
                                  if (_plcEipOption != 'None' &&
                                      _inputTabController != null)
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: TabBar(
                                          controller: _inputTabController,
                                          isScrollable: true,
                                          tabAlignment: TabAlignment.center,
                                          labelPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8.0,
                                              ),
                                          tabs: const [
                                            Tab(text: 'DI'),
                                            Tab(text: 'PLI/ESI'),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
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
                                  const SizedBox(width: 12),
                                  if (_plcEipOption != 'None' &&
                                      _outputTabController != null)
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: TabBar(
                                          controller: _outputTabController,
                                          isScrollable: true,
                                          tabAlignment: TabAlignment.center,
                                          labelPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8.0,
                                              ),
                                          tabs: const [
                                            Tab(text: 'DO'),
                                            Tab(text: 'PLO/ESO'),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
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

                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(bottom: 640.0),
                                  child: Builder(
                                    builder: (_) {
                                      final bool useTabs =
                                          _plcEipOption != 'None';
                                      final bool showDio =
                                          !useTabs || _inputTabIndex == 0;
                                      return InputSection(
                                        controllers:
                                            showDio
                                                ? widget.inputControllers
                                                : widget.plcEipInputControllers,
                                        count: formState.inputCount,
                                        visibilityList: _inputVisibility,
                                        onVisibilityChanged:
                                            (index) => _toggleSignalVisibility(
                                              index,
                                              SignalType.input,
                                            ),
                                        triggerOption: formState.triggerOption,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),

                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(bottom: 640.0),
                                  child: Builder(
                                    builder: (_) {
                                      final bool useTabs =
                                          _plcEipOption != 'None';
                                      final bool showDio =
                                          !useTabs || _outputTabIndex == 0;
                                      return OutputSection(
                                        controllers:
                                            showDio
                                                ? widget.outputControllers
                                                : widget
                                                    .plcEipOutputControllers,
                                        count: formState.outputCount,
                                        visibilityList: _outputVisibility,
                                        onVisibilityChanged:
                                            (index) => _toggleSignalVisibility(
                                              index,
                                              SignalType.output,
                                            ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),

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

                const SizedBox(width: 32),

                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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

  // カメラ設定テーブルを構築する
  Widget _buildInteractiveTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal, // 讓ｪ譁ｹ蜷代・繧ｹ繧ｯ繝ｭ繝ｼ繝ｫ繧定ｿｽ蜉
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth, // 譛蟆丞ｹ・ｒ隕ｪ縺ｮ蟷・↓險ｭ螳・
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

  // テーブルのカラム幅を生成する
  Map<int, TableColumnWidth> _generateColumnWidths() {
    final Map<int, TableColumnWidth> columnWidths = {
      0: const FixedColumnWidth(60), // カラムヘッダーの幅
    };

    double columnWidth = 100.0; // カラムヘッダーの幅

    if (formState.camera > 6) {
      columnWidth = 80.0;
    } else if (formState.camera > 4) {
      columnWidth = 90.0;
    }

    for (int i = 1; i <= formState.camera; i++) {
      columnWidths[i] = FixedColumnWidth(columnWidth);
    }

    return columnWidths;
  }

  // テーブルの行を構築する
  List<TableRow> _buildTableRows() {
    List<TableRow> rows = [];

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

    for (int row = 0; row < _rowCount; row++) {
      rows.add(
        TableRow(
          children: [
            TableCell(
              child: InkWell(
                onTap: () => _changeRowMode(row),
                child: Container(
                  color:
                      rowModeColors[_rowModes[row]]?.withAlpha(
                        (0.3 * 255).round(),
                      ) ??
                      Theme.of(context).colorScheme.surfaceContainerHighest
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

  // セルモード選択用のドロップダウンを構築する
  Widget _buildModeDropdown(int row, int col) {
    const double kMinInteractiveDimension = 48.0; // セルモードのドロップダウンの高さ

    final bool _canSelectHwTrigger = formState.hwPort > 0;

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
        color:
            cellModeColors[_tableData[row][col]]?.withAlpha(
              (0.3 * 255).round(),
            ) ??
            Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4.0), // セルモードのドロップダウン
      child: DropdownButton<CellMode>(
        value: currentValue,
        isExpanded: true,
        isDense: true,
        underline: Container(), // セルモードのドロップダウンの下線
        itemHeight: kMinInteractiveDimension,
        onChanged: (CellMode? newValue) {
          if (newValue != null) {
            if (!_canSelectHwTrigger && newValue == CellMode.mode3) {
              return;
            }
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
                child: SizedBox(
                  height: kMinInteractiveDimension - 16, // セルモードのドロップダウンの高さ
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 12, // セルモードのドロップダウンの幅
                        height: 12, // セルモードのドロップダウンの高さ
                        decoration: BoxDecoration(
                          color: cellModeColors[mode],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 4), // セルモードのドロップダウンの幅
                      Flexible(
                        child: Text(
                          _labelForCellMode(context, mode),
                          overflow: TextOverflow.ellipsis, // セルモードのドロップダウンの文字数
                          style: const TextStyle(
                            fontSize: 12,
                          ), // セルモードのドロップダウンの文字サイズ
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

  // カラムヘッダーを構築する
  Widget _buildColumnHeader(int col) {
    final bool _canSelectHwTrigger = formState.hwPort > 0; // HW Trigger が選択可能か

    final Color? bgColor = cellModeColors[_columnModes
                .isNotEmpty // カラムモードの背景色
            ? _columnModes[col]
            : CellMode.none]
        ?.withAlpha((0.3 * 255).round());

    final List<CellMode> allowedModes = // カラムモードの選択可能なモード
        CellMode.values
            .where((m) => m != CellMode.mode4 && m != CellMode.mode5)
            .toList();

    return PopupMenuButton<CellMode>(
      onSelected: (CellMode mode) {
        if (!_canSelectHwTrigger && mode == CellMode.mode3)
          return; // HW Trigger が選択可能でない場合は mode3 を選択できない
        if (mode == CellMode.mode4 || mode == CellMode.mode5) return;
        _changeColumnMode(col, mode);
      },
      itemBuilder: (context) {
        final modes = // カラムモードの選択可能なモード
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
                      width: 12, // カラモードのドロップダウンの幅
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

  SignalType _inferSignalType(TimingFormState fs, int index) {
    if (fs.triggerOption != 'Code Trigger') return SignalType.input;
    if (fs.inputCount >= 32) {
      if (index >= 1 && index <= 8) return SignalType.control;
      if (index >= 9 && index <= 14) return SignalType.group;
      if (index >= 15 && index <= 20) return SignalType.task;
    } else if (fs.inputCount == 16) {
      if (index >= 1 && index <= 4) return SignalType.control;
      if (index >= 5 && index <= 7) return SignalType.group;
      if (index >= 8 && index <= 13) return SignalType.task;
    }
    return SignalType.input;
  }

  bool _inferVisibility(TimingFormState fs, int index) {
    if (fs.triggerOption != 'Code Trigger') return true;
    if (fs.inputCount >= 32) {
      return index == 0 || index > 20;
    }
    if (fs.inputCount == 16) {
      return index == 0 || index > 13;
    }
    return true;
  }

  String get plcOption => _plcEipOption;

  String formatPlcLabel(int index, String user) {
    final prefix = _plcEipOption == 'PLC' ? 'PLO' : 'ESO';
    return user.isNotEmpty
        ? '$prefix${index + 1}: $user'
        : '$prefix${index + 1}';
  }
}
