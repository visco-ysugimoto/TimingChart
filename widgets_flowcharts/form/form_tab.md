# FormTab ウィジェット フロー

`FormTab` は、タイミングチャートのフォーム入力画面を管理するウィジェットです。

## 主要な機能

- 入力/出力/HW Trigger の信号設定を管理
- カメラ設定とトリガーオプション（Single/Code/Command）の選択
- Camera Configuration Table によるカメラ設定の管理
- Template/Update ボタンによる設定の適用と更新
- 設定のインポート/エクスポート機能

## データフロー

```mermaid
flowchart TD
    A[FormTab 初期化] --> B[FormStateNotifierから状態取得]
    B --> C[FormControllersNotifierからコントローラー取得]
    C --> D[各セクションにデータを渡す]
    
    D --> E[InputSection]
    D --> F[OutputSection]
    D --> G[HwTriggerSection]
    D --> H[CameraSection]
    
    E --> I[SuggestionTextField × N]
    F --> I
    G --> I
    
    H --> J[CustomDropdown]
    
    K[Update Chart ボタン押下] --> L[更新パラメータ生成<br/>(names / values / types / ports / ioSources)]
    L --> M[onUpdateChart コールバック]
    
    style A fill:#e1f5ff
    style D fill:#fff3e0
    style L fill:#e8f5e9
```

## 初期化フロー

```
[FormTab 作成]
    │
    ├─→ FormStateNotifier から状態取得
    │   ├─→ inputCount
    │   ├─→ outputCount
    │   ├─→ hwPort
    │   ├─→ triggerOption
    │   └─→ cameraCount
    │
    ├─→ FormControllersNotifier からコントローラー取得
    │   ├─→ inputControllers[]
    │   ├─→ outputControllers[]
    │   └─→ hwTriggerControllers[]
    │
    └─→ 各セクションにデータを渡す
```

## Update Chart ボタン処理

```mermaid
flowchart LR
    A[Update Chart ボタン押下] --> B[FormTab._onUpdateChart]
    B --> C[generateSignalNames()]
    B --> D[generateFilteredChartData()]
    B --> E[generateSignalTypes()]
    B --> F[generatePortNumbers()]
    B --> G[generateIoChannelSources()]
    
    C --> H[可視信号のみへフィルタ]
    D --> H
    E --> H
    F --> H
    G --> H
    
    H --> I[onUpdateChart コールバック]
    I --> J[TimingChartGeneratorHomePage に渡す]
    
    style A fill:#ffebee
    style H fill:#e3f2fd
    style I fill:#fff3e0
```

## 主要メソッド

### build()
フォームUIを構築します。

### _buildInputSection()
入力セクションを構築します。

### _buildOutputSection()
出力セクションを構築します。

### _onUpdateChart()
チャート更新処理を実行します。
- `FormTabState` が `names / values / types / ports / ioSources` を生成（可視信号のみ）
- `onUpdateChart` コールバックを呼び出し（親: `TimingChartGeneratorHomePage`）

## データ構造

### onUpdateChart コールバック引数
`FormTab` は `SignalData` オブジェクト1個を渡すのではなく、以下の配列をまとめて親へ渡します。

- `names: List<String>`: 信号名（可視信号のみ）
- `values: List<List<int>>`: 波形（可視信号のみ）
- `types: List<SignalType>`: 信号タイプ（可視信号のみ）
- `ports: List<int>`: ポート番号（可視信号のみ）
- `ioSources: List<IoChannelSource>`: IOソース（可視信号のみ）
- `overrideFlag: bool`: 既存値を上書きするか（現状は主に `false`）

### SignalData（内部表現）
フォーム内では `lib/models/chart/signal_data.dart` の `SignalData(name, signalType, values, isVisible)` を使って
「可視性や型を含む信号一覧」を保持し、`Update Chart` 時に可視信号だけを抽出して上記配列にします。

## 関連ファイル

- `lib/widgets/form/form_tab.dart` - 実装ファイル
- [input_section.md](input_section.md) - InputSectionの詳細
- [output_section.md](output_section.md) - OutputSectionの詳細
- [hw_trigger_section.md](hw_trigger_section.md) - HwTriggerSectionの詳細
- [camera_section.md](camera_section.md) - CameraSectionの詳細
- [../data_flow/form_to_chart.md](../data_flow/form_to_chart.md) - FormTabからTimingChartへのデータフロー

