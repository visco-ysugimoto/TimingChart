# main.dart 処理フローチャート

## 0. 全体図（main.dart からの流れ）

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

## 1. アプリケーション起動フロー

```
[アプリ起動]
    │
    ├─→ kZiqImportTest == true?
    │   │
    │   ├─ YES → [ZIQインポートテストモード実行]
    │   │         │
    │   │         ├─→ ZIQファイル選択
    │   │         │
    │   │         ├─→ ZIPファイルから必要なファイルを読み込み
    │   │         │   ├─ vxVisMgr.ini
    │   │         │   ├─ DioMonitorLog.csv
    │   │         │   ├─ Plc_DioMonitorLog.csv
    │   │         │   └─ FNL_DioMonitorLog.csv
    │   │         │
    │   │         ├─→ INIファイル解析
    │   │         │   ├─ IOActive設定
    │   │         │   ├─ IOSetting設定
    │   │         │   └─ StatusSignal設定
    │   │         │
    │   │         ├─→ CSVファイル解析
    │   │         │   ├─ タイムライン生成
    │   │         │   ├─ アクティブポート検出
    │   │         │   └─ アクティブ入力ポート検出
    │   │         │
    │   │         └─→ 結果をコンソールに出力
    │   │
    │   └─ NO → [通常モード]
    │            │
    │            ├─→ Provider初期化
    │            │   ├─ FormStateNotifier
    │            │   ├─ FormControllersNotifier
    │            │   ├─ LocaleNotifier
    │            │   └─ SettingsNotifier
    │            │
    │            └─→ TimingChartGeneratorApp起動
    │                 │
    │                 └─→ TimingChartGeneratorHomePage表示
```

## 2. TimingChartGeneratorHomePage 初期化フロー

```
[initState呼び出し]
    │
    ├─→ TabController初期化 (2タブ)
    │
    ├─→ 初期フォーム状態設定
    │   ├─ triggerOption: 'Single Trigger'
    │   ├─ ioPort: 32
    │   ├─ inputCount: 32
    │   ├─ outputCount: 32
    │   └─ hwPort: 0
    │
    ├─→ FormControllersNotifier初期化
    │   ├─ 入力コントローラー作成
    │   ├─ 出力コントローラー作成
    │   └─ ハードウェアトリガーコントローラー作成
    │
    ├─→ TimingChartController初期化
    │
    ├─→ タブ変更リスナー登録
    │
    └─→ フォーム状態をProviderに設定
```

## 3. タブ変更フロー

```
[タブ変更]
    │
    ├─→ チャートタブ → フォームタブ?
    │   │
    │   └─ YES → チャートアノテーションを保存
    │
    └─→ フォームタブ → チャートタブ?
        │
        └─ YES → チャートデータを更新
                 ├─→ アノテーション適用
                 ├─→ 信号名を設定
                 └─→ 信号値を設定
```

## 4. 入力/出力転送フロー

```
[転送ボタン押下]
    │
    ├─→ 現在のチャートデータを取得
    │   ├─→ 信号名リスト
    │   └─→ 信号値リスト
    │
    ├─→ 名前→値のマッピングを作成
    │
    ├─→ コントローラーの値を交換
    │   ├─→ DIO ↔ PLC/EIP
    │
    ├─→ チャート信号データを更新
    │   ├─→ 名前に対応する値を更新
    │
    ├─→ フォームに信号値を登録
    │
    └─→ チャートを更新
        ├─→ 信号名を更新
        └─→ 信号値を更新
```

## 5. ZIQインポートフロー

```
[ZIQインポート開始]
    │
    ├─→ ローディング表示開始
    │
    ├─→ ZIQファイル選択
    │   └─→ ZIPファイルに変換
    │
    ├─→ ZIPファイルから必要なファイルを読み込み
    │   ├─ vxVisMgr.ini
    │   ├─ DioMonitorLog.csv
    │   ├─ Plc_DioMonitorLog.csv
    │   └─ FNL_DioMonitorLog.csv
    │
    ├─→ ZiqImportService.importZiq実行
    │   ├─→ INIファイル解析
    │   ├─→ CSVファイル解析
    │   ├─→ 信号データ生成
    │   └─→ マッピング情報生成
    │
    ├─→ フォーム状態更新
    │   ├─→ 入力ポート数更新
    │   ├─→ 出力ポート数更新
    │   ├─→ トリガーオプション更新
    │   └─→ PLC/EIPオプション設定
    │
    ├─→ チャートデータ更新
    │   ├─→ 信号データ設定
    │   ├─→ ポート番号設定
    │   ├─→ IOソース設定
    │   └─→ 表示名生成
    │
    ├─→ ステップ継続時間設定
    │   ├─→ 平均時間計算
    │   └─→ 各ステップの時間設定
    │
    ├─→ 時間単位をミリ秒に設定
    │
    ├─→ チャートコントローラー更新
    │
    ├─→ グリッド再計算要求
    │
    ├─→ インポート結果をスナックバーで表示
    │
    └─→ ローディング表示終了
```

