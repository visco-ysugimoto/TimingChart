import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 多言語対応に必要
import 'package:flutter/scheduler.dart'; // SchedulerBinding用のインポート
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fontsを追加

// ★ 作成した他のファイルをインポート
import 'generated/l10n.dart';
import 'models/form/form_state.dart';
import 'models/chart/signal_data.dart';
import 'models/chart/timing_chart_annotation.dart';
import 'models/backup/app_config.dart'; // AppConfigをインポート
import 'utils/file_utils.dart'; // FileUtilsをインポート
import 'widgets/form/form_tab.dart';
import 'widgets/chart/timing_chart.dart';
import 'widgets/settings/settings_window.dart';
// import 'widgets/chart/chart_signals.dart'; // SignalType を含むファイルをインポートから削除

import 'providers/form_state_notifier.dart';
import 'providers/locale_notifier.dart'; // LocaleNotifierをインポート
import 'providers/settings_notifier.dart'; // SettingsNotifierをインポート
import 'suggestion_loader.dart';

// ==========================================================
// main.dart の概要と処理フロー
// 目的: Timing Chart Generator のエントリポイント。テーマ・多言語・状態管理を初期化し、
//       フォームタブとチャートタブ間のデータ同期／エクスポート・インポートを提供する。
// 主要構成:
// - Provider/MultiProvider: フォーム状態, コントローラ管理, ロケール, 設定
// - MyApp: テーマとローカライズの適用
// - MyHomePage(Stateful): 2つのタブ(FormTab/TimingChart)の表示と相互連携
// データの流れ(概要):
// 1) FormTabで入力 → onUpdateChart で _chartSignals/_chartPortNumbers を更新 → TimingChartへ反映
// 2) TimingChartで編集 → _syncChartDataToFormTab で FormTab に反映（名前順保持）
// 3) エクスポート時: チャートの最新値を FormTab に一旦反映 → AppConfigを作成 → 各種出力(JSON/XLSX/画像)
// 4) インポート時: AppConfigを読み込み → Providerと各コントローラを更新 → FormTab/TimingChartを復元
// UI更新の注意点:
// - build中に状態更新しないため、WidgetsBinding.addPostFrameCallback を使うヘルパー _scheduleFormUpdate を利用
// - コントローラの個数変更は Provider 更新と setState を同じポストフレームで実施して不整合を防止
// タブ遷移:
// - フォーム→チャート: 保存済みアノテーションを反映
// - チャート→フォーム: テキストフィールドのスクロール位置などを保つため、チャート→フォームの値同期は自動で行わない
// ==========================================================

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FormStateNotifier()),
        ChangeNotifierProvider(
          create: (_) => LocaleNotifier(),
        ), // LocaleNotifierを追加
        ChangeNotifierProvider(create: (_) => SettingsNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocaleNotifier, SettingsNotifier>(
      builder: (context, localeNotifier, settings, child) {
        final brightness =
            settings.darkMode ? Brightness.dark : Brightness.light;
        final baseTheme = ThemeData(brightness: brightness);
        return MaterialApp(
          title: 'Timing Chart Generator',
          theme: baseTheme.copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: settings.accentColor,
              brightness: brightness,
            ),
            scaffoldBackgroundColor: baseTheme.colorScheme.surface,
            textTheme: GoogleFonts.notoSansJpTextTheme(baseTheme.textTheme),
            appBarTheme: baseTheme.appBarTheme.copyWith(
              backgroundColor: settings.accentColor,
              titleTextStyle: GoogleFonts.notoSansJp(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
              filled: true,
              fillColor:
                  brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.white,
            ),
            dropdownMenuTheme: baseTheme.dropdownMenuTheme.copyWith(
              menuStyle: MenuStyle(
                backgroundColor: WidgetStateProperty.all(
                  brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.white,
                ),
              ),
            ),
          ),
          // --- 多言語対応設定 ---
          localizationsDelegates: const [
            S.delegate, // 生成されたローカライズデリゲート
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales, // サポートするロケール
          locale: localeNotifier.locale, // LocaleNotifierからlocaleを取得
          // ----------------------
          home: const MyHomePage(),
        );
      },
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

  // === GUI オプション ===
  // IO ラベルの末尾番号 (Input1 など) を表示するかどうか。
  bool _showIoNumbers = true;

  // フォームの状態
  List<TextEditingController> _inputControllers = [];
  List<TextEditingController> _outputControllers = [];
  List<TextEditingController> _hwTriggerControllers = [];

  // チャートの状態
  List<SignalData> _chartSignals = [];
  List<int> _chartPortNumbers = [];
  List<TimingChartAnnotation> _chartAnnotations = [];

  // タイミングチャートの参照を保持する変数を追加
  final GlobalKey<TimingChartState> _timingChartKey =
      GlobalKey<TimingChartState>();

  // フォームタブへの参照
  final GlobalKey<FormTabState> _formTabKey = GlobalKey<FormTabState>();

  // Provider から取得しやすくするためのゲッター
  FormStateNotifier get _formNotifier =>
      Provider.of<FormStateNotifier>(context, listen: false);

  // Provider 経由でフォーム状態を取得（listen:false）
  TimingFormState get _formState =>
      Provider.of<FormStateNotifier>(context, listen: false).state;

  // build 中に Provider の notifyListeners が発火しないよう、
  // フレーム終了後に更新をスケジュールするヘルパー
  void _scheduleFormUpdate(void Function(FormStateNotifier) edit) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) edit(_formNotifier);
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 初期ステートを Provider に設定
    final initial = const TimingFormState(
      triggerOption: 'Single Trigger',
      ioPort: 32,
      hwPort: 0,
      camera: 1,
      inputCount: 32,
      outputCount: 32,
    );

    _scheduleFormUpdate((n) => n.replace(initial));

    _initializeControllers(
      initial.inputCount,
      initial.outputCount,
      initial.hwPort,
    );

    // テストコメントは削除
    _chartAnnotations = [];

    // タブ切り替え時のリスナー登録
    _tabController.addListener(_handleTabChange);

    // 初期値を Provider に同期
    // initState では context が使えるため listen: false で呼び出し
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _formNotifier.replace(_formState);
    });
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
      // アノテーションを保存（チャートデータの同期は行わない）
      if (_timingChartKey.currentState != null) {
        _chartAnnotations = _timingChartKey.currentState!.getAnnotations();
      }

      // フォームタブに戻る際は、テキストフィールドの位置を保持するため
      // updateSignalDataFromChartDataは呼び出さない
      print("チャートタブからフォームタブに戻りました。テキストフィールドの位置を保持します。");
    }

    // フォームタブからチャートタブに移動する場合
    if (_tabController.previousIndex == 0 && _tabController.index == 1) {
      // 保存しておいたアノテーションを反映
      if (_timingChartKey.currentState != null) {
        _timingChartKey.currentState!.updateAnnotations(_chartAnnotations);
      }
    }
  }

  void _initializeControllers(int inputCount, int outputCount, int hwPort) {
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
      inputCount,
      (index) => TextEditingController(),
    );
    _outputControllers = List.generate(
      outputCount,
      (index) => TextEditingController(),
    );
    _hwTriggerControllers = List.generate(
      hwPort,
      (index) => TextEditingController(),
    );
  }

  void _updateInputControllers(int target) {
    if (_inputControllers.length > target) {
      for (int i = target; i < _inputControllers.length; i++) {
        _inputControllers[i].dispose();
      }
      _inputControllers = _inputControllers.sublist(0, target);
    } else if (_inputControllers.length < target) {
      _inputControllers.addAll(
        List.generate(
          target - _inputControllers.length,
          (_) => TextEditingController(),
        ),
      );
    }
  }

  void _updateOutputControllers(int target) {
    if (_outputControllers.length > target) {
      for (int i = target; i < _outputControllers.length; i++) {
        _outputControllers[i].dispose();
      }
      _outputControllers = _outputControllers.sublist(0, target);
    } else if (_outputControllers.length < target) {
      _outputControllers.addAll(
        List.generate(
          target - _outputControllers.length,
          (_) => TextEditingController(),
        ),
      );
    }
  }

  // --- 新規: Input Port のみ更新 ---
  void _updateInputCount(int inputPorts) {
    _scheduleFormUpdate((n) {
      // Provider を更新（ioPort は互換のため同時更新）
      n.update(ioPort: inputPorts, inputCount: inputPorts);

      // UI 更新
      setState(() {
        _updateInputControllers(inputPorts);
      });
    });
  }

  // --- 新規: Output Port のみ更新 ---
  void _updateOutputCount(int outputPorts) {
    _scheduleFormUpdate((n) {
      n.update(outputCount: outputPorts);

      setState(() {
        _updateOutputControllers(outputPorts);
      });
    });
  }

  void _updateHwTriggerControllers([int? desiredCount]) {
    final target = desiredCount ?? _formState.hwPort;

    if (_hwTriggerControllers.length > target) {
      for (int i = target; i < _hwTriggerControllers.length; i++) {
        _hwTriggerControllers[i].dispose();
      }
      _hwTriggerControllers = _hwTriggerControllers.sublist(0, target);
    } else if (_hwTriggerControllers.length < target) {
      _hwTriggerControllers.addAll(
        List.generate(
          target - _hwTriggerControllers.length,
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

    // === 追加: チャートデータとコメントもクリア ===
    setState(() {
      _chartSignals.clear();
      _chartPortNumbers.clear();
      _chartAnnotations.clear();
    });

    // チャートウィジェットを空データで更新
    if (_timingChartKey.currentState != null) {
      _timingChartKey.currentState!.updateSignalNames([]);
      _timingChartKey.currentState!.updateSignals([]);
      // コメント(アノテーション)もクリア
      _timingChartKey.currentState!.updateAnnotations([]);
    }
  }

  // AppConfigを現在の状態から作成
  Future<AppConfig> _createAppConfig() async {
    print("\n===== _createAppConfig (Chart first) =====");

    // 最新のアノテーションを保存
    _chartAnnotations =
        _timingChartKey.currentState?.getAnnotations() ?? _chartAnnotations;

    // フォームタブの最新データを取得
    List<SignalData> signalData = [];
    List<List<CellMode>> tableData = [];
    List<bool> inputVisibility = [];
    List<bool> outputVisibility = [];
    List<bool> hwTriggerVisibility = [];
    List<String> rowModes = [];

    if (_formTabKey.currentState != null) {
      // フォームタブからデータを取得
      signalData = _formTabKey.currentState!.getSignalDataList();
      tableData = _formTabKey.currentState!.getTableData();
      inputVisibility = _formTabKey.currentState!.getInputVisibility();
      outputVisibility = _formTabKey.currentState!.getOutputVisibility();
      hwTriggerVisibility = _formTabKey.currentState!.getHwTriggerVisibility();
      rowModes = _formTabKey.currentState!.getRowModes();
    }

    // --- 出力用 SignalData はチャートタブの順序をそのまま使用 ---
    if (_timingChartKey.currentState != null) {
      final orderedNames = _timingChartKey.currentState!.getSignalIdNames();
      final mapByName = {for (var s in _chartSignals) s.name: s};
      signalData = orderedNames.map((n) => mapByName[n]!).toList();
    } else {
      signalData = List<SignalData>.from(_chartSignals);
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
      rowModes: rowModes,
      annotations: _chartAnnotations,
      omissionIndices:
          _timingChartKey.currentState?.getOmissionTimeIndices() ?? const [],
    );
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
    // --- 先に TimingChart の最新値だけを FormTab に反映（名前位置は保持） ---
    if (_timingChartKey.currentState != null &&
        _formTabKey.currentState != null) {
      final chartData = _timingChartKey.currentState!.getChartData();
      _formTabKey.currentState!.setChartDataOnly(chartData);
    }

    // 1フレーム待って状態が反映されるのを待つ
    await SchedulerBinding.instance.endOfFrame;

    // エクスポート前の確認
    final shouldContinue = await _confirmExport();
    if (!shouldContinue) return;

    // チャートタブで表示中の場合は、最新のチャート値のみ FormTab に反映（名前位置は保持）
    if (_tabController.index == 1 && _timingChartKey.currentState != null) {
      final chartData = _timingChartKey.currentState!.getChartData();
      if (_formTabKey.currentState != null) {
        _formTabKey.currentState!.setChartDataOnly(chartData);
      }
    }

    // 1フレーム待ってからAppConfigを作成（状態が確実に反映されるように）
    await SchedulerBinding.instance.endOfFrame;

    // さらに1フレーム待ってからエクスポート処理を実行
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final config = await _createAppConfig();
      final success = await FileUtils.exportWaveDrom(
        config,
        annotations: _chartAnnotations,
        omissionIndices: _timingChartKey.currentState?.getOmissionTimeIndices(),
      );

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

    // Provider を更新
    _scheduleFormUpdate((n) => n.replace(config.formState));

    // コントローラー長を調整
    setState(() {
      _updateInputControllers(config.formState.inputCount);
      _updateOutputControllers(config.formState.outputCount);
      _updateHwTriggerControllers(config.formState.hwPort);
    });

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

      // --- チャートタブ側を復元 ---
      _chartAnnotations = config.annotations;

      // Signals (order) : use chartOrder if present else keep existing order
      if (config.annotations.isNotEmpty || config.omissionIndices.isNotEmpty) {
        if (_timingChartKey.currentState != null) {
          _timingChartKey.currentState!.updateAnnotations(_chartAnnotations);
          _timingChartKey.currentState!.setOmission(config.omissionIndices);
        }
      }
    });

    // 結果メッセージを表示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('インポートが完了しました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 旧PNGエクスポートは削除

  // チャート画像(JPEG)をエクスポート（背景はテーマ依存）
  Future<void> _exportChartImageJpeg() async {
    // チャート最新の描画を反映
    await SchedulerBinding.instance.endOfFrame;
    // ダーク/ライトから背景色を決定
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final bytes = await _timingChartKey.currentState?.captureChartJpeg(
      backgroundColor: bg,
      quality: 90,
    );
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('画像の生成に失敗しました')));
      return;
    }

    final ok = await FileUtils.exportJpegBytes(bytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'JPEG画像を保存しました' : '保存がキャンセルされました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // XLSX形式でエクスポート
  Future<void> _exportXlsx() async {
    try {
      // 最新のチャートデータを同期
      if (_timingChartKey.currentState != null &&
          _formTabKey.currentState != null) {
        final chartData = _timingChartKey.currentState!.getChartData();
        _formTabKey.currentState!.setChartDataOnly(chartData);
      }

      // 1フレーム待って状態を反映
      await SchedulerBinding.instance.endOfFrame;

      // IO情報を収集し、ID名をlabel名に変換
      print('=== IO Information: ID to Label conversion ===');

      // Input情報をID名からlabel名に変換
      List<String> inputNames = [];
      for (int i = 0; i < _inputControllers.length; i++) {
        final inputText = _inputControllers[i].text.trim();
        if (inputText.isNotEmpty) {
          final labelName = await labelOfId(inputText);
          print('Converting Input[$i]: $inputText -> $labelName');
          inputNames.add(labelName);
        } else {
          inputNames.add('');
        }
      }

      // Output情報をID名からlabel名に変換
      List<String> outputNames = [];
      for (int i = 0; i < _outputControllers.length; i++) {
        final outputText = _outputControllers[i].text.trim();
        if (outputText.isNotEmpty) {
          final labelName = await labelOfId(outputText);
          print('Converting Output[$i]: $outputText -> $labelName');
          outputNames.add(labelName);
        } else {
          outputNames.add('');
        }
      }

      // HW Trigger情報をID名からlabel名に変換
      List<String> hwTriggerNames = [];
      for (int i = 0; i < _hwTriggerControllers.length; i++) {
        final hwText = _hwTriggerControllers[i].text.trim();
        if (hwText.isNotEmpty) {
          final labelName = await labelOfId(hwText);
          print('Converting HW Trigger[$i]: $hwText -> $labelName');
          hwTriggerNames.add(labelName);
        } else {
          hwTriggerNames.add('');
        }
      }

      print('=== End IO conversion ===');

      // チャート信号データを収集し、ID名をlabel名に変換
      List<SignalData> signalData = [];

      if (_timingChartKey.currentState != null) {
        // チャートタブの順序でSignalDataを取得
        final orderedNames = _timingChartKey.currentState!.getSignalIdNames();
        final mapByName = {for (var s in _chartSignals) s.name: s};

        print('=== XLSX Export: ID to Label conversion ===');
        print('Ordered signal IDs: $orderedNames');

        // チャートで表示されている順序に従って SignalData を並び替え
        for (String signalId in orderedNames) {
          if (mapByName.containsKey(signalId)) {
            final originalSignal = mapByName[signalId]!;
            // ID名をlabel名に変換してSignalDataを作成
            final labelName = await labelOfId(signalId);
            print('Converting: $signalId -> $labelName');
            final modifiedSignal = originalSignal.copyWith(name: labelName);
            signalData.add(modifiedSignal);
          }
        }

        // チャートに無い新規信号があれば後ろに追加
        for (var signal in _chartSignals) {
          if (!orderedNames.contains(signal.name)) {
            final labelName = await labelOfId(signal.name);
            print('Converting additional signal: ${signal.name} -> $labelName');
            final modifiedSignal = signal.copyWith(name: labelName);
            signalData.add(modifiedSignal);
          }
        }

        print(
          'Final signal names for XLSX: ${signalData.map((s) => s.name).toList()}',
        );
        print('=== End conversion ===');
      } else {
        // チャートタブが使用されていない場合はlabelOfIdで変換
        for (var signal in _chartSignals) {
          final labelName = await labelOfId(signal.name);
          print('Converting from _chartSignals: ${signal.name} -> $labelName');
          final modifiedSignal = signal.copyWith(name: labelName);
          signalData.add(modifiedSignal);
        }
      }

      // XLSXエクスポートを実行
      final success = await FileUtils.exportXlsx(
        inputNames: inputNames,
        outputNames: outputNames,
        hwTriggerNames: hwTriggerNames,
        chartSignals: signalData,
      );

      // 結果メッセージを表示
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'XLSXファイルを保存しました' : 'ファイルの保存がキャンセルされました'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('XLSXエクスポート中にエラーが発生しました: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
        title: Text(s.appTitle), // ★ l10nからタイトル取得
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.language, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    Provider.of<LocaleNotifier>(context).locale.languageCode ==
                            'ja'
                        ? 'JP'
                        : Provider.of<LocaleNotifier>(
                          context,
                        ).locale.languageCode.toUpperCase(),
                    style: GoogleFonts.notoSansJp(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.notoSansJp(fontSize: 20),
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
                style: GoogleFonts.notoSansJp(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
            // チャート画像をエクスポート (JPEG)
            ListTile(
              leading: Icon(Icons.image_outlined),
              title: const Text('チャート画像をエクスポート (JPEG)'),
              onTap: () {
                Navigator.pop(context);
                _exportChartImageJpeg();
              },
            ),
            // XLSXエクスポート
            ListTile(
              leading: Icon(Icons.table_chart),
              title: const Text('XLSXエクスポート'),
              onTap: () {
                Navigator.pop(context);
                _exportXlsx();
              },
            ),
            Divider(),
            // 言語切替
            ListTile(
              leading: Icon(Icons.language),
              title: const Text('English'),
              onTap: () {
                setSuggestionLanguage(SuggestionLanguage.en);
                Provider.of<LocaleNotifier>(
                  context,
                  listen: false,
                ).setLocale(const Locale('en'));
                Navigator.pop(context);
                setState(() {});
              },
            ),
            ListTile(
              leading: Icon(Icons.language),
              title: const Text('日本語'),
              onTap: () {
                setSuggestionLanguage(SuggestionLanguage.ja);
                Provider.of<LocaleNotifier>(
                  context,
                  listen: false,
                ).setLocale(const Locale('ja'));
                Navigator.pop(context);
                setState(() {});
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.help),
              title: Text(s.menu_help),
              onTap: () {
                Navigator.pop(context);
                // ここにヘルプメニューの動作を実装
              },
            ),

            // 環境設定 (Preferences)
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('環境設定'), // TODO: l10n
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => SettingsWindow(
                          showIoNumbers: _showIoNumbers,
                          onShowIoNumbersChanged: (val) {
                            setState(() => _showIoNumbers = val);
                          },
                        ),
                  ),
                );
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
            inputControllers: _inputControllers,
            outputControllers: _outputControllers,
            hwTriggerControllers: _hwTriggerControllers,
            onTriggerOptionChanged: (String? newValue) {
              if (newValue != null) {
                // Provider に反映し、UI は自動リビルド
                _scheduleFormUpdate((n) => n.update(triggerOption: newValue));
              }
            },
            // Input Port 変更
            onInputPortChanged: (int? newValue) {
              if (newValue != null && newValue != _formState.inputCount) {
                _updateInputCount(newValue);
              }
            },
            // Output Port 変更
            onOutputPortChanged: (int? newValue) {
              if (newValue != null && newValue != _formState.outputCount) {
                _updateOutputCount(newValue);
              }
            },
            onHwPortChanged: (int? newValue) {
              if (newValue != null && newValue != _formState.hwPort) {
                // Provider への反映とコントローラリストのリサイズを
                // 同じポストフレームコールバック内で実行し、
                // 両者のタイミングずれによる RangeError を防ぐ
                _scheduleFormUpdate((n) {
                  // 1) Provider の状態を更新
                  n.update(hwPort: newValue);

                  // 2) コントローラリストをリサイズし、UI を再構築
                  setState(() => _updateHwTriggerControllers(newValue));
                });
              }
            },
            onCameraChanged: (int? newValue) {
              if (newValue != null) {
                _scheduleFormUpdate((n) => n.update(camera: newValue));
              }
            },
            onUpdateChart: (
              signalNames,
              chartData,
              signalTypes,
              portNumbers,
              bool overrideFlag,
            ) {
              setState(() {
                // --- 現在のチャート波形を取得（ユーザ編集後の最新状態を優先） ---
                Map<String, List<int>> existingValuesMap = {};
                if (_timingChartKey.currentState != null) {
                  final currentChartValues =
                      _timingChartKey.currentState!.getChartData();

                  // _chartSignals と表示行は同じ順序である前提
                  for (
                    int i = 0;
                    i < _chartSignals.length && i < currentChartValues.length;
                    i++
                  ) {
                    existingValuesMap[_chartSignals[i].name] =
                        currentChartValues[i];
                  }
                } else {
                  // フォールバック: これまで保持している値
                  for (var signal in _chartSignals) {
                    existingValuesMap[signal.name] = signal.values;
                  }
                }

                // ------- Signal 値の決定 -------
                List<SignalData> newChartSignals = [];

                for (int i = 0; i < signalNames.length; i++) {
                  List<int> signalValues;

                  if (overrideFlag) {
                    // Template など: 最新データで完全上書き
                    if (i < chartData.length) {
                      signalValues = List<int>.from(chartData[i]);
                    } else {
                      signalValues = List.filled(32, 0);
                    }
                  } else {
                    // Update Chart 等: 既存の手動調整を優先保持
                    if (existingValuesMap.containsKey(signalNames[i])) {
                      signalValues = List<int>.from(
                        existingValuesMap[signalNames[i]]!,
                      );

                      if (i < chartData.length &&
                          signalValues.length != chartData[i].length) {
                        if (signalValues.length < chartData[i].length) {
                          // 既存データが短い場合は伸ばす
                          signalValues.addAll(
                            List.filled(
                              chartData[i].length - signalValues.length,
                              0,
                            ),
                          );
                        } else if (signalValues.length > chartData[i].length) {
                          // 既存データが長い場合はチャート側を延長し、既存を保持
                          final int diff =
                              signalValues.length - chartData[i].length;
                          chartData[i].addAll(List.filled(diff, 0));
                          // signalValues はそのまま保持（切り詰めない）
                        }
                      }
                    } else if (i < chartData.length) {
                      signalValues = List<int>.from(chartData[i]);
                    } else {
                      signalValues = List.filled(32, 0);
                    }
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

                // === 追加: 既存の並び順を保持 (overrideFlag が false の場合のみ) ===
                if (!overrideFlag && _timingChartKey.currentState != null) {
                  final currentOrder =
                      _timingChartKey.currentState!.getSignalIdNames();

                  if (currentOrder.isNotEmpty) {
                    // name -> SignalData マップ
                    final mapByName = {
                      for (final s in _chartSignals) s.name: s,
                    };

                    final reordered = <SignalData>[];
                    for (final name in currentOrder) {
                      if (mapByName.containsKey(name)) {
                        reordered.add(mapByName[name]!);
                      }
                    }
                    // Chart に無い新規信号は後ろに追加
                    for (final s in _chartSignals) {
                      if (!currentOrder.contains(s.name)) {
                        reordered.add(s);
                      }
                    }

                    _chartSignals = reordered;
                  }
                }

                // --- ポート番号も並び替える ---
                final nameToPort = <String, int>{};
                for (
                  int i = 0;
                  i < signalNames.length && i < portNumbers.length;
                  i++
                ) {
                  nameToPort[signalNames[i]] = portNumbers[i];
                }

                _chartPortNumbers =
                    _chartSignals.map((s) => nameToPort[s.name] ?? 0).toList();

                // チャートウィジェットを更新
                if (_timingChartKey.currentState != null) {
                  final orderedNames =
                      _chartSignals.map((s) => s.name).toList();
                  _timingChartKey.currentState!.updateSignalNames(orderedNames);
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
            fitToScreen: true,
            showAllSignalTypes: true,
            showIoNumbers: _showIoNumbers,
            portNumbers: _chartPortNumbers,
          ),
        ],
      ),
    );
  }
}
