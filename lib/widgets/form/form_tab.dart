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
import '../../models/form/form_state.dart';
import '../../models/chart/chart_data_generator.dart'; // chart_data_generator.dartをインポート
import '../../models/chart/signal_type.dart'; // SignalTypeをインポート
import '../../models/chart/signal_data.dart'; // SignalDataをインポート
import '../../models/chart/io_channel_source.dart'; // IoChannelSourceをインポート
import '../../models/backup/app_config.dart'; // AppConfigをインポート
import '../../models/form/camera_table_types.dart';
import 'input_section.dart';
import 'output_section.dart';
import 'hw_trigger_section.dart';
import '../common/custom_dropdown.dart';
// import '../../common_padding.dart';
import '../../providers/form_state_notifier.dart';
import 'package:provider/provider.dart';
import '../../utils/chart_template_engine.dart';
import 'dart:math' as math;
import '../../providers/form_controllers_notifier.dart';
import 'camera_configuration_table.dart';
import 'form_tab_signal_mapper.dart';
import 'form_tab_controller_mapper.dart';
import 'form_tab_constants.dart';
import 'form_tab_output_preset.dart';
import 'form_tab_rules.dart';
import '../../utils/code_trigger_helpers.dart';

class FormTab extends StatefulWidget {
  /// Template、インポート、またはチャート編集による基準チャートが存在するか
  final bool hasChartBaseline;

  /// 入力（DIO）信号名
  final List<TextEditingController> inputControllers;

  /// 入力（PLC/EIP）信号名
  final List<TextEditingController> plcEipInputControllers;

  /// 出力（DIO）信号名
  final List<TextEditingController> outputControllers;

  /// 出力（PLC/EIP）信号名
  final List<TextEditingController> plcEipOutputControllers;

  /// HW Trigger 信号名
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
    required this.hasChartBaseline,
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
  /// NOTE:
  /// - この State は「フォーム入力 → SignalData/チャート生成 → 親へ通知」までの橋渡し役です。
  /// - UI の見た目（ヘッダー/入力欄/テーブル）は `build()` 配下の private widget に分割し、
  ///   ここでは “状態と振る舞い（ロジック）” が追えるようにしています。
  ///
  /// 画面の大きな流れ:
  /// - 入力欄（Controller）/テーブル（_tableData）/可視性（_*Visibility）を更新
  /// - `_updateSignalDataList()` が「直前の値をなるべく引き継ぎながら」 SignalData を再構築
  /// - Update/Template で onUpdateChart を呼び出し、親（MyHomePage）へ反映

  // AutomaticKeepAliveClientMixin により、タブ切り替え後も状態を保持するため true を返す
  @override
  bool get wantKeepAlive => true;

  static const double _buttonHeight = 48.0;
  static const double _buttonHorizontalPadding = 16.0;
  static const double _buttonVerticalPadding = 12.0;

  // --- 画面状態（テーブル） ---
  /// Camera Configuration Table の行数（初期値: `FormTabConstants.defaultRowCount`）
  int _rowCount = FormTabConstants.defaultRowCount;

  /// テーブルのセル状態（row x camera）
  List<List<CellMode>> _tableData = [];

  // --- 画面状態（信号一覧） ---
  /// 表示用の信号リスト（可視性を含む）
  List<SignalData> _signalDataList = [];

  /// 波形値の引き継ぎ用。信号名ではなく portKey で保持する（名前変更/順序入れ替えに強くする）
  Map<String, List<int>> _portValues = {};

  /// 直近の “出力済みチャート（可視信号のみ）”。
  /// - getSignalDataList() の復元や updateChartData() のマージに使う
  List<List<int>> _actualChartData = [];

  // --- 画面状態（テーブル付随） ---
  /// 行モード：セルとは独立に設定できるモード（none / 同時取込）
  List<RowMode> _rowModes = [];

  /// カラム一括変更のための現在値（UI用）
  List<CellMode> _columnModes = [];

  // --- 画面状態（可視性） ---
  /// チェックボックスの状態（SignalData の isVisible と同期する）
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

  // --- 画面状態（サブモード） ---
  /// PLC/EIP のモード（None/PLC/EIP）。UIのTabBar構成にも影響する。
  String _plcEipOption = PlcEipOptions.none;

  /// 外部から追加で渡される “信号名→波形” の一時バッファ（次回更新で取り込み後にクリア）
  Map<String, List<int>> _externalSignalValues = {};

  // --- UI補助（タブ） ---
  /// 出力用のサブタブ（DIO / PLC-EIP）
  TabController? _outputTabController;
  int _outputTabIndex = 0;

  /// 入力用のサブタブ（DIO / PLC-EIP）
  TabController? _inputTabController;
  int _inputTabIndex = 0;

  // 外部から PLC/EIP オプションを制御するためのセッター
  void setPlcEipOption(String value) {
    if (value != PlcEipOptions.none &&
        value != PlcEipOptions.plc &&
        value != PlcEipOptions.eip) {
      return;
    }
    setState(() {
      _plcEipOption = value;
    });
    _ensureOutputTabController();
    _ensureInputTabController();
  }

  /// 出力タブコントローラーを初期化または破棄する
  ///
  /// NOTE: None の場合は TabController を保持しない（TabBarも出さない）
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

  /// 入力タブコントローラーを初期化または破棄する
  ///
  /// NOTE: None の場合は TabController を保持しない（TabBarも出さない）
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

