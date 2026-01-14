# FormTab → TimingChart データ更新フロー

このドキュメントは、FormTabからTimingChartへのデータ更新フローを説明します。

## データ更新フロー

```mermaid
flowchart LR
    A[Update Chart ボタン押下] --> B[FormTab._onUpdateChart]
    B --> C[FormTabState で更新パラメータ生成]
    C --> C1[generateSignalNames()]
    C --> C2[generateFilteredChartData()]
    C --> C3[generateSignalTypes()]
    C --> C4[generatePortNumbers()]
    C --> C5[generateIoChannelSources()]
    
    C --> D[可視信号のみへフィルタ]
    D --> E[onUpdateChart コールバック]
    E --> F[TimingChartGeneratorHomePage]
    
    F --> G[ChartUpdateService.updateChart<br/>(既存値/順序をマージ)]
    G --> H[setState: _chartSignals / _chartPortNumbers / _chartIoSources 更新]
    H --> I[TimingChartController.setSignalNames/setSignals]
    I --> J[TimingChart に反映・再描画]
    
    style A fill:#ffebee
    style C fill:#e3f2fd
    style F fill:#fff3e0
    style I fill:#e8f5e9
    style J fill:#c8e6c9
```

## 詳細な処理フロー

### 1. Update Chart ボタン押下

ユーザーが「Update Chart」ボタンを押すと、`FormTab._onUpdateChart()` が呼び出されます。

### 2. SignalData 生成

`FormTab._onUpdateChart()` 内で、以下の更新パラメータが生成されます：

- **信号名**: `generateSignalNames()`
- **信号値（チャートデータ）**: `generateFilteredChartData()`（可視信号のみ）
- **信号タイプ**: `generateSignalTypes()`
- **ポート番号**: `generatePortNumbers()`（可視信号のみへ整合）
- **IOソース**: `generateIoChannelSources()`

### 3. SignalData オブジェクト作成

生成されたデータから `SignalData` オブジェクトが作成されます：

```dart
SignalData(
  signalNames: List<String>,      // 信号名のリスト
  signals: List<List<int>>,         // 信号値のリスト（各行は時間経過に伴う0/1値のリスト）
  signalTypes: List<SignalType>,    // 信号タイプのリスト
  portNumbers: List<int>,           // ポート番号のリスト
)
```

### 4. onUpdateChart コールバック

更新パラメータが `onUpdateChart` コールバックを通じて `TimingChartGeneratorHomePage` に渡されます。

### 5. TimingChartGeneratorHomePage で状態更新

`TimingChartGeneratorHomePage` で以下の状態が更新されます：

- `ChartUpdateService.updateChart(...)` で「既存値の維持」と「表示順の維持」を行った上で、
  - `_chartSignals`
  - `_chartPortNumbers`
  - `_chartIoSources`
  を `setState` で更新します。

### 6. TimingChart にデータを渡す

更新されたデータは、`TimingChart(controller: ...)` 経由で反映されます（必要に応じて `TimingChartState` にも反映）：

- `initialSignalNames`
- `initialSignals`
- `signalTypes`
- `portNumbers`

### 7. TimingChart 再ビルド

`TimingChart` が再ビルドされ、新しいデータでチャートが描画されます。

## データ構造

### SignalData

```dart
class SignalData {
  final List<String> signalNames;
  final List<List<int>> signals;
  final List<SignalType> signalTypes;
  final List<int> portNumbers;
}
```

### 信号値の形式

各信号は時間経過に伴う0/1値のリストとして表現されます：

```dart
signals: [
  [0, 1, 1, 0, 1, ...],  // 信号1の時間経過
  [1, 0, 0, 1, 0, ...],  // 信号2の時間経過
  ...
]
```

## 関連ファイル

- `lib/widgets/form/form_tab.dart` - FormTabの実装
- `lib/widgets/chart/timing_chart.dart` - TimingChartの実装
- `lib/services/chart_update_service.dart` - 既存値/順序を保ちながら更新するサービス
- `lib/models/chart/chart_data_generator.dart` - 初期チャートデータ生成ユーティリティ（必要時）
- [../form/form_tab.md](../form/form_tab.md) - FormTabの詳細
- [../chart/timing_chart.md](../chart/timing_chart.md) - TimingChartの詳細

