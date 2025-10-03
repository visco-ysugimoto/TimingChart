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
import 'dart:io' as io;

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
import 'models/chart/io_channel_source.dart';
// import 'widgets/chart/chart_signals.dart'; // SignalType を含むファイルをインポートから削除

import 'providers/form_state_notifier.dart';
import 'providers/form_controllers_notifier.dart';
import 'providers/locale_notifier.dart'; // LocaleNotifierをインポート
import 'providers/settings_notifier.dart'; // SettingsNotifierをインポート
import 'suggestion_loader.dart';
import 'providers/timing_chart_controller.dart';
import 'dart:math' as math;
// import 'utils/chart_template_engine.dart';
// import 'utils/csv_io_log_parser.dart';
// import 'utils/wavedrom_converter.dart';

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

// --- テストモード用 dart-define ---
const bool kZiqImportTest = bool.fromEnvironment(
  'ZIQ_IMPORT_TEST',
  defaultValue: false,
);
const String kZiqPath = String.fromEnvironment('ZIQ_PATH', defaultValue: '');

Future<void> main() async {
  if (kZiqImportTest) {
    WidgetsFlutterBinding.ensureInitialized();
    await _runZiqImportTestMode();
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FormStateNotifier()),
        ChangeNotifierProvider(create: (_) => FormControllersNotifier()),
        ChangeNotifierProvider(
          create: (_) => LocaleNotifier(),
        ), // LocaleNotifierを追加
        ChangeNotifierProvider(create: (_) => SettingsNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _runZiqImportTestMode() async {
  try {
    final String path =
        kZiqPath.isNotEmpty
            ? kZiqPath
            : (await FileUtils.pickZiqAndConvertToZipPath() ?? '');
    if (path.isEmpty) {
      debugPrint('ZIQ_IMPORT_TEST: ziq のパスが指定されていません（キャンセル）');
      io.exit(2);
    }

    final files = await FileUtils.readRequiredFilesFromZip(path);
    final ini = files['vxVisMgr.ini'];
    final dio = files['DioMonitorLog.csv'];
    final plc = files['Plc_DioMonitorLog.csv'];
    final fnl = files['FNL_DioMonitorLog.csv'];

    // サマリ出力
    // NOTE: .ziq は ZIP 互換。拡張子が .ziq のままでも解析可能
    // （FileUtils.readRequiredFilesFromZip は拡張子に依存せず中身で判定）
    //
    // 出力は人間が読むことを想定
    print('ZIQ_IMPORT_TEST: "$path" を読み込みました');
    print(' - vxVisMgr.ini: ${ini != null ? 'OK' : 'MISSING'}');
    print(' - DioMonitorLog.csv: ${dio != null ? 'OK' : 'MISSING'}');
    print(' - Plc_DioMonitorLog.csv: ${plc != null ? 'OK' : 'MISSING'}');
    print(' - FNL_DioMonitorLog.csv: ${fnl != null ? 'OK' : 'MISSING'}');

    if (ini != null) {
      final ioActive = VxVisMgrParser.parseIOActive(ini);
      final ioSetting = VxVisMgrParser.parseIOSetting(ini);
      final enabled =
          VxVisMgrParser.parseStatusSignalSettings(
            ini,
          ).where((s) => s.enabled).toList();

      if (ioActive != null) {
        print(
          ' IOActive: pinPorts=${ioActive.pinPorts}, poutPorts=${ioActive.poutPorts}',
        );
      }
      if (ioSetting != null) {
        final trigger =
            (ioSetting.plcCommandEnabled || ioSetting.ethernetIpCommandEnabled)
                ? 'Command Trigger'
                : (ioSetting.triggerMode == 0
                    ? 'Code Trigger'
                    : 'Single Trigger');
        final plcEip =
            ioSetting.plcLinkEnabled
                ? 'PLC'
                : (ioSetting.ethernetIpEnabled ? 'EIP' : 'None');
        print(' IOSetting: trigger=$trigger, PLC/EIP=$plcEip');
      }
      print(' Enabled signals: ${enabled.length}');
    }

    final csvPairs = <MapEntry<String, String>>[];
    if (dio != null && dio.isNotEmpty) csvPairs.add(MapEntry('DIO', dio));
    if (plc != null && plc.isNotEmpty) csvPairs.add(MapEntry('PLC', plc));
    if (fnl != null && fnl.isNotEmpty) csvPairs.add(MapEntry('EIP', fnl));
    if (csvPairs.isNotEmpty) {
      final timeline = CsvIoLogParser.parseTimelineMulti(csvPairs);
      final active = ActivePortDetector.detectActivePorts(csvPairs);
      final activeIn = ActivePortDetector.detectActiveInputPorts(csvPairs);
      final activePrintable = <String, List<int>>{
        for (final e in active.entries) e.key: (e.value.toList()..sort()),
      };
      print(
        ' Timeline: rows=${timeline.entries.length} (末尾最大200), inPorts=${timeline.inPortCount}, outPorts=${timeline.outPortCount}',
      );
      print(' ActivePorts: $activePrintable');
      final activeInPrintable = <String, List<int>>{
        for (final e in activeIn.entries) e.key: (e.value.toList()..sort()),
      };
      print(' ActiveInputPorts: $activeInPrintable');

      // === ActivePorts に対応する信号名を出力（INI 定義を優先、なければ動的名） ===
      if (ini != null) {
        final mapping = await VxVisMgrMappingLoader.loadMapping();
        final enabled =
            VxVisMgrParser.parseStatusSignalSettings(
              ini,
            ).where((s) => s.enabled).toList();

        String plcEipOption = 'None';
        final ioSetting2 = VxVisMgrParser.parseIOSetting(ini);
        if (ioSetting2 != null) {
          if (ioSetting2.plcLinkEnabled) {
            plcEipOption = 'PLC';
          } else if (ioSetting2.ethernetIpEnabled) {
            plcEipOption = 'EIP';
          }
        }

        final namesBySourcePort = <String, Map<int, String>>{
          'DIO': <int, String>{},
          'PLC': <int, String>{},
          'EIP': <int, String>{},
        };
        for (final s in enabled) {
          if (!s.portNoByIndex.containsKey(0)) continue;
          final n0 = s.portNoByIndex[0]! + 1; // 1-based
          final type = s.portTypeByIndex[0];
          final label = mapping[s.name] ?? s.name;
          if (type != null && type != 0) {
            final src = plcEipOption == 'PLC' ? 'PLC' : 'EIP';
            namesBySourcePort[src]![n0] = label;
          } else {
            namesBySourcePort['DIO']![n0] = label;
          }
        }

        String _fallbackName(String source, int port) {
          if (source == 'DIO') return 'Output$port';
          if (source == 'PLC') return 'PLO$port';
          if (source == 'EIP') return 'ESO$port';
          return 'Port$port';
        }

        print(' ActivePort Names:');
        for (final source in ['DIO', 'PLC', 'EIP']) {
          final ports = active[source];
          if (ports == null || ports.isEmpty) continue;
          final sorted = ports.toList()..sort();
          for (final p in sorted) {
            final name =
                namesBySourcePort[source]?[p] ?? _fallbackName(source, p);
            print('  - $source:$p -> $name');
          }
        }

        // INIでEnableなシグナルは、アクティブでなくても一覧出力
        print(' Enabled (INI) Signals:');
        for (final source in ['DIO', 'PLC', 'EIP']) {
          final map = namesBySourcePort[source]!;
          if (map.isEmpty) continue;
          final keys = map.keys.toList()..sort();
          for (final p in keys) {
            print('  - $source:$p -> ${map[p]}');
          }
        }

        // 未定義シグナル検出: CSVでは活動したが、INIのEnable/Port.No(0)で定義がないポート
        final definedPorts = <String, Set<int>>{
          'DIO': namesBySourcePort['DIO']!.keys.toSet(),
          'PLC': namesBySourcePort['PLC']!.keys.toSet(),
          'EIP': namesBySourcePort['EIP']!.keys.toSet(),
        };
        final undefinedActivePorts = <String, List<int>>{};
        for (final source in ['DIO', 'PLC', 'EIP']) {
          final act = active[source] ?? <int>{};
          final def = definedPorts[source] ?? <int>{};
          final diff = act.difference(def).toList()..sort();
          if (diff.isNotEmpty) {
            undefinedActivePorts[source] = diff;
          }
        }
        if (undefinedActivePorts.isEmpty) {
          print(' Undefined ActivePorts: none');
        } else {
          print(' Undefined ActivePorts: $undefinedActivePorts');
        }
      }
    }

    io.exit(0);
  } catch (e, st) {
    debugPrint('ZIQ_IMPORT_TEST: 例外: $e\n$st');
    io.exit(1);
  }
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
  late FormControllersNotifier _controllersNotifier;

  // チャートの状態
  List<SignalData> _chartSignals = [];
  List<int> _chartPortNumbers = [];
  List<IoChannelSource> _chartIoSources = [];
  List<TimingChartAnnotation> _chartAnnotations = [];
  late final TimingChartController _chartController;

  // ziq(zip) から読み取ったファイル内容の保持先
  String? _vxVisMgrIniContent;
  String? _dioMonitorLogCsvContent;
  String? _plcDioMonitorLogCsvContent;
  String? _fnlDioMonitorLogCsvContent;
  // 解析結果: [StatusSignalSetting] の xxx.Enable=1 の xxx 一覧
  List<String> _enabledStatusSignals = [];
  // 解析結果: Enable=1 の構造一覧 (name, portNo[0] 等)
  List<StatusSignalSetting> _enabledSignalStructures = [];

  // name -> suggestionId のマッピング
  Map<String, String> _vxvisNameToSuggestionId = {};

  // 出力割り当て: Port.No 0 = n → outputIndex = n+1 に割り当て予定
  List<_OutputAssignment> _dioOutputAssignments = [];
  List<_OutputAssignment> _plcEipOutputAssignments = [];
  String _plcEipOption = 'None';

  // （デバッグ用出力は未使用のため削除）

  // ziq 読み込み・解析中インジケータ
  bool _isImportingZiq = false;

  Future<void> _applyOutputAssignments() async {
    // 必要な出力数を確保
    int maxIndex = 0;
    for (final a in _dioOutputAssignments) {
      if (a.outputIndex1Based > maxIndex) maxIndex = a.outputIndex1Based;
    }
    if (maxIndex > _formState.outputCount) {
      _updateOutputCount(maxIndex);
      // コントローラ更新を待つ
      await SchedulerBinding.instance.endOfFrame;
    }

    setState(() {
      for (final a in _dioOutputAssignments) {
        if (a.suggestionId.isEmpty) continue;
        final idx = a.outputIndex1Based - 1;
        if (idx >= 0 && idx < _outputControllers.length) {
          _controllersNotifier.setOutputText(idx, a.suggestionId);
        }
      }

      if (_plcEipOption != 'None') {
        for (final a in _plcEipOutputAssignments) {
          if (a.suggestionId.isEmpty) continue;
          final idx = a.outputIndex1Based - 1;
          if (idx >= 0 && idx < _plcEipOutputControllers.length) {
            _controllersNotifier.setPlcEipOutputText(idx, a.suggestionId);
          }
        }
      } else {
        _clearPlcEipControllersIfDisabled();
      }
    });
  }

  void _clearPlcEipControllersIfDisabled() {
    if (_plcEipOption == 'None') {
      for (final controller in _plcEipOutputControllers) {
        controller.clear();
      }
    }
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

  List<TextEditingController> get _inputControllers =>
      _controllersNotifier.inputControllers;
  List<TextEditingController> get _plcEipInputControllers =>
      _controllersNotifier.plcEipInputControllers;
  List<TextEditingController> get _outputControllers =>
      _controllersNotifier.outputControllers;
  List<TextEditingController> get _plcEipOutputControllers =>
      _controllersNotifier.plcEipOutputControllers;
  List<TextEditingController> get _hwTriggerControllers =>
      _controllersNotifier.hwTriggerControllers;

  Future<void> _transferOutputs(
    List<TextEditingController> dioControllers,
    List<TextEditingController> plcControllers,
  ) async {
    final form = _formTabKey.currentState;
    final chart = _timingChartKey.currentState;

    final currentNames =
        chart?.getSignalIdNames() ?? _chartSignals.map((s) => s.name).toList();
    final currentValues =
        chart != null
            ? chart.getChartData()
            : _chartSignals.map((s) => s.values).toList();

    final nameToValues = <String, List<int>>{};
    for (int i = 0; i < currentNames.length; i++) {
      nameToValues[currentNames[i]] = List<int>.from(currentValues[i]);
    }

    final int len = math.min(dioControllers.length, plcControllers.length);
    for (int i = 0; i < len; i++) {
      final dioName = dioControllers[i].text.trim();
      final plcUser = plcControllers[i].text.trim();
      final plcName = form?.formatPlcLabel(i, plcUser) ?? plcUser;

      if (dioName.isEmpty && plcName.isEmpty) {
        continue;
      }

      final dioValues = nameToValues[dioName];
      final plcValues = nameToValues[plcName];

      if (dioValues != null) {
        nameToValues[plcName] = dioValues;
      }
      if (plcValues != null) {
        nameToValues[dioName] = plcValues;
      }

      final tmp = dioControllers[i].text;
      dioControllers[i].text = plcControllers[i].text;
      plcControllers[i].text = tmp;
    }

    final updatedSignals =
        _chartSignals.map((signal) {
          final stored = nameToValues[signal.name];
          if (stored != null) {
            return signal.copyWith(values: stored);
          }
          return signal;
        }).toList();

    setState(() {
      _chartSignals = updatedSignals;
    });

    if (chart != null) {
      chart.updateSignalNames(updatedSignals.map((e) => e.name).toList());
      chart.updateSignals(updatedSignals.map((e) => e.values).toList());
    }
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

    _controllersNotifier = Provider.of<FormControllersNotifier>(
      context,
      listen: false,
    );
    _controllersNotifier.initialize(
      inputCount: initial.inputCount,
      outputCount: initial.outputCount,
      hwTriggerCount: initial.hwPort,
    );

    // テストコメントは削除
    _chartAnnotations = [];

    // チャートコントローラ初期化（初期は空値）
    _chartController = TimingChartController.fromInitial(
      _chartSignals.map((s) => s.name).toList(),
      _chartSignals.map((s) => s.values).toList(),
      _chartAnnotations,
    );

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
    // チャートタブからフォームタブに戻る場合
    if (_tabController.previousIndex == 1 && _tabController.index == 0) {
      // アノテーションを保存（チャートデータの同期は行わない）
      if (_timingChartKey.currentState != null) {
        _chartAnnotations = List.from(_chartController.annotations);
      }

      // フォームタブに戻る際は、テキストフィールドの位置を保持するため
      // updateSignalDataFromChartDataは呼び出さない
      debugPrint("チャートタブからフォームタブに戻りました。テキストフィールドの位置を保持します。");
    }

    // フォームタブからチャートタブに移動する場合
    if (_tabController.previousIndex == 0 && _tabController.index == 1) {
      // 保存しておいたアノテーションを反映
      if (_timingChartKey.currentState != null) {
        _timingChartKey.currentState!.updateAnnotations(_chartAnnotations);

        // チャートデータを反映（ziqインポート直後など）
        if (_chartSignals.isNotEmpty) {
          final signalNames = _chartSignals.map((s) => s.name).toList();
          final signalValues = _chartSignals.map((s) => s.values).toList();
          _chartController.setSignalNames(signalNames);
          _chartController.setSignals(signalValues);
          _timingChartKey.currentState!.updateSignalNames(signalNames);
          _timingChartKey.currentState!.updateSignals(signalValues);
          debugPrint('チャートタブへ移動: ${signalNames.length}個の信号を反映しました');
        }
      }
    }
  }

  // --- 新規: Input Port のみ更新 ---
  void _updateInputCount(int inputPorts) {
    _scheduleFormUpdate((n) {
      // Provider を更新（ioPort は互換のため同時更新）
      n.update(ioPort: inputPorts, inputCount: inputPorts);
    });
    _controllersNotifier.setInputCount(inputPorts);
  }

  // --- 新規: Output Port のみ更新 ---
  void _updateOutputCount(int outputPorts) {
    _scheduleFormUpdate((n) {
      n.update(outputCount: outputPorts);
    });
    _controllersNotifier.setOutputCount(outputPorts);
  }

  void _updateHwTriggerControllers([int? desiredCount]) {
    final target = desiredCount ?? _formState.hwPort;
    _controllersNotifier.setHwTriggerCount(target);
  }

  void _clearAllTextFields() {
    _controllersNotifier.clearAllTexts();

    // === 追加: チャートデータとコメントもクリア ===
    setState(() {
      _chartSignals.clear();
      _chartPortNumbers.clear();
      _chartIoSources.clear();
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
    _controllersNotifier.setInputCount(32);
    _controllersNotifier.setOutputCount(32);
    _controllersNotifier.setHwTriggerCount(0);
  }

  IoChannelSource _resolvePlcEipSource({bool allowUnknown = false}) {
    if (_plcEipOption == 'PLC') return IoChannelSource.plc;
    if (_plcEipOption == 'EIP') return IoChannelSource.eip;
    return allowUnknown ? IoChannelSource.unknown : IoChannelSource.dio;
  }

  String _extractLabelPrefix(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '';
    final colonIdx = trimmed.indexOf(':');
    if (colonIdx != -1) {
      return trimmed.substring(0, colonIdx);
    }
    final spaceIdx = trimmed.indexOf(' ');
    if (spaceIdx != -1) {
      return trimmed.substring(0, spaceIdx);
    }
    return trimmed;
  }

  int _findControllerIndexByLabel(
    String label,
    List<TextEditingController> controllers,
  ) {
    final target = label.trim();
    for (int i = 0; i < controllers.length; i++) {
      if (controllers[i].text.trim() == target) {
        return i;
      }
    }
    final colonIdx = target.indexOf(':');
    if (colonIdx != -1) {
      final suffix = target.substring(colonIdx + 1).trim();
      if (suffix.isNotEmpty) {
        for (int i = 0; i < controllers.length; i++) {
          if (controllers[i].text.trim() == suffix) {
            return i;
          }
        }
      }
    }
    return -1;
  }

  IoChannelSource _sourceFromPrefix(String prefixUpper, SignalType type) {
    if (prefixUpper.startsWith('PLIN') ||
        prefixUpper.startsWith('PLI') ||
        prefixUpper.startsWith('PLON') ||
        prefixUpper.startsWith('PLO')) {
      return IoChannelSource.plc;
    }
    if (prefixUpper.startsWith('ESIN') ||
        prefixUpper.startsWith('ESI') ||
        prefixUpper.startsWith('ESON') ||
        prefixUpper.startsWith('ESO')) {
      return IoChannelSource.eip;
    }
    if (prefixUpper.startsWith('PLC/EIP')) {
      return IoChannelSource.plcEip;
    }
    if (prefixUpper.startsWith('INPUT') || prefixUpper.startsWith('OUTPUT')) {
      return IoChannelSource.dio;
    }
    return IoChannelSource.unknown;
  }

  IoChannelSource _detectIoSourceFor(String label, SignalType type) {
    if (type != SignalType.input && type != SignalType.output) {
      return IoChannelSource.unknown;
    }

    final prefix = _extractLabelPrefix(label).toUpperCase();
    final prefSource = _sourceFromPrefix(prefix, type);
    if (prefSource != IoChannelSource.unknown) {
      if (prefSource == IoChannelSource.plcEip) {
        return _resolvePlcEipSource(allowUnknown: true);
      }
      return prefSource;
    }

    if (type == SignalType.input) {
      if (_findControllerIndexByLabel(label, _inputControllers) != -1) {
        return IoChannelSource.dio;
      }
      if (_findControllerIndexByLabel(label, _plcEipInputControllers) != -1) {
        return _resolvePlcEipSource(allowUnknown: true);
      }
    } else if (type == SignalType.output) {
      if (_findControllerIndexByLabel(label, _outputControllers) != -1) {
        return IoChannelSource.dio;
      }
      if (_findControllerIndexByLabel(label, _plcEipOutputControllers) != -1) {
        return _resolvePlcEipSource(allowUnknown: true);
      }
    }

    return IoChannelSource.unknown;
  }

  IoChannelSource _mapOutSourceTag(String tag) {
    switch (tag) {
      case 'PLC':
        return IoChannelSource.plc;
      case 'EIP':
        return IoChannelSource.eip;
      case 'PLC/EIP':
        return IoChannelSource.plcEip;
      case 'DIO':
        return IoChannelSource.dio;
      default:
        return IoChannelSource.unknown;
    }
  }

  // AppConfigを現在の状態から作成
  Future<AppConfig> _createAppConfig() async {
    debugPrint("\n===== _createAppConfig (Chart first) =====");

    // 最新のアノテーションを保存
    _chartAnnotations = List.from(_chartController.annotations);

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
      final orderedNames = _chartController.signalNames;
      final mapByName = {for (var s in _chartSignals) s.name: s};
      signalData = orderedNames.map((n) => mapByName[n]!).toList();
    } else {
      signalData = List<SignalData>.from(_chartSignals);
    }

    debugPrint("最終的に使用する信号データ数: ${signalData.length}");
    if (signalData.isNotEmpty) {
      debugPrint(
        "非ゼロ値を含む: ${signalData.any((signal) => signal.values.any((val) => val != 0))}",
      );
    }
    debugPrint("===== _createAppConfig 終了 =====\n");

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
      // ms 関連は SettingsNotifier から取得
      timeUnitIsMs:
          Provider.of<SettingsNotifier>(context, listen: false).timeUnitIsMs,
      msPerStep:
          Provider.of<SettingsNotifier>(context, listen: false).msPerStep,
      stepDurationsMs:
          Provider.of<SettingsNotifier>(context, listen: false).stepDurationsMs,
    );
  }

  // エクスポート前に「Update Chart」ボタンを自動的に押すことを推奨するダイアログを表示
  Future<bool> _confirmExport() async {
    debugPrint("===== _confirmExport =====");
    debugPrint("現在のタブインデックス: ${_tabController.index}");

    // チャートタブに表示されている場合は確認なしで続行
    if (_tabController.index == 1 && _timingChartKey.currentState != null) {
      List<List<int>> chartData = _chartController.signals;
      debugPrint("チャートタブのデータ行数: ${chartData.length}");
      if (chartData.isNotEmpty) {
        debugPrint("データ内容: ${chartData[0].take(10)}...");
        final hasNonZero = chartData.any(
          (row) => row.any((value) => value != 0),
        );
        debugPrint("非ゼロ値を含む: $hasNonZero");

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
      final chartData = _chartController.signals;
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
      final chartData = _chartController.signals;
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

    if (config == null) {
      return;
    }

    final formState = _formTabKey.currentState;
    formState?.clearAllForImport();

    _scheduleFormUpdate((n) => n.replace(config.formState));

    _controllersNotifier.setInputCount(config.formState.inputCount);
    _controllersNotifier.setOutputCount(config.formState.outputCount);
    _updateHwTriggerControllers(config.formState.hwPort);

    final settings = Provider.of<SettingsNotifier>(context, listen: false);
    settings.timeUnitIsMs = config.timeUnitIsMs;
    settings.msPerStep = config.msPerStep;
    if (config.stepDurationsMs.isNotEmpty) {
      settings.setStepDurationsMs(config.stepDurationsMs);
    }

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final form = _formTabKey.currentState;
      if (form != null) {
        form.updateFromAppConfig(config);
      }

      _chartAnnotations = config.annotations;
      if ((config.annotations.isNotEmpty ||
              config.omissionIndices.isNotEmpty) &&
          _timingChartKey.currentState != null) {
        _timingChartKey.currentState!.updateAnnotations(_chartAnnotations);
        _timingChartKey.currentState!.setOmission(config.omissionIndices);
      }
    });

    if (!mounted) {
      return;
    }

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
        final chartData = _chartController.signals;
        _formTabKey.currentState!.setChartDataOnly(chartData);
      }

      // 1フレーム待って状態を反映
      await SchedulerBinding.instance.endOfFrame;

      // IO情報を収集し、ID名をlabel名に変換（表示名として分かりやすく）
      debugPrint('=== IO Information: ID to Label conversion ===');

      // Input情報をID名からlabel名に変換
      List<String> inputNames = [];
      for (int i = 0; i < _inputControllers.length; i++) {
        final inputText = _inputControllers[i].text.trim();
        if (inputText.isNotEmpty) {
          final labelName = await labelOfId(inputText);
          debugPrint('Converting Input[$i]: $inputText -> $labelName');
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
          debugPrint('Converting Output[$i]: $outputText -> $labelName');
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
          debugPrint('Converting HW Trigger[$i]: $hwText -> $labelName');
          hwTriggerNames.add(labelName);
        } else {
          hwTriggerNames.add('');
        }
      }

      debugPrint('=== End IO conversion ===');

      // チャート信号データを収集し、ID名をlabel名に変換
      // チャートタブの表示順を優先して並べ替える
      List<SignalData> signalData = [];

      if (_timingChartKey.currentState != null) {
        // チャートタブの順序でSignalDataを取得
        final orderedNames = _chartController.signalNames;
        final mapByName = {for (var s in _chartSignals) s.name: s};

        debugPrint('=== XLSX Export: ID to Label conversion ===');
        debugPrint('Ordered signal IDs: $orderedNames');

        // チャートで表示されている順序に従って SignalData を並び替え
        for (String signalId in orderedNames) {
          if (mapByName.containsKey(signalId)) {
            final originalSignal = mapByName[signalId]!;
            // ID名をlabel名に変換してSignalDataを作成
            final labelName = await labelOfId(signalId);
            debugPrint('Converting: $signalId -> $labelName');
            final modifiedSignal = originalSignal.copyWith(name: labelName);
            signalData.add(modifiedSignal);
          }
        }

        // チャートに無い新規信号があれば後ろに追加
        for (var signal in _chartSignals) {
          if (!orderedNames.contains(signal.name)) {
            final labelName = await labelOfId(signal.name);
            debugPrint(
              'Converting additional signal: ${signal.name} -> $labelName',
            );
            final modifiedSignal = signal.copyWith(name: labelName);
            signalData.add(modifiedSignal);
          }
        }

        debugPrint(
          'Final signal names for XLSX: ${signalData.map((s) => s.name).toList()}',
        );
        debugPrint('=== End conversion ===');
      } else {
        // チャートタブが使用されていない場合はlabelOfIdで変換
        for (var signal in _chartSignals) {
          final labelName = await labelOfId(signal.name);
          debugPrint(
            'Converting from _chartSignals: ${signal.name} -> $labelName',
          );
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
                    _fnlDioMonitorLogCsvContent =
                        files['FNL_DioMonitorLog.csv'];
                    // ini を解析
                    if (_vxVisMgrIniContent == null) {
                      _enabledStatusSignals = [];
                      _enabledSignalStructures = [];
                      _dioOutputAssignments = [];
                      _plcEipOutputAssignments = [];
                      _plcEipOption = 'None';
                      _clearPlcEipControllersIfDisabled();
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

                      final ioSetting = VxVisMgrParser.parseIOSetting(
                        _vxVisMgrIniContent!,
                      );

                      String triggerOption = _formState.triggerOption;
                      _plcEipOption = 'None';
                      if (ioSetting != null) {
                        if (ioSetting.plcLinkEnabled) {
                          _plcEipOption = 'PLC';
                        } else if (ioSetting.ethernetIpEnabled) {
                          _plcEipOption = 'EIP';
                        } else if (ioSetting.useVirtualIoOnTrigger == 1) {
                          if (ioSetting.plcLinkEnabled) {
                            _plcEipOption = 'PLC';
                          } else if (ioSetting.ethernetIpEnabled) {
                            _plcEipOption = 'EIP';
                          }
                        }
                        // Command Trigger 判定（ご提示仕様）
                        final bool isPlcCommand =
                            ioSetting.plcLinkEnabled &&
                            ioSetting.plcCommandEnabled;
                        final bool isEipCommand =
                            ioSetting.ethernetIpEnabled &&
                            ioSetting.ethernetIpCommandEnabled;
                        if (isPlcCommand || isEipCommand) {
                          triggerOption = 'Command Trigger';
                        } else {
                          triggerOption =
                              ioSetting.triggerMode == 0
                                  ? 'Code Trigger'
                                  : 'Single Trigger';
                        }
                      }

                      // Port.No 0 をもつものだけを対象に、UI 用の割り当てを作成
                      _dioOutputAssignments = [];
                      _plcEipOutputAssignments = [];

                      // 既に割り当てられた信号名を記録（重複防止用）
                      final assignedSignalNames = <String>{};

                      for (final s in _enabledSignalStructures) {
                        if (!s.portNoByIndex.containsKey(0)) continue;
                        final n0 = s.portNoByIndex[0]!; // 0-based
                        final type = s.portTypeByIndex[0];
                        final suggestionId =
                            _vxvisNameToSuggestionId[s.name] ?? '';

                        // 使用する信号名を決定（マッピング名優先、なければINI名）
                        final signalName =
                            suggestionId.isNotEmpty ? suggestionId : s.name;

                        debugPrint(
                          'INI解析: ${s.name} -> Port.No=${n0 + 1}, Type=$type, SignalName=$signalName',
                        );

                        // 既に割り当てられている信号名の場合はスキップ
                        if (assignedSignalNames.contains(signalName)) {
                          debugPrint(
                            'INI割り当て: 重複スキップ - $signalName (${s.name})',
                          );
                          continue;
                        }
                        assignedSignalNames.add(signalName);
                        debugPrint(
                          'INI割り当て: $signalName (${s.name}) -> Port.No=${n0 + 1}, Type=$type',
                        );

                        final assignment = _OutputAssignment(
                          name: s.name,
                          suggestionId: suggestionId,
                          portNo0: n0 + 1,
                          outputIndex1Based: n0 + 1,
                        );

                        if (type != null && type != 0) {
                          _plcEipOutputAssignments.add(assignment);
                        } else {
                          _dioOutputAssignments.add(assignment);
                        }
                      }

                      // 割り当て結果をデバッグ出力
                      debugPrint('=== DIO割り当て結果 ===');
                      for (final a in _dioOutputAssignments) {
                        debugPrint(
                          'DIO: ${a.name} -> Port.No=${a.portNo0}, SuggestionId=${a.suggestionId}',
                        );
                      }
                      debugPrint('=== PLC/EIP割り当て結果 ===');
                      for (final a in _plcEipOutputAssignments) {
                        debugPrint(
                          'PLC/EIP: ${a.name} -> Port.No=${a.portNo0}, SuggestionId=${a.suggestionId}',
                        );
                      }

                      // 先に Output テキスト欄へラベルを反映（同期版）
                      // マッピングが無ければ INI の信号名を使用
                      for (final a in _dioOutputAssignments) {
                        final idx = a.outputIndex1Based - 1;
                        if (idx >= 0 && idx < _outputControllers.length) {
                          final signalName =
                              a.suggestionId.isNotEmpty
                                  ? a.suggestionId
                                  : a.name;
                          _outputControllers[idx].text = signalName;
                          debugPrint('DIOテキスト反映: $signalName -> DIO[$idx]');
                        }
                      }

                      for (final a in _plcEipOutputAssignments) {
                        final idx = a.outputIndex1Based - 1;
                        if (idx >= 0 && idx < _plcEipOutputControllers.length) {
                          final signalName =
                              a.suggestionId.isNotEmpty
                                  ? a.suggestionId
                                  : a.name;
                          _plcEipOutputControllers[idx].text = signalName;
                          debugPrint(
                            'PLC/EIPテキスト反映: $signalName -> PLC/EIP[$idx]',
                          );
                        }
                      }

                      // 入力欄はINIではなくCSVのINアクティブ検出に基づき後段で反映するため、ここでは何もしない

                      if (_formTabKey.currentState != null) {
                        _formTabKey.currentState!.setPlcEipOption(
                          _plcEipOption,
                        );
                      }
                      // 決定した Trigger Option をフォーム状態へ同期
                      _scheduleFormUpdate(
                        (n) => n.update(triggerOption: triggerOption),
                      );
                      _clearPlcEipControllersIfDisabled();

                      // === CSV ログを解析してチャートへ反映 ===
                      // 複数CSV（DIO/PLC/EIP）を統合
                      final csvPairs = <MapEntry<String, String>>[];
                      if (_dioMonitorLogCsvContent != null &&
                          _dioMonitorLogCsvContent!.isNotEmpty) {
                        csvPairs.add(
                          MapEntry('DIO', _dioMonitorLogCsvContent!),
                        );
                      }
                      if (_plcDioMonitorLogCsvContent != null &&
                          _plcDioMonitorLogCsvContent!.isNotEmpty) {
                        csvPairs.add(
                          MapEntry('PLC', _plcDioMonitorLogCsvContent!),
                        );
                      }
                      if (_fnlDioMonitorLogCsvContent != null &&
                          _fnlDioMonitorLogCsvContent!.isNotEmpty) {
                        csvPairs.add(
                          MapEntry('EIP', _fnlDioMonitorLogCsvContent!),
                        );
                      }
                      if (csvPairs.isNotEmpty) {
                        // === 活動ポート検出と動的信号名生成 ===
                        final activePorts =
                            ActivePortDetector.detectActivePorts(csvPairs);

                        // 既存のINI定義ポートを取得
                        final definedPorts = <String, Set<int>>{};
                        for (final a in _dioOutputAssignments) {
                          definedPorts
                              .putIfAbsent('DIO', () => <int>{})
                              .add(a.portNo0);
                        }
                        for (final a in _plcEipOutputAssignments) {
                          final source = _plcEipOption == 'PLC' ? 'PLC' : 'EIP';
                          definedPorts
                              .putIfAbsent(source, () => <int>{})
                              .add(a.portNo0);
                        }

                        // 未定義の活動ポートを検出
                        final undefinedActivePorts = <String, Set<int>>{};
                        for (final source in activePorts.keys) {
                          final defined = definedPorts[source] ?? <int>{};
                          final active = activePorts[source]!;
                          final undefined = active.difference(defined);
                          if (undefined.isNotEmpty) {
                            undefinedActivePorts[source] = undefined;
                          }
                        }

                        // 未定義の活動ポートに対して動的な信号名を生成
                        // 既にINIで割り当てられた信号名を収集（重複防止用）
                        final assignedNames = <String>{};
                        for (final a in _dioOutputAssignments) {
                          if (a.suggestionId.isNotEmpty) {
                            assignedNames.add(a.suggestionId);
                          } else {
                            assignedNames.add(a.name);
                          }
                        }
                        for (final a in _plcEipOutputAssignments) {
                          if (a.suggestionId.isNotEmpty) {
                            assignedNames.add(a.suggestionId);
                          } else {
                            assignedNames.add(a.name);
                          }
                        }

                        for (final source in undefinedActivePorts.keys) {
                          final ports = undefinedActivePorts[source]!;
                          for (final port in ports) {
                            String signalName;
                            if (source == 'DIO') {
                              signalName = 'Output$port';
                            } else if (source == 'PLC') {
                              signalName = 'PLO$port';
                            } else if (source == 'EIP') {
                              signalName = 'ESO$port';
                            } else {
                              continue;
                            }

                            // 既にINIで割り当てられた信号名との重複をチェック
                            if (assignedNames.contains(signalName)) {
                              debugPrint(
                                'CSV動的割り当て: 重複スキップ - $signalName ($source:$port)',
                              );
                              continue; // 重複する場合はスキップ
                            }

                            // フォームの出力コントローラに追加
                            // 注意: 既存のINI定義ポートは除外し、動的信号のみを追加
                            if (source == 'DIO' &&
                                port <= _outputControllers.length) {
                              // DIO出力の空いているポートにのみ追加
                              if (_outputControllers[port - 1].text.isEmpty) {
                                _outputControllers[port - 1].text = signalName;
                                debugPrint(
                                  'CSV動的割り当て: $signalName -> DIO:$port',
                                );
                              }
                            } else if ((source == 'PLC' || source == 'EIP') &&
                                port <= _plcEipOutputControllers.length) {
                              // PLC/EIP出力の空いているポートにのみ追加
                              if (_plcEipOutputControllers[port - 1]
                                  .text
                                  .isEmpty) {
                                _plcEipOutputControllers[port - 1].text =
                                    signalName;
                                debugPrint(
                                  'CSV動的割り当て: $signalName -> $source:$port',
                                );
                              }
                            }
                          }
                        }

                        // === 入力の活動ポート（CSVのIN行）に基づき入力欄へ自動反映（空欄のみ） ===
                        final activeInputPorts =
                            ActivePortDetector.detectActiveInputPorts(csvPairs);
                        for (final entry in activeInputPorts.entries) {
                          final source = entry.key; // 'DIO'|'PLC'|'EIP'
                          final ports = entry.value.toList()..sort();
                          for (final port in ports) {
                            if (source == 'DIO') {
                              if (port >= 1 &&
                                  port <= _inputControllers.length) {
                                if (_inputControllers[port - 1].text.isEmpty) {
                                  _inputControllers[port - 1].text =
                                      'Input$port';
                                  debugPrint(
                                    'CSV入力割り当て: Input$port -> DIO:$port',
                                  );
                                }
                              }
                            } else if (source == 'PLC' || source == 'EIP') {
                              if (port >= 1 &&
                                  port <= _plcEipInputControllers.length) {
                                if (_plcEipInputControllers[port - 1]
                                    .text
                                    .isEmpty) {
                                  final prefix =
                                      (source == 'PLC') ? 'PLI' : 'ESI';
                                  final name = '$prefix$port';
                                  _plcEipInputControllers[port - 1].text = name;
                                  debugPrint(
                                    'CSV入力割り当て: $name -> $source:$port',
                                  );
                                }
                              }
                            }
                          }
                        }

                        // タイムライン（CSV行順）で IN/OUT を統合（複数ソース対応）
                        final timeline = CsvIoLogParser.parseTimelineMulti(
                          csvPairs,
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
                          // 平均 ms/step を総和/総数で算出
                          final double sumMs = stepDurationsMs
                              .where((e) => e.isFinite && e > 0)
                              .fold<double>(0.0, (a, b) => a + b);
                          final double avgMs = sumMs / stepDurationsMs.length;
                          if (avgMs.isFinite && avgMs > 0) {
                            settings.msPerStep = avgMs;
                          }
                          // タイムライン長と stepDurations 長の整合性を確保
                          final int maxLen = timeline.entries.length;
                          if (stepDurationsMs.length != maxLen) {
                            final List<double> fixed = List<double>.from(
                              stepDurationsMs,
                            );
                            if (fixed.length < maxLen) {
                              fixed.addAll(
                                List<double>.filled(
                                  maxLen - fixed.length,
                                  settings.msPerStep,
                                ),
                              );
                            } else if (fixed.length > maxLen) {
                              fixed.removeRange(maxLen, fixed.length);
                            }
                            settings.setStepDurationsMs(fixed);
                            _chartController.setStepDurationsMs(fixed);
                          } else {
                            settings.setStepDurationsMs(stepDurationsMs);
                            _chartController.setStepDurationsMs(
                              stepDurationsMs,
                            );
                          }
                        }

                        // ms 単位に切替え、グリッド再計算を促す
                        Provider.of<SettingsNotifier>(context, listen: false)
                            .timeUnitIsMs = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _chartController.requestGridRecompute();
                            setState(() {});
                          }
                        });

                        // === Output の取り込み（IN行では前回値を保持） ===
                        final int timeLength = timeline.entries.length;
                        // OUT 結果を後段で使うための一時保持領域（スコープ外に宣言）
                        final outSource =
                            <
                              String,
                              String
                            >{}; // name -> 'DIO'|'PLC'|'EIP'|'PLC/EIP'
                        final outNamesDio = <String>[];
                        final outTypesDio = <SignalType>[];
                        final outPortsDio = <int>[];
                        final outValuesDio = <List<int>>[];
                        final outNamesPlc = <String>[];
                        final outTypesPlc = <SignalType>[];
                        final outPortsPlc = <int>[];
                        final outValuesPlc = <List<int>>[];
                        if (timeLength > 0) {
                          // --- DIO 出力 ---
                          int dioOutputs = _formState.outputCount;
                          for (final a in _dioOutputAssignments) {
                            if (a.outputIndex1Based > dioOutputs)
                              dioOutputs = a.outputIndex1Based;
                          }
                          // 動的に生成されたポートも含める
                          for (final source in undefinedActivePorts.keys) {
                            if (source == 'DIO') {
                              final ports = undefinedActivePorts[source]!;
                              for (final port in ports) {
                                if (port > dioOutputs) dioOutputs = port;
                              }
                            }
                          }
                          List<List<int>> outChartRowsDio = List.generate(
                            dioOutputs,
                            (_) => List.filled(timeLength, 0),
                          );

                          // 既存のINI定義ポートの処理
                          for (final a in _dioOutputAssignments) {
                            final outIdx = a.outputIndex1Based - 1;
                            final portK = a.portNo0;
                            if (outIdx < 0 || outIdx >= dioOutputs) continue;
                            int last = 0;
                            for (int t = 0; t < timeLength; t++) {
                              final e = timeline.entries[t];
                              if (e.type == 'OUT' &&
                                  (e.source == null || e.source == 'DIO')) {
                                final row = e.bits;
                                final colIdx = row.length - portK; // 右端が Port1
                                final v =
                                    (colIdx >= 0 &&
                                            colIdx < row.length &&
                                            row[colIdx] != 0)
                                        ? 1
                                        : 0;
                                last = v;
                                outChartRowsDio[outIdx][t] = v;
                              } else {
                                outChartRowsDio[outIdx][t] = last;
                              }
                            }
                          }

                          // 動的に生成されたポートの処理
                          for (final source in undefinedActivePorts.keys) {
                            if (source == 'DIO') {
                              final ports = undefinedActivePorts[source]!;
                              for (final port in ports) {
                                final outIdx = port - 1;
                                if (outIdx < 0 || outIdx >= dioOutputs)
                                  continue;
                                int last = 0;
                                for (int t = 0; t < timeLength; t++) {
                                  final e = timeline.entries[t];
                                  if (e.type == 'OUT' &&
                                      (e.source == null || e.source == 'DIO')) {
                                    final row = e.bits;
                                    final colIdx =
                                        row.length - port; // 右端が Port1
                                    final v =
                                        (colIdx >= 0 &&
                                                colIdx < row.length &&
                                                row[colIdx] != 0)
                                            ? 1
                                            : 0;
                                    last = v;
                                    outChartRowsDio[outIdx][t] = v;
                                  } else {
                                    outChartRowsDio[outIdx][t] = last;
                                  }
                                }
                              }
                            }
                          }
                          for (int i = 0; i < dioOutputs; i++) {
                            if (i >= _outputControllers.length) continue;
                            final name = _outputControllers[i].text.trim();
                            if (name.isEmpty) continue;
                            outNamesDio.add(name);
                            outTypesDio.add(SignalType.output);
                            outPortsDio.add(i + 1);
                            outValuesDio.add(outChartRowsDio[i]);
                            // 出所属性（DIO）
                            final s = outSource[name];
                            if (s == null) {
                              outSource[name] = 'DIO';
                            } else if (s == 'PLC' ||
                                s == 'EIP' ||
                                s == 'PLC/EIP') {
                              outSource[name] = 'PLC/EIP';
                            }
                          }

                          // --- PLC/EIP 出力 ---
                          if (_plcEipOption != 'None') {
                            int plcOutputs = _formState.outputCount;
                            for (final a in _plcEipOutputAssignments) {
                              if (a.outputIndex1Based > plcOutputs)
                                plcOutputs = a.outputIndex1Based;
                            }
                            // 動的に生成されたポートも含める
                            for (final source in undefinedActivePorts.keys) {
                              if (source == 'PLC' || source == 'EIP') {
                                final ports = undefinedActivePorts[source]!;
                                for (final port in ports) {
                                  if (port > plcOutputs) plcOutputs = port;
                                }
                              }
                            }
                            List<List<int>> outChartRowsPlc = List.generate(
                              plcOutputs,
                              (_) => List.filled(timeLength, 0),
                            );
                            bool seenPlc = false;
                            bool seenEip = false;

                            // 既存のINI定義ポートの処理
                            for (final a in _plcEipOutputAssignments) {
                              final outIdx = a.outputIndex1Based - 1;
                              final portK = a.portNo0;
                              if (outIdx < 0 || outIdx >= plcOutputs) continue;
                              int last = 0;
                              for (int t = 0; t < timeLength; t++) {
                                final e = timeline.entries[t];
                                if (e.type == 'OUT' &&
                                    (e.source == 'PLC' || e.source == 'EIP')) {
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
                                  outChartRowsPlc[outIdx][t] = v;
                                  if (e.source == 'PLC')
                                    seenPlc = true;
                                  else if (e.source == 'EIP')
                                    seenEip = true;
                                } else {
                                  outChartRowsPlc[outIdx][t] = last;
                                }
                              }
                            }

                            // 動的に生成されたポートの処理
                            for (final source in undefinedActivePorts.keys) {
                              if (source == 'PLC' || source == 'EIP') {
                                final ports = undefinedActivePorts[source]!;
                                for (final port in ports) {
                                  final outIdx = port - 1;
                                  if (outIdx < 0 || outIdx >= plcOutputs)
                                    continue;
                                  int last = 0;
                                  for (int t = 0; t < timeLength; t++) {
                                    final e = timeline.entries[t];
                                    if (e.type == 'OUT' && e.source == source) {
                                      final row = e.bits;
                                      final colIdx =
                                          row.length - port; // 右端が Port1
                                      final v =
                                          (colIdx >= 0 &&
                                                  colIdx < row.length &&
                                                  row[colIdx] != 0)
                                              ? 1
                                              : 0;
                                      last = v;
                                      outChartRowsPlc[outIdx][t] = v;
                                      if (e.source == 'PLC')
                                        seenPlc = true;
                                      else if (e.source == 'EIP')
                                        seenEip = true;
                                    } else {
                                      outChartRowsPlc[outIdx][t] = last;
                                    }
                                  }
                                }
                              }
                            }
                            for (int i = 0; i < plcOutputs; i++) {
                              if (i >= _plcEipOutputControllers.length)
                                continue;
                              final name =
                                  _plcEipOutputControllers[i].text.trim();
                              if (name.isEmpty) continue;
                              outNamesPlc.add(name);
                              outTypesPlc.add(SignalType.output);
                              outPortsPlc.add(i + 1);
                              outValuesPlc.add(outChartRowsPlc[i]);
                              // 出所属性（PLC/EIP）
                              final src =
                                  (seenPlc && seenEip)
                                      ? 'PLC/EIP'
                                      : (seenPlc ? 'PLC' : 'EIP');
                              final s = outSource[name];
                              if (s == null) {
                                outSource[name] = src;
                              } else if (s != src) {
                                outSource[name] = 'PLC/EIP';
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
                            _controllersNotifier.setInputText(0, 'TRIGGER');
                          }

                          List<List<int>> inChart = [];
                          List<String> inNames = [];
                          List<SignalType> inTypes = [];

                          // --- DIO 入力 ---
                          for (int idx0 = 0; idx0 < inputs; idx0++) {
                            if (idx0 >= _inputControllers.length) continue;
                            final name = _inputControllers[idx0].text.trim();
                            if (name.isEmpty) continue;
                            List<int> series = List.filled(inTime, 0);
                            for (int t = 0; t < inTime; t++) {
                              final e = timeline.entries[t];
                              if (e.type == 'IN' && e.source == 'DIO') {
                                final row = e.bits;
                                // 右端が Input1。CSV末尾の空欄は除外済み
                                final col = row.length - (idx0 + 1);
                                if (col >= 0 && col < row.length) {
                                  series[t] = row[col] != 0 ? 1 : 0;
                                }
                              } else if (e.type != 'IN') {
                                // OUT 行: 常に 0
                                series[t] = 0;
                              }
                            }
                            inChart.add(series);
                            inNames.add(name);
                            inTypes.add(SignalType.input);
                          }

                          // --- PLC/EIP 入力 ---
                          for (int idx0 = 0; idx0 < inputs; idx0++) {
                            if (idx0 >= _plcEipInputControllers.length)
                              continue;
                            final name =
                                _plcEipInputControllers[idx0].text.trim();
                            if (name.isEmpty) continue;
                            // どのソースを対象にするかを決定
                            bool allowPlc;
                            bool allowEip;
                            if (name.startsWith('PLI')) {
                              allowPlc = true;
                              allowEip = false;
                            } else if (name.startsWith('ESI')) {
                              allowPlc = false;
                              allowEip = true;
                            } else {
                              // 明示されていない場合は現在のオプションに従う（未設定なら両方）
                              if (_plcEipOption == 'PLC') {
                                allowPlc = true;
                                allowEip = false;
                              } else if (_plcEipOption == 'EIP') {
                                allowPlc = false;
                                allowEip = true;
                              } else {
                                allowPlc = true;
                                allowEip = true;
                              }
                            }
                            List<int> series = List.filled(inTime, 0);
                            for (int t = 0; t < inTime; t++) {
                              final e = timeline.entries[t];
                              if (e.type == 'IN') {
                                final isPlc = e.source == 'PLC';
                                final isEip = e.source == 'EIP';
                                if ((isPlc && allowPlc) ||
                                    (isEip && allowEip)) {
                                  final row = e.bits;
                                  final col = row.length - (idx0 + 1);
                                  if (col >= 0 && col < row.length) {
                                    series[t] = row[col] != 0 ? 1 : 0;
                                  }
                                }
                              } else if (e.type != 'IN') {
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

                          // 5) Output（存在すれば）: 同名は1本にマージ（PLC/EIP優先）
                          if (timeLength > 0) {
                            // 名前→系列のマップ化
                            final dioMap = <String, List<int>>{};
                            for (int i = 0; i < outNamesDio.length; i++) {
                              dioMap[outNamesDio[i]] = outValuesDio[i];
                            }
                            final plcMap = <String, List<int>>{};
                            for (int i = 0; i < outNamesPlc.length; i++) {
                              plcMap[outNamesPlc[i]] = outValuesPlc[i];
                            }

                            // 表示順は DIO → PLC/EIP の順序でユニーク化
                            final orderedOutputNames = <String>[];
                            for (final n in outNamesDio) {
                              if (!orderedOutputNames.contains(n))
                                orderedOutputNames.add(n);
                            }
                            for (final n in outNamesPlc) {
                              if (!orderedOutputNames.contains(n))
                                orderedOutputNames.add(n);
                            }

                            // マージ（PLC/EIP優先: 非0を優先）
                            final mergedValuesByName = <String, List<int>>{};
                            for (final n in orderedOutputNames) {
                              final dio = dioMap[n];
                              final plc = plcMap[n];
                              if (dio == null && plc != null) {
                                mergedValuesByName[n] = plc;
                              } else if (dio != null && plc == null) {
                                mergedValuesByName[n] = dio;
                              } else if (dio != null && plc != null) {
                                final len = math.min(dio.length, plc.length);
                                final merged = List<int>.from(dio);
                                for (int t = 0; t < len; t++) {
                                  if (plc[t] != 0) merged[t] = plc[t];
                                }
                                mergedValuesByName[n] = merged;
                              }
                            }

                            // 結合配列へ反映
                            for (final n in orderedOutputNames) {
                              final v = mergedValuesByName[n];
                              if (v == null) continue;
                              combinedNames.add(n);
                              combinedTypes.add(SignalType.output);
                              combinedValues.add(v);
                            }
                          }

                          // 5.5) フォーム未設定の追加出力（CSVで1を含んだポート）: 省略（既存名のみ使用）

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
                              final syncedSources = <IoChannelSource>[];

                              // 入力/出力/HW の名前→ポート番号マップを用意
                              final inputNameToPort = <String, int>{
                                for (int i = 0; i < inNames.length; i++)
                                  inNames[i]: i + 1,
                              };
                              // 出力名→ポート番号
                              final outputNameToPort = <String, int>{};
                              for (int i = 0; i < outNamesDio.length; i++) {
                                outputNameToPort.putIfAbsent(
                                  outNamesDio[i],
                                  () => outPortsDio[i],
                                );
                              }
                              for (int i = 0; i < outNamesPlc.length; i++) {
                                outputNameToPort.putIfAbsent(
                                  outNamesPlc[i],
                                  () => outPortsPlc[i],
                                );
                              }
                              final hwNameToPort = <String, int>{
                                for (int i = 0; i < _formState.hwPort; i++)
                                  if (i < _hwTriggerControllers.length &&
                                      _hwTriggerControllers[i].text
                                          .trim()
                                          .isNotEmpty)
                                    _hwTriggerControllers[i].text.trim(): i + 1,
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
                                IoChannelSource source;
                                if (type == SignalType.output) {
                                  source = _mapOutSourceTag(
                                    outSource[name] ?? 'DIO',
                                  );
                                  if (source == IoChannelSource.plcEip) {
                                    final resolved = _resolvePlcEipSource(
                                      allowUnknown: true,
                                    );
                                    if (resolved != IoChannelSource.unknown) {
                                      source = resolved;
                                    }
                                  }
                                } else if (type == SignalType.input) {
                                  source = _detectIoSourceFor(name, type);
                                } else {
                                  source = IoChannelSource.unknown;
                                }
                                syncedSources.add(source);
                              }
                              _chartSignals = syncedSignals;
                              _chartPortNumbers = syncedPorts;
                              _chartIoSources = syncedSources;
                            });
                            _formTabKey.currentState!
                                .updateSignalDataFromChartData(
                                  combinedValues,
                                  combinedNames,
                                  combinedTypes,
                                );
                            // SignalDataリストを更新してチャートに反映
                            _formTabKey.currentState!.refreshSignalDataList();
                            // 既存データの破壊を避けるため、ここでは updateChartData は呼ばない
                            if (_timingChartKey.currentState != null) {
                              // 出力名→ポート番号（表示用）を再構築（setState外で使うため）
                              final Map<String, int> nameToPortForLabel = {};
                              for (int i = 0; i < outNamesDio.length; i++) {
                                nameToPortForLabel.putIfAbsent(
                                  outNamesDio[i],
                                  () => outPortsDio[i],
                                );
                              }
                              for (int i = 0; i < outNamesPlc.length; i++) {
                                nameToPortForLabel.putIfAbsent(
                                  outNamesPlc[i],
                                  () => outPortsPlc[i],
                                );
                              }
                              // 表示用ラベルを作成（DIO: Output{i}, PLC: PLO{i}, EIP: ESO{i}）
                              final List<String> displayNames = List.generate(
                                combinedNames.length,
                                (i) {
                                  final name = combinedNames[i];
                                  final type = combinedTypes[i];
                                  if (type != SignalType.output) {
                                    return name; // 出力以外はそのまま
                                  }
                                  final port = nameToPortForLabel[name] ?? 0;
                                  final src = outSource[name] ?? 'DIO';
                                  String prefix;
                                  if (src == 'PLC' ||
                                      (src == 'PLC/EIP' &&
                                          _plcEipOption == 'PLC')) {
                                    prefix = 'PLO';
                                  } else if (src == 'EIP' ||
                                      (src == 'PLC/EIP' &&
                                          _plcEipOption == 'EIP')) {
                                    prefix = 'ESO';
                                  } else {
                                    prefix = 'Output';
                                  }
                                  if (port > 0) {
                                    return '$prefix$port: $name';
                                  }
                                  return name;
                                },
                              );

                              _timingChartKey.currentState!.updateSignalNames(
                                displayNames,
                              );
                              _timingChartKey.currentState!.updateSignals(
                                combinedValues,
                              );
                            }
                            // コントローラにも即時反映（Update Chart 不要にする）
                            // TimingChart へ渡した表示名と同一の配列を使用
                            if (_timingChartKey.currentState != null) {
                              // displayNames は直前の if ブロック内で定義されているので、もう一度生成
                              final Map<String, int> nameToPortForLabel = {};
                              for (int i = 0; i < outNamesDio.length; i++) {
                                nameToPortForLabel.putIfAbsent(
                                  outNamesDio[i],
                                  () => outPortsDio[i],
                                );
                              }
                              for (int i = 0; i < outNamesPlc.length; i++) {
                                nameToPortForLabel.putIfAbsent(
                                  outNamesPlc[i],
                                  () => outPortsPlc[i],
                                );
                              }
                              final controllerDisplayNames = List.generate(
                                combinedNames.length,
                                (i) {
                                  final name = combinedNames[i];
                                  final type = combinedTypes[i];
                                  if (type != SignalType.output) return name;
                                  if (_showIoNumbers) {
                                    return name;
                                  }
                                  final port = nameToPortForLabel[name] ?? 0;
                                  final src = outSource[name] ?? 'DIO';
                                  String prefix;
                                  if (src == 'PLC' ||
                                      (src == 'PLC/EIP' &&
                                          _plcEipOption == 'PLC')) {
                                    prefix = 'PLO';
                                  } else if (src == 'EIP' ||
                                      (src == 'PLC/EIP' &&
                                          _plcEipOption == 'EIP')) {
                                    prefix = 'ESO';
                                  } else {
                                    prefix = 'Output';
                                  }
                                  if (port > 0) {
                                    return '$prefix$port: $name';
                                  }
                                  return name;
                                },
                              );
                              _chartController.setSignalNames(
                                controllerDisplayNames,
                              );
                              _chartController.setSignals(combinedValues);
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
                  final foundFnl =
                      _fnlDioMonitorLogCsvContent != null ? 'OK' : 'なし';

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'ZIP解析完了  vxVisMgr.ini:$foundIni  DioMonitorLog.csv:$foundDio  Plc_DioMonitorLog.csv:$foundPlc  FNL_DioMonitorLog.csv:$foundFnl  EnabledSignals:${_enabledStatusSignals.length}  DioMap:${_dioOutputAssignments.length}  PlcEipMap:${_plcEipOutputAssignments.length}',
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
                plcEipInputControllers: _plcEipInputControllers,
                outputControllers: _outputControllers,
                plcEipOutputControllers: _plcEipOutputControllers,
                hwTriggerControllers: _hwTriggerControllers,
                controllersNotifier: _controllersNotifier,
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
                onTransferOutputs: _transferOutputs,
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
                      final currentChartValues = _chartController.signals;

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
                    List<IoChannelSource> newChartSources = [];

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
                              // 既存データが長い場合はそのまま既存を優先（chartData は不変）
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
                      newChartSources.add(
                        _detectIoSourceFor(signalNames[i], signalTypes[i]),
                      );
                    }

                    _chartSignals = newChartSignals;

                    var effectiveSources = List<IoChannelSource>.from(
                      newChartSources,
                    );

                    // === 追加: 既存の並び順を保持 (overrideFlag が false の場合のみ) ===
                    if (!overrideFlag && _timingChartKey.currentState != null) {
                      final currentOrder = _chartController.signalNames;

                      if (currentOrder.isNotEmpty) {
                        final mapByName = {
                          for (final s in _chartSignals) s.name: s,
                        };
                        final sourceByName = <String, List<IoChannelSource>>{};
                        for (int i = 0; i < _chartSignals.length; i++) {
                          final key = _chartSignals[i].name;
                          sourceByName
                              .putIfAbsent(key, () => [])
                              .add(effectiveSources[i]);
                        }

                        final reordered = <SignalData>[];
                        final reorderedSources = <IoChannelSource>[];
                        for (final name in currentOrder) {
                          final signal = mapByName[name];
                          if (signal != null) {
                            reordered.add(signal);
                            final list = sourceByName[name];
                            if (list != null && list.isNotEmpty) {
                              reorderedSources.add(list.removeAt(0));
                            } else {
                              reorderedSources.add(IoChannelSource.unknown);
                            }
                            mapByName.remove(name);
                          }
                        }
                        for (final entry in mapByName.entries) {
                          reordered.add(entry.value);
                          final list = sourceByName[entry.key];
                          if (list != null && list.isNotEmpty) {
                            reorderedSources.add(list.removeAt(0));
                          } else {
                            reorderedSources.add(IoChannelSource.unknown);
                          }
                        }

                        _chartSignals = reordered;
                        effectiveSources = reorderedSources;
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
                    _chartIoSources = effectiveSources;

                    // チャートウィジェットを更新
                    if (_timingChartKey.currentState != null) {
                      final orderedNames =
                          _chartSignals.map((s) => s.name).toList();
                      _chartController.setSignalNames(orderedNames);
                      _chartController.setSignals(
                        _chartSignals.map((s) => s.values).toList(),
                      );
                    }
                  });
                },
                onClearFields: () {
                  _clearAllTextFields();
                  final settings = Provider.of<SettingsNotifier>(
                    context,
                    listen: false,
                  );
                  settings.setStepDurationsMs([]);
                  _chartController.setStepDurationsMs([]);
                  _chartController.requestGridRecompute();
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
                controller: _chartController,
                fitToScreen: true,
                showAllSignalTypes: true,
                showIoNumbers: _showIoNumbers,
                portNumbers: _chartPortNumbers,
                ioSources: _chartIoSources,
                plcEipMode: _plcEipOption,
              ),
            ],
          ),
          if (_isImportingZiq)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha((0.35 * 255).round()),
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
