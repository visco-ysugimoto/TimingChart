# OutputSection ウィジェット フロー

`OutputSection` は、出力信号セクションを表示するウィジェットです。

## 主要な機能

- 出力信号の設定
- 可視性の制御（チェックボックス）

## データフロー

```mermaid
flowchart TD
    A[OutputSection 作成] --> B[count分のフィールドを生成]
    B --> C[SuggestionTextField]
    C --> D[候補リスト表示]
    D --> E[重複チェック]
    B --> F[Checkbox]
    F --> G[可視性変更]
    
    style A fill:#e1f5ff
    style C fill:#e8f5e9
    style F fill:#fff3e0
```

## 主要メソッド

### build()
出力セクションのUIを構築します。

## パラメータ

### コンストラクタパラメータ
- `controllers`: TextEditingControllerのリスト
- `count`: 出力ポート数
- `visibilityList`: 可視性のリスト
- `onVisibilityChanged`: 可視性変更時のコールバック

## 関連ファイル

- `lib/widgets/form/output_section.dart` - 実装ファイル
- [form_tab.md](form_tab.md) - FormTabの詳細
- [../common/suggestion_text_field.md](../common/suggestion_text_field.md) - SuggestionTextFieldの詳細

