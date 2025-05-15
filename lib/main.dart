import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 多言語対応に必要
import 'package:flutter/scheduler.dart'; // SchedulerBinding用のインポート
import 'dart:io';
import 'dart:async';
//import 'package:provider/provider.dart'; // もし Provider を使う場合 (今回は使わない前提)

// ★ 作成した他のファイルをインポート
import 'generated/l10n.dart';
import 'models/form/form_state.dart';
import 'models/chart/signal_data.dart';
import 'models/chart/signal_type.dart';
import 'models/chart/timing_chart_annotation.dart';
import 'models/backup/app_config.dart'; // AppConfigをインポート
import 'utils/file_utils.dart'; // FileUtilsをインポート
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

  // タイミングチャートの参照を保持する変数を追加
  GlobalKey<TimingChartState> _timingChartKey = GlobalKey<TimingChartState>();

  // フォームタブへの参照
  GlobalKey<FormTabState> _formTabKey = GlobalKey<FormTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _formState = TimingFormState(
      triggerOption: 'Single Trigger',
      ioPort: 32,
      hwPort: 0,
      camera: 1,
      inputCount: 32,
      outputCount: 32,
    );
    _initializeControllers();

    // テストコメントは削除
    _chartAnnotations = [];

    // タブ切り替え時のリスナー登録
    _tabController.addListener(_handleTabChange);
  }

  // タブ切り替え時の処理
  void _handleTabChange() {
    print("=== タブ移動検知 ===");
    print(
      "previousIndex: ${_tabController.previousIndex}, currentIndex: ${_tabController.index}",
    );

    // フォーム・チャートの主要パラメータを出力
    print("--- _formState ---");
    print("triggerOption: ${_formState.triggerOption}");
    print("ioPort: ${_formState.ioPort}");
    print("hwPort: ${_formState.hwPort}");
    print("camera: ${_formState.camera}");
    print("inputCount: ${_formState.inputCount}");
    print("outputCount: ${_formState.outputCount}");

    print("--- _chartSignals ---");
    for (var s in _chartSignals) {
      print(
        "name: ${s.name}, type: ${s.signalType}, values: ${s.values.take(10)}...",
      );
    }

    print("--- _inputControllers ---");
    for (int i = 0; i < _inputControllers.length; i++) {
      print("input[$i]: ${_inputControllers[i].text}");
    }
    print("--- _outputControllers ---");
    for (int i = 0; i < _outputControllers.length; i++) {
      print("output[$i]: ${_outputControllers[i].text}");
    }
    print("--- _hwTriggerControllers ---");
    for (int i = 0; i < _hwTriggerControllers.length; i++) {
      print("hwTrigger[$i]: ${_hwTriggerControllers[i].text}");
    }

    // チャートタブからフォームタブに戻る場合
    if (_tabController.previousIndex == 1 && _tabController.index == 0) {
      // チャートデータをフォームタブに同期
      _syncChartDataToFormTab();

      // ビルドサイクルを待ってからAppConfigを作成
      Future.delayed(Duration(milliseconds: 100), () async {
        await SchedulerBinding.instance.endOfFrame;

        // 再度同期を実行（確実に最新の状態を取得するため）
        if (_timingChartKey.currentState != null) {
          final chartData = _timingChartKey.currentState!.getChartData();
          if (_formTabKey.currentState != null) {
            _formTabKey.currentState!.updateSignalDataFromChartData(
              chartData,
              _chartSignals.map((s) => s.name).toList(),
              _chartSignals.map((s) => s.signalType).toList(),
            );
          }
        }

        // さらに1フレーム待ってからAppConfigを更新
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final config = _createAppConfig();
          // ここでAppConfigを更新する処理を追加
          setState(() {
            _formState = config.formState;
            _chartSignals = config.signals;
          });
        });
      });
    }
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

  // AppConfigを現在の状態から作成
  AppConfig _createAppConfig() {
    print("\n===== _createAppConfig =====");

    // チャートタブでの編集内容をフォームタブに同期
    if (_timingChartKey.currentState != null &&
        _formTabKey.currentState != null) {
      print("エクスポート前にチャートデータをFormTabに強制同期します");
      final chartData = _timingChartKey.currentState!.getChartData();
      _formTabKey.currentState!.updateSignalDataFromChartData(
        chartData,
        _chartSignals.map((s) => s.name).toList(),
        _chartSignals.map((s) => s.signalType).toList(),
      );
    }

    // ビルドフェーズが完了するのを待つ
    Future<void> wait = Future.delayed(Duration.zero);
    wait.then((_) => print("ビルドフェーズが完了しました"));

    // フォームタブの最新データを取得
    List<SignalData> signalData = [];
    List<List<CellMode>> tableData = [];
    List<bool> inputVisibility = [];
    List<bool> outputVisibility = [];
    List<bool> hwTriggerVisibility = [];

    if (_formTabKey.currentState != null) {
      // フォームタブからデータを取得
      signalData = _formTabKey.currentState!.getSignalDataList();
      tableData = _formTabKey.currentState!.getTableData();
      inputVisibility = _formTabKey.currentState!.getInputVisibility();
      outputVisibility = _formTabKey.currentState!.getOutputVisibility();
      hwTriggerVisibility = _formTabKey.currentState!.getHwTriggerVisibility();

      // FormTabから取得したデータを確認
      print("FormTabから取得した信号データ数: ${signalData.length}");
      if (signalData.isNotEmpty) {
        print("最初の信号値: ${signalData[0].values.take(10)}...");
        print(
          "非ゼロ値を含む: ${signalData.any((signal) => signal.values.any((val) => val != 0))}",
        );
      }
    }

    print("最終的に使用する信号データ数: ${signalData.length}");
    if (signalData.isNotEmpty) {
      print(
        "非ゼロ値を含む: ${signalData.any((signal) => signal.values.any((val) => val != 0))}",
      );
    }
    print("===== _createAppConfig 終了 =====\n");

    return AppConfig.fromCurrentState(
      formState: _formState,
      signals: signalData,
      tableData: tableData,
      inputControllers: _inputControllers,
      outputControllers: _outputControllers,
      hwTriggerControllers: _hwTriggerControllers,
      inputVisibility: inputVisibility,
      outputVisibility: outputVisibility,
      hwTriggerVisibility: hwTriggerVisibility,
    );
  }

  // チャートでの編集内容をフォームタブに反映する
  void _syncChartDataToFormTab() {
    if (_timingChartKey.currentState != null &&
        _formTabKey.currentState != null) {
      // チャートデータを取得
      final chartData = _timingChartKey.currentState!.getChartData();

      // デバッグ出力
      print("===== _syncChartDataToFormTab =====");
      print("チャートデータ行数: ${chartData.length}");
      if (chartData.isNotEmpty) {
        print("データ内容: ${chartData[0].take(10)}...");
        print("非ゼロ値を含む: ${chartData.any((row) => row.any((val) => val != 0))}");
      }

      // FormTabの信号データを更新
      _formTabKey.currentState!.updateSignalDataFromChartData(
        chartData,
        _chartSignals.map((s) => s.name).toList(),
        _chartSignals.map((s) => s.signalType).toList(),
      );
    }
  }

  // エクスポート前に「Update Chart」ボタンを自動的に押すことを推奨するダイアログを表示
  Future<bool> _confirmExport() async {
    print("===== _confirmExport =====");
    print("現在のタブインデックス: ${_tabController.index}");

    // チャートタブに表示されている場合は確認なしで続行
    if (_tabController.index == 1 && _timingChartKey.currentState != null) {
      List<List<int>> chartData = _timingChartKey.currentState!.getChartData();
      print("チャートタブのデータ行数: ${chartData.length}");
      if (chartData.isNotEmpty) {
        print("データ内容: ${chartData[0].take(10)}...");
        final hasNonZero = chartData.any(
          (row) => row.any((value) => value != 0),
        );
        print("非ゼロ値を含む: $hasNonZero");

        if (hasNonZero) {
          return true; // チャートタブでデータがある場合は確認なしで続行
        }
      }
    }

    List<SignalData> signalData = [];

    if (_formTabKey.currentState != null) {
      // フォームタブからデータを取得
      signalData = _formTabKey.currentState!.getSignalDataList();
    }

    if (signalData.isEmpty ||
        !signalData.any((signal) => signal.values.any((value) => value != 0))) {
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

    // チャートタブでの編集内容をフォームタブに同期
    _syncChartDataToFormTab();

    // ビルドサイクルを待ってからAppConfigを作成
    await Future.delayed(Duration(milliseconds: 100)); // 短い遅延を追加
    await SchedulerBinding.instance.endOfFrame; // フレーム終了を待つ

    // 再度同期を実行（確実に最新の状態を取得するため）
    if (_tabController.index == 1 && _timingChartKey.currentState != null) {
      final chartData = _timingChartKey.currentState!.getChartData();
      if (_formTabKey.currentState != null) {
        _formTabKey.currentState!.updateSignalDataFromChartData(
          chartData,
          _chartSignals.map((s) => s.name).toList(),
          _chartSignals.map((s) => s.signalType).toList(),
        );
      }
    }

    // さらに1フレーム待ってからエクスポート処理を実行
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final config = _createAppConfig();
      final success = await FileUtils.exportAppConfig(config);

      // 結果メッセージを表示
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'JSONファイルを保存しました' : 'ファイルの保存がキャンセルされました'),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  // エクスポート設定をインポート
  Future<void> _importConfig() async {
    final config = await FileUtils.importAppConfig();

    if (config == null) return;

    // 状態を更新
    setState(() {
      // フォーム状態を更新
      _formState = config.formState;

      // コントローラーを更新
      _updateInputOutputCounts(_formState.ioPort);
      _updateHwTriggerControllers();

      // テキストを設定
      for (
        int i = 0;
        i < config.inputNames.length && i < _inputControllers.length;
        i++
      ) {
        _inputControllers[i].text = config.inputNames[i];
      }

      for (
        int i = 0;
        i < config.outputNames.length && i < _outputControllers.length;
        i++
      ) {
        _outputControllers[i].text = config.outputNames[i];
      }

      for (
        int i = 0;
        i < config.hwTriggerNames.length && i < _hwTriggerControllers.length;
        i++
      ) {
        _hwTriggerControllers[i].text = config.hwTriggerNames[i];
      }

      // FormTabを更新（ビルド後に実行）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_formTabKey.currentState != null) {
          _formTabKey.currentState!.updateFromAppConfig(config);
        }
      });
    });

    // 結果メッセージを表示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('インポートが完了しました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
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
            // インポート
            ListTile(
              leading: Icon(Icons.file_upload),
              title: Text('インポート'),
              onTap: () {
                Navigator.pop(context);
                _importConfig();
              },
            ),
            // エクスポート
            ListTile(
              leading: Icon(Icons.file_download),
              title: Text('エクスポート'),
              onTap: () {
                Navigator.pop(context);
                _exportConfig();
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
            key: _formTabKey,
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

                // 既存の値をマップに格納して名前で検索できるようにする
                Map<String, List<int>> existingValuesMap = {};
                for (var signal in _chartSignals) {
                  existingValuesMap[signal.name] = signal.values;
                }

                for (int i = 0; i < signalNames.length; i++) {
                  // 既存のデータがあれば再利用、なければ新規作成
                  List<int> signalValues;

                  if (existingValuesMap.containsKey(signalNames[i]) &&
                      existingValuesMap[signalNames[i]]!.any((v) => v != 0)) {
                    // 既存の非ゼロデータがある場合は保持
                    print("既存の信号データを保持: ${signalNames[i]}");
                    signalValues = existingValuesMap[signalNames[i]]!;

                    // 長さの調整が必要な場合
                    if (i < chartData.length &&
                        signalValues.length != chartData[i].length) {
                      if (signalValues.length < chartData[i].length) {
                        // 足りない分を0で埋める
                        signalValues.addAll(
                          List.filled(
                            chartData[i].length - signalValues.length,
                            0,
                          ),
                        );
                      } else {
                        // 長すぎる場合は切り詰める
                        signalValues = signalValues.sublist(
                          0,
                          chartData[i].length,
                        );
                      }
                    }
                  } else {
                    // 新規信号または値が全て0の信号の場合は新しい値を使用
                    signalValues =
                        i < chartData.length
                            ? List.from(chartData[i])
                            : List.filled(32, 0);
                  }

                  newChartSignals.add(
                    SignalData(
                      name: signalNames[i],
                      signalType: signalTypes[i],
                      values: signalValues,
                      isVisible: true,
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
            showImportExportButtons: false, // インポート/エクスポートボタンを非表示
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
