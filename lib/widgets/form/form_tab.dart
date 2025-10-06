/*
FormTab・医ヵ繧ｩ繝ｼ繝蜈･蜉帙ち繝厄ｼ・

縺薙・逕ｻ髱｢縺ｧ縺ｧ縺阪ｋ縺薙→
- 蜈･蜃ｺ蜉・HW Trigger 縺ｮ菫｡蜿ｷ蜷阪ｒ蜈･蜉帙・陦ｨ遉ｺ/髱櫁｡ｨ遉ｺ繧貞・譖ｿ
- 繧ｫ繝｡繝ｩ謨ｰ繧・推遞ｮ繝昴・繝域焚縲ゝrigger 繝｢繝ｼ繝会ｼ・ingle/Code/Command・峨ｒ驕ｸ謚・
- Camera Configuration Table 縺ｧ蜿冶ｾｼ繧ｹ繧ｱ繧ｸ繝･繝ｼ繝ｫ・亥推繧ｫ繝｡繝ｩ縺ｮ繝｢繝ｼ繝会ｼ峨ｒ險ｭ險・
- Template/Update 繝懊ち繝ｳ縺ｧ豕｢蠖｢繧堤函謌舌＠縲√メ繝｣繝ｼ繝医∈蜿肴丐
- 險ｭ螳壹・繧､繝ｳ繝昴・繝・繧ｨ繧ｯ繧ｹ繝昴・繝茨ｼ亥ｿ・ｦ√↓蠢懊§縺ｦ・・

蜈ｨ菴薙・繝・・繧ｿ縺ｮ豬√ｌ・域ｦら払・・
1) 逕ｻ髱｢荳翫・ TextEditingController 鄒､縺後Θ繝ｼ繧ｶ繝ｼ蜈･蜉帙ｒ菫晄戟
2) 縲袈pdate Chart縲阪ｒ謚ｼ縺吶→縲∫樟蝨ｨ縺ｮ繝輔か繝ｼ繝迥ｶ諷・竊・SignalData 縺ｫ蜿肴丐
3) 蜿ｯ隕悶ヵ繧｣繝ｫ繧ｿ繧・・繝ｼ繝育分蜿ｷ繧定ｨ育ｮ励＠縺ｦ縲∬ｦｪ・・yHomePage・峨∈ onUpdateChart 縺ｧ騾∽ｿ｡
4) 隕ｪ蛛ｴ縺ｯ TimingChart 縺ｫ陦ｨ遉ｺ逕ｨ繝・・繧ｿ繧呈ｸ｡縺励∝ｿ・ｦ√↓蠢懊§縺ｦ FormTab 蛛ｴ縺ｸ繧ょ､繧呈綾縺・

驥崎ｦ√↑險ｭ險医・繧､繝ｳ繝・
- AutomaticKeepAliveClientMixin 縺ｫ繧医ｊ繧ｿ繝門・譖ｿ縺ｧ繧ょ・蜉帙′豸医∴縺ｪ縺・
- Provider(FormStateNotifier) 縺ｮ蛟､縺ｨ TextEditingController 縺ｮ髟ｷ縺輔ｒ縺薙∪繧√↓蜷梧悄
- Post-frame・・idgetsBinding・峨〒縺ｮ譖ｴ譁ｰ繧堤畑縺・※ build 荳ｭ縺ｮ騾夂衍繧帝∩縺代∽ｾ句､悶ｄ謠冗判繧ｺ繝ｬ繧貞屓驕ｿ
- 縲靴ode/Command Trigger縲肴凾縺ｯ陬懷勧菫｡蜿ｷ・・ontrol/Group/Task/CODE_OPTION 遲会ｼ峨ｒ閾ｪ蜍慕函謌・
*/
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:collection/collection.dart';
import '../../models/form/form_state.dart';
import '../../models/chart/chart_data_generator.dart'; // 譁ｰ縺励＞繧ｸ繧ｧ繝阪Ξ繝ｼ繧ｿ繧偵う繝ｳ繝昴・繝・
import '../../models/chart/signal_type.dart'; // SignalType縺ｮ繧､繝ｳ繝昴・繝医ｒ霑ｽ蜉
import '../../models/chart/signal_data.dart'; // SignalData繧ｯ繝ｩ繧ｹ繧偵う繝ｳ繝昴・繝・
import '../../models/chart/io_channel_source.dart'; // IoChannelSource縺ｮ繧､繝ｳ繝昴・繝医ｒ霑ｽ蜉
import '../../models/backup/app_config.dart'; // AppConfig繧偵う繝ｳ繝昴・繝・
import '../../utils/file_utils.dart'; // FileUtils繧偵う繝ｳ繝昴・繝・
import 'input_section.dart';
import 'output_section.dart';
import 'hw_trigger_section.dart';
import '../common/custom_dropdown.dart';
// import '../../common_padding.dart';
// import '../chart/chart_signals.dart'; // 譛ｪ菴ｿ逕ｨ縺ｮ縺溘ａ荳譎ら噪縺ｫ辟｡蜉ｹ蛹・
import '../../providers/form_state_notifier.dart';
import 'package:provider/provider.dart';
import '../../utils/chart_template_engine.dart';
import 'dart:math' as math;
import '../../providers/locale_notifier.dart';
import '../../providers/form_controllers_notifier.dart';

// 繧ｻ繝ｫ縺ｮ繝｢繝ｼ繝峨ｒ陦ｨ縺吝・謖吝梛
enum CellMode { none, mode1, mode2, mode3, mode4, mode5 }

// 陦後Δ繝ｼ繝会ｼ・one / 蜷梧凾蜿冶ｾｼ・・
enum RowMode { none, simultaneous }

const rowModeColors = {
  RowMode.none: Colors.white,
  RowMode.simultaneous: Colors.teal, // 莉ｻ諢上・濶ｲ
};

const rowModeLabels = {RowMode.none: '', RowMode.simultaneous: '蜷梧凾蜿冶ｾｼ'};

const rowModeLabelsEn = {
  RowMode.none: '',
  RowMode.simultaneous: 'Simultaneous',
};

// 繧ｻ繝ｫ繝｢繝ｼ繝峨・濶ｲ縺ｨ繝ｩ繝吶Ν縺ｮ繝槭ャ繝斐Φ繧ｰ
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
  final bool
  showImportExportButtons; // 繧､繝ｳ繝昴・繝・繧ｨ繧ｯ繧ｹ繝昴・繝医・繧ｿ繝ｳ縺ｮ陦ｨ遉ｺ蛻ｶ蠕｡繝輔Λ繧ｰ
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
    required this.onInputPortChanged,
    required this.onOutputPortChanged,
    required this.onHwPortChanged,
    required this.onCameraChanged,
    required this.onUpdateChart,
    required this.onClearFields,
    required this.onTransferInputs,
    required this.onTransferOutputs,
    this.showImportExportButtons = false, // 繝・ヵ繧ｩ繝ｫ繝医・髱櫁｡ｨ遉ｺ
  });

  @override
  State<FormTab> createState() => FormTabState();
}