  /// トリガーオプションに応じて入力名を自動設定する
  ///
  /// 既存仕様:
  /// - Single Trigger: Input1 を TRIGGER に寄せる
  /// - Code Trigger: Control/Group/Task の領域は自動命名（ユーザー入力は受け付けない）
  void applyInputNamesForTriggerOption() {
    final fs = formState;
    if (fs.triggerOption == TriggerOptions.single) {
      if (widget.inputControllers.isNotEmpty) {
        widget.controllersNotifier.setInputText(0, SignalNames.trigger);
      }
      return;
    }

    if (fs.triggerOption == TriggerOptions.code) {
      if (fs.codeTriggerOnPlcEip) {
        if (fs.useDioTriggerPortWithVirtualIo) {
          if (widget.inputControllers.isNotEmpty) {
            widget.controllersNotifier.setInputText(0, SignalNames.trigger);
          }
        } else {
          if (widget.plcEipInputControllers.isNotEmpty) {
            widget.plcEipInputControllers[0].text = SignalNames.trigger;
          }
          if (widget.inputControllers.isNotEmpty) {
            widget.inputControllers[0].text = '';
          }
        }
      } else if (widget.inputControllers.isNotEmpty) {
        widget.controllersNotifier.setInputText(0, SignalNames.trigger);
      }
      _assignCodeTriggerInputNames(fs);
    }
  }

  /// Code Trigger モード用の入力名を設定する（自動命名）
  ///
  /// [codeTriggerOnPlcEip] が true のときは PLI/ESI 側へ、
  /// false のときは従来どおり DIO 側へ割り当てる。
  void _assignCodeTriggerInputNames(TimingFormState fs) {
    final dioControllers = widget.inputControllers;
    final plcControllers = widget.plcEipInputControllers;
    final bool onPlcEip = fs.codeTriggerOnPlcEip;
    final controllers = onPlcEip ? plcControllers : dioControllers;

    for (int i = 0; i < fs.inputCount && i < controllers.length; i++) {
      final newName = CodeTriggerHelpers.nameForIndex(i, fs.inputCount);
      if (newName != null && controllers[i].text != newName) {
        controllers[i].text = newName;
      }
    }
  }

  // bool _hwVis(int index) =>
  //     index < _hwTriggerVisibility.length ? _hwTriggerVisibility[index] : true;

  int _selectOutputIndex(String signalId, int totalOutputs, int totalCameras) =>
      FormTabOutputPreset.selectOutputIndex(
        signalId,
        totalOutputs,
        totalCameras,
      );

  @override
  /// Provider の state が変わったタイミングで呼ばれる（初期化と状態同期）
  ///
  /// 目的:
  /// - 初回だけ、テーブル/可視性/SignalData を初期化
  /// - input/output/hw/camera が変わった時、配列サイズや SignalData を追従させる
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

