# SuggestionTextField ウィジェット フロー

`SuggestionTextField` は、候補付きテキストフィールドウィジェットです。

## 主要な機能

- 候補リストの表示
- ID ↔ ラベル変換
- 重複チェック
- 言語変更対応

## 初期化フロー

```mermaid
flowchart TD
    A[SuggestionTextField 作成] --> B[initState呼び出し]
    B --> C[_updateSuggestions呼び出し]
    C --> D[widget.loadSuggestions実行]
    D --> E[候補リストを非同期取得]
    
    B --> F[_internalController作成]
    F --> G[widget.controller.textをラベルに変換]
    
    B --> H[widget.controllerのリスナー登録]
    H --> I[_onExternalControllerChanged]

    B --> H2{重複チェック有効?}
    H2 -->|Yes| H3[excludeControllers の変更リスナー登録]
    
    B --> J[言語変更リスナー登録]
    J --> K[suggestionLanguageVersion.addListener]
    
    style A fill:#e1f5ff
    style C fill:#fff3e0
    style E fill:#e8f5e9
```

## 入力処理フロー

```mermaid
flowchart TD
    A[ユーザー入力（ラベル）] --> B[Autocomplete/TextField に反映]
    B --> C[重複チェック（label→id変換して比較）]
    C --> D{重複あり?}
    D -->|Yes| E[errorText表示 + 背景を赤系に]
    D -->|No| F[入力済みをアクセント色でハイライト]
    
    B --> G{確定タイミング}
    G -->|フォーカス喪失| H[_commitFieldToParent]
    G -->|onEditingComplete| H
    H --> I[ラベル→IDへ変換して widget.controller.text に反映]
    
    style A fill:#e1f5ff
    style C fill:#fff3e0
    style D fill:#ffebee
```

## 主要メソッド

### initState()
初期化処理を実行します。
- `_updateSuggestions()` を呼び出し
- `_internalController` を作成
- `widget.controller` のリスナーを登録
- （重複チェック有効時）`excludeControllers` の変更リスナーを登録
- 言語変更リスナーを登録

### _updateSuggestions()
候補リストを更新します。
- `widget.loadSuggestions()` を実行
- `translateCurrent` がtrueの場合、現在のテキストを翻訳

### _onExternalControllerChanged()
外部コントローラーの変更を処理します。
- `widget.controller.text` をラベルに変換
- `_internalController.text` を更新

### _onFocusChange() / _commitFieldToParent()
確定タイミング（フォーカス喪失や編集完了）で、入力された **ラベル** を候補リストから **ID** に変換し、
`widget.controller.text` に反映します。

### _idToLabel()
IDをラベルに変換します。
- 候補リストからIDに対応するラベルを検索

### _labelToId()
ラベルをIDに変換します。
- 候補リストからラベルに対応するIDを検索

## パラメータ

### コンストラクタパラメータ
- `label`: ラベルテキスト
- `controller`: TextEditingController
- `loadSuggestions`: 候補リストを読み込む関数
- `excludeControllers`: 重複チェック用のコントローラーリスト（オプション）
- `enableDuplicateCheck`: 重複チェックを有効にするかどうか

## 言語変更対応

言語が変更されると、`suggestionLanguageVersion` のリスナーが呼び出され、`_updateSuggestions(translateCurrent: true)` が実行されます。これにより、現在のテキストが新しい言語で翻訳されます。

## 重複チェック

`enableDuplicateCheck` がtrueの場合、`excludeControllers` に含まれるコントローラーの値と重複していないかチェックします。

**現状実装のポイント:**
- 候補一覧は「使用済みID」を除外してフィルタされます（入力時の候補から重複を避ける）
- 入力フィールドは **重複時に `errorText` を表示** し、背景色も赤系に変わります

## 関連ファイル

- `lib/widgets/common/suggestion_text_field.dart` - 実装ファイル
- [../form/form_tab.md](../form/form_tab.md) - FormTabでの使用例

