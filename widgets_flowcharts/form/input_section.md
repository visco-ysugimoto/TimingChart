# InputSection ウィジェット フロー

`InputSection` は、入力信号セクションを表示するウィジェットです。

## 主要な機能

- 入力信号の設定
- 信号タイプの自動判定（Control/Group/Task）
- ロックされた信号の表示（編集不可）

## データフロー

```mermaid
flowchart TD
    A[InputSection 作成] --> B[count分のフィールドを生成]
    B --> C{信号タイプを判定}
    C -->|Control/Group/Task| D[ロックされたTextField]
    C -->|Input| E[SuggestionTextField]
    
    D --> F[編集不可]
    E --> G[候補リスト表示]
    G --> H[重複チェック]
    
    style A fill:#e1f5ff
    style D fill:#ffebee
    style E fill:#e8f5e9
```

## 信号タイプの判定

### Code Trigger モード（32ポート）
- Input2~9: `SignalType.control`
- Input10~15: `SignalType.group`
- Input16~21: `SignalType.task`
- その他: `SignalType.input`

### Code Trigger モード（16ポート）
- Input2~5: `SignalType.control`
- Input6~8: `SignalType.group`
- Input9~14: `SignalType.task`
- その他: `SignalType.input`

## 主要メソッド

### build()
入力セクションのUIを構築します。

### _getSignalType()
信号タイプを取得します。
- `triggerOption` と `count` に基づいて判定
- Code Trigger モードの場合、特定のインデックス範囲で Control/Group/Task を返す

## パラメータ

### コンストラクタパラメータ
- `controllers`: TextEditingControllerのリスト
- `count`: 入力ポート数
- `visibilityList`: 可視性のリスト
- `onVisibilityChanged`: 可視性変更時のコールバック
- `triggerOption`: トリガーオプション（Single/Code/Command）

## 関連ファイル

- `lib/widgets/form/input_section.dart` - 実装ファイル
- [form_tab.md](form_tab.md) - FormTabの詳細
- [../common/suggestion_text_field.md](../common/suggestion_text_field.md) - SuggestionTextFieldの詳細

