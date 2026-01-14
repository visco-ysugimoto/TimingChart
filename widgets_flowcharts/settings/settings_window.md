# SettingsWindow ウィジェット フロー

`SettingsWindow` は、環境設定ウィンドウを表示するウィジェットです。

## 主要な機能

- 一般設定
- チャート設定
- 入出力設定
- 外観設定
- 言語設定

## データフロー

```mermaid
flowchart TD
    A[SettingsWindow 表示] --> B[NavigationRailでカテゴリ選択]
    B --> C{選択されたカテゴリ}
    
    C -->|0| D[一般設定]
    C -->|1| E[チャート設定]
    C -->|2| F[入出力設定]
    C -->|3| G[外観設定]
    C -->|4| H[言語設定]
    
    D --> I[設定値の取得]
    E --> I
    F --> I
    G --> I
    H --> I
    
    I --> J[設定変更]
    J --> K[SettingsNotifier / LocaleNotifier / 親State を更新]
    K --> L[Provider.watch + setState により反映]
    
    style A fill:#e1f5ff
    style B fill:#fff3e0
    style I fill:#e8f5e9
```

## カテゴリ一覧

### 0: 一般設定
- IO番号表示の切り替え
- デフォルトカメラ数の設定

### 1: チャート設定
- グリッド線の表示切り替え
- デフォルトチャート長の設定
- 信号色の設定（入力/出力/HWトリガー）
- コメント色の設定（破線/矢印/省略線）

### 2: 入出力設定
- デフォルトエクスポートフォルダの設定
- ファイル名プレフィックスの設定

### 3: 外観設定
- ダークモードの切り替え
- アクセントカラーの設定

### 4: 言語設定
- 日本語/英語の選択

## 主要メソッド

### build()
設定ウィンドウのUIを構築します。

### _buildPanel()
選択されたカテゴリに応じた設定パネルを構築します。

### _pickColor()
色選択ダイアログを表示します。

## パラメータ

### コンストラクタパラメータ
- `showIoNumbers`: IO番号を表示するかどうか
- `onShowIoNumbersChanged`: IO番号表示変更時のコールバック

## SettingsNotifier との連携

`SettingsWindow` は主に `SettingsNotifier` を `Provider.watch()` で監視してUIへ反映します。

- **showIoNumbers**: `SettingsNotifier` ではなく `TimingChartGeneratorHomePage` 側の state（+ SharedPreferences）で保持し、
  `SettingsWindow(showIoNumbers, onShowIoNumbersChanged)` 経由で変更します。
- **言語**: `LocaleNotifier` を更新します（`SettingsNotifier` ではありません）。

## 関連ファイル

- `lib/widgets/settings/settings_window.dart` - 実装ファイル
- [../data_flow/state_management.md](../data_flow/state_management.md) - 状態管理の詳細

