import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 多言語対応に必要
//import 'package:provider/provider.dart'; // もし Provider を使う場合 (今回は使わない前提)

// ★ 作成した他のファイルをインポート
import 'generated/l10n.dart';
import 'models/form/form_state.dart';
import 'models/chart/signal_data.dart';
import 'models/chart/timing_chart_annotation.dart';
import 'widgets/form/form_tab.dart';
import 'widgets/chart/timing_chart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timing Chart Generator', // アプリタイトル (l10nを使っても良い)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      // --- 多言語対応設定 ---
      localizationsDelegates: const [
        S.delegate, // 生成されたローカライズデリゲート
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales, // サポートするロケール
      // locale: const Locale('ja'), // 特定の言語で固定する場合
      // ----------------------
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  // ★ アプリタイトルは MyHomePage で持つ方が良いかも (l10n対応のため)
  // final String title = 'Timing Chart Generator';

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // フォームの状態
  late TimingFormState _formState;
  List<TextEditingController> _inputControllers = [];
  List<TextEditingController> _outputControllers = [];
  List<TextEditingController> _hwTriggerControllers = [];

  // チャートの状態
  List<SignalData> _chartSignals = [];
  List<TimingChartAnnotation> _chartAnnotations = [];
  final int _initialTimeSteps = 50;
  final double _cellWidth = 50.0;
  final double _cellHeight = 30.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _formState = TimingFormState(
      triggerOption: 'Single',
      ioPort: 6,
      hwPort: 0,
      camera: 1,
      inputCount: 6,
      outputCount: 6,
    );
    _initializeControllers();
  }

  void _initializeControllers() {
    // 既存のコントローラーを破棄
    for (var controller in _inputControllers) {
      controller.dispose();
    }
    for (var controller in _outputControllers) {
      controller.dispose();
    }
    for (var controller in _hwTriggerControllers) {
      controller.dispose();
    }

    // 新しいコントローラーリストを作成
    _inputControllers = List.generate(
      _formState.inputCount,
      (index) => TextEditingController(),
    );
    _outputControllers = List.generate(
      _formState.outputCount,
      (index) => TextEditingController(),
    );
    _hwTriggerControllers = List.generate(
      _formState.hwPort,
      (index) => TextEditingController(),
    );
  }

  void _updateInputOutputCounts(int totalIoPorts) {
    setState(() {
      _formState = _formState.copyWith(
        inputCount: totalIoPorts,
        outputCount: totalIoPorts,
      );
      _updateInputControllers();
      _updateOutputControllers();
    });
  }

  void _updateInputControllers() {
    if (_inputControllers.length > _formState.inputCount) {
      for (int i = _formState.inputCount; i < _inputControllers.length; i++) {
        _inputControllers[i].dispose();
      }
      _inputControllers = _inputControllers.sublist(0, _formState.inputCount);
    } else if (_inputControllers.length < _formState.inputCount) {
      _inputControllers.addAll(
        List.generate(
          _formState.inputCount - _inputControllers.length,
          (_) => TextEditingController(),
        ),
      );
    }
  }

  void _updateOutputControllers() {
    if (_outputControllers.length > _formState.outputCount) {
      for (int i = _formState.outputCount; i < _outputControllers.length; i++) {
        _outputControllers[i].dispose();
      }
      _outputControllers = _outputControllers.sublist(
        0,
        _formState.outputCount,
      );
    } else if (_outputControllers.length < _formState.outputCount) {
      _outputControllers.addAll(
        List.generate(
          _formState.outputCount - _outputControllers.length,
          (_) => TextEditingController(),
        ),
      );
    }
  }

  void _updateHwTriggerControllers() {
    if (_hwTriggerControllers.length > _formState.hwPort) {
      for (int i = _formState.hwPort; i < _hwTriggerControllers.length; i++) {
        _hwTriggerControllers[i].dispose();
      }
      _hwTriggerControllers = _hwTriggerControllers.sublist(
        0,
        _formState.hwPort,
      );
    } else if (_hwTriggerControllers.length < _formState.hwPort) {
      _hwTriggerControllers.addAll(
        List.generate(
          _formState.hwPort - _hwTriggerControllers.length,
          (_) => TextEditingController(),
        ),
      );
    }
  }

  void _clearAllTextFields() {
    for (var controller in _inputControllers) {
      controller.clear();
    }
    for (var controller in _outputControllers) {
      controller.clear();
    }
    for (var controller in _hwTriggerControllers) {
      controller.clear();
    }
  }

  void _updateChartFromForm() {
    final List<SignalData> newChartSignals = [];
    int inputSignalCount = 0;
    int outputSignalCount = 0;
    int hwTriggerSignalCount = 0;

    // Input信号を収集
    for (int i = 0; i < _formState.inputCount; i++) {
      if (i < _inputControllers.length) {
        final name = _inputControllers[i].text.trim();
        if (name.isNotEmpty) {
          newChartSignals.add(
            SignalData(
              name: 'In${i + 1} : $name',
              color: Colors.blue,
              values: List.filled(_initialTimeSteps, 0),
            ),
          );
          inputSignalCount++;
        }
      }
    }

    // Output信号を収集
    for (int i = 0; i < _formState.outputCount; i++) {
      if (i < _outputControllers.length) {
        final name = _outputControllers[i].text.trim();
        if (name.isNotEmpty) {
          newChartSignals.add(
            SignalData(
              name: 'Out${i + 1} : $name',
              color: Colors.green,
              values: List.filled(_initialTimeSteps, 0),
            ),
          );
          outputSignalCount++;
        }
      }
    }

    // HW Trigger信号を収集
    for (int i = 0; i < _formState.hwPort; i++) {
      if (i < _hwTriggerControllers.length) {
        final name = _hwTriggerControllers[i].text.trim();
        if (name.isNotEmpty) {
          newChartSignals.add(
            SignalData(
              name: 'HW${i + 1} : $name',
              color: Colors.red,
              values: List.filled(_initialTimeSteps, 0),
            ),
          );
          hwTriggerSignalCount++;
        }
      }
    }

    setState(() {
      _chartSignals = newChartSignals;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _inputControllers) {
      controller.dispose();
    }
    for (var controller in _outputControllers) {
      controller.dispose();
    }
    for (var controller in _hwTriggerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // l10nのための S オブジェクトを取得
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(
        //backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Row(
          children: [
            SizedBox(
              width: 200, // メニューバーに十分な幅を確保
              child: MenuBar(
                children: [
                  SubmenuButton(
                    menuChildren: [
                      MenuItemButton(
                        onPressed: () => debugPrint('New'),
                        child: Text(s.menu_item_new), // ★ l10n
                      ),
                      MenuItemButton(
                        onPressed: () => debugPrint('Open'),
                        child: Text(s.menu_item_open), // ★ l10n
                      ),
                      MenuItemButton(
                        onPressed: () => debugPrint('Save'),
                        child: Text(s.menu_item_save), // ★ l10n
                      ),
                      MenuItemButton(
                        onPressed: () => debugPrint('Save As'),
                        child: Text(s.menu_item_save_as), // ★ l10n
                      ),
                    ],
                    child: Text(s.menu_file), // ★ l10n
                  ),
                  SubmenuButton(
                    menuChildren: [
                      MenuItemButton(
                        onPressed: () => debugPrint('Cut'),
                        child: Text(s.menu_item_cut), // ★ l10n
                      ),
                      MenuItemButton(
                        onPressed: () => debugPrint('Copy'),
                        child: Text(s.menu_item_copy), // ★ l10n
                      ),
                      MenuItemButton(
                        onPressed: () => debugPrint('Paste'),
                        child: Text(s.menu_item_paste), // ★ l10n
                      ),
                    ],
                    child: Text(s.menu_edit), // ★ l10n
                  ),
                  SubmenuButton(
                    menuChildren: [
                      MenuItemButton(
                        onPressed: () => debugPrint('About'),
                        child: Text(s.menu_item_about), // ★ l10n
                      ),
                    ],
                    child: Text(s.menu_help), // ★ l10n
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                s.appTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                ),
              ), // ★ l10nからタイトル取得
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontSize: 20),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 6.0,
          tabs: [
            Tab(
              text: s.formTabTitle,
              icon: Icon(Icons.input),
            ), // ★ l10nからタブタイトル取得
            Tab(
              text: s.chartTabTitle,
              icon: Icon(Icons.bar_chart),
            ), // ★ l10nからタブタイトル取得
          ],
        ),
        // --- メニューバーは title Row 内に移動済み ---
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- Form Tab ---
          FormTab(
            formState: _formState,
            inputControllers: _inputControllers,
            outputControllers: _outputControllers,
            hwTriggerControllers: _hwTriggerControllers,
            onTriggerOptionChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _formState = _formState.copyWith(triggerOption: newValue);
                });
              }
            },
            onIoPortChanged: (int? newValue) {
              if (newValue != null && newValue != _formState.ioPort) {
                setState(() {
                  _formState = _formState.copyWith(ioPort: newValue);
                  _updateInputOutputCounts(newValue);
                });
              }
            },
            onHwPortChanged: (int? newValue) {
              if (newValue != null && newValue != _formState.hwPort) {
                setState(() {
                  _formState = _formState.copyWith(hwPort: newValue);
                  _updateHwTriggerControllers();
                });
              }
            },
            onCameraChanged: (int? newValue) {
              if (newValue != null) {
                setState(() {
                  _formState = _formState.copyWith(camera: newValue);
                });
              }
            },
            onUpdateChart: _updateChartFromForm,
            onClearFields: _clearAllTextFields,
          ),

          // --- TimingChart Tab ---
          TimingChart(
            // ★ 修正: 以前のパラメータを削除し、新しい必須パラメータを設定
            // signals: _chartSignals,
            // annotations: _chartAnnotations,
            // cellWidth: _cellWidth,
            // cellHeight: _cellHeight,
            // timeSteps: _initialTimeSteps,

            // ★ _chartSignals (List<SignalData>) から必要なデータを抽出して渡す
            initialSignalNames: _chartSignals.map((s) => s.name).toList(),
            initialSignals: _chartSignals.map((s) => s.values).toList(),
            // ★ _chartAnnotations はそのまま渡せる
            initialAnnotations: _chartAnnotations,
            // ★ SignalType を _chartSignals から推定して渡す (簡易版)
            signalTypes:
                _chartSignals.map((s) {
                  if (s.name.startsWith('In')) return SignalType.input;
                  if (s.name.startsWith('HW')) return SignalType.hwTrigger;
                  if (s.name.startsWith('Out')) return SignalType.output;
                  return SignalType.input; // デフォルト
                }).toList(),
          ),
        ],
      ),
    );
  }
}
