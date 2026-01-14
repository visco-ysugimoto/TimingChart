# lib/widgets データフロー ドキュメント

このディレクトリには、`lib/widgets` フォルダ内の各ウィジェットのデータフローと処理フローがフォルダごとに整理されています。

## main.dart からの全体図（入口）

アプリ全体の起動〜画面遷移/主要フローは、まずこちらを参照してください。

- **詳細版**: [MAIN_FLOWCHART.md](../MAIN_FLOWCHART.md)
- **画像（SVG）**: [diagrams/main_overview.svg](diagrams/main_overview.svg)
- **ビューア（SVG表示 + ダウンロード）**: [diagrams/main_overview.html](diagrams/main_overview.html)
- **Mermaid生コード**: [diagrams/main_overview.mmd](diagrams/main_overview.mmd)

```mermaid
flowchart TD
    START[アプリ起動] --> MAIN[main()]
    MAIN --> TEST{ kZiqImportTest ?<br/>ZIQ_IMPORT_TEST }

    %% --- Test mode ---
    TEST -->|Yes| ZIQTEST[_runZiqImportTestMode]
    ZIQTEST --> ZIQFILES[ZIQ/ZIP から必要ファイル抽出<br/>vxVisMgr.ini / DioMonitorLog.csv / Plc_*.csv / FNL_*.csv]
    ZIQFILES --> PARSEINI[INI解析<br/>IOActive/IOSetting/StatusSignal]
    PARSEINI --> PARSECSV[CSV解析<br/>Timeline/ActivePorts]
    PARSECSV --> OUT[結果をコンソール出力して終了]

    %% --- Normal mode ---
    TEST -->|No| RUNAPP[runApp(MultiProvider)]
    RUNAPP --> P1[FormStateNotifier]
    RUNAPP --> P2[FormControllersNotifier]
    RUNAPP --> P3[LocaleNotifier]
    RUNAPP --> P4[SettingsNotifier]

    RUNAPP --> APP[TimingChartGeneratorApp]
    APP --> HOME[TimingChartGeneratorHomePage]

    HOME --> TABS[TabController (2 tabs)]
    TABS --> TAB0[Tab0: FormTab]
    TABS --> TAB1[Tab1: TimingChart]

    %% Form -> Chart update
    TAB0 --> UC[Update Chart]
    UC --> CB[onUpdateChart callback]
    CB --> UPD[ChartUpdateService.updateChart<br/>(既存値/順序をマージ)]
    UPD --> S1[setState: _chartSignals/_chartPortNumbers/_chartIoSources]
    S1 --> CTRL[TimingChartController.setSignalNames/setSignals]
    CTRL --> TAB1

    %% Import/Export/Settings
    TAB0 --> ZIQ[ZIQ Import]
    ZIQ --> ZIQSVC[ZiqImportService.importZiq]
    ZIQSVC --> APPLY[フォーム/設定/チャートへ反映<br/>(ports, names, durations, timeUnitIsMs...)]

    TAB0 --> EXP[Export]
    EXP --> EXPSVC[ExportService.*<br/>(JSON/JPEG/XLSX)]

    HOME --> DRAWER[Drawer]
    DRAWER --> SETTINGS[SettingsWindow]
    DRAWER --> HELP[HelpDialog]
    DRAWER --> ABOUT[VersionInfoDialog]

    %% Notes
    SETTINGS -.-> NOTE1[showIoNumbers は HomePage state + SharedPreferences で保持]
    SETTINGS -.-> NOTE2[言語は LocaleNotifier を更新]

    style START fill:#e1f5ff
    style HOME fill:#e1f5ff
    style TAB0 fill:#fff3e0
    style TAB1 fill:#f3e5f5
    style SETTINGS fill:#e8f5e9
```

## ディレクトリ構造