    // 仕様: Input=6 では Code Trigger を選べないため、状態を Single に戻す
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
            isVisible: i < _hwTriggerVisibility.length
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
            isVisible: i < _outputVisibility.length
                ? _outputVisibility[i]
                : true,
          ),
        );
      }
    }

    if (_plcEipOption != PlcEipOptions.none) {
      for (int i = 0; i < formState.outputCount; i++) {
        if (i < widget.plcEipOutputControllers.length &&
            widget.plcEipOutputControllers[i].text.isNotEmpty) {
          final base = _plcEipOption == PlcEipOptions.plc
              ? 'PLO${i + 1}'
              : 'ESO${i + 1}';
          final user = widget.plcEipOutputControllers[i].text;
          final label = '$base: $user';
          _signalDataList.add(
            SignalData(
              name: label,
              signalType: SignalType.output,
              values: List.filled(FormTabConstants.defaultWaveLength, 0),
              isVisible: i < _outputVisibility.length
                  ? _outputVisibility[i]
                  : true,
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
      _rowModes[row] = current == RowMode.none
          ? RowMode.simultaneous
          : RowMode.none;
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

  // Code Trigger用の信号タイプと可視性を決定
  // （旧）Code Trigger用の補助関数群は、マッピングロジック整理に伴い未使用になったため削除

  /// 現在の設定から信号データリストを生成・更新する（メイン処理）
  ///
  /// ここでやっていること:
  /// - 前回の値（_signalDataList / _portValues）を回収し、可能な限り波形を引き継ぐ
  /// - Controller の入力/可視性/PLC-EIP の状態に応じて SignalData を再構築
  ///
  /// NOTE:
  /// - portKey（例: dio-input:0）で値を保持しているため、信号名が変わっても引き継ぎやすい
  void _updateSignalDataList() {
    final Map<String, List<int>> prevPortValues = {
      for (final entry in _portValues.entries)
        entry.key: List<int>.from(entry.value),
    };

    setState(() {
      // Code Trigger 時の入力名自動設定（従来の副作用を維持）
      if (formState.triggerOption == TriggerOptions.code) {
        applyInputNamesForTriggerOption();
      }

      // 前の値を収集
      final Map<String, List<int>> prevValueMap = {
        for (final sig in _signalDataList) sig.name: List<int>.from(sig.values),
      };
      if (_externalSignalValues.isNotEmpty) {
        final externalCopy = {
          for (final entry in _externalSignalValues.entries)
            entry.key: List<int>.from(entry.value),
        };
        for (final entry in externalCopy.entries) {
          prevValueMap[entry.key] = List<int>.from(entry.value);
        }
        FormTabSignalMapper.applyExternalValuesToPortCache(
          prevPortValues: prevPortValues,
          externalValues: externalCopy,
          inputControllers: widget.inputControllers,
          plcEipInputControllers: widget.plcEipInputControllers,
          hwTriggerControllers: widget.hwTriggerControllers,
          outputControllers: widget.outputControllers,
          plcEipOutputControllers: widget.plcEipOutputControllers,
        );
        _externalSignalValues.clear();
      }

      final int defaultWaveLength =
          FormTabSignalMapper.computeDefaultWaveLength(
            prevValueMap: prevValueMap,
            prevPortValues: prevPortValues,
            fallbackLength: FormTabConstants.defaultWaveLength,
          );

      final List<String> prevOrder = _signalDataList
          .map((s) => s.name)
          .toList();

      final inputSignalMap = FormTabSignalMapper.buildInputSignalMap(
        formState: formState,
        inputControllers: widget.inputControllers,
        plcEipInputControllers: widget.plcEipInputControllers,
        plcEipOption: _plcEipOption,
        inputVisibility: _inputVisibility,
        inferSignalType: (index, {bool isPlcEipChannel = false}) =>
            _inferSignalType(
              formState,
              index,
              isPlcEipChannel: isPlcEipChannel,
            ),
        inferVisibility: (index, {bool isPlcEipChannel = false}) =>
            _inferVisibility(
              formState,
              index,
              isPlcEipChannel: isPlcEipChannel,
            ),
        prevPortValues: prevPortValues,
        prevValueMap: prevValueMap,
        defaultWaveLength: defaultWaveLength,
      );

      final hwTriggerSignalMap = FormTabSignalMapper.buildHwTriggerSignalMap(
        formState: formState,
        hwTriggerControllers: widget.hwTriggerControllers,
        hwTriggerVisibility: _hwTriggerVisibility,
        prevPortValues: prevPortValues,
        prevValueMap: prevValueMap,
        defaultWaveLength: defaultWaveLength,
      );

      final outputSignalMap = FormTabSignalMapper.buildOutputSignalMap(
        formState: formState,
        outputControllers: widget.outputControllers,
        plcEipOutputControllers: widget.plcEipOutputControllers,
        plcEipOption: _plcEipOption,
        outputVisibility: _outputVisibility,
        prevPortValues: prevPortValues,
        prevValueMap: prevValueMap,
        defaultWaveLength: defaultWaveLength,
      );

      final Map<String, List<int>> newPortValues =
          FormTabSignalMapper.buildPortValues(
            formState: formState,
            inputSignalMap: inputSignalMap,
            outputSignalMap: outputSignalMap,
            hwTriggerSignalMap: hwTriggerSignalMap,
          );

      // チャートデータを生成
      generateTimingChartDataWithPositions(
        inputSignalMap,
        outputSignalMap,
        hwTriggerSignalMap,
        timeLength: defaultWaveLength,
      );

      // 信号データリストを構築
      _signalDataList = FormTabSignalMapper.populateSignalDataList(
        formState: formState,
        plcEipOption: _plcEipOption,
        inputSignalMap: inputSignalMap,
        outputSignalMap: outputSignalMap,
        hwTriggerSignalMap: hwTriggerSignalMap,
        prevOrder: prevOrder,
      );

      // Code/Command Trigger用の信号を追加（従来通り）
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

      _portValues = newPortValues;
    });
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
              _plcEipOption == PlcEipOptions.plc
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
              _plcEipOption == PlcEipOptions.plc
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

    int waveLength = chartData.isNotEmpty
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

  /// "Update Chart" ボタンが押されたときの処理
  ///
  /// - 現在のフォーム状態からチャートを生成し、親へ通知する
  /// - Code/Command の場合は Option 波形を注入して整合性を取る
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

    final visibleNameSet = _signalDataList
        .where((s) => s.isVisible)
        .map((s) => s.name)
        .toSet();

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

    // デバッグ用（必要なら後で logger に寄せる）
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

  bool _hasUpdateTarget(TimingFormState fs) {
    // Code/Command は専用のオプション信号を自動生成する。
    if (fs.triggerOption == TriggerOptions.code ||
        fs.triggerOption == TriggerOptions.command) {
      return true;
    }

    bool hasNamedSignal(
      List<TextEditingController> controllers,
      int count, {
      List<bool>? visibility,
    }) {
      final limit = math.min(count, controllers.length);
      for (int i = 0; i < limit; i++) {
        final isVisible =
            visibility == null || i >= visibility.length || visibility[i];
        if (isVisible && controllers[i].text.trim().isNotEmpty) {
          return true;
        }
      }
      return false;
    }

    if (hasNamedSignal(widget.inputControllers, fs.inputCount)) {
      return true;
    }
    if (_plcEipOption != PlcEipOptions.none &&
        hasNamedSignal(widget.plcEipInputControllers, fs.inputCount)) {
      return true;
    }
    if (hasNamedSignal(
      widget.outputControllers,
      fs.outputCount,
      visibility: _outputVisibility,
    )) {
      return true;
    }
    if (_plcEipOption != PlcEipOptions.none &&
        hasNamedSignal(
          widget.plcEipOutputControllers,
          fs.outputCount,
          visibility: _outputVisibility,
        )) {
      return true;
    }
    return hasNamedSignal(
      widget.hwTriggerControllers,
      fs.hwPort,
      visibility: _hwTriggerVisibility,
    );
  }

  List<TextEditingController> get _signalControllers => [
    ...widget.inputControllers,
    ...widget.plcEipInputControllers,
    ...widget.outputControllers,
    ...widget.plcEipOutputControllers,
    ...widget.hwTriggerControllers,
  ];

  // Template 信号データの更新

  /// "Template" ボタンが押されたときの処理（テンプレートエンジンを使用）
  ///
  /// 目的:
  /// - テーブル（_tableData / _rowModes）から “推奨のタイミング” を計算し、
  ///   ChartTemplateEngine で波形テンプレートを生成して反映する
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

    if (!mounted) return;

    if (generatedSignals.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('信号データの更新が完了しました')));
      return;
    }

    // === 信号データの更新 ===
    List<SignalData> filteredSignals = generatedSignals;
    if (formState.hwPort == 0) {
      filteredSignals = generatedSignals
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
      filteredSignals = filteredSignals
          .where((sig) => sig.name != 'CONTACT_INPUT_WAITING')
          .toList();
    }
    if (!(hasContactInputMode || hasHwTriggerMode)) {
      filteredSignals = filteredSignals
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

    final visibleNameSet = _signalDataList
        .where((s) => s.isVisible)
        .map((s) => s.name)
        .toSet();

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

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('信号データの更新が完了しました')));
  }

  // 信号データリストを取得する（外部アクセス用）
  List<SignalData> getSignalDataList() {
    if (_actualChartData.isNotEmpty &&
        _actualChartData.any((row) => row.any((val) => val != 0))) {
      List<SignalData> result = [];
      int dataIndex = 0;

      // 入力信号
      for (int i = 0; i < formState.inputCount; i++) {
        if (i >= widget.inputControllers.length) break;
        if (widget.inputControllers[i].text.isEmpty) continue;

        final SignalType signalType = FormTabRules.inferInputSignalType(
          triggerOption: formState.triggerOption,
          inputCount: formState.inputCount,
          index: i,
          codeTriggerOnPlcEip: formState.codeTriggerOnPlcEip,
          isPlcEipChannel: false,
        );

        List<int> values;
        if (dataIndex < _actualChartData.length) {
          values = List.from(_actualChartData[dataIndex]);
          dataIndex++;
        } else {
          values = List.filled(FormTabConstants.defaultWaveLength, 0);
        }

        result.add(
          SignalData(
            name: widget.inputControllers[i].text,
            signalType: signalType,
            values: values,
            isVisible: i < _inputVisibility.length ? _inputVisibility[i] : true,
          ),
        );
      }

      for (int i = 0; i < formState.hwPort; i++) {
        if (i >= widget.hwTriggerControllers.length) break;
        if (widget.hwTriggerControllers[i].text.isNotEmpty) {
          if (dataIndex < _actualChartData.length) {
            result.add(
              SignalData(
                name: widget.hwTriggerControllers[i].text,
                signalType: SignalType.hwTrigger,
                values: List.from(_actualChartData[dataIndex]),
                isVisible: i < _hwTriggerVisibility.length
                    ? _hwTriggerVisibility[i]
                    : true,
              ),
            );
            dataIndex++;
          }
        }
      }

      // 出力信号
      for (int i = 0; i < formState.outputCount; i++) {
        if (i >= widget.outputControllers.length) break;
        if (widget.outputControllers[i].text.isNotEmpty) {
          if (dataIndex < _actualChartData.length) {
            result.add(
              SignalData(
                name: widget.outputControllers[i].text,
                signalType: SignalType.output,
                values: List.from(_actualChartData[dataIndex]),
                isVisible: i < _outputVisibility.length
                    ? _outputVisibility[i]
                    : true,
              ),
            );
            dataIndex++;
          }
        }
      }

      if (_plcEipOption != PlcEipOptions.none) {
        for (int i = 0; i < formState.outputCount; i++) {
          if (i >= widget.plcEipOutputControllers.length) continue;
          final text = widget.plcEipOutputControllers[i].text;
          if (text.isEmpty) continue;

          final String prefix = _plcEipOption == PlcEipOptions.plc
              ? 'PLO'
              : 'ESO';
          final String name = '$prefix${i + 1}: $text';

          if (dataIndex < _actualChartData.length) {
            result.add(
              SignalData(
                name: name,
                signalType: SignalType.output,
                values: List.from(_actualChartData[dataIndex]),
                isVisible: i < _outputVisibility.length
                    ? _outputVisibility[i]
                    : true,
              ),
            );
            dataIndex++;
          } else {
            result.add(
              SignalData(
                name: name,
                signalType: SignalType.output,
                values: List.filled(FormTabConstants.defaultWaveLength, 0),
                isVisible: i < _outputVisibility.length
                    ? _outputVisibility[i]
                    : true,
              ),
            );
          }
        }
      }

      if (result.isNotEmpty) {
        return result;
      }
    }

    _updateSignalDataList();
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

      _rowModes = config.rowModes
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

      _actualChartData = _signalDataList
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

  // （controller割当ロジックは `FormTabControllerMapper` に切り出し）

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
      final existingMaps = FormTabControllerMapper.buildExistingControllerMaps(
        inputControllers: widget.inputControllers,
        outputControllers: widget.outputControllers,
        hwTriggerControllers: widget.hwTriggerControllers,
        plcEipOutputControllers: widget.plcEipOutputControllers,
        plcEipInputControllers: widget.plcEipInputControllers,
      );
      final existingInputMap = existingMaps['input']!;
      final existingOutputMap = existingMaps['output']!;
      final existingHwTriggerMap = existingMaps['hwTrigger']!;
      final existingPlcMap = existingMaps['plc']!;
      final existingPlcInputMap = existingMaps['plcInput']!;

      // すべてのコントローラーをクリア
      FormTabControllerMapper.clearAllControllers(
        inputControllers: widget.inputControllers,
        outputControllers: widget.outputControllers,
        hwTriggerControllers: widget.hwTriggerControllers,
        plcEipInputControllers: widget.plcEipInputControllers,
      );

      // チャートデータから信号を各コントローラーに割り当て
      for (int i = 0; i < chartData.length; i++) {
        final name = i < signalNames.length ? signalNames[i] : 'Signal $i';
        final type = i < signalTypes.length ? signalTypes[i] : SignalType.input;
        final values = List<int>.from(chartData[i]);

        if (type == SignalType.input ||
            type == SignalType.control ||
            type == SignalType.group ||
            type == SignalType.task) {
          FormTabControllerMapper.assignInputSignal(
            formState: formState,
            name: name,
            existingInputMap: existingInputMap,
            existingPlcInputMap: existingPlcInputMap,
            inputControllers: widget.inputControllers,
            plcEipInputControllers: widget.plcEipInputControllers,
            contactInputWaitingName: SignalNames.contactInputWaiting,
            contactInputWaitingIndex32:
                FormTabConstants.contactInputWaitingIndex32,
          );
        } else if (type == SignalType.output) {
          FormTabControllerMapper.assignOutputSignal(
            formState: formState,
            name: name,
            existingOutputMap: existingOutputMap,
            existingPlcMap: existingPlcMap,
            outputControllers: widget.outputControllers,
            reservedOutputStart: FormTabConstants.reservedOutputStart,
            selectOutputIndex: _selectOutputIndex,
          );
        } else if (type == SignalType.hwTrigger) {
          FormTabControllerMapper.assignHwTriggerSignal(
            name: name,
            existingHwTriggerMap: existingHwTriggerMap,
            hwTriggerControllers: widget.hwTriggerControllers,
          );
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

      if (formState.triggerOption == TriggerOptions.code) {
        applyInputNamesForTriggerOption();
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
  Widget build(BuildContext context) {
    super.build(context);

    // UI 更新用に Provider を監視（ビルドと状態更新をトリガー）
    final fs = context.watch<FormStateNotifier>().state;

    // UIスタイルはまとめて生成（build内のノイズを減らし、画面構造を読みやすくする）
    final buttonStyles = _FormTabButtonStyles.from(
      context,
      height: _buttonHeight,
      horizontalPadding: _buttonHorizontalPadding,
      verticalPadding: _buttonVerticalPadding,
    );
    final headerStyles = _FormTabHeaderStyles.from(context);

    // PLC/EIP の有無で TabController を持つ/捨てるので、build前に状態を保証する
    _ensureOutputTabController();
    _ensureInputTabController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge(_signalControllers),
          builder: (context, child) {
            final hasUpdateTarget = _hasUpdateTarget(fs);
            final canUpdateChart = widget.hasChartBaseline && hasUpdateTarget;
            final updateChartTooltip = !widget.hasChartBaseline
                ? '先にTemplateを実行するか、ファイルをインポートしてください'
                : !hasUpdateTarget
                ? '更新対象の信号名を1件以上入力してください'
                : 'フォームの内容を既存チャートに反映します';

            return _FormTabHeaderSection(
              formState: fs,
              plcEipOption: _plcEipOption,
              onTriggerOptionChanged: widget.onTriggerOptionChanged,
              onPlcEipOptionChanged: (newValue) {
                if (newValue == null) return;
                setState(() {
                  _plcEipOption = newValue;
                });
                widget.onPlcEipOptionChanged(newValue);
                _ensureOutputTabController();
                _ensureInputTabController();
              },
              onInputPortChanged: widget.onInputPortChanged,
              onOutputPortChanged: widget.onOutputPortChanged,
              onHwPortChanged: widget.onHwPortChanged,
              onCameraChanged: widget.onCameraChanged,
              showTransferButtons: _plcEipOption != PlcEipOptions.none,
              onTransferInputs: () => _transferInputControllers(
                widget.inputControllers,
                widget.plcEipInputControllers,
              ),
              onTransferOutputs: () => _transferOutputControllers(
                widget.outputControllers,
                widget.plcEipOutputControllers,
              ),
              onClear: () {
                _clearTableData();
                widget.onClearFields();
              },
              onTemplatePressed: _onTemplatePressed,
              onUpdateChartPressed: _onUpdateChart,
              canUpdateChart: canUpdateChart,
              updateChartTooltip: updateChartTooltip,
              buttonStyles: buttonStyles,
            );
          },
        ),

        Expanded(
          child: _FormTabBodySection(
            formState: fs,
            plcEipOption: _plcEipOption,
            inputTabController: _inputTabController,
            outputTabController: _outputTabController,
            inputTabIndex: _inputTabIndex,
            outputTabIndex: _outputTabIndex,
            inputControllers: widget.inputControllers,
            plcEipInputControllers: widget.plcEipInputControllers,
            outputControllers: widget.outputControllers,
            plcEipOutputControllers: widget.plcEipOutputControllers,
            hwTriggerControllers: widget.hwTriggerControllers,
            inputVisibility: _inputVisibility,
            outputVisibility: _outputVisibility,
            hwTriggerVisibility: _hwTriggerVisibility,
            onToggleVisibility: _toggleSignalVisibility,
            headerStyles: headerStyles,
            addRowButtonStyle: buttonStyles.addRow,
            removeRowButtonStyle: buttonStyles.removeRow,
            rowCount: _rowCount,
            tableData: _tableData,
            rowModes: _rowModes,
            columnModes: _columnModes,
            onAddRow: _addRow,
            onRemoveRow: _removeRow,
            onToggleRowMode: _changeRowMode,
            onChangeCellMode: _changeCellMode,
            onChangeColumnMode: _changeColumnMode,
          ),
        ),
      ],
    );
  }

  SignalType _inferSignalType(
    TimingFormState fs,
    int index, {
    bool isPlcEipChannel = false,
  }) {
    return FormTabRules.inferInputSignalType(
      triggerOption: fs.triggerOption,
      inputCount: fs.inputCount,
      index: index,
      codeTriggerOnPlcEip: fs.codeTriggerOnPlcEip,
      isPlcEipChannel: isPlcEipChannel,
    );
  }

  bool _inferVisibility(
    TimingFormState fs,
    int index, {
    bool isPlcEipChannel = false,
  }) {
    return FormTabRules.inferInputVisibility(
      triggerOption: fs.triggerOption,
      inputCount: fs.inputCount,
      index: index,
      codeTriggerOnPlcEip: fs.codeTriggerOnPlcEip,
      isPlcEipChannel: isPlcEipChannel,
    );
  }

  String get plcOption => _plcEipOption;

  String formatPlcLabel(int index, String user) {
    final prefix = _plcEipOption == PlcEipOptions.plc ? 'PLO' : 'ESO';
    return user.isNotEmpty
        ? '$prefix${index + 1}: $user'
        : '$prefix${index + 1}';
  }
}

class _FormTabButtonStyles {
  /// FormTab 内で使うボタンスタイルの束。
  ///
  /// NOTE: “同じpadding/高さで色だけ違う” という意図を揃えるためにまとめている。
  final ButtonStyle clear;
  final ButtonStyle update;
  final ButtonStyle template;
  final ButtonStyle addRow;
  final ButtonStyle removeRow;

  const _FormTabButtonStyles({
    required this.clear,
    required this.update,
    required this.template,
    required this.addRow,
    required this.removeRow,
  });

  static _FormTabButtonStyles from(
    BuildContext context, {
    required double height,
    required double horizontalPadding,
    required double verticalPadding,
  }) {
    final EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: horizontalPadding,
      vertical: verticalPadding,
    );

    return _FormTabButtonStyles(
      clear: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade100,
        foregroundColor: Colors.red.shade900,
        minimumSize: Size(120, height),
        padding: padding,
      ),
      update: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade100,
        foregroundColor: Colors.blue.shade900,
        minimumSize: Size(120, height),
        padding: padding,
      ),
      template: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.shade100,
        foregroundColor: Colors.orange.shade900,
        minimumSize: Size(120, height),
        padding: padding,
      ),
      addRow: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade100,
        foregroundColor: Colors.green.shade900,
        minimumSize: Size(120, height),
        padding: padding,
      ),
      removeRow: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade100,
        foregroundColor: Colors.red.shade900,
        minimumSize: Size(120, height),
        padding: padding,
      ),
    );
  }
}

