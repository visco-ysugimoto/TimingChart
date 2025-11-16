# VersionInfoDialog ウィジェット フロー

`VersionInfoDialog` は、バージョン情報を表示するダイアログウィジェットです。

## 主要な機能

- バージョン情報の表示
- 変更点の表示（Markdown形式）

## データフロー

```mermaid
flowchart TD
    A[VersionInfoDialog 作成] --> B[AlertDialog作成]
    B --> C[バージョン情報セクション]
    B --> D[変更点セクション]
    C --> E[SelectableTextでバージョン表示]
    D --> F[MarkdownBodyで変更点表示]
    
    style A fill:#e1f5ff
    style C fill:#fff3e0
    style D fill:#e8f5e9
```

## 主要メソッド

### build()
ダイアログのUIを構築します。

## パラメータ

### コンストラクタパラメータ
- `title`: ダイアログのタイトル（オプション）
- `version`: バージョン文字列（オプション）
- `changelog`: 変更点のMarkdownテキスト（オプション）

## 表示内容

### バージョン情報セクション
- バージョンラベル
- バージョン文字列（選択可能）

### 変更点セクション
- 変更点ラベル
- Markdown形式の変更点テキスト（スクロール可能）

## 関連ファイル

- `lib/widgets/common/version_info_dialog.dart` - 実装ファイル