```
widgets_flowcharts/
├── README.md                    # このファイル（全体のインデックス）
├── chart/                       # タイミングチャート関連ウィジェット
│   ├── README.md
│   ├── timing_chart.md
│   ├── chart_signals.md
│   ├── chart_grid.md
│   ├── chart_annotations.md
│   ├── coordinate_mapper.md
│   └── drawing_util.md
├── form/                        # フォーム入力関連ウィジェット
│   ├── README.md
│   ├── form_tab.md
│   ├── input_section.md
│   ├── output_section.md
│   ├── hw_trigger_section.md
│   └── camera_section.md
├── common/                      # 共通ウィジェット
│   ├── README.md
│   ├── suggestion_text_field.md
│   ├── custom_dropdown.md
│   └── version_info_dialog.md
├── settings/                     # 設定関連ウィジェット
│   ├── README.md
│   └── settings_window.md
└── data_flow/                   # データフローと状態管理
    ├── README.md
    ├── form_to_chart.md
    ├── state_management.md
    └── event_handling.md
```

## 全体アーキテクチャ

```mermaid
flowchart TD
    A[main.dart] --> AP[MultiProvider]
    AP --> APP[TimingChartGeneratorApp]
    APP --> HOME[TimingChartGeneratorHomePage]
    HOME --> B[TabController]
    B --> C[Tab 0: FormTab]
    B --> D[Tab 1: TimingChart]
    
    C --> E[InputSection]
    C --> F[OutputSection]
    C --> G[HwTriggerSection]
    C --> H[CameraSection]
    C --> I[Update Chart Button]
    
    E --> J[SuggestionTextField × N]
    F --> J
    G --> J
    H --> K[CustomDropdown]
    
    I --> L[更新パラメータ生成<br/>(names / values / types / ports / ioSources)]
    L --> M[onUpdateChart コールバック]
    M --> S[TimingChartGeneratorHomePage<br/>onUpdateChart ハンドラ]
    S --> U[ChartUpdateService.updateChart<br/>(既存値/順序のマージ)]
    U --> V[setState: _chartSignals / _chartPortNumbers / _chartIoSources 更新]
    V --> W[TimingChartController.setSignalNames/setSignals]
    
    D --> N[ChartGridManager]
    D --> O[ChartSignalsManager]
    D --> P[ChartAnnotationsManager]
    D --> Q[ChartCoordinateMapper]
    D --> R[chart_drawing_util.dart<br/>drawing utils]
    
    HOME --> X[SettingsWindow]
    
    style A fill:#e1f5ff
    style HOME fill:#e1f5ff
    style C fill:#fff3e0
    style D fill:#f3e5f5
    style X fill:#e8f5e9
```

## 各フォルダの説明

### [chart/](chart/) - タイミングチャート関連
タイミングチャートの描画と管理に関するウィジェットのフローを説明します。
- `TimingChart`: メインのチャートウィジェット
- `ChartSignalsManager`: 信号波形の描画
- `ChartGridManager`: グリッドとラベルの描画
- `ChartAnnotationsManager`: アノテーションの描画

### [form/](form/) - フォーム入力関連
フォーム入力画面のウィジェットのフローを説明します。
- `FormTab`: メインのフォームタブ
- `InputSection`: 入力信号セクション
- `OutputSection`: 出力信号セクション
- `HwTriggerSection`: HWトリガーセクション

### [common/](common/) - 共通ウィジェット
複数の場所で使用される共通ウィジェットのフローを説明します。
- `SuggestionTextField`: 候補付きテキストフィールド
- `CustomDropdown`: カスタムドロップダウン
- `VersionInfoDialog`: バージョン情報ダイアログ

### [settings/](settings/) - 設定関連
設定ウィンドウのウィジェットのフローを説明します。
- `SettingsWindow`: 設定ウィンドウ

### [data_flow/](data_flow/) - データフローと状態管理
ウィジェット間のデータフローと状態管理の仕組みを説明します。
- `form_to_chart.md`: FormTabからTimingChartへのデータ更新フロー
- `state_management.md`: Providerを使った状態管理
- `event_handling.md`: イベント処理のフロー

## 関連ドキュメント

- [MAIN_FLOWCHART.md](../MAIN_FLOWCHART.md) - main.dartの処理フロー
- [TIMING_CHART_FLOWCHARTS.md](../TIMING_CHART_FLOWCHARTS.md) - TimingChartの詳細フロー