class _FormTabHeaderStyles {
  /// FormTab 内で使う “見出し（ヘッダー）” の見た目を統一するための束。
  final BoxDecoration headerDecoration;
  final BoxDecoration inactiveHeaderDecoration;
  final EdgeInsets headerPadding;
  final double headerHeight;

  const _FormTabHeaderStyles({
    required this.headerDecoration,
    required this.inactiveHeaderDecoration,
    required this.headerPadding,
    required this.headerHeight,
  });

  static _FormTabHeaderStyles from(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color headerBg = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest;
    final Color background = headerBg.withAlpha(
      (FormTabConstants.alphaBlendValue * 255).round(),
    );
    final Color borderColor = isDark
        ? Colors.grey.shade700
        : Colors.grey.shade300;

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

    return _FormTabHeaderStyles(
      headerDecoration: headerDecoration,
      inactiveHeaderDecoration: inactiveHeaderDecoration,
      headerPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      headerHeight: 48.0,
    );
  }
}

class _FormTabHeaderSection extends StatelessWidget {
  /// 画面上部の “設定UI + 操作ボタン” の塊。
  ///
  /// - Trigger/PLC/Input/Output/HW/Camera を選ぶ
  /// - Transfer/Clear/Template/Update を実行する
  final TimingFormState formState;
  final String plcEipOption;
  final ValueChanged<String?> onTriggerOptionChanged;
  final ValueChanged<String?> onPlcEipOptionChanged;
  final ValueChanged<int?> onInputPortChanged;
  final ValueChanged<int?> onOutputPortChanged;
  final ValueChanged<int?> onHwPortChanged;
  final ValueChanged<int?> onCameraChanged;
  final bool showTransferButtons;
  final VoidCallback onTransferInputs;
  final VoidCallback onTransferOutputs;
  final VoidCallback onClear;
  final Future<void> Function() onTemplatePressed;
  final Future<void> Function() onUpdateChartPressed;
  final bool canUpdateChart;
  final String updateChartTooltip;
  final _FormTabButtonStyles buttonStyles;