## 6. チャート更新フロー

```
[チャート更新要求]
    │
    ├─→ ChartUpdateService.updateChart実行
    │   ├─→ 既存信号とのマージ処理
    │   ├─→ 信号タイプ判定
    │   ├─→ IOソース検出
    │   └─→ ポート番号設定
    │
    ├─→ 状態更新
    │   ├─→ _chartSignals更新
    │   ├─→ _chartPortNumbers更新
    │   └─→ _chartIoSources更新
    │
    ├─→ チャートコントローラー更新
    │   ├─→ 信号名設定
    │   └─→ 信号値設定
    │
    └─→ チャートウィジェット更新
        ├─→ 信号名更新
        └─→ 信号値更新
```

## 7. IOソース検出フロー

```
[IOソース検出]
    │
    ├─→ 信号タイプが入力/出力?
    │   └─ NO → unknownを返す
    │
    ├─→ ラベルからプレフィックス抽出
    │   ├─→ コロン(:)で分割
    │   └─→ スペースで分割
    │
    ├─→ プレフィックスから判定
    │   ├─→ PLI/PLO → PLC
    │   ├─→ ESI/ESO → EIP
    │   ├─→ INPUT/OUTPUT → DIO
    │   └─→ 不明 → 次のステップへ
    │
    ├─→ コントローラーリストを検索
    │   ├─→ 入力の場合
    │   │   ├─→ DIO入力コントローラー検索
    │   │   └─→ PLC/EIP入力コントローラー検索
    │   │
    │   └─→ 出力の場合
    │       ├─→ DIO出力コントローラー検索
    │       └─→ PLC/EIP出力コントローラー検索
    │
    └─→ IOソースを返す
```

## 8. エクスポートフロー

```
[エクスポート要求]
    │
    ├─→ JSONエクスポート?
    │   │
    │   └─ YES → ExportService.exportConfig実行
    │            ├─→ フォーム状態取得
    │            ├─→ チャートデータ取得
    │            ├─→ アノテーション取得
    │            ├─→ JSON形式に変換
    │            └─→ ファイル保存
    │
    ├─→ JPEGエクスポート?
    │   │
    │   └─ YES → ExportService.exportChartImageJpeg実行
    │            ├─→ チャートをレンダリング
    │            ├─→ 画像に変換
    │            └─→ JPEGファイル保存
    │
    └─→ XLSXエクスポート?
        │
        └─ YES → ExportService.exportXlsx実行
                 ├─→ 信号データ取得
                 ├─→ アノテーション取得
                 ├─→ Excel形式に変換
                 └─→ XLSXファイル保存
```

## 9. 設定インポートフロー

```
[設定インポート開始]
    │
    ├─→ JSONファイル選択
    │
    ├─→ FileUtils.importAppConfig実行
    │   └─→ JSONファイル読み込み
    │
    ├─→ フォーム状態復元
    │   ├─→ 入力ポート数設定
    │   ├─→ 出力ポート数設定
    │   └─→ ハードウェアトリガー数設定
    │
    ├─→ コントローラーの値を設定
    │   ├─→ 入力名設定
    │   ├─→ 出力名設定
    │   └─→ ハードウェアトリガー名設定
    │
    ├─→ 設定値復元
    │   ├─→ 時間単位設定
    │   ├─→ ステップ時間設定
    │   └─→ ステップ継続時間設定
    │
    ├─→ チャートデータ復元
    │   ├─→ アノテーション設定
    │   └─→ 省略インデックス設定
    │
    └─→ フォームタブに設定を適用
```

## 10. 全フィールドクリアフロー

```
[クリアボタン押下]
    │
    ├─→ すべてのコントローラーをクリア
    │
    ├─→ チャートデータをクリア
    │   ├─→ 信号データ削除
    │   ├─→ ポート番号削除
    │   ├─→ IOソース削除
    │   └─→ アノテーション削除
    │
    ├─→ チャートウィジェットをクリア
    │   ├─→ 信号名を空に
    │   ├─→ 信号値を空に
    │   └─→ アノテーションを空に
    │
    ├─→ フォーム状態を初期値にリセット
    │   ├─→ triggerOption: 'Single Trigger'
    │   ├─→ ioPort: 32
    │   ├─→ inputCount: 32
    │   ├─→ outputCount: 32
    │   └─→ hwPort: 0
    │
    ├─→ コントローラー数を初期値に設定
    │
    └─→ ステップ継続時間をクリア
```

## 11. ウィジェット破棄フロー

```
[dispose呼び出し]
    │
    ├─→ タブ変更リスナーを削除
    │
    ├─→ TabControllerを破棄
    │
    ├─→ すべてのコントローラーを破棄
    │   ├─→ 入力コントローラー
    │   ├─→ 出力コントローラー
    │   └─→ ハードウェアトリガーコントローラー
    │
    └─→ 親クラスのdispose呼び出し
```