class FormTabState extends State<FormTab>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  // --- AutomaticKeepAliveClientMixin ---
  // 繧ｿ繝悶ｒ蛻・ｊ譖ｿ縺医※繧ょ・蜉帷憾諷九ｒ菫晄戟縺吶ｋ縺溘ａ縺ｫ true 繧定ｿ斐☆
  @override
  bool get wantKeepAlive => true;

  // 險隱櫁｡ｨ遉ｺ・域律譛ｬ隱・闍ｱ隱橸ｼ峨↓蠢懊§縺ｦ UI 繝ｩ繝吶Ν繧貞・繧頑崛縺医ｋ繝倥Ν繝・
  // LocaleNotifier 縺九ｉ迴ｾ蝨ｨ縺ｮ險隱槭さ繝ｼ繝峨ｒ蜿門ｾ励＠縲・←蛻・↑譁・ｭ怜・繧定ｿ斐☆

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

  // 繝懊ち繝ｳ縺ｮ繧ｹ繧ｿ繧､繝ｫ繧堤ｵｱ荳縺吶ｋ縺溘ａ縺ｮ螳壽焚
  static const double _buttonHeight = 48.0;
  static const double _buttonHorizontalPadding = 16.0;
  static const double _buttonVerticalPadding = 12.0;

  // --- 繝・・繝悶Ν逕ｨ縺ｮ迥ｶ諷・---
  // 蛻晄悄陦梧焚
  int _rowCount = 6;

  // 繝・・繝悶Ν繝・・繧ｿ繧剃ｿ晄戟縺吶ｋ2谺｡蜈・・蛻暦ｼ亥・譛溷､縺ｯ縺吶∋縺ｦnone・・
  List<List<CellMode>> _tableData = [];

  // SignalData縺ｮ繝ｪ繧ｹ繝医ｒ菫晄戟
  List<SignalData> _signalDataList = [];
  Map<String, List<int>> _portValues = {};

  // 螳滄圀縺ｮ繝√Ε繝ｼ繝医ョ繝ｼ繧ｿ繧剃ｿ晄戟・域峩譁ｰ譎ゅ↓菫晏ｭ假ｼ・
  List<List<int>> _actualChartData = [];

  // --- 陦後Δ繝ｼ繝・---
  // 蜷・｡後↓蟇ｾ縺励※繧ｻ繝ｫ縺ｨ縺ｯ迢ｬ遶九↓險ｭ螳壹〒縺阪ｋ繝｢繝ｼ繝峨ｒ菫晄戟・・one / 蜷梧凾蜿冶ｾｼ・・
  List<RowMode> _rowModes = [];

  // === 霑ｽ蜉: 蛻励Δ繝ｼ繝・===
  // 蜷・き繝｡繝ｩ蛻励↓蟇ｾ縺吶ｋ CellMode 繧剃ｿ晄戟・亥・荳諡ｬ螟画峩逕ｨ・・
  List<CellMode> _columnModes = [];

  // 菫｡蜿ｷ縺ｮ陦ｨ遉ｺ/髱櫁｡ｨ遉ｺ迥ｶ諷九ｒ邂｡逅・☆繧九Μ繧ｹ繝・(莉･蜑阪・繝ｪ繧ｹ繝医・莠呈鋤諤ｧ縺ｮ縺溘ａ縺ｫ谿九＠縺ｦ縺翫￥)
  List<bool> _inputVisibility = [];
  List<bool> _outputVisibility = [];
  List<bool> _hwTriggerVisibility = [];

  // Provider 縺九ｉ繝輔か繝ｼ繝迥ｶ諷九ｒ蜿門ｾ励☆繧九ご繝・ち繝ｼ
  TimingFormState get formState => context.read<FormStateNotifier>().state;

  bool _initializedWithProvider = false;

  // 蜑榊屓蜿門ｾ励＠縺溷推繧ｫ繧ｦ繝ｳ繝医ｒ菫晄戟縺励∝､牙喧繧呈､懃衍縺吶ｋ
  int _prevInputCount = -1;
  int _prevOutputCount = -1;
  int _prevHwPort = -1;
  int _prevCamera = -1;

  // PLC / EIP 繧ｪ繝励す繝ｧ繝ｳ
  String _plcEipOption = 'None';
  Map<String, List<int>> _externalSignalValues = {};

  // 蜃ｺ蜉帶ｬ・・繧ｵ繝悶ち繝厄ｼ・IO / PLC-EIP・・
  TabController? _outputTabController;
  int _outputTabIndex = 0;
  // 蜈･蜉帶ｬ・・繧ｵ繝悶ち繝厄ｼ・IO / PLC-EIP・・
  TabController? _inputTabController;
  int _inputTabIndex = 0;

  // 螟夜Κ縺九ｉ PLC/EIP 繧貞渚譏縺吶ｋ縺溘ａ縺ｮ繧ｻ繝・ち繝ｼ
  void setPlcEipOption(String value) {
    if (value != 'None' && value != 'PLC' && value != 'EIP') return;
    setState(() {
      _plcEipOption = value;
    });
    _ensureOutputTabController();
    _ensureInputTabController();
  }

  void _ensureOutputTabController() {
    if (_plcEipOption == 'None') {
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
        // 繧ｿ繝門・譖ｿ譎ゅ↓邱ｨ髮・ｸｭ縺ｮ繝輔ぅ繝ｼ繝ｫ繝峨′縺ゅｌ縺ｰ遒ｺ螳壹＆縺帙ｋ
        if (mounted) {
          FocusScope.of(context).unfocus();
        }
        setState(() {
          _outputTabIndex = _outputTabController!.index;
        });
      });
    }
  }

  void _ensureInputTabController() {
    if (_plcEipOption == 'None') {
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

  void refreshSignalDataList() {
    _updateSignalDataList();
  }

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

  // TriggerOption 縺ｫ蝓ｺ縺･縺・Input 繝・く繧ｹ繝医ヵ繧｣繝ｼ繝ｫ繝牙錐繧定・蜍戊ｨｭ螳・
  // Template 縺ｨ蜷後§隕丞援・・ode Trigger 譎ゅ・縺ｿ驕ｩ逕ｨ・・
  void applyInputNamesForTriggerOption() {
    final fs = formState;
    // Single Trigger: Input1 縺ｫ TRIGGER
    if (fs.triggerOption == 'Single Trigger') {
      if (widget.inputControllers.isNotEmpty) {
        widget.controllersNotifier.setInputText(0, 'TRIGGER');
      }
      return;
    }

    // Code Trigger: 繧ｳ繝ｼ繝牙牡蠖・
    if (fs.triggerOption == 'Code Trigger') {
      _assignCodeTriggerInputNames(fs);
    }
    // 蜷榊燕險ｭ螳壼ｾ後∝ｿ・ｦ√↑繧・SignalData 蜀咲函謌舌・蜻ｼ縺ｳ蜃ｺ縺怜・縺ｧ陦後≧
  }

  void _assignCodeTriggerInputNames(TimingFormState fs) {
    final controllers = widget.inputControllers;
    String? nameForIndex(int index) {
      if (fs.inputCount >= 32) {
        if (index >= 1 && index <= 8) {
          return 'Control Code${index}(bit)';
        }
        if (index >= 9 && index <= 14) {
          return 'Group Code${index}(bit)';
        }
        if (index >= 15 && index <= 20) {
          return 'Task Code${index}(bit)';
        }
      } else if (fs.inputCount == 16) {
        if (index >= 1 && index <= 4) {
          return 'Control Code${index}(bit)';
        }
        if (index >= 5 && index <= 7) {
          return 'Group Code${index}(bit)';
        }
        if (index >= 8 && index <= 13) {
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

  // ===== Output 繝槭ャ繝斐Φ繧ｰ: totalOutputs -> { signalId : index } =====
  static const Map<int, Map<String, int>> _outputPresetMap = {
    // 6 繝昴・繝域ｩ・
    6: {
      'AUTO_MODE': 1,
      'BUSY': 2, // Output1
      'ENABLE_RESULT_SIGNAL': 3, // Output2
      'TOTAL_RESULT_OK': 4, // Output3
      'TOTAL_RESULT_NG': 5, // Output4
    },
    // 16 繝昴・繝域ｩ・
    16: {
      'AUTO_MODE': 1,
      'BUSY': 2, // Output9
      'ENABLE_RESULT_SIGNAL': 6, // Output10
      'TOTAL_RESULT_OK': 9, // Output11
      'TOTAL_RESULT_NG': 10, // Output12
    },
    // 32 繝昴・繝域ｩ・
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

  // 繝励Μ繧ｻ繝・ヨ繝槭ャ繝斐Φ繧ｰ縺九ｉ繧､繝ｳ繝・ャ繧ｯ繧ｹ繧貞叙蠕暦ｼ育┌縺代ｌ縺ｰ -1・・
  int _selectOutputIndex(String signalId, int totalOutputs, int totalCameras) {
    // --- 蜍慕噪蜑ｲ莉・ 32 繝昴・繝域ｩ溘〒 CAM_EXPOSURE / ACQUISITION 繧帝・鄂ｮ ---
    if (totalOutputs == 32) {
      final expReg = RegExp(r'^CAMERA_(\d+)_IMAGE_EXPOSURE');
      final acqReg = RegExp(r'^CAMERA_(\d+)_IMAGE_ACQUISITION');

      RegExpMatch? m = expReg.firstMatch(signalId);
      if (m != null) {
        final cam = int.parse(m.group(1)!);
        if (cam >= 1 && cam <= totalCameras) {
          // Output4(index3) 縺九ｉ鬆・↓驟咲ｽｮ
          return 3 + (cam - 1);
        }
      }

      m = acqReg.firstMatch(signalId);
      if (m != null) {
        final cam = int.parse(m.group(1)!);
        if (cam >= 1 && cam <= totalCameras) {
          // Exposure 縺ｮ蠕後↓邯壹￠縺ｦ驟咲ｽｮ (Acquisition)
          return 3 + totalCameras + (cam - 1);
        }
      }

      // ---- TOTAL_RESULT_OK 繧・Acquisition 鄒､縺ｮ 2 縺､蠕後↓驟咲ｽｮ ----
      if (signalId == 'TOTAL_RESULT_OK') {
        // 譛蠕後・ Acquisition 繧､繝ｳ繝・ャ繧ｯ繧ｹ = 3 + totalCameras*2 - 1
        // 縺昴％縺九ｉ 2 縺､蠕・( +2 )
        return 3 + totalCameras * 2 + 1;
      }
      if (signalId == 'TOTAL_RESULT_NG') {
        // 譛蠕後・ Acquisition 繧､繝ｳ繝・ャ繧ｯ繧ｹ = 3 + totalCameras*2 - 1
        // 縺昴％縺九ｉ 2 縺､蠕・( +2 )
        return 3 + totalCameras * 2 + 2;
      }
    }

    // 髱咏噪繝励Μ繧ｻ繝・ヨ
    final preset = _outputPresetMap[totalOutputs];
    if (preset == null) return -1;
    return preset[signalId] ?? -1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final fs = formState;

    // 蛻晏屓蛻晄悄蛹・
    if (!_initializedWithProvider) {
      _initializeTableData();
      _initializeSignalVisibility();
      _initializeSignalDataList();
      _initializedWithProvider = true;
    }

    // 繧ｫ繝｡繝ｩ謨ｰ縺悟､峨ｏ縺｣縺溷ｴ蜷医・繝・・繝悶Ν蜀榊・譛溷喧
    if (_prevCamera != -1 && _prevCamera != fs.camera) {
      _initializeTableData();

      // HW Port 縺・0 縺ｾ縺溘・繧ｫ繝｡繝ｩ謨ｰ莉･螟悶・蝣ｴ蜷医・縲∬・蜍慕噪縺ｫ繧ｫ繝｡繝ｩ謨ｰ縺ｸ譖ｴ譁ｰ
      if (fs.hwPort != 0 && fs.hwPort != fs.camera) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          widget.onHwPortChanged(fs.camera);
        });
      }
    }

    // 蜈･蜃ｺ蜉・HWTrigger 縺ｮ謨ｰ縺悟､峨ｏ縺｣縺溷ｴ蜷医↓ Visibility 繝ｪ繧ｹ繝医ｒ譖ｴ譁ｰ
    if (_prevInputCount != -1 && _prevInputCount != fs.inputCount) {
      _updateVisibilityList(_inputVisibility, fs.inputCount);
    }
    if (_prevOutputCount != -1 && _prevOutputCount != fs.outputCount) {
      _updateVisibilityList(_outputVisibility, fs.outputCount);
    }
    if (_prevHwPort != -1 && _prevHwPort != fs.hwPort) {
      _updateVisibilityList(_hwTriggerVisibility, fs.hwPort);
    }

    // 蠢・ｦ√〒縺ゅｌ縺ｰ SignalData 繧貞・逕滓・
    if (_prevInputCount != fs.inputCount ||
        _prevOutputCount != fs.outputCount ||
        _prevHwPort != fs.hwPort ||
        _prevCamera != fs.camera) {
      _initializeSignalDataList();
    }

    // IO 繝昴・繝・= 6 縺ｮ縺ｨ縺阪・ Code Trigger 繧貞ｼｷ蛻ｶ逧・↓ Single Trigger 縺ｸ螟画峩
    if (fs.inputCount == 6 && fs.triggerOption == 'Code Trigger') {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        widget.onTriggerOptionChanged('Single Trigger');
      });
    }

    // 迴ｾ蝨ｨ蛟､繧剃ｿ晏ｭ・
    _prevInputCount = fs.inputCount;
    _prevOutputCount = fs.outputCount;
    _prevHwPort = fs.hwPort;
    _prevCamera = fs.camera;
  }

  // SignalData繝ｪ繧ｹ繝医ｒ蛻晄悄蛹・
  void _initializeSignalDataList() {
    final formState = context.read<FormStateNotifier>().state;
    _signalDataList = [];

    // 蜈･蜉帑ｿ｡蜿ｷ
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
          values: List.filled(32, 0),
          isVisible: isVisible,
        ),
      );
    }

    // HW繝医Μ繧ｬ繝ｼ菫｡蜿ｷ (Input 縺ｮ谺｡縺ｫ霑ｽ蜉)
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

    // 蜃ｺ蜉帑ｿ｡蜿ｷ (譛蠕後↓霑ｽ蜉)
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

    // PLC/EIP 蜃ｺ蜉帑ｿ｡蜿ｷ・域怙蠕後↓霑ｽ蜉・・
    if (_plcEipOption != 'None') {
      for (int i = 0; i < formState.outputCount; i++) {
        if (i < widget.plcEipOutputControllers.length &&
            widget.plcEipOutputControllers[i].text.isNotEmpty) {
          final base = _plcEipOption == 'PLC' ? 'PLO${i + 1}' : 'ESO${i + 1}';
          final user = widget.plcEipOutputControllers[i].text;
          final label = '$base: $user';
          _signalDataList.add(
            SignalData(
              name: label,
              signalType: SignalType.output,
              values: List.filled(32, 0),
              isVisible:
                  i < _outputVisibility.length ? _outputVisibility[i] : true,
            ),
          );
        }
      }
    }

    // === CODE_OPTION 霑ｽ蜉 (Code Trigger 繝｢繝ｼ繝牙ｰら畑) ===
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

    // === Command Option 霑ｽ蜉 (Command Trigger 繝｢繝ｼ繝牙ｰら畑) ===
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

  // 菫｡蜿ｷ縺ｮ陦ｨ遉ｺ/髱櫁｡ｨ遉ｺ迥ｶ諷九ｒ蛻晄悄蛹・
  void _initializeSignalVisibility() {
    setState(() {
      _inputVisibility = List.generate(formState.inputCount, (_) => true);
      _outputVisibility = List.generate(formState.outputCount, (_) => true);
      _hwTriggerVisibility = List.generate(formState.hwPort, (_) => true);
    });
  }

  // 陦ｨ遉ｺ/髱櫁｡ｨ遉ｺ繝ｪ繧ｹ繝医ｒ譖ｴ譁ｰ
  void _updateVisibilityList(List<bool> list, int newCount) {
    setState(() {
      if (list.length < newCount) {
        // 蠅怜刈縺励◆蝣ｴ蜷医∵眠縺励＞隕∫ｴ繧稚rue縺ｧ霑ｽ蜉
        list.addAll(List.generate(newCount - list.length, (_) => true));
      } else if (list.length > newCount) {
        // 貂帛ｰ代＠縺溷ｴ蜷医∽ｽ吝・縺ｪ隕∫ｴ繧貞炎髯､
        list.removeRange(newCount, list.length);
      }
    });
  }

  // 繝・・繝悶Ν繝・・繧ｿ縺ｮ蛻晄悄蛹・
  void _initializeTableData() {
    // 螳牙・繝√ぉ繝・け・医き繝｡繝ｩ謨ｰ縺・縺ｮ蝣ｴ蜷医↓蛯吶∴繧具ｼ・
    final cameraCount = formState.camera > 0 ? formState.camera : 1;

    setState(() {
      _tableData = List.generate(
        _rowCount,
        (_) => List.generate(cameraCount, (_) => CellMode.none),
      );

      // 陦後Δ繝ｼ繝峨ｂ蜷梧凾縺ｫ蛻晄悄蛹・
      _rowModes = List.generate(_rowCount, (_) => RowMode.none);

      // === 霑ｽ蜉: 蛻励Δ繝ｼ繝峨ｂ蛻晄悄蛹・===
      _columnModes = List.generate(cameraCount, (_) => CellMode.none);
    });
  }

  // 陦後ｒ霑ｽ蜉
  void _addRow() {
    setState(() {
      _tableData.add(List.generate(formState.camera, (_) => CellMode.none));
      _rowCount++;

      // 陦後Δ繝ｼ繝峨Μ繧ｹ繝医↓繧りｿｽ蜉
      _rowModes.add(RowMode.none);
    });
  }

  // 陦後ｒ蜑企勁
  void _removeRow() {
    if (_rowCount > 1) {
      setState(() {
        _tableData.removeLast();
        _rowCount--;

        // 陦後Δ繝ｼ繝峨Μ繧ｹ繝医ｂ蜷梧悄
        _rowModes.removeLast();
      });
    }
  }

  // 繧ｻ繝ｫ縺ｮ蛟､繧貞､画峩
  void _changeCellMode(int row, int col, CellMode newMode) {
    setState(() {
      _tableData[row][col] = newMode;
    });
  }

  // === 霑ｽ蜉: 蛻励Δ繝ｼ繝峨ｒ荳諡ｬ螟画峩 ===
  void _changeColumnMode(int col, CellMode newMode) {
    setState(() {
      for (int row = 0; row < _tableData.length; row++) {
        _tableData[row][col] = newMode;
      }
      // 驕ｸ謚樒憾諷九ｒ菫晏ｭ倥＠縺ｦ繝倥ャ繝繝ｼ縺ｮ濶ｲ陦ｨ遉ｺ縺ｫ蛻ｩ逕ｨ
      if (col < _columnModes.length) {
        _columnModes[col] = newMode;
      }
    });
  }

  // 陦後Δ繝ｼ繝峨ｒ螟画峩
  void _changeRowMode(int row) {
    setState(() {
      final current = _rowModes[row];
      _rowModes[row] =
          current == RowMode.none ? RowMode.simultaneous : RowMode.none;
    });
  }

  // 菫｡蜿ｷ縺ｮ陦ｨ遉ｺ/髱櫁｡ｨ遉ｺ繧貞・繧頑崛縺・
  void _toggleSignalVisibility(int index, SignalType type) {
    setState(() {
      // 1. 繝√ぉ繝・け繝懊ャ繧ｯ繧ｹ縺ｮ迥ｶ諷九ｒ譖ｴ譁ｰ
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

      // 2. SignalData 蛛ｴ繧貞錐蜑阪・繝ｼ繧ｹ縺ｧ譖ｴ譁ｰ・井ｽ咲ｽｮ繧ｺ繝ｬ蟇ｾ遲厄ｼ・
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

  // 繝・・繝悶Ν繝・・繧ｿ繧偵け繝ｪ繧｢縺吶ｋ繝｡繧ｽ繝・ラ
  void _clearTableData() {
    setState(() {
      // 蜈ｨ縺ｦ縺ｮ繧ｻ繝ｫ繧地one縺ｫ險ｭ螳・
      for (int row = 0; row < _tableData.length; row++) {
        for (int col = 0; col < _tableData[row].length; col++) {
          _tableData[row][col] = CellMode.none;
        }
      }

      // 陦後Δ繝ｼ繝峨ｂ繝ｪ繧ｻ繝・ヨ
      for (int i = 0; i < _rowModes.length; i++) {
        _rowModes[i] = RowMode.none;
      }
    });
  }

  // 繧､繝ｳ繝昴・繝亥燕縺ｫ Clear 逶ｸ蠖薙・蜃ｦ逅・ｒ螟夜Κ縺九ｉ螳溯｡後☆繧九◆繧√・蜈ｬ髢九Γ繧ｽ繝・ラ
  void clearAllForImport() {
    _clearTableData();
    widget.onClearFields();
  }

  // SignalData繝ｪ繧ｹ繝医ｒ譖ｴ譁ｰ縺励∽ｽ咲ｽｮ諠・ｱ繧剃ｿ晄戟縺吶ｋ
  void _updateSignalDataList() {
    final Map<String, List<int>> prevPortValues = {
      for (final entry in _portValues.entries)
        entry.key: List<int>.from(entry.value),
    };

    setState(() {
      final Map<String, List<int>> prevValueMap = {
        for (final sig in _signalDataList) sig.name: List<int>.from(sig.values),
      };
      if (_externalSignalValues.isNotEmpty) {
        for (final entry in _externalSignalValues.entries) {
          prevValueMap[entry.key] = List<int>.from(entry.value);
        }
        _externalSignalValues.clear();
      }
      // Use the longest known waveform length so new signals stay aligned.
      int defaultWaveLength = 0;
      for (final values in prevValueMap.values) {
        defaultWaveLength = math.max(defaultWaveLength, values.length);
      }
      for (final values in prevPortValues.values) {
        defaultWaveLength = math.max(defaultWaveLength, values.length);
      }
      if (defaultWaveLength == 0) {
        defaultWaveLength = 32;
      }

      final List<String> prevOrder =
          _signalDataList.map((s) => s.name).toList();

      _signalDataList = [];

      final Map<int, SignalData> inputSignalMap = {};
      final Map<int, SignalData> outputSignalMap = {};
      final Map<int, SignalData> hwTriggerSignalMap = {};
      final Map<String, List<int>> newPortValues = {};

      List<int> resolveValues({
        required String primaryKey,
        String? alternateKey,
        required String name,
        List<String> additionalNames = const [],
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
        final MapEntry<String, List<int>>? normalizedEntry = prevValueMap
            .entries
            .firstWhereOrNull(
              (entry) => _normalizeSignalName(entry.key) == normalized,
            );
        if (normalizedEntry != null) {
          return List<int>.from(normalizedEntry.value);
        }

        for (final fallbackName in additionalNames) {
          if (fallbackName.isEmpty) continue;
          final String fallbackNormalized = _normalizeSignalName(fallbackName);
          final MapEntry<String, List<int>>? fallbackEntry = prevValueMap
              .entries
              .firstWhereOrNull(
                (entry) =>
                    _normalizeSignalName(entry.key) == fallbackNormalized,
              );
          if (fallbackEntry != null) {
            return List<int>.from(fallbackEntry.value);
          }
        }

        return List.filled(defaultWaveLength, 0);
      }

      String dioInputKey(int index) => 'dio-input:$index';
      String plcInputKey(int index) => 'plc-input:$index';
      String hwKey(int index) => 'hw:$index';
      String dioOutputKey(int index) => 'dio-output:$index';
      String plcOutputKey(int index) => 'plc-output:$index';

      List<String> inputFallbackNames(int index) => <String>[
        'Input${index + 1}',
        'Input ${index + 1}',
        'PLI${index + 1}',
        'ESI${index + 1}',
      ];

      List<String> outputFallbackNames(int index) => <String>[
        'Output${index + 1}',
        'Output ${index + 1}',
        'PLO${index + 1}',
        'ESO${index + 1}',
      ];

      for (int i = 0; i < formState.inputCount; i++) {
        if (i < widget.inputControllers.length &&
            widget.inputControllers[i].text.isNotEmpty) {
          SignalType signalType = SignalType.input;
          bool isVisible =
              i < _inputVisibility.length ? _inputVisibility[i] : true;

          if (formState.triggerOption == 'Code Trigger') {
            if (formState.inputCount >= 32) {
              if (i >= 1 && i <= 8) {
                signalType = SignalType.control;
                isVisible = false;
                widget.controllersNotifier.setInputText(
                  i,
                  'Control Code${i}(bit)',
                );
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
                widget.controllersNotifier.setInputText(
                  i,
                  'Control Code${i}(bit)',
                );
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
          final List<int> values = resolveValues(
            primaryKey: dioInputKey(i),
            alternateKey: plcInputKey(i),
            name: name,
            additionalNames: inputFallbackNames(i),
          );

          inputSignalMap[i] = SignalData(
            name: name,
            signalType: signalType,
            values: values,
            isVisible: isVisible,
          );
          newPortValues[dioInputKey(i)] = List<int>.from(values);
        }
      }

      if (_plcEipOption != 'None') {
        for (int i = 0; i < formState.inputCount; i++) {
          if (i < widget.plcEipInputControllers.length &&
              widget.plcEipInputControllers[i].text.isNotEmpty) {
            final String name = widget.plcEipInputControllers[i].text;
            final int key = formState.inputCount + i;
            final List<int> values = resolveValues(
              primaryKey: plcInputKey(i),
              alternateKey: dioInputKey(i),
              name: name,
              additionalNames: inputFallbackNames(i),
            );
            inputSignalMap[key] = SignalData(
              name: name,
              signalType: SignalType.input,
              values: values,
              isVisible:
                  i < _inputVisibility.length ? _inputVisibility[i] : true,
            );
            newPortValues[plcInputKey(i)] = List<int>.from(values);
          }
        }
      }

      for (int i = 0; i < formState.hwPort; i++) {
        if (widget.hwTriggerControllers[i].text.isNotEmpty) {
          final String name = widget.hwTriggerControllers[i].text;
          final List<int> values = resolveValues(
            primaryKey: hwKey(i),
            name: name,
          );
          hwTriggerSignalMap[i] = SignalData(
            name: name,
            signalType: SignalType.hwTrigger,
            values: values,
            isVisible:
                i < _hwTriggerVisibility.length
                    ? _hwTriggerVisibility[i]
                    : true,
          );
          newPortValues[hwKey(i)] = List<int>.from(values);
        }
      }

      for (int i = 0; i < formState.outputCount; i++) {
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

          final List<int> values = resolveValues(
            primaryKey: dioOutputKey(i),
            alternateKey: plcOutputKey(i),
            name: displayName,
            additionalNames: outputFallbackNames(i),
          );

          outputSignalMap[i] = SignalData(
            name: displayName,
            signalType: SignalType.output,
            values: values,
            isVisible:
                i < _outputVisibility.length ? _outputVisibility[i] : true,
          );
          newPortValues[dioOutputKey(i)] = List<int>.from(values);
        }
      }

      if (_plcEipOption != 'None') {
        for (int i = 0; i < formState.outputCount; i++) {
          if (i < widget.plcEipOutputControllers.length &&
              widget.plcEipOutputControllers[i].text.isNotEmpty) {
            final String prefix = _plcEipOption == 'PLC' ? 'PLO' : 'ESO';
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

            final int key = formState.outputCount + i;
            final String fallbackBase = 'Output ${i + 1}';
            final List<String> additionalNames =
                <String>[
                      user,
                      base,
                      'Output${i + 1}',
                      fallbackBase,
                      ...outputFallbackNames(i),
                    ]
                    .where((element) => element.trim().isNotEmpty)
                    .toSet()
                    .toList();

            final List<int> values = resolveValues(
              primaryKey: plcOutputKey(i),
              alternateKey: dioOutputKey(i),
              name: label,
              additionalNames: additionalNames,
            );

            outputSignalMap[key] = SignalData(
              name: label,
              signalType: SignalType.output,
              values: values,
              isVisible:
                  i < _outputVisibility.length ? _outputVisibility[i] : true,
            );
            newPortValues[plcOutputKey(i)] = List<int>.from(values);
          }
        }
      }

      generateTimingChartDataWithPositions(
        inputSignalMap,
        outputSignalMap,
        hwTriggerSignalMap,
        timeLength: defaultWaveLength,
      );

      for (int i = 0; i < formState.inputCount; i++) {
        if (inputSignalMap.containsKey(i)) {
          _signalDataList.add(inputSignalMap[i]!);
        }
      }
      if (_plcEipOption != 'None') {
        for (int i = 0; i < formState.inputCount; i++) {
          final int key = formState.inputCount + i;
          if (inputSignalMap.containsKey(key)) {
            _signalDataList.add(inputSignalMap[key]!);
          }
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

      final List<int> extraOutputKeys =
          outputSignalMap.keys.where((k) => k >= formState.outputCount).toList()
            ..sort();
      for (final int k in extraOutputKeys) {
        _signalDataList.add(outputSignalMap[k]!);
      }

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

  // 繧ｫ繝｡繝ｩ繝・・繝悶Ν縺ｮ諠・ｱ縺ｫ蝓ｺ縺･縺・※譎らｳｻ蛻励ョ繝ｼ繧ｿ繧堤函謌・
  List<List<int>> generateTimingChartData({int timeLength = 32}) {
    final chartData = ChartDataGenerator.generateTimingChart(
      formState: formState,
      inputControllers: widget.inputControllers,
      outputControllers: widget.outputControllers,
      hwTriggerControllers: widget.hwTriggerControllers,
      tableData: _tableData,
      timeLength: timeLength,
    );

    // 繝・ヰ繝・げ蜃ｺ蜉・
    debugPrint('ChartDataGenerator.generateTimingChart 縺ｮ邨先棡:');
    debugPrint('  霑泌唆縺輔ｌ縺溘ョ繝ｼ繧ｿ陦梧焚: ${chartData.length}');
    if (chartData.isNotEmpty) {
      debugPrint('  譛蛻昴・陦後・繝・・繧ｿ萓・ ${chartData[0]}');
      debugPrint('  譛蛻昴・菫｡蜿ｷ蜷・ ${_signalDataList.firstOrNull?.name ?? 'N/A'}');
    }

    return chartData;
  }

  // 菴咲ｽｮ諠・ｱ繧剃ｿ晄戟縺励※繝√Ε繝ｼ繝医ョ繝ｼ繧ｿ繧堤函謌・
  List<List<int>> generateTimingChartDataWithPositions(
    Map<int, SignalData> inputSignalMap,
    Map<int, SignalData> outputSignalMap,
    Map<int, SignalData> hwTriggerSignalMap, {
    int timeLength = 32,
  }) {
    List<List<int>> chartData = [];

    // Input菫｡蜿ｷ縺ｮ繝・・繧ｿ繧剃ｽ咲ｽｮ鬆・↓霑ｽ蜉
    for (int i = 0; i < formState.inputCount; i++) {
      if (inputSignalMap.containsKey(i)) {
        chartData.add(List.filled(timeLength, 0));
      }
    }

    // HWTrigger菫｡蜿ｷ縺ｮ繝・・繧ｿ繧剃ｽ咲ｽｮ鬆・↓霑ｽ蜉
    for (int i = 0; i < formState.hwPort; i++) {
      if (hwTriggerSignalMap.containsKey(i)) {
        chartData.add(List.filled(timeLength, 0));
      }
    }

    // Output菫｡蜿ｷ縺ｮ繝・・繧ｿ繧剃ｽ咲ｽｮ鬆・↓霑ｽ蜉・域僑蠑ｵ繧ｭ繝ｼ繧ょ性繧√※繧ｽ繝ｼ繝茨ｼ・
    final outputKeys = outputSignalMap.keys.toList()..sort();
    for (int i = 0; i < outputKeys.length; i++) {
      chartData.add(List.filled(timeLength, 0));
    }

    return chartData;
  }

  // SignalData繝ｪ繧ｹ繝医°繧芽｡ｨ遉ｺ逕ｨ縺ｮ菫｡蜿ｷ蜷阪Μ繧ｹ繝医ｒ逕滓・
  List<String> generateSignalNames() {
    List<String> names = [];
    for (var signal in _signalDataList) {
      if (signal.isVisible) {
        names.add(signal.name);
      }
    }
    return names;
  }

  // SignalData繝ｪ繧ｹ繝医°繧芽｡ｨ遉ｺ逕ｨ縺ｮ菫｡蜿ｷ繧ｿ繧､繝励Μ繧ｹ繝医ｒ逕滓・
  List<SignalType> generateSignalTypes() {
    List<SignalType> types = [];
    for (var signal in _signalDataList) {
      if (signal.isVisible) {
        types.add(signal.signalType);
      }
    }
    return types;
  }

  // 繝√Ε繝ｼ繝域峩譁ｰ譎ゅ・陦ｨ遉ｺ/髱櫁｡ｨ遉ｺ蟇ｾ蠢懊・繝・・繧ｿ繧堤函謌・
  List<List<int>> generateFilteredChartData() {
    List<List<int>> filteredData = [];
    for (var signal in _signalDataList) {
      if (signal.isVisible) {
        filteredData.add(List<int>.from(signal.values));
      }
    }
    return filteredData;
  }

  // SignalData繝ｪ繧ｹ繝医°繧牙・繝昴・繝育分蜿ｷ繝ｪ繧ｹ繝医ｒ逕滓・ (Input/Output/HWTrigger 縺ｮ繧､繝ｳ繝・ャ繧ｯ繧ｹ+1)
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
            // PLC/EIP蜈･蜉帙さ繝ｳ繝医Ο繝ｼ繝ｩ縺ｧ繧よ爾縺・
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
          // PLC/EIP 蜃ｺ蜉幢ｼ医Λ繝吶Ν蠖｢蠑・PLO{i} / ESO{i} 繧偵・繝ｼ繝育分蜿ｷ縺ｫ螟画鋤・・
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

  // SignalData繝ｪ繧ｹ繝医°繧迂oChannelSource繝ｪ繧ｹ繝医ｒ逕滓・
  List<IoChannelSource> generateIoChannelSources() {
    List<IoChannelSource> sources = [];

    for (var signal in _signalDataList) {
      if (!signal.isVisible) continue;

      switch (signal.signalType) {
        case SignalType.input:
          // DIO蜈･蜉帙°PLC/EIP蜈･蜉帙°繧貞愛螳・
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
          // DIO蜃ｺ蜉帙°PLC/EIP蜃ｺ蜉帙°繧貞愛螳・
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

  // 譖ｴ譁ｰ繝懊ち繝ｳ繧ｯ繝ｪ繝・け譎ゅ・蜃ｦ逅・
  Future<void> _onUpdateChart() async {
    _updateSignalDataList();

    // 繝√Ε繝ｼ繝医ョ繝ｼ繧ｿ繧堤函謌・
    List<String> names = generateSignalNames();
    final chartData = generateFilteredChartData();
    List<SignalType> types = generateSignalTypes();
    List<int> ports = generatePortNumbers();

    // === CODE_OPTION 豕｢蠖｢逕滓・ ===
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
        // 蜈磯ｭ縺ｫ霑ｽ蜉縺励※ 1逡ｪ逶ｮ縺ｮ陦後↓陦ｨ遉ｺ縺吶ｋ
        names.insert(0, 'CODE_OPTION');
        types.insert(0, SignalType.input);
        ports.insert(0, 0);
        chartData.insert(0, codeWave);
      }

      // BUSY/TRIGGER/EXPOSURE 隱ｿ謨ｴ・亥・騾壹Ν繝ｼ繝ｫ・・
      _applyOptionPostRules(names, chartData, types, ports, 'CODE_OPTION');
    }

    // === Command Option 豕｢蠖｢逕滓・ ===
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
        // 蜈磯ｭ縺ｫ霑ｽ蜉縺励※ 1逡ｪ逶ｮ縺ｮ陦後↓陦ｨ遉ｺ縺吶ｋ
        names.insert(0, 'Command Option');
        types.insert(0, SignalType.input);
        ports.insert(0, 0);
        chartData.insert(0, cmdWave);
      }

      // BUSY/TRIGGER/EXPOSURE 隱ｿ謨ｴ・亥・騾壹Ν繝ｼ繝ｫ・・
      _applyOptionPostRules(names, chartData, types, ports, 'Command Option');
    }

    // === 蜿ｯ隕也憾諷九〒譛邨ゅヵ繧｣繝ｫ繧ｿ ===
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

    // 信号データの更新
    _actualChartData = List.from(outChartData);

    // 信号データの確認
    debugPrint('信号データの確認:');
    debugPrint('  信号名: $names');
    debugPrint('  信号タイプ: $types');
    debugPrint('  信号データの数: ${chartData.length}');
    if (chartData.isNotEmpty) {
      debugPrint('  信号データ: ${chartData[0]}');
      debugPrint('  信号データ: ${chartData[0].firstOrNull ?? 'N/A'}');
    }

    // 信号データの更新
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
  Future<void> _onTemplatePressed() async {
    // 信号データの更新
    // 信号データの更新
    // 信号データの更新
    // 32 信号データの更新

    // ---------- Exposure 信号データの更新 ----------
    const int minGap = 4;
    int currentTime = 6;

    // exposureTimes[camIndex] = List<timeIndex>
    Map<int, List<int>> exposureTimes = {
      for (int c = 1; c <= formState.camera; c++) c: [],
    };

    // 信号データの更新
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
          // rowMode.none 陦後・繧ｫ繝｡繝ｩ縺斐→縺ｫ鬆・ｬ｡蜃ｦ逅・(蠕捺擂騾壹ｊ)
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
      // --- 蜷梧凾蜿冶ｾｼ縺檎┌縺・ｴ蜷・ 繧ｫ繝｡繝ｩ1縺ｮ蜈ｨ蜿冶ｾｼ 竊・繧ｫ繝｡繝ｩ2 竊・... 縺ｮ鬆・↓蜃ｦ逅・---
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

    // ---------- 蠢・ｦ√し繝ｳ繝励Ν髟ｷ繧定ｨ育ｮ・----------
    int maxTimeIndex = exposureTimes.values
        .expand((list) => list)
        .fold<int>(0, (prev, element) => math.max(prev, element));

    // 譛蠕後・Exposure縺九ｉ蜷・ｨｮ豢ｾ逕滉ｿ｡蜿ｷ・・cquisition, BUSY, RESULT遲会ｼ峨′逕滓・縺輔ｌ繧九％縺ｨ繧定・・縺・
    // 螳牙・蛛ｴ縺ｫ +32 繧ｹ繝・ャ繝励・繝舌ャ繝輔ぃ繧堤｢ｺ菫昴☆繧九・
    int requiredSampleLength = math.max(32, maxTimeIndex + 32);

    // ChartTemplateEngine 繧貞虚逧・し繝ｳ繝励Ν髟ｷ縺ｧ逕滓・
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

    // --- Camera Configuration Table 縺九ｉ Mode 譛臥┌繧貞愛螳・---
    bool hasContactInputMode = false; // Mode2
    bool hasHwTriggerMode = false; // Mode3
    for (int r = 0; r < _tableData.length; r++) {
      for (int c = 0; c < _tableData[r].length; c++) {
        if (_tableData[r][c] == CellMode.mode2) hasContactInputMode = true;
        if (_tableData[r][c] == CellMode.mode3) hasHwTriggerMode = true;
      }
    }

    // --- Mode 縺檎┌縺・ｴ蜷医・荳崎ｦ√↑菫｡蜿ｷ繧帝勁螟・---
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

    // 逕滓・縺輔ｌ縺滉ｿ｡蜿ｷ繧偵ヵ繧ｩ繝ｼ繝縺ｮ繝・く繧ｹ繝医ヵ繧｣繝ｼ繝ｫ繝峨♀繧医・蜀・Κ迥ｶ諷九∈蜿肴丐
    updateSignalDataFromChartData(
      filteredSignals.map((e) => e.values).toList(),
      filteredSignals.map((e) => e.name).toList(),
      filteredSignals.map((e) => e.signalType).toList(),
    );

    // 繝√Ε繝ｼ繝医ｒ譖ｴ譁ｰ (ID竊偵Λ繝吶Ν螟画鋤)
    final List<String> names = filteredSignals.map((e) => e.name).toList();
    final values = filteredSignals.map((e) => e.values).toList();
    final types = filteredSignals.map((e) => e.signalType).toList();

    // Port逡ｪ蜿ｷ繝ｪ繧ｹ繝医ｒ縺薙％縺ｧ蛻晄悄蛹・(蠕後〒蜀崎ｨ育ｮ励〒荳頑嶌縺・
    List<int> ports = [];

    // === CODE_OPTION 豕｢蠖｢逕滓・ (Template) ===
    if (formState.triggerOption == 'Code Trigger') {
      final autoIdx = names.indexOf('AUTO_MODE');
      int waveLength = values.isNotEmpty ? values[0].length : 32;

      List<int> codeWave = List<int>.filled(waveLength, 0);

      if (autoIdx != -1) {
        final autoWave = values[autoIdx];
        codeWave = _generateCodeOptionWave(autoWave, waveLength);
      }

      // 蜈磯ｭ縺ｫ霑ｽ蜉
      names.insert(0, 'CODE_OPTION');
      types.insert(0, SignalType.input);
      values.insert(0, codeWave);

      // BUSY/TRIGGER/EXPOSURE 隱ｿ謨ｴ
      _applyOptionPostRules(names, values, types, ports, 'CODE_OPTION');
    }

    // === Command Option 豕｢蠖｢逕滓・ (Template) ===
    if (formState.triggerOption == 'Command Trigger') {
      final autoIdx = names.indexOf('AUTO_MODE');
      int waveLength = values.isNotEmpty ? values[0].length : 32;

      List<int> commandWave = List<int>.filled(waveLength, 0);

      if (autoIdx != -1) {
        final autoWave = values[autoIdx];
        // Code Trigger 縺ｨ蜷梧ｧ倥・豕｢蠖｢逕滓・繧帝←逕ｨ
        commandWave = _generateCodeOptionWave(autoWave, waveLength);
      }

      // 蜈磯ｭ縺ｫ霑ｽ蜉・井ｻｮ諠ｳ逧・↓ Input0 縺ｨ縺励※謇ｱ縺・ｼ・
      names.insert(0, 'Command Option');
      types.insert(0, SignalType.input);
      values.insert(0, commandWave);

      // BUSY/TRIGGER/EXPOSURE 隱ｿ謨ｴ・・ode Trigger 縺ｨ蜷梧ｧ假ｼ・
      _applyOptionPostRules(names, values, types, ports, 'Command Option');
    }

    // === 霑ｽ蜉: 繝昴・繝育分蜿ｷ繝ｪ繧ｹ繝医ｒ CODE_OPTION 繧貞性繧蠖｢縺ｧ蜀咲函謌・===
    // updateSignalDataFromChartData 縺ｮ譎らせ縺ｧ縺ｯ CODE_OPTION 繧貞性縺ｾ縺ｪ縺・
    // _signalDataList 縺悟・讒狗ｯ峨＆繧後※縺・ｋ蜿ｯ閭ｽ諤ｧ縺後≠繧九◆繧√√％縺薙〒
    // _updateSignalDataList() 繧貞他縺ｳ蜃ｺ縺励※ CODE_OPTION 繧堤｢ｺ螳溘↓霑ｽ蜉縺励・
    // 縺昴・蠕・generatePortNumbers() 縺ｧ髟ｷ縺輔ｒ謠・∴縺溘Μ繧ｹ繝医ｒ蜿門ｾ励☆繧九・
    if (formState.triggerOption == 'Code Trigger') {
      _updateSignalDataList();
    }

    // === 蜿ｯ隕也憾諷九〒譛邨ゅヵ繧｣繝ｫ繧ｿ・・emplate邨瑚ｷｯ・・===
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

    // ports 蜀崎ｨ育ｮ暦ｼ亥庄隕悶ヵ繧｣繝ｫ繧ｿ蠕鯉ｼ・
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

    // --- 霑ｽ蜉: 繝ｦ繝ｼ繧ｶ繝ｼ縺ｸ螳御ｺ・夂衍 ---
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('信号データの更新が完了しました')));
  }

  // AppConfig繧堤樟蝨ｨ縺ｮ迥ｶ諷九°繧我ｽ懈・
  AppConfig _createAppConfig() {
    // 信号データの確認
    debugPrint('===== 信号データの確認:=====');
    debugPrint('信号データの数: ${_actualChartData.length}');
    if (_actualChartData.isNotEmpty) {
      debugPrint('信号データ: ${_actualChartData[0]}');
      debugPrint(
        '信号データに0が含まれているか: ${_actualChartData.any((row) => row.any((value) => value != 0))}',
      );
    }

    // ChartDataGenerator縺ｮ螳溯｣・ｒ遒ｺ隱・
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

    // 譖ｴ譁ｰ縺輔ｌ縺欖ignalData繝ｪ繧ｹ繝医ｒ菴懈・
    List<SignalData> updatedSignals = [];
    int dataIndex = 0;

    // 蜈･蜉帑ｿ｡蜿ｷ
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

        // index縺ｯ譛ｪ菴ｿ逕ｨ縺ｮ縺溘ａ蜑企勁貂医∩
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

        // index縺ｯ譛ｪ菴ｿ逕ｨ縺ｮ縺溘ａ蜑企勁貂医∩
      }
    }

    // HW繝医Μ繧ｬ繝ｼ菫｡蜿ｷ
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

        // index縺ｯ譛ｪ菴ｿ逕ｨ縺ｮ縺溘ａ蜑企勁貂医∩
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

  // 繧ｨ繧ｯ繧ｹ繝昴・繝亥燕縺ｫ縲袈pdate Chart縲阪・繧ｿ繝ｳ繧定・蜍慕噪縺ｫ謚ｼ縺吶％縺ｨ繧呈耳螂ｨ縺吶ｋ繝繧､繧｢繝ｭ繧ｰ繧定｡ｨ遉ｺ
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

  // 信号データの更新
  Future<void> _exportConfig() async {
    // 信号データの更新
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

    setState(() {
      // 信号データの更新
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

      // 信号データの更新
      if (_rowModes.length < _rowCount) {
        _rowModes.addAll(
          List.filled(_rowCount - _rowModes.length, RowMode.none),
        );
      } else if (_rowModes.length > _rowCount) {
        _rowModes = _rowModes.sublist(0, _rowCount);
      }

      // 陦ｨ遉ｺ/髱櫁｡ｨ遉ｺ迥ｶ諷九ｒ譖ｴ譁ｰ
      _inputVisibility = List.from(config.inputVisibility);
      _outputVisibility = List.from(config.outputVisibility);
      _hwTriggerVisibility = List.from(config.hwTriggerVisibility);

      // SignalData繧呈峩譁ｰ
      _signalDataList = List.from(config.signals);

      // --- 繝√Ε繝ｼ繝医ョ繝ｼ繧ｿ繧貞ｾｩ蜈・(蜿ｯ隕紋ｿ｡蜿ｷ縺ｮ縺ｿ) ---
      _actualChartData =
          _signalDataList
              .where((s) => s.isVisible)
              .map((s) => List<int>.from(s.values))
              .toList();

      // 繧ｳ繝ｳ繝医Ο繝ｼ繝ｩ繝ｼ繧呈峩譁ｰ
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

    // 繝√Ε繝ｼ繝医ｒ譖ｴ譁ｰ
    await _onUpdateChart();

    // 邨先棡繝｡繝・そ繝ｼ繧ｸ繧定｡ｨ遉ｺ
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('繧､繝ｳ繝昴・繝医′螳御ｺ・＠縺ｾ縺励◆'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 螟夜Κ縺九ｉ繧｢繧ｯ繧ｻ繧ｹ縺ｧ縺阪ｋ繧医≧縺ｫ縺吶ｋ繝｡繧ｽ繝・ラ・井ｽ咲ｽｮ髢｢菫ゅｒ菫晄戟・・
  List<SignalData> getSignalDataList() {
    // _actualChartData縺後≠繧後・縲√◎繧後ｒ蜆ｪ蜈医＠縺ｦ菴ｿ逕ｨ
    if (_actualChartData.isNotEmpty &&
        _actualChartData.any((row) => row.any((val) => val != 0))) {
      debugPrint("getSignalDataList: _actualChartData縺九ｉ髱槭ぞ繝ｭ繝・・繧ｿ繧呈､懷・");

      // 菴咲ｽｮ髢｢菫ゅｒ菫晄戟縺励※SignalData繧呈ｧ狗ｯ・
      List<SignalData> result = [];
      int dataIndex = 0;

      // 蜈･蜉帑ｿ｡蜿ｷ・井ｽ咲ｽｮ繧剃ｿ晄戟・・
      for (int i = 0; i < formState.inputCount; i++) {
        if (widget.inputControllers[i].text.isNotEmpty) {
          SignalType signalType = SignalType.input;
          // Code Trigger縺ｮ蝣ｴ蜷医・繧ｿ繧､繝怜愛螳・
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

      // HW繝医Μ繧ｬ繝ｼ菫｡蜿ｷ・井ｽ咲ｽｮ繧剃ｿ晄戟・・
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
            // 譌｢蟄倥ョ繝ｼ繧ｿ縺檎┌縺・ｴ蜷医〒繧・0 豕｢蠖｢縺ｧ霑ｽ蜉
            result.add(
              SignalData(
                name: name,
                signalType: SignalType.output,
                values: List.filled(32, 0),
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

    // 繝・・繧ｿ縺後↑縺・ｴ蜷医・譌｢蟄倥・繝ｪ繧ｹ繝医ｒ繧ｳ繝斐・縺励※霑斐☆
    _updateSignalDataList();
    debugPrint("getSignalDataList: 信号データの数: ${_signalDataList.length}");
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

  // AppConfig縺九ｉ縺ｮ繝・・繧ｿ譖ｴ譁ｰ
  void updateFromAppConfig(AppConfig config) {
    setState(() {
      // 繝・・繝悶Ν繝・・繧ｿ繧呈峩譁ｰ
      if (config.tableData.isNotEmpty) {
        _tableData = List.from(config.tableData);
        _rowCount = _tableData.length;
      }

      // --- RowMode 繧貞ｾｩ蜈・---
      _rowModes =
          config.rowModes
              .map(
                (name) => RowMode.values.firstWhere(
                  (e) => e.name == name,
                  orElse: () => RowMode.none,
                ),
              )
              .toList();

      // 陦梧焚縺ｨ縺ｮ蟾ｮ繧定ｪｿ謨ｴ
      if (_rowModes.length < _rowCount) {
        _rowModes.addAll(
          List.filled(_rowCount - _rowModes.length, RowMode.none),
        );
      } else if (_rowModes.length > _rowCount) {
        _rowModes = _rowModes.sublist(0, _rowCount);
      }

      // 陦ｨ遉ｺ/髱櫁｡ｨ遉ｺ迥ｶ諷九ｒ譖ｴ譁ｰ
      if (config.inputVisibility.length == _inputVisibility.length) {
        _inputVisibility = List.from(config.inputVisibility);
      }

      if (config.outputVisibility.length == _outputVisibility.length) {
        _outputVisibility = List.from(config.outputVisibility);
      }

      if (config.hwTriggerVisibility.length == _hwTriggerVisibility.length) {
        _hwTriggerVisibility = List.from(config.hwTriggerVisibility);
      }

      // SignalData縺ｮ譖ｴ譁ｰ
      _signalDataList = List.from(config.signals);

      // --- 繝√Ε繝ｼ繝医ョ繝ｼ繧ｿ繧貞ｾｩ蜈・---
      _actualChartData =
          _signalDataList
              .where((s) => s.isVisible)
              .map((s) => List<int>.from(s.values))
              .toList();

      // 繝√Ε繝ｼ繝医ｒ譖ｴ譁ｰ
      _onUpdateChart();
    });
  }

  // 繝√Ε繝ｼ繝医ョ繝ｼ繧ｿ繧貞ｼｷ蛻ｶ逧・↓譖ｴ譁ｰ縺吶ｋ繝｡繧ｽ繝・ラ
  Future<void> updateChartData() async {
    _updateSignalDataList();

    // 譌｢蟄倥・繝√Ε繝ｼ繝医ョ繝ｼ繧ｿ繧剃ｿ晏ｭ・
    List<List<int>> existingChartData = _actualChartData;
    bool hasExistingNonZeroData =
        existingChartData.isNotEmpty &&
        existingChartData.any((row) => row.any((val) => val != 0));

    if (hasExistingNonZeroData) {
      debugPrint("既存の信号データに0が含まれています");
    }

    // 譁ｰ縺励＞繝√Ε繝ｼ繝医ョ繝ｼ繧ｿ繧堤函謌・
    final newChartData = generateTimingChartData();

    if (hasExistingNonZeroData &&
        existingChartData.length == newChartData.length) {
      // 譌｢蟄倥ョ繝ｼ繧ｿ縺ｨ譁ｰ縺励＞繝・・繧ｿ縺ｮ髟ｷ縺輔′蜷後§蝣ｴ蜷医・撼繧ｼ繝ｭ蛟､繧剃ｿ晄戟縺吶ｋ
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
      // 髟ｷ縺輔′驕輔≧蝣ｴ蜷医ｄ譌｢蟄倥ョ繝ｼ繧ｿ縺後↑縺・ｴ蜷医・譁ｰ縺励＞繝・・繧ｿ繧剃ｽｿ逕ｨ
      _actualChartData = newChartData;
    }

    // 繝√Ε繝ｼ繝医ｒ譖ｴ譁ｰ・・D 竊・繝ｩ繝吶Ν縺ｸ螟画鋤・・
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

  // 繝√Ε繝ｼ繝医ち繝悶°繧牙､縺ｮ縺ｿ繧呈峩譁ｰ・亥錐蜑堺ｽ咲ｽｮ縺ｯ螟画峩縺励↑縺・ｼ・
  void setChartDataOnly(List<List<int>> chartData) {
    if (chartData.isEmpty) return;
    setState(() {
      _actualChartData = List.from(chartData);
    });
  }

  // 繝√Ε繝ｼ繝医ち繝悶°繧峨・繝・・繧ｿ縺ｧSignalData繧呈峩譁ｰ
  void updateSignalDataFromChartData(
    List<List<int>> chartData,
    List<String> signalNames,
    List<SignalType> signalTypes,
  ) {
    if (chartData.isEmpty) return;

    setState(() {
      _actualChartData = List.from(chartData);
      List<SignalData> newSignalList = [];

      // 譌｢蟄倥・繧ｳ繝ｳ繝医Ο繝ｼ繝ｩ繝ｼ縺ｮ蛟､繧剃ｿ晏ｭ假ｼ亥・縺ｮ菴咲ｽｮ繧剃ｿ晄戟縺吶ｋ縺溘ａ・・
      Map<String, int> existingInputMap = {};
      Map<String, int> existingOutputMap = {};
      Map<String, int> existingHwTriggerMap = {};
      // PLC/EIP 蛛ｴ縺ｫ譌｢縺ｫ蟄伜惠縺吶ｋ蜷榊燕縺ｯ DIO 縺ｸ縺ｯ譖ｸ縺崎ｾｼ縺ｾ縺ｪ縺・◆繧√∝・縺ｫ蜿朱寔
      final Map<String, int> existingPlcMap = {};
      // PLC/EIP 蜈･蜉帛・縺ｫ譌｢縺ｫ蟄伜惠縺吶ｋ蜷榊燕縺ｯ DIO 縺ｸ縺ｯ譖ｸ縺崎ｾｼ縺ｾ縺ｪ縺・◆繧√∝・縺ｫ蜿朱寔
      final Map<String, int> existingPlcInputMap = {};

      // 譌｢蟄倥・蛟､縺ｨ縺昴・菴咲ｽｮ繧定ｨ倬鹸
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

      // 蜈ｨ縺ｦ縺ｮ繧ｳ繝ｳ繝医Ο繝ｼ繝ｩ繝ｼ繧偵け繝ｪ繧｢
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

      for (int i = 0; i < chartData.length; i++) {
        final name = i < signalNames.length ? signalNames[i] : 'Signal $i';
        final type = i < signalTypes.length ? signalTypes[i] : SignalType.input;
        final values = List<int>.from(
          chartData[i],
        ); // 莉･蠕後・譖ｸ縺崎ｾｼ縺ｿ縺ｧ菴ｿ逕ｨ縺吶ｋ縺溘ａ菫晄戟

        // 繧ｳ繝ｳ繝医Ο繝ｼ繝ｩ繝ｼ縺ｸ蜿肴丐・域里蟄倥・菴咲ｽｮ繧貞━蜈井ｽｿ逕ｨ・・
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
            // 譌｢蟄倅ｽ咲ｽｮ縺後↑縺・ｴ蜷医・譛蛻昴・遨ｺ縺・※縺・ｋ菴咲ｽｮ繧剃ｽｿ逕ｨ
            for (int j = 0; j < widget.inputControllers.length; j++) {
              if (widget.inputControllers[j].text.isEmpty) {
                targetIndex = j;
                break;
              }
            }
          }
          // 豕ｨ諢・ PLC/EIP 蜈･蜉帛・縺ｫ譌｢縺ｫ蟄伜惠縺吶ｋ蜷榊燕縺ｯ DIO 縺ｸ縺ｯ譖ｸ縺崎ｾｼ縺ｾ縺ｪ縺・
          if (existingPlcInputMap.containsKey(name)) {
            // PLC/EIP蜈･蜉帛・縺ｫ譖ｸ縺崎ｾｼ繧
            final plcTargetIndex = existingPlcInputMap[name]!;
            if (plcTargetIndex >= 0 &&
                plcTargetIndex < widget.plcEipInputControllers.length) {
              widget.plcEipInputControllers[plcTargetIndex].text = name;
            }
          } else {
            // DIO蜈･蜉帛・縺ｫ譖ｸ縺崎ｾｼ繧
            if (targetIndex >= 0 &&
                targetIndex < widget.inputControllers.length) {
              widget.inputControllers[targetIndex].text = name;
            }
          }
        } else if (type == SignalType.output) {
          // 1) 譌｢蟄倥・菴咲ｽｮ・・NI 縺ｮ Port.No 蜿肴丐貂医∩・峨ｒ譛蜆ｪ蜈・
          final fs = context.read<FormStateNotifier>().state;
          int targetIndex = existingOutputMap[name] ?? -1;

          if (targetIndex != -1) {
            // 繧ｫ繝｡繝ｩ逕ｨ莠育ｴ・ヶ繝ｭ繝・け繧帝撼繧ｫ繝｡繝ｩ菫｡蜿ｷ縺ｧ菴ｿ逕ｨ縺励↑縺・宛邏・
            if (fs.outputCount == 32) {
              final int reservedStart = 3; // Output4 縺九ｉ
              final int reservedEnd =
                  3 + fs.camera * 2 - 1; // Exposure/Acq 縺ｮ譛ｫ蟆ｾ
              final bool isInReserved =
                  targetIndex >= reservedStart && targetIndex <= reservedEnd;
              final bool isCameraSignal = RegExp(
                r'^CAMERA_(\d+)_IMAGE_(EXPOSURE|ACQUISITION)',
              ).hasMatch(name);
              if (!isCameraSignal && isInReserved) {
                targetIndex = -1; // 莠育ｴ・ヶ繝ｭ繝・け縺ｯ菴ｿ繧上○縺ｪ縺・
              }
            }
          }

          // 1.5) CSV 逕ｱ譚･縺ｮ豎守畑蜷・"OutputN" 縺ｯ N 逡ｪ繝昴・繝医↓驟咲ｽｮ縺吶ｋ
          if (targetIndex == -1) {
            final m = RegExp(r'^Output(\d+)$').firstMatch(name);
            if (m != null) {
              final portNum = int.tryParse(m.group(1)!);
              if (portNum != null &&
                  portNum >= 1 &&
                  portNum <= fs.outputCount) {
                int candidate = portNum - 1; // 0-based index for OutputN
                if (fs.outputCount == 32) {
                  final int reservedStart = 3; // Output4 縺九ｉ
                  final int reservedEnd = 3 + fs.camera * 2 - 1; // 莠育ｴ・忰蟆ｾ
                  final bool isInReserved =
                      candidate >= reservedStart && candidate <= reservedEnd;
                  final bool isCameraSignal = RegExp(
                    r'^CAMERA_(\d+)_IMAGE_(EXPOSURE|ACQUISITION)',
                  ).hasMatch(name);
                  if (!isCameraSignal && isInReserved) {
                    candidate = -1; // 莠育ｴ・ヶ繝ｭ繝・け縺ｯ菴ｿ繧上○縺ｪ縺・
                  }
                }
                if (candidate != -1) {
                  targetIndex = candidate;
                }
              }
            }
          }

          // 2) 譌｢蟄倅ｽ咲ｽｮ縺檎┌縺代ｌ縺ｰ縲√・繝ｪ繧ｻ繝・ヨ菴咲ｽｮ繧剃ｽｿ逕ｨ
          if (targetIndex == -1) {
            targetIndex = _selectOutputIndex(name, fs.outputCount, fs.camera);
          }

          // 3) 縺昴ｌ縺ｧ繧りｦ九▽縺九ｉ縺ｪ縺代ｌ縺ｰ縲∫ｩｺ縺・※縺・ｋ谺・ｒ謗｢縺・
          if (targetIndex == -1) {
            int startIdx = 0;
            if (fs.outputCount == 32) {
              // TOTAL_RESULT_NG 縺ｮ逶ｴ蠕後°繧蛾・鄂ｮ縺励◆縺・
              int reservedEnd = 3 + fs.camera * 2 + 2; // TOT_NG index
              startIdx = reservedEnd + 1;
              if (startIdx >= widget.outputControllers.length) {
                startIdx = 0; // 繝輔か繝ｼ繝ｫ繝舌ャ繧ｯ・亥ｿｵ縺ｮ縺溘ａ・・
              }
            }

            for (int j = startIdx; j < widget.outputControllers.length; j++) {
              if (widget.outputControllers[j].text.isEmpty) {
                targetIndex = j;
                break;
              }
            }
            // 蜑肴婿讀懃ｴ｢縺ｧ隕九▽縺九ｉ縺ｪ縺代ｌ縺ｰ蜈磯ｭ縺九ｉ蜀肴､懃ｴ｢
            if (targetIndex == -1) {
              for (int j = 0; j < startIdx; j++) {
                if (widget.outputControllers[j].text.isEmpty) {
                  targetIndex = j;
                  break;
                }
              }
            }
          }

          // 4) 豎ｺ螳壹＠縺滓ｬ・↓譖ｸ縺崎ｾｼ繧
          // 豕ｨ諢・ PLC/EIP 蛛ｴ縺ｫ譌｢縺ｫ蟄伜惠縺吶ｋ蜷榊燕縺ｯ DIO 縺ｸ縺ｯ譖ｸ縺崎ｾｼ縺ｾ縺ｪ縺・
          if (!existingPlcMap.containsKey(name)) {
            if (targetIndex >= 0 &&
                targetIndex < widget.outputControllers.length) {
              widget.outputControllers[targetIndex].text = name;
            }
          }
        } else if (type == SignalType.hwTrigger) {
          int targetIndex = existingHwTriggerMap[name] ?? -1;
          if (targetIndex == -1) {
            // 譌｢蟄倅ｽ咲ｽｮ縺後↑縺・ｴ蜷医・譛蛻昴・遨ｺ縺・※縺・ｋ菴咲ｽｮ繧剃ｽｿ逕ｨ
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

  // RowMode 縺ｮ繝ｪ繧ｹ繝医ｒ蜿門ｾ・
  List<String> getRowModes() => _rowModes.map((e) => e.name).toList();

  // ----------------- 霑ｽ蜉: CODE_OPTION 豕｢蠖｢逕滓・繝倥Ν繝・-----------------
  List<int> _generateCodeOptionWave(List<int> autoWave, int waveLength) {
    // AUTO_MODE 縺ｮ遶倶ｸ翫ｊ讀懷・ (0竊帝撼0)
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

  // ・亥炎髯､・韻ode Trigger 蟆ら畑繝昴せ繝亥・逅・・ _applyOptionPostRules 縺ｫ邨ｱ蜷・

  // --- 霑ｽ蜉: 繧ｪ繝励す繝ｧ繝ｳ菫｡蜿ｷ・・ODE_OPTION / Command Option・牙・騾壹・繝昴せ繝亥・逅・---
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

    // --- TRIGGER: 蜈ｨ縺ｦ縺ｮ遶倶ｸ翫ｊ讀懷・ ---
    int triggerIdx = names.indexOf('TRIGGER');
    if (triggerIdx == -1) {
      // 蟄伜惠縺励↑縺代ｌ縺ｰ霑ｽ蜉
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

    // ---------- BUSY: 繧ｪ繝励す繝ｧ繝ｳ豕｢蠖｢縺ｨ蜷後§ High 蛹ｺ髢・----------
    int busyIdx = names.indexOf('BUSY');
    if (busyIdx != -1) {
      values[busyIdx] = List<int>.from(codeWave);
    }

    // ---------- EXPOSURE: 3 蝗・rise 蠕後↓髢句ｧ・----------
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
      // ---------- 繧ｹ繧ｱ繧ｸ繝･繝ｼ繝ｫ蜈ｨ菴薙ｒ3蝗樒岼rise蠕後↓繧ｷ繝輔ヨ ----------
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

        // --- 蜈ｨ繧ｷ繝輔ヨ蟇ｾ雎｡縺九ｉ譛騾溘・繝代Ν繧ｹ菴咲ｽｮ繧呈､懷・ ---
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

        // --- 繧ｷ繝輔ヨ驥上ｒ險育ｮ励＠縲∝・蟇ｾ雎｡縺ｫ驕ｩ逕ｨ ---
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
    // AutomaticKeepAliveClientMixin 繧剃ｽｿ縺・ｴ蜷医・ super.build(context) 縺悟ｿ・ｦ・
    super.build(context);

    // UI 譖ｴ譁ｰ逕ｨ縺ｫ Provider 繧定ｳｼ隱ｭ・医ン繝ｫ繝峨→萓晏ｭ倬未菫よ峩譁ｰ繧偵ヨ繝ｪ繧ｬ・・
    final watchedState = context.watch<FormStateNotifier>().state;

    // 蜈ｱ騾壹・繧ｿ繝ｳ繧ｹ繧ｿ繧､繝ｫ繧剃ｽ懈・
    final clearButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.red.shade100,
      foregroundColor: Colors.red.shade900,
      minimumSize: Size(120, _buttonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: _buttonHorizontalPadding,
        vertical: _buttonVerticalPadding,
      ),
    );
    // Update Chart 繝懊ち繝ｳ逕ｨ繧ｹ繧ｿ繧､繝ｫ
    final updateButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.blue.shade100,
      foregroundColor: Colors.blue.shade900,
      minimumSize: Size(120, _buttonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: _buttonHorizontalPadding,
        vertical: _buttonVerticalPadding,
      ),
    );

    // Template 繝懊ち繝ｳ逕ｨ繧ｹ繧ｿ繧､繝ｫ
    final templateButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.orange.shade100,
      foregroundColor: Colors.orange.shade900,
      minimumSize: Size(120, _buttonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: _buttonHorizontalPadding,
        vertical: _buttonVerticalPadding,
      ),
    );
    // Add Row 繝懊ち繝ｳ逕ｨ繧ｹ繧ｿ繧､繝ｫ
    final addRowButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.green.shade100,
      foregroundColor: Colors.green.shade900,
      minimumSize: Size(120, _buttonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: _buttonHorizontalPadding,
        vertical: _buttonVerticalPadding,
      ),
    );
    // Remove Row 繝懊ち繝ｳ逕ｨ繧ｹ繧ｿ繧､繝ｫ
    final removeRowButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.red.shade100,
      foregroundColor: Colors.red.shade900,
      minimumSize: Size(120, _buttonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: _buttonHorizontalPadding,
        vertical: _buttonVerticalPadding,
      ),
    );

    // 繧ｻ繧ｯ繧ｷ繝ｧ繝ｳ繝倥ャ繝繝ｼ縺ｮ繧ｹ繧ｿ繧､繝ｫ繧貞ｮ夂ｾｩ
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

    // 蜃ｺ蜉帙そ繧ｯ繧ｷ繝ｧ繝ｳ縺ｮ繧ｿ繝悶さ繝ｳ繝医Ο繝ｼ繝ｩ繧貞ｿ・ｦ√↓蠢懊§縺ｦ貅門ｙ
    _ensureOutputTabController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 荳企Κ縺ｮ繝峨Ο繝・・繝繧ｦ繝ｳ繧ｻ繧ｯ繧ｷ繝ｧ繝ｳ
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 1 陦後↓ 6 縺､縺ｮ繝峨Ο繝・・繝繧ｦ繝ｳ繧帝・鄂ｮ
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
                      // HW Port 縺ｯ 0 縺ｾ縺溘・ Camera 謨ｰ縺ｨ蜷後§蛟､縺ｮ縺ｿ驕ｸ謚槫庄閭ｽ
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

              // 繝懊ち繝ｳ陦・
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
                  // 繧､繝ｳ繝昴・繝・繧ｨ繧ｯ繧ｹ繝昴・繝医・繧ｿ繝ｳ縺ｯ譚｡莉ｶ莉倥″縺ｧ陦ｨ遉ｺ
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
                      // 繝・・繝悶Ν繝・・繧ｿ繧偵け繝ｪ繧｢
                      _clearTableData();
                      // 繝・く繧ｹ繝医ヵ繧｣繝ｼ繝ｫ繝峨ｒ繧ｯ繝ｪ繧｢
                      widget.onClearFields();
                    },
                    style: clearButtonStyle,
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 16),
                  // Template 繝懊ち繝ｳ
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

        // 繝｡繧､繝ｳ繧ｳ繝ｳ繝・Φ繝・お繝ｪ繧｢
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 蟾ｦ蛛ｴ縺ｮ繧ｫ繝ｩ繝 - 菫｡蜿ｷ蜷榊・蜉帙ヵ繧｣繝ｼ繝ｫ繝臥ｾ､
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 騾｣邯壹＠縺溘・繝・ム繝ｼ繝舌・
                      Row(
                        children: [
                          // Input Signals 繝倥ャ繝繝ｼ
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
                          // Output Signals 繝倥ャ繝繝ｼ・医ち繝悶ｒ繝ｩ繝吶Ν蜀・↓驟咲ｽｮ・・
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
                          // HW Trigger 繝倥ャ繝繝ｼ・・蛻礼岼・・
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

                      // 繝輔ぅ繝ｼ繝ｫ繝蛾Κ蛻・
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Input Signals 繧ｻ繧ｯ繧ｷ繝ｧ繝ｳ
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

                            // Output Signals 繧ｻ繧ｯ繧ｷ繝ｧ繝ｳ
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

                            // HW Trigger 繧ｻ繧ｯ繧ｷ繝ｧ繝ｳ
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

                // 蛻励・髢馴囈
                const SizedBox(width: 32),

                // 蜿ｳ蛛ｴ縺ｮ繧ｫ繝ｩ繝 - Camera Configuration Table
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 繝・・繝悶Ν繝倥ャ繝繝ｼ
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
                      // 繝懊ち繝ｳ陦後ｒ霑ｽ蜉
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
                      // 繝・・繝悶Ν繧ｳ繝ｳ繝・リ
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

  // 繧､繝ｳ繧ｿ繝ｩ繧ｯ繝・ぅ繝悶↑繝・・繝悶Ν繧呈ｧ狗ｯ・
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

  // 繧ｫ繝｡繝ｩ謨ｰ縺ｫ蝓ｺ縺･縺・※繧ｫ繝ｩ繝蟷・ｒ逕滓・
  Map<int, TableColumnWidth> _generateColumnWidths() {
    final Map<int, TableColumnWidth> columnWidths = {
      0: const FixedColumnWidth(60), // 陦檎分蜿ｷ蛻励・蝗ｺ螳壼ｹ・
    };

    // 繧ｫ繝｡繝ｩ謨ｰ縺ｫ蠢懊§縺ｦ驕ｩ蛻・↑蟷・ｒ險ｭ螳・
    double columnWidth = 100.0; // 繝・ヵ繧ｩ繝ｫ繝亥ｹ・

    // 繧ｫ繝｡繝ｩ謨ｰ縺悟､壹＞蝣ｴ蜷医・蛻怜ｹ・ｒ邵ｮ蟆・
    if (formState.camera > 6) {
      columnWidth = 80.0;
    } else if (formState.camera > 4) {
      columnWidth = 90.0;
    }

    // 縺吶∋縺ｦ縺ｮ繧ｫ繝｡繝ｩ蛻励↓蜷後§蝗ｺ螳壼ｹ・ｒ驕ｩ逕ｨ
    for (int i = 1; i <= formState.camera; i++) {
      columnWidths[i] = FixedColumnWidth(columnWidth);
    }

    return columnWidths;
  }

  // 繝・・繝悶Ν縺ｮ陦後ｒ讒狗ｯ・
  List<TableRow> _buildTableRows() {
    List<TableRow> rows = [];

    // 繝倥ャ繝繝ｼ陦後ｒ霑ｽ蜉
    rows.add(
      TableRow(
        decoration: BoxDecoration(
          // 繝繝ｼ繧ｯ繝｢繝ｼ繝峨〒繧・Camera Configuration Table 縺ｨ蜷後§螟冶ｦｳ縺ｫ蜷医ｏ縺帙ｋ
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
          // 繧ｫ繝｡繝ｩ謨ｰ縺ｫ蝓ｺ縺･縺・※繝倥ャ繝繝ｼ繧堤函謌・
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

    // 繝・・繧ｿ陦後ｒ霑ｽ蜉
    for (int row = 0; row < _rowCount; row++) {
      rows.add(
        TableRow(
          children: [
            // 陦檎分蜿ｷ繧ｻ繝ｫ
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
            // 繧ｫ繝｡繝ｩ蛻励・繧ｻ繝ｫ繧堤函謌・
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

  // 繝｢繝ｼ繝蛾∈謚槭ラ繝ｭ繝・・繝繧ｦ繝ｳ繧呈ｧ狗ｯ・
  Widget _buildModeDropdown(int row, int col) {
    // Flutter縺ｮ蜀・Κ螳夂ｾｩ蛟､繧剃ｽｿ逕ｨ
    const double kMinInteractiveDimension = 48.0; // Flutter縺ｮ蜀・Κ蛟､

    // HW Trigger 逕ｨ繝昴・繝医′ 0 縺ｮ蝣ｴ蜷医・ HW 繝医Μ繧ｬ (mode3) 繧堤┌蜉ｹ蛹・
    final bool _canSelectHwTrigger = formState.hwPort > 0;

    // 險ｱ蜿ｯ縺吶ｋ繝｢繝ｼ繝会ｼ・ode4, mode5 繧帝勁螟悶＠縲∝ｿ・ｦ√↑繧・mode3 繧る勁螟厄ｼ・
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
      padding: const EdgeInsets.symmetric(horizontal: 4.0), // 繝代ョ繧｣繝ｳ繧ｰ繧堤ｸｮ蟆・
      child: DropdownButton<CellMode>(
        value: currentValue,
        isExpanded: true,
        isDense: true, // 繧医ｊ繧ｳ繝ｳ繝代け繝医↑繝峨Ο繝・・繝繧ｦ繝ｳ
        underline: Container(), // 荳狗ｷ壹ｒ髱櫁｡ｨ遉ｺ
        // 譏守､ｺ逧・↓Flutter縺ｮ譛蟆丞､繧定ｨｭ螳・
        itemHeight: kMinInteractiveDimension,
        onChanged: (CellMode? newValue) {
          if (newValue != null) {
            // HW 繝昴・繝医′ 0 縺ｮ蝣ｴ蜷医・ mode3 縺ｸ縺ｮ螟画峩繧堤┌隕・
            if (!_canSelectHwTrigger && newValue == CellMode.mode3) {
              // 蠢・ｦ√↓蠢懊§縺ｦ SnackBar 縺ｪ縺ｩ縺ｧ繝ｦ繝ｼ繧ｶ繝ｼ縺ｸ騾夂衍縺吶ｋ縺薙→繧ょ庄閭ｽ
              return;
            }
            // mode4, mode5 縺ｯ辟｡蜉ｹ蛹・
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
                // 繧ｳ繝ｳ繝・Φ繝・・鬮倥＆繧定ｪｿ謨ｴ縺励※蜈ｨ菴薙・鬮倥＆繧堤｢ｺ菫・
                child: SizedBox(
                  height: kMinInteractiveDimension - 16, // 繝代ョ繧｣繝ｳ繧ｰ縺ｮ蛻・ｒ閠・・
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 12, // 繧ｵ繧､繧ｺ邵ｮ蟆・
                        height: 12, // 繧ｵ繧､繧ｺ邵ｮ蟆・
                        decoration: BoxDecoration(
                          color: cellModeColors[mode],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 4), // 髢馴囈邵ｮ蟆・
                      Flexible(
                        child: Text(
                          _labelForCellMode(context, mode),
                          overflow:
                              TextOverflow.ellipsis, // 繝・く繧ｹ繝医′縺ｯ縺ｿ蜃ｺ縺吝ｴ蜷医・逵∫払
                          style: const TextStyle(
                            fontSize: 12,
                          ), // 繝輔か繝ｳ繝医し繧､繧ｺ繧貞ｰ上＆縺・
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

  // === 霑ｽ蜉: 繧ｫ繝ｩ繝繝倥ャ繝繝ｼ・医き繝｡繝ｩ蛻暦ｼ峨え繧｣繧ｸ繧ｧ繝・ヨ ===
  Widget _buildColumnHeader(int col) {
    // HW Trigger 逕ｨ繝昴・繝医′ 0 縺ｮ蝣ｴ蜷医・ HW 繝医Μ繧ｬ (mode3) 繧堤┌蜉ｹ蛹・
    final bool _canSelectHwTrigger = formState.hwPort > 0;

    // 迴ｾ蝨ｨ縺ｮ繝｢繝ｼ繝芽牡
    final Color? bgColor = cellModeColors[_columnModes.isNotEmpty
            ? _columnModes[col]
            : CellMode.none]
        ?.withAlpha((0.3 * 255).round());

    // 險ｱ蜿ｯ縺吶ｋ繝｢繝ｼ繝会ｼ・ode4, mode5 繧帝勁螟厄ｼ・
    final List<CellMode> allowedModes =
        CellMode.values
            .where((m) => m != CellMode.mode4 && m != CellMode.mode5)
            .toList();

    return PopupMenuButton<CellMode>(
      onSelected: (CellMode mode) {
        // HW繝昴・繝医′辟｡縺・ｴ蜷医・ mode3 繧堤┌隕・
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
