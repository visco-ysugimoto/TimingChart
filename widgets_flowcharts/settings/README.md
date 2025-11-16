# settings/ フォルダ - 設定関連ウィジェット

このフォルダには、設定ウィンドウのウィジェットのデータフローが含まれています。

## ファイル一覧

- [settings_window.md](settings_window.md) - SettingsWindowの詳細フロー

## 全体構造

```mermaid
flowchart TD
    A[SettingsWindow] --> B[NavigationRail]
    B --> C[一般設定]
    B --> D[チャート設定]
    B --> E[入出力設定]
    B --> F[外観設定]
    B --> G[言語設定]
    
    C --> H[IO番号表示]
    C --> I[デフォルトカメラ数]
    
    D --> J[グリッド表示]
    D --> K[信号色設定]
    D --> L[コメント色設定]
    
    E --> M[エクスポートフォルダ]
    E --> N[ファイル名プレフィックス]
    
    F --> O[ダークモード]
    F --> P[アクセントカラー]
    
    G --> Q[日本語]
    G --> R[英語]
    
    style A fill:#e1f5ff
    style B fill:#fff3e0
```

## 主要なウィジェット

### SettingsWindow
設定ウィンドウ。NavigationRailを使用してカテゴリを選択し、各カテゴリの設定項目を表示します。

