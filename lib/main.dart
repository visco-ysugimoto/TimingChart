/*
main.dart（アプリの入り口）

このファイルで分かること（初心者向けの道しるべ）
1) アプリ起動と初期化: Provider を使ってグローバル状態を準備し、runApp で描画開始
2) テーマと多言語: MaterialTheme + l10n を適用（英語/日本語切替）
3) 画面構成: 2つのタブ（FormTab / TimingChart）で入力と可視化を行う
4) データの流れ: FormTab ↔ TimingChart 間の同期、エクスポート/インポートの前後関係

基本的な操作の流れ
- フォームに信号名などを入力 → 「Update Chart」でチャートへ反映 → 必要ならエクスポート
- 既存設定(ZIP/ziq)を読み込む → 自動でフォーム/チャートに反映 → 必要なら編集してエクスポート

キーワードの簡単説明
- Provider: アプリ全体で共有したい状態（フォームの設定など）を購読・通知する仕組み
- TextEditingController: 各テキスト入力の現在値を保持し、UIと同期させる仕組み
- Post-frame コールバック: 画面の描画（build）完了直後に安全に状態を更新するための呼び出し
*/
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
import 'utils/vxvismgr_parser.dart';
import 'utils/vxvismgr_mapping_loader.dart';
import 'utils/csv_io_log_parser.dart';
import 'models/chart/signal_type.dart';
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
    // アプリ全体のテーマと言語設定を組み立てて返す
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

  // ziq(zip) から読み取ったファイル内容の保持先
  String? _vxVisMgrIniContent;
  String? _dioMonitorLogCsvContent;
  String? _plcDioMonitorLogCsvContent;
  // 解析結果: [StatusSignalSetting] の xxx.Enable=1 の xxx 一覧
  List<String> _enabledStatusSignals = [];
  // 解析結果: Enable=1 の構造一覧 (name, portNo[0] 等)
  List<StatusSignalSetting> _enabledSignalStructures = [];

  // name -> suggestionId のマッピング
  Map<String, String> _vxvisNameToSuggestionId = {};

  // 出力割り当て: Port.No 0 = n → outputIndex = n+1 に割り当て予定
  List<_OutputAssignment> _outputAssignments = [];

  // （デバッグ用出力は未使用のため削除）

  // ziq 読み込み・解析中インジケータ
  bool _isImportingZiq = false;

  Future<void> _applyOutputAssignments() async {
    // 必要な出力数を確保
    int maxIndex = 0;
    for (final a in _outputAssignments) {
      if (a.outputIndex1Based > maxIndex) maxIndex = a.outputIndex1Based;
    }
    if (maxIndex > _formState.outputCount) {
      _updateOutputCount(maxIndex);
      // コントローラ更新を待つ
      await SchedulerBinding.instance.endOfFrame;
    }

    setState(() {
      for (final a in _outputAssignments) {
        if (a.suggestionId.isEmpty) continue;
        final idx = a.outputIndex1Based - 1;
        if (idx >= 0 && idx < _outputControllers.length) {
          _outputControllers[idx].text = a.suggestionId;
        }
      }
    });
  }

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
    // ポイント: Provider には実アプリの初期設定（ポート数など）を入れておく
    final initial = const TimingFormState(
      triggerOption: 'Single Trigger',
      ioPort: 32,
      hwPort: 0,
      camera: 1,
      inputCount: 32,
      outputCount: 32,
    );

    _scheduleFormUpdate((n) => n.replace(initial));

    // 画面上のテキスト入力用コントローラ群も、初期値に合わせて数を揃える
    _initializeControllers(
      initial.inputCount,
      initial.outputCount,
      initial.hwPort,
    );

    // テストコメントは削除
    _chartAnnotations = [];

    // タブ切り替え時のリスナー登録
    // フォーム→チャート移動時にアノテーション反映、チャート→フォームでは位置保持などを行う
    _tabController.addListener(_handleTabChange);

    // 初期値を Provider に同期
    // 注意: build 中の状態更新を避けるため、フレーム終了後に実行
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
      // 重要: 新しいリストに置き換えず、同一インスタンスのまま短縮する
      _inputControllers.removeRange(target, _inputControllers.length);
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
      // 重要: 新しいリストに置き換えず、同一インスタンスのまま短縮する
      _outputControllers.removeRange(target, _outputControllers.length);
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
      // 重要: 新しいリストに置き換えず、同一インスタンスのまま短縮する
      _hwTriggerControllers.removeRange(target, _hwTriggerControllers.length);
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

    // === 追加: ドロップダウン（フォーム状態）も初期値に戻す ===
    _scheduleFormUpdate((n) {
      n.replace(
        const TimingFormState(
          triggerOption: 'Single Trigger',
          ioPort: 32,
          hwPort: 0,
          camera: 1,
          inputCount: 32,
          outputCount: 32,
        ),
      );
    });

    // コントローラ数も初期値へ再調整
    _updateInputControllers(32);
    _updateOutputControllers(32);
    _updateHwTriggerControllers(0);
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
    // ポイント: エクスポートは「チャートに見えている最新の波形」で出すため、
    //           FormTab にも最新データを一旦コピーしてから AppConfig を作る
    if (_timingChartKey.currentState != null &&
        _formTabKey.currentState != null) {
      final chartData = _timingChartKey.currentState!.getChartData();
      _formTabKey.currentState!.setChartDataOnly(chartData);
    }

    // 1フレーム待って状態が反映されるのを待つ
    await SchedulerBinding.instance.endOfFrame;

    // エクスポート前の確認
    // 入力が空などの場合、利用者に「Update Chart」実行を案内
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
    // （フレーム順序を分けることで、UI更新とファイル出力の競合を避ける）
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

    // 設定適用の前に Clear 相当を実行（テキスト/テーブル/ドロップダウン初期化）
    if (_formTabKey.currentState != null) {
      _formTabKey.currentState!.clearAllForImport();
    }

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
      // XLSX も画面に表示中の順序・波形をソースにする
      if (_timingChartKey.currentState != null &&
          _formTabKey.currentState != null) {
        final chartData = _timingChartKey.currentState!.getChartData();
        _formTabKey.currentState!.setChartDataOnly(chartData);
      }

      // 1フレーム待って状態を反映
      await SchedulerBinding.instance.endOfFrame;

      // IO情報を収集し、ID名をlabel名に変換（表示名として分かりやすく）
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
      // チャートタブの表示順を優先して並べ替える
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
    // l10nのための S オブジェクトを取得（画面テキストを多言語化するヘルパー）
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(
        //backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(color: Colors.white), // ハンバーガーメニューの色を白に設定
        title: Text(s.appTitle), // ★ l10nからタイトル取得（固定文言を直書きしない）
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
        // 2つのタブ（フォーム入力 / タイミングチャート）
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
      // サイドメニュー（インポート/エクスポート、言語切替、設定など）
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
            // インポート（前に保存した設定を読み込む）
            ListTile(
              leading: Icon(Icons.file_download),
              title: Text(s.drawer_import),
              onTap: () {
                Navigator.pop(context);
                _importConfig();
              },
            ),
            // インポート(ziq) - vxVisMgr.ini などを含む ZIP から解析して取り込む
            ListTile(
              leading: Icon(Icons.archive_outlined),
              title: Text(s.drawer_import_ziq),
              onTap: () async {
                Navigator.pop(context);
                final zipPath = await FileUtils.pickZiqAndConvertToZipPath();
                if (!mounted) return;
                if (zipPath == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(s.drawer_import_ziq_cancelled),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                setState(() => _isImportingZiq = true);
                // 解析前に Clear 相当を実行
                if (_formTabKey.currentState != null) {
                  _formTabKey.currentState!.clearAllForImport();
                }
                try {
                  final files = await FileUtils.readRequiredFilesFromZip(
                    zipPath,
                  );
                  if (!mounted) return;

                  // マッピングを読み込む（assets）
                  final mapping = await VxVisMgrMappingLoader.loadMapping();

                  setState(() {
                    _vxVisMgrIniContent = files['vxVisMgr.ini'];
                    _dioMonitorLogCsvContent = files['DioMonitorLog.csv'];
                    _plcDioMonitorLogCsvContent =
                        files['Plc_DioMonitorLog.csv'];
                    _vxvisNameToSuggestionId = mapping;
                    // ini を解析
                    if (_vxVisMgrIniContent == null) {
                      _enabledStatusSignals = [];
                      _enabledSignalStructures = [];
                      _outputAssignments = [];
                    } else {
                      // 1) まず IOActive を反映（Input/Output ポート数）
                      final ioActive = VxVisMgrParser.parseIOActive(
                        _vxVisMgrIniContent!,
                      );
                      if (ioActive != null) {
                        if (ioActive.pinPorts > 0 &&
                            ioActive.pinPorts != _formState.inputCount) {
                          _updateInputCount(ioActive.pinPorts);
                        }
                        if (ioActive.poutPorts > 0 &&
                            ioActive.poutPorts != _formState.outputCount) {
                          _updateOutputCount(ioActive.poutPorts);
                        }
                      }

                      final all = VxVisMgrParser.parseStatusSignalSettings(
                        _vxVisMgrIniContent!,
                      );
                      _enabledSignalStructures =
                          all.where((s) => s.enabled).toList();
                      _enabledStatusSignals =
                          _enabledSignalStructures.map((e) => e.name).toList();

                      // Port.No 0 をもつものだけを対象に、UI 用の割り当てを作成
                      _outputAssignments =
                          _enabledSignalStructures
                              .where((s) => s.portNoByIndex.containsKey(0))
                              .map((s) {
                                // INI の Port.No 0 = n は 0-based（Port1 は n=0）
                                // UI は 1-based で扱うため +1
                                final n0 = s.portNoByIndex[0]!; // 0-based
                                final outputIndex = n0 + 1; // UI 1-based index
                                final suggestionId =
                                    _vxvisNameToSuggestionId[s.name] ?? '';
                                return _OutputAssignment(
                                  name: s.name,
                                  suggestionId: suggestionId,
                                  portNo0: n0 + 1, // CSV 列参照用の 1-based
                                  outputIndex1Based: outputIndex,
                                );
                              })
                              .toList();

                      // 先に Output テキスト欄へラベルを反映（同期版）
                      // マッピングが無ければ INI の信号名を使用
                      for (final a in _outputAssignments) {
                        final idx = a.outputIndex1Based - 1;
                        if (idx >= 0 && idx < _outputControllers.length) {
                          _outputControllers[idx].text =
                              a.suggestionId.isNotEmpty
                                  ? a.suggestionId
                                  : a.name;
                        }
                      }

                      // [IOSetting] を解析して TriggerOption と PLC/EIP を反映
                      final ioSetting = VxVisMgrParser.parseIOSetting(
                        _vxVisMgrIniContent!,
                      );
                      if (ioSetting != null) {
                        // TriggerOption
                        final triggerOption =
                            ioSetting.triggerMode == 0
                                ? 'Code Trigger'
                                : 'Single Trigger';
                        _scheduleFormUpdate(
                          (n) => n.update(triggerOption: triggerOption),
                        );
                        // 入力欄の自動設定（Templateと同じ規則）
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          if (_formTabKey.currentState != null) {
                            // 入力名の自動設定のみ行う（テンプレゼロ波形での上書きを防止）
                            _formTabKey.currentState!
                                .applyInputNamesForTriggerOption();
                          }
                        });

                        // PLC / EIP (UseVirtualIO_on_Trigger: 0 => None, 1 => PLC)
                        final plcEip =
                            ioSetting.useVirtualIoOnTrigger == 1
                                ? 'PLC'
                                : 'None';
                        // FormTab へ反映（UI）
                        if (_formTabKey.currentState != null) {
                          _formTabKey.currentState!.setPlcEipOption(plcEip);
                        }

                        // === CSV ログを解析してチャートへ反映 ===
                        final csvText =
                            ioSetting.useVirtualIoOnTrigger == 1
                                ? _plcDioMonitorLogCsvContent
                                : _dioMonitorLogCsvContent;
                        if (csvText != null && csvText.isNotEmpty) {
                          // タイムライン（CSV行順）で IN/OUT を統合
                          final timeline = CsvIoLogParser.parseTimeline(
                            csvText,
                          );
                          // タイムスタンプから各ステップの継続時間[ms]を推定
                          final stepDurationsMs =
                              CsvIoLogParserTimestamps.inferStepDurationsMsFromTimeline(
                                timeline,
                              );
                          if (stepDurationsMs.isNotEmpty) {
                            final settings = Provider.of<SettingsNotifier>(
                              context,
                              listen: false,
                            );
                            // 平均 ms/step を設定（相対幅の合計がステップ数に一致するように）
                            final double avgMs =
                                stepDurationsMs
                                    .where((e) => e.isFinite && e > 0)
                                    .fold<double>(0.0, (a, b) => a + b) /
                                stepDurationsMs.length;
                            if (avgMs.isFinite && avgMs > 0) {
                              settings.msPerStep = avgMs;
                            }
                            settings.setStepDurationsMs(stepDurationsMs);
                          }

                          // === Output の取り込み（IN行では前回値を保持） ===
                          final int timeLength = timeline.entries.length;
                          // OUT 結果を後段で使うための一時保持領域（スコープ外に宣言）
                          final outNames = <String>[];
                          final outTypes = <SignalType>[];
                          final outPorts = <int>[];
                          final outValues = <List<int>>[];
                          if (timeLength > 0) {
                            int outputs = _formState.outputCount;
                            for (final a in _outputAssignments) {
                              if (a.outputIndex1Based > outputs)
                                outputs = a.outputIndex1Based;
                            }
                            List<List<int>> outChartRows = List.generate(
                              outputs,
                              (_) => List.filled(timeLength, 0),
                            );

                            for (final a in _outputAssignments) {
                              final outIdx = a.outputIndex1Based - 1;
                              final portK = a.portNo0; // 1-based
                              if (outIdx < 0 || outIdx >= outputs) continue;
                              for (int t = 0; t < timeLength; t++) {
                                final e = timeline.entries[t];
                                if (e.type == 'OUT') {
                                  final row = e.bits;
                                  // 右端が Port1（row は末尾空欄除外済み）
                                  final colIdx = row.length - portK;
                                  if (t < 3) {
                                    // デバッグ: 最初の数ステップで抽出位置と値を確認
                                    debugPrint(
                                      '[OUT map] name=${a.name} portK=$portK time#$t rowLen=${row.length} colIdx=$colIdx val=' +
                                          ((colIdx >= 0 &&
                                                  colIdx < row.length &&
                                                  row[colIdx] != 0)
                                              ? '1'
                                              : '0'),
                                    );
                                  }
                                  if (colIdx >= 0 && colIdx < row.length) {
                                    outChartRows[outIdx][t] =
                                        row[colIdx] != 0 ? 1 : 0;
                                  } else {
                                    outChartRows[outIdx][t] = 0;
                                  }
                                } else {
                                  // IN 行: 直前の OUT 値を維持
                                  outChartRows[outIdx][t] =
                                      t > 0 ? outChartRows[outIdx][t - 1] : 0;
                                }
                              }
                            }

                            // 一旦、OUT の結果を保持（後で IN と結合して一括反映）
                            for (int i = 0; i < outputs; i++) {
                              if (i >= _outputControllers.length) continue;
                              final name = _outputControllers[i].text.trim();
                              if (name.isEmpty) continue;
                              outNames.add(name);
                              outTypes.add(SignalType.output);
                              outPorts.add(i + 1);
                              outValues.add(outChartRows[i]);
                            }
                            // この場ではまだ FormTab へ反映しない（IN と結合して一回で反映する）
                            // === 追加: CSVで1を含む未マッピングのOUTポートを自動生成 ===
                            final assignedPortKs =
                                _outputAssignments
                                    .map((a) => a.portNo0)
                                    .toSet();
                            final int outPortCount = timeline.outPortCount;
                            if (outPortCount > 0) {
                              for (
                                int portK = 1;
                                portK <= outPortCount;
                                portK++
                              ) {
                                if (assignedPortKs.contains(portK)) continue;

                                int last = 0;
                                bool anyOne = false;
                                final series = List<int>.filled(timeLength, 0);

                                for (int t = 0; t < timeLength; t++) {
                                  final e = timeline.entries[t];
                                  if (e.type == 'OUT') {
                                    final row = e.bits;
                                    final colIdx =
                                        row.length - portK; // 右端が Port1
                                    final v =
                                        (colIdx >= 0 &&
                                                colIdx < row.length &&
                                                row[colIdx] != 0)
                                            ? 1
                                            : 0;
                                    last = v;
                                    series[t] = v;
                                    if (v == 1) anyOne = true;
                                  } else {
                                    // IN 行: 直前の OUT 値を維持
                                    series[t] = last;
                                  }
                                }

                                if (anyOne) {
                                  final name = 'Output$portK';
                                  outNames.add(name);
                                  outTypes.add(SignalType.output);
                                  outPorts.add(portK);
                                  outValues.add(series);
                                }
                              }
                            }
                          }

                          // === Input の取り込み（OUT行では0を出力） ===
                          final int inTime = timeline.entries.length;
                          if (inTime > 0 && _formTabKey.currentState != null) {
                            final int inputs = _formState.inputCount;

                            if (triggerOption == 'Code Trigger' &&
                                _inputControllers.isNotEmpty) {
                              _inputControllers[0].text = 'TRIGGER';
                            }

                            List<List<int>> inChart = [];
                            List<String> inNames = [];
                            List<SignalType> inTypes = [];

                            for (int idx0 = 0; idx0 < inputs; idx0++) {
                              if (idx0 >= _inputControllers.length) continue;
                              final name = _inputControllers[idx0].text.trim();
                              if (name.isEmpty) continue;
                              List<int> series = List.filled(inTime, 0);
                              for (int t = 0; t < inTime; t++) {
                                final e = timeline.entries[t];
                                if (e.type == 'IN') {
                                  final row = e.bits;
                                  // 右端が Input1。CSV末尾の空欄は除外済み
                                  final col = row.length - (idx0 + 1);
                                  if (col >= 0 && col < row.length) {
                                    series[t] = row[col] != 0 ? 1 : 0;
                                  }
                                } else {
                                  // OUT 行: 常に 0
                                  series[t] = 0;
                                }
                              }
                              inChart.add(series);
                              inNames.add(name);
                              inTypes.add(SignalType.input);
                            }
                            // === IN と OUT を結合して一回で FormTab へ反映（表示順: CODE_OPTION → Command Option → Input → HW Trigger → Output） ===
                            final combinedValues = <List<int>>[];
                            final combinedNames = <String>[];
                            final combinedTypes = <SignalType>[];

                            // 1) CODE_OPTION を最上段（存在すれば）。無ければ0波形で追加（Code Trigger のヘッダ表示用）
                            int idxCode = inNames.indexOf('CODE_OPTION');
                            if (idxCode != -1) {
                              combinedNames.add(inNames[idxCode]);
                              combinedTypes.add(inTypes[idxCode]);
                              combinedValues.add(inChart[idxCode]);
                            } else {
                              if (triggerOption == 'Code Trigger') {
                                combinedNames.add('CODE_OPTION');
                                combinedTypes.add(SignalType.input);
                                combinedValues.add(
                                  List<int>.filled(timeLength, 0),
                                );
                              }
                            }
                            // 2) Command Option を次段（存在すれば）
                            int idxCmd = inNames.indexOf('Command Option');
                            if (idxCmd != -1) {
                              combinedNames.add(inNames[idxCmd]);
                              combinedTypes.add(inTypes[idxCmd]);
                              combinedValues.add(inChart[idxCmd]);
                            }
                            // 3) 残りの Input
                            for (int i = 0; i < inNames.length; i++) {
                              if (i == idxCode || i == idxCmd) continue;
                              combinedNames.add(inNames[i]);
                              combinedTypes.add(inTypes[i]);
                              combinedValues.add(inChart[i]);
                            }

                            // 4) HW Trigger（CSVに依存しないため 0 波形で配置）
                            if (_formState.hwPort > 0) {
                              for (int j = 0; j < _formState.hwPort; j++) {
                                final hwName =
                                    (j < _hwTriggerControllers.length)
                                        ? _hwTriggerControllers[j].text.trim()
                                        : '';
                                if (hwName.isEmpty) continue;
                                combinedNames.add(hwName);
                                combinedTypes.add(SignalType.hwTrigger);
                                combinedValues.add(
                                  List<int>.filled(timeLength, 0),
                                );
                              }
                            }

                            // 5) Output（存在すれば）
                            if (timeLength > 0) {
                              for (int i = 0; i < _formState.outputCount; i++) {
                                final name =
                                    (i < _outputControllers.length)
                                        ? _outputControllers[i].text.trim()
                                        : '';
                                if (name.isEmpty) continue;
                                final idxInOut = outNames.indexOf(name);
                                if (idxInOut != -1) {
                                  combinedNames.add(name);
                                  combinedTypes.add(SignalType.output);
                                  combinedValues.add(outValues[idxInOut]);
                                }
                              }
                            }

                            // 5.5) フォーム未設定の追加出力（CSVで1を含んだポート）
                            for (int i = 0; i < outNames.length; i++) {
                              final name = outNames[i];
                              if (!combinedNames.contains(name)) {
                                final values = outValues[i];
                                if (values.any((v) => v != 0)) {
                                  combinedNames.add(name);
                                  combinedTypes.add(SignalType.output);
                                  combinedValues.add(values);
                                }
                              }
                            }

                            if (combinedNames.isNotEmpty) {
                              // デバッグ: 反映直前の要約
                              debugPrint(
                                '[COMBINED] names=${combinedNames.length}, valuesRows=${combinedValues.length}, anyNonZero=${combinedValues.any((r) => r.any((v) => v != 0))}',
                              );

                              // FormTab 側の実データにも保存（エクスポートや復元に備える）
                              if (_formTabKey.currentState != null) {
                                _formTabKey.currentState!.setChartDataOnly(
                                  combinedValues,
                                );
                              }

                              // メイン側の初期表示用データも同期（タブ切替時に使用）
                              setState(() {
                                final syncedSignals = <SignalData>[];
                                final syncedPorts = <int>[];

                                // 入力/出力/HW の名前→ポート番号マップを用意
                                final inputNameToPort = <String, int>{
                                  for (int i = 0; i < inNames.length; i++)
                                    inNames[i]: i + 1,
                                };
                                final outputNameToPort = <String, int>{
                                  for (int i = 0; i < outNames.length; i++)
                                    outNames[i]: outPorts[i],
                                };
                                final hwNameToPort = <String, int>{
                                  for (int i = 0; i < _formState.hwPort; i++)
                                    if (i < _hwTriggerControllers.length &&
                                        _hwTriggerControllers[i].text
                                            .trim()
                                            .isNotEmpty)
                                      _hwTriggerControllers[i].text.trim():
                                          i + 1,
                                };

                                for (int i = 0; i < combinedNames.length; i++) {
                                  final name = combinedNames[i];
                                  final type = combinedTypes[i];
                                  final vals = combinedValues[i];
                                  syncedSignals.add(
                                    SignalData(
                                      name: name,
                                      signalType: type,
                                      values: vals,
                                      isVisible: true,
                                    ),
                                  );

                                  int portNum = 0;
                                  switch (type) {
                                    case SignalType.output:
                                      portNum = outputNameToPort[name] ?? 0;
                                      break;
                                    case SignalType.input:
                                      // CODE_OPTION/Command Option は 0、その他は入力欄のインデックス+1
                                      if (name != 'CODE_OPTION' &&
                                          name != 'Command Option') {
                                        portNum = inputNameToPort[name] ?? 0;
                                      }
                                      break;
                                    case SignalType.hwTrigger:
                                      portNum = hwNameToPort[name] ?? 0;
                                      break;
                                    default:
                                      portNum = 0;
                                  }
                                  syncedPorts.add(portNum);
                                }
                                _chartSignals = syncedSignals;
                                _chartPortNumbers = syncedPorts;
                              });
                              _formTabKey.currentState!
                                  .updateSignalDataFromChartData(
                                    combinedValues,
                                    combinedNames,
                                    combinedTypes,
                                  );
                              // 既存データの破壊を避けるため、ここでは updateChartData は呼ばない
                              if (_timingChartKey.currentState != null) {
                                _timingChartKey.currentState!.updateSignalNames(
                                  combinedNames,
                                );
                                _timingChartKey.currentState!.updateSignals(
                                  combinedValues,
                                );
                              }
                            }
                          }
                        }
                      }
                    }
                  });

                  final foundIni = _vxVisMgrIniContent != null ? 'OK' : 'なし';
                  final foundDio =
                      _dioMonitorLogCsvContent != null ? 'OK' : 'なし';
                  final foundPlc =
                      _plcDioMonitorLogCsvContent != null ? 'OK' : 'なし';

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'ZIP解析完了  vxVisMgr.ini:$foundIni  DioMonitorLog.csv:$foundDio  Plc_DioMonitorLog.csv:$foundPlc  EnabledSignals:${_enabledStatusSignals.length}  OutputMap:${_outputAssignments.length}',
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );

                  // Output テキストフィールドに suggestion id を自動入力
                  await _applyOutputAssignments();
                } finally {
                  if (mounted) setState(() => _isImportingZiq = false);
                }
              },
            ),
            // エクスポート
            ListTile(
              leading: Icon(Icons.file_upload),
              title: Text(s.drawer_export),
              onTap: () {
                Navigator.pop(context);
                _exportConfig();
              },
            ),
            // チャート画像をエクスポート (JPEG)
            ListTile(
              leading: Icon(Icons.image_outlined),
              title: Text(s.drawer_export_chart_jpeg),
              onTap: () {
                Navigator.pop(context);
                _exportChartImageJpeg();
              },
            ),
            // XLSXエクスポート
            ListTile(
              leading: Icon(Icons.table_chart),
              title: Text(s.drawer_export_xlsx),
              onTap: () {
                Navigator.pop(context);
                _exportXlsx();
              },
            ),
            Divider(),
            // 言語切替
            ListTile(
              leading: Icon(Icons.language),
              title: Text(s.language_english),
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
              title: Text(s.language_japanese),
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
              title: Text(s.drawer_preferences),
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
      body: Stack(
        children: [
          TabBarView(
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
                    _scheduleFormUpdate(
                      (n) => n.update(triggerOption: newValue),
                    );
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
                        i < _chartSignals.length &&
                            i < currentChartValues.length;
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
                            } else if (signalValues.length >
                                chartData[i].length) {
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
                        _chartSignals
                            .map((s) => nameToPort[s.name] ?? 0)
                            .toList();

                    // チャートウィジェットを更新
                    if (_timingChartKey.currentState != null) {
                      final orderedNames =
                          _chartSignals.map((s) => s.name).toList();
                      _timingChartKey.currentState!.updateSignalNames(
                        orderedNames,
                      );
                      _timingChartKey.currentState!.updateSignals(
                        _chartSignals.map((s) => s.values).toList(),
                      );
                    }
                  });
                },
                onClearFields: () {
                  _clearAllTextFields();
                  // グリッド調整も初期化（非等間隔のドラッグ調整をリセット）
                  if (_timingChartKey.currentState != null) {
                    _timingChartKey.currentState!.resetGridAdjustments();
                  }
                },
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
          if (_isImportingZiq)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'インポート中... しばらくお待ちください',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OutputAssignment {
  final String name;
  final String suggestionId;
  final int portNo0; // 0-based from ini
  final int outputIndex1Based; // n+1

  const _OutputAssignment({
    required this.name,
    required this.suggestionId,
    required this.portNo0,
    required this.outputIndex1Based,
  });
}
