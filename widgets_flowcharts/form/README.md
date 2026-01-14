# form/ フォルダ - フォーム入力関連ウィジェット

このフォルダには、フォーム入力画面のウィジェットのデータフローが含まれています。

## ファイル一覧

- [form_tab.md](form_tab.md) - FormTabウィジェットの詳細フロー
- [input_section.md](input_section.md) - InputSectionのフロー
- [output_section.md](output_section.md) - OutputSectionのフロー
- [hw_trigger_section.md](hw_trigger_section.md) - HwTriggerSectionのフロー
- [camera_section.md](camera_section.md) - CameraSectionのフロー

## 全体構造

```mermaid
flowchart TD
    A[FormTab] --> B[InputSection]
    A --> C[OutputSection]
    A --> D[HwTriggerSection]
    A --> E[CameraSection]
    A --> F[Update Chart Button]
    
    B --> G[SuggestionTextField × N]
    C --> G
    D --> G
    E --> H[CustomDropdown]
    
    F --> I[更新パラメータ生成<br/>(names / values / types / ports / ioSources)]
    I --> J[onUpdateChart コールバック]
    
    style A fill:#e1f5ff
    style F fill:#fff3e0
    style I fill:#e8f5e9
```

## データフロー

```
[FormTab 初期化]
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

## 主要なウィジェット

### FormTab
メインのフォームタブ。各セクションを統合管理し、チャート更新処理を担当します。

### InputSection
入力信号セクション。入力信号の設定を行います。

### OutputSection
出力信号セクション。出力信号の設定を行います。

### HwTriggerSection
HWトリガーセクション。ハードウェアトリガーの設定を行います。

### CameraSection
カメラ選択セクション。カメラの選択を行います。