  const _FormTabHeaderSection({
    required this.formState,
    required this.plcEipOption,
    required this.onTriggerOptionChanged,
    required this.onPlcEipOptionChanged,
    required this.onInputPortChanged,
    required this.onOutputPortChanged,
    required this.onHwPortChanged,
    required this.onCameraChanged,
    required this.showTransferButtons,
    required this.onTransferInputs,
    required this.onTransferOutputs,
    required this.onClear,
    required this.onTemplatePressed,
    required this.onUpdateChartPressed,
    required this.canUpdateChart,
    required this.updateChartTooltip,
    required this.buttonStyles,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> triggerItems = FormTabRules.triggerOptionsForInputCount(
      formState.inputCount,
    );
    final String dropdownValue = triggerItems.contains(formState.triggerOption)
        ? formState.triggerOption
        : TriggerOptions.single;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: CustomDropdown<String>(
                  value: dropdownValue,
                  items: triggerItems,
                  onChanged: onTriggerOptionChanged,
                  label: 'Trigger Option',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDropdown<String>(
                  value: plcEipOption,
                  items: const [
                    PlcEipOptions.none,
                    PlcEipOptions.plc,
                    PlcEipOptions.eip,
                  ],
                  onChanged: onPlcEipOptionChanged,
                  label: 'PLC / EIP',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDropdown<int>(
                  value: FormTabRules.portOptions.contains(formState.inputCount)
                      ? formState.inputCount
                      : FormTabRules.portOptions.firstWhere(
                          (v) => v >= formState.inputCount,
                          orElse: () => FormTabRules.portOptions.last,
                        ),
                  items: FormTabRules.portOptions,
                  onChanged: onInputPortChanged,
                  label: 'Input Port',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDropdown<int>(
                  value:
                      FormTabRules.portOptions.contains(formState.outputCount)
                      ? formState.outputCount
                      : FormTabRules.portOptions.firstWhere(
                          (v) => v >= formState.outputCount,
                          orElse: () => FormTabRules.portOptions.last,
                        ),
                  items: FormTabRules.portOptions,
                  onChanged: onOutputPortChanged,
                  label: 'Output Port',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDropdown<int>(
                  value:
                      (formState.hwPort == 0 ||
                          formState.hwPort == formState.camera)
                      ? formState.hwPort
                      : formState.camera,
                  items: [0, formState.camera],
                  onChanged: onHwPortChanged,
                  label: 'HW Port',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDropdown<int>(
                  value: formState.camera,
                  items: List.generate(8, (index) => index + 1),
                  onChanged: onCameraChanged,
                  label: 'Camera',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (showTransferButtons) ...[
                ElevatedButton.icon(
                  onPressed: onTransferInputs,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('DI⇔PLI/ESI'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onTransferOutputs,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('DO⇔PLO/ESO'),
                ),
                const SizedBox(width: 16),
              ],
              ElevatedButton(
                onPressed: onClear,
                style: buttonStyles.clear,
                child: const Text('Clear'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: onTemplatePressed,
                style: buttonStyles.template,
                child: const Text('Template'),
              ),
              const SizedBox(width: 16),
              Tooltip(
                message: updateChartTooltip,
                child: ElevatedButton(
                  onPressed: canUpdateChart ? onUpdateChartPressed : null,
                  style: buttonStyles.update,
                  child: const Text('Update Chart'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormTabBodySection extends StatelessWidget {
  /// 画面下部の “信号入力（3カラム） + カメラ設定テーブル” の塊。
  ///
  /// - 左: Input / Output / HW Trigger の各入力欄
  /// - 右: Camera Configuration Table
  static const double _signalsScrollBottomPadding = 640.0;

  final TimingFormState formState;
  final String plcEipOption;

  final TabController? inputTabController;
  final TabController? outputTabController;
  final int inputTabIndex;
  final int outputTabIndex;

  final List<TextEditingController> inputControllers;
  final List<TextEditingController> plcEipInputControllers;
  final List<TextEditingController> outputControllers;
  final List<TextEditingController> plcEipOutputControllers;
  final List<TextEditingController> hwTriggerControllers;

  final List<bool> inputVisibility;
  final List<bool> outputVisibility;
  final List<bool> hwTriggerVisibility;
  final void Function(int index, SignalType type) onToggleVisibility;

  final _FormTabHeaderStyles headerStyles;

  final ButtonStyle addRowButtonStyle;
  final ButtonStyle removeRowButtonStyle;

  final int rowCount;
  final List<List<CellMode>> tableData;
  final List<RowMode> rowModes;
  final List<CellMode> columnModes;
  final VoidCallback onAddRow;
  final VoidCallback onRemoveRow;
  final void Function(int row) onToggleRowMode;
  final void Function(int row, int col, CellMode mode) onChangeCellMode;
  final void Function(int col, CellMode mode) onChangeColumnMode;

  const _FormTabBodySection({
    required this.formState,
    required this.plcEipOption,
    required this.inputTabController,
    required this.outputTabController,
    required this.inputTabIndex,
    required this.outputTabIndex,
    required this.inputControllers,
    required this.plcEipInputControllers,
    required this.outputControllers,
    required this.plcEipOutputControllers,
    required this.hwTriggerControllers,
    required this.inputVisibility,
    required this.outputVisibility,
    required this.hwTriggerVisibility,
    required this.onToggleVisibility,
    required this.headerStyles,
    required this.addRowButtonStyle,
    required this.removeRowButtonStyle,
    required this.rowCount,
    required this.tableData,
    required this.rowModes,
    required this.columnModes,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onToggleRowMode,
    required this.onChangeCellMode,
    required this.onChangeColumnMode,
  });

  @override
  Widget build(BuildContext context) {
    final bool useTabs = plcEipOption != PlcEipOptions.none;

    return Padding(
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
                      child: _SignalHeader(
                        title: 'Input Signals',
                        decoration: headerStyles.headerDecoration,
                        padding: headerStyles.headerPadding,
                        height: headerStyles.headerHeight,
                        tabBar: (useTabs && inputTabController != null)
                            ? TabBar(
                                controller: inputTabController,
                                isScrollable: true,
                                tabAlignment: TabAlignment.center,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                tabs: const [
                                  Tab(text: 'DI'),
                                  Tab(text: 'PLI/ESI'),
                                ],
                              )
                            : null,
                      ),
                    ),
                    Expanded(
                      child: _SignalHeader(
                        title: 'Output Signals',
                        decoration: headerStyles.headerDecoration,
                        padding: headerStyles.headerPadding,
                        height: headerStyles.headerHeight,
                        tabBar: (useTabs && outputTabController != null)
                            ? TabBar(
                                controller: outputTabController,
                                isScrollable: true,
                                tabAlignment: TabAlignment.center,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                tabs: const [
                                  Tab(text: 'DO'),
                                  Tab(text: 'PLO/ESO'),
                                ],
                              )
                            : null,
                      ),
                    ),
                    Expanded(
                      child: _SignalHeader(
                        title: 'HW Trigger Signals',
                        decoration: formState.hwPort > 0
                            ? headerStyles.headerDecoration
                            : headerStyles.inactiveHeaderDecoration,
                        padding: headerStyles.headerPadding,
                        height: headerStyles.headerHeight,
                        titleColor: formState.hwPort > 0
                            ? null
                            : Colors.grey.shade500,
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
                            padding: const EdgeInsets.only(
                              bottom: _signalsScrollBottomPadding,
                            ),
                            child: InputSection(
                              controllers: (!useTabs || inputTabIndex == 0)
                                  ? inputControllers
                                  : plcEipInputControllers,
                              count: formState.inputCount,
                              visibilityList: inputVisibility,
                              onVisibilityChanged: (index) =>
                                  onToggleVisibility(index, SignalType.input),
                              triggerOption: formState.triggerOption,
                              codeTriggerOnPlcEip:
                                  formState.codeTriggerOnPlcEip,
                              isPlcEipChannel: useTabs && inputTabIndex == 1,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(
                              bottom: _signalsScrollBottomPadding,
                            ),
                            child: OutputSection(
                              controllers: (!useTabs || outputTabIndex == 0)
                                  ? outputControllers
                                  : plcEipOutputControllers,
                              count: formState.outputCount,
                              visibilityList: outputVisibility,
                              onVisibilityChanged: (index) =>
                                  onToggleVisibility(index, SignalType.output),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: formState.hwPort > 0
                            ? SingleChildScrollView(
                                padding: const EdgeInsets.only(
                                  bottom: _signalsScrollBottomPadding,
                                ),
                                child: HwTriggerSection(
                                  controllers: hwTriggerControllers,
                                  count: formState.hwPort,
                                  visibilityList: hwTriggerVisibility,
                                  onVisibilityChanged: (index) =>
                                      onToggleVisibility(
                                        index,
                                        SignalType.hwTrigger,
                                      ),
                                ),
                              )
                            : const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16.0),
                                  child: Text(
                                    "HW Trigger Ports are not available.",
                                    style: TextStyle(color: Colors.grey),
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
                  decoration: headerStyles.headerDecoration,
                  padding: headerStyles.headerPadding,
                  alignment: Alignment.centerLeft,
                  height: headerStyles.headerHeight,
                  child: const Text(
                    'Camera Configuration Table',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onAddRow,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Row'),
                      style: addRowButtonStyle,
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: rowCount > 1 ? onRemoveRow : null,
                      icon: const Icon(Icons.remove),
                      label: const Text('Remove Row'),
                      style: removeRowButtonStyle,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: CameraConfigurationTable(
                    cameraCount: formState.camera,
                    rowCount: rowCount,
                    tableData: tableData,
                    rowModes: rowModes,
                    columnModes: columnModes,
                    canSelectHwTrigger: formState.hwPort > 0,
                    onToggleRowMode: onToggleRowMode,
                    onChangeCellMode: onChangeCellMode,
                    onChangeColumnMode: onChangeColumnMode,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalHeader extends StatelessWidget {
  /// Input/Output/HW の見出し行（必要に応じて TabBar を右側に表示）
  final String title;
  final BoxDecoration decoration;
  final EdgeInsets padding;
  final double height;
  final Color? titleColor;
  final Widget? tabBar;

  const _SignalHeader({
    required this.title,
    required this.decoration,
    required this.padding,
    required this.height,
    this.titleColor,
    this.tabBar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: decoration,
      padding: padding,
      alignment: Alignment.centerLeft,
      height: height,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: titleColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (tabBar != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: tabBar!),
            ),
          ],
        ],
      ),
    );
  }
}
