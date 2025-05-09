import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 多言語対応に必要
//import 'package:provider/provider.dart'; // もし Provider を使う場合 (今回は使わない前提)

// ★ 作成した他のファイルをインポート
import 'generated/l10n.dart';
import 'models/form/form_state.dart';
import 'models/chart/signal_data.dart';
import 'models/chart/signal_type.dart';
import 'models/chart/timing_chart_annotation.dart';
import 'widgets/form/form_tab.dart';
import 'widgets/chart/timing_chart.dart';
// import 'widgets/chart/chart_signals.dart'; // SignalType を含むファイルをインポートから削除

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

  // タイミングチャートの参照を保持する変数を追加
  GlobalKey<TimingChartState> _timingChartKey = GlobalKey<TimingChartState>();

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

    // テストコメントは削除
    _chartAnnotations = [];
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

  // 信号タイプに応じた色を返す
  Color _getColorForSignalType(SignalType type) {
    switch (type) {
      case SignalType.input:
        return Colors.blue;
      case SignalType.output:
        return Colors.red;
      case SignalType.hwTrigger:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _toggleSingleSignalValue(int signalIndex, int timeIndex) {
    if (signalIndex < 0 || signalIndex >= _chartSignals.length) return;
    if (timeIndex < 0 || timeIndex >= _chartSignals[signalIndex].values.length)
      return;

    setState(() {
      final newValues = List<int>.from(_chartSignals[signalIndex].values);
      newValues[timeIndex] = newValues[timeIndex] == 0 ? 1 : 0;

      _chartSignals[signalIndex] = _chartSignals[signalIndex].copyWith(
        values: newValues,
      );

      // タイミングチャートの状態を更新
      if (_timingChartKey.currentState != null) {
        _timingChartKey.currentState!.updateSignals(
          _chartSignals.map((s) => s.values).toList(),
        );
      }
    });
  }

  void _addAnnotation(TimingChartAnnotation annotation) {
    setState(() {
      _chartAnnotations.add(annotation);

      // タイミングチャートの状態を更新
      if (_timingChartKey.currentState != null) {
        _timingChartKey.currentState!.updateAnnotations(_chartAnnotations);
      }
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
        iconTheme: IconThemeData(color: Colors.white), // ハンバーガーメニューの色を白に設定
        title: Text(
          s.appTitle,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ), // ★ l10nからタイトル取得
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
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                s.appTitle,
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            // File メニュー項目
            ListTile(
              leading: Icon(Icons.file_open),
              title: Text(s.menu_file),
              onTap: () {
                Navigator.pop(context);
                // ここにファイルメニューの動作を実装
              },
            ),
            // 新規
            ListTile(
              leading: Icon(Icons.add),
              title: Text(s.menu_item_new),
              onTap: () {
                Navigator.pop(context);
                debugPrint('New');
              },
            ),
            // 開く
            ListTile(
              leading: Icon(Icons.folder_open),
              title: Text(s.menu_item_open),
              onTap: () {
                Navigator.pop(context);
                debugPrint('Open');
              },
            ),
            // 保存
            ListTile(
              leading: Icon(Icons.save),
              title: Text(s.menu_item_save),
              onTap: () {
                Navigator.pop(context);
                debugPrint('Save');
              },
            ),
            // 名前を付けて保存
            ListTile(
              leading: Icon(Icons.save_as),
              title: Text(s.menu_item_save_as),
              onTap: () {
                Navigator.pop(context);
                debugPrint('Save As');
              },
            ),
            Divider(),
            // 編集メニュー項目
            ListTile(
              leading: Icon(Icons.edit),
              title: Text(s.menu_edit),
              onTap: () {
                Navigator.pop(context);
                // ここに編集メニューの動作を実装
              },
            ),
            // 切り取り
            ListTile(
              leading: Icon(Icons.content_cut),
              title: Text(s.menu_item_cut),
              onTap: () {
                Navigator.pop(context);
                debugPrint('Cut');
              },
            ),
            // コピー
            ListTile(
              leading: Icon(Icons.content_copy),
              title: Text(s.menu_item_copy),
              onTap: () {
                Navigator.pop(context);
                debugPrint('Copy');
              },
            ),
            // 貼り付け
            ListTile(
              leading: Icon(Icons.content_paste),
              title: Text(s.menu_item_paste),
              onTap: () {
                Navigator.pop(context);
                debugPrint('Paste');
              },
            ),
            Divider(),
            // ヘルプメニュー項目
            ListTile(
              leading: Icon(Icons.help),
              title: Text(s.menu_help),
              onTap: () {
                Navigator.pop(context);
                // ここにヘルプメニューの動作を実装
              },
            ),
            // About
            ListTile(
              leading: Icon(Icons.info),
              title: Text(s.menu_item_about),
              onTap: () {
                Navigator.pop(context);
                debugPrint('About');
              },
            ),
          ],
        ),
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
            onUpdateChart: (signalNames, chartData, signalTypes) {
              setState(() {
                // 既存の手動編集内容をマージ
                List<SignalData> newChartSignals = [];
                for (int i = 0; i < signalNames.length; i++) {
                  // 既存の_signalDataから同名の信号を探す
                  final existing = _chartSignals.firstWhere(
                    (s) => s.name == signalNames[i],
                    orElse:
                        () => SignalData(
                          name: signalNames[i],
                          signalType: signalTypes[i],
                          values: List.filled(
                            i < chartData.length ? chartData[i].length : 32,
                            0,
                          ),
                        ),
                  );
                  // 既存があれば手動編集内容を優先、なければ新規
                  newChartSignals.add(
                    SignalData(
                      name: signalNames[i],
                      signalType: signalTypes[i],
                      values:
                          existing.values.length ==
                                  (i < chartData.length
                                      ? chartData[i].length
                                      : 32)
                              ? existing.values
                              : List.filled(
                                i < chartData.length ? chartData[i].length : 32,
                                0,
                              ),
                    ),
                  );
                }
                _chartSignals = newChartSignals;

                // チャートウィジェットを更新
                if (_timingChartKey.currentState != null) {
                  _timingChartKey.currentState!.updateSignalNames(signalNames);
                  _timingChartKey.currentState!.updateSignals(
                    _chartSignals.map((s) => s.values).toList(),
                  );
                }
              });
            },
            onClearFields: _clearAllTextFields,
          ),

          // --- TimingChart Tab ---
          TimingChart(
            key: _timingChartKey,
            // ★ _chartSignals (List<SignalData>) から必要なデータを抽出して渡す
            initialSignalNames: _chartSignals.map((s) => s.name).toList(),
            initialSignals: _chartSignals.map((s) => s.values).toList(),
            // ★ _chartAnnotations はそのまま渡せる
            initialAnnotations: _chartAnnotations,
            // ★ SignalType を _chartSignals から取得して渡す
            signalTypes: _chartSignals.map((s) => s.signalType).toList(),
          ),
        ],
      ),
    );
  }
}
