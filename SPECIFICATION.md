# Timing Chart Generator 仕様書

## 1. 目的・概要
- 製造ラインや画像検査装置の **タイミングチャート** を GUI で生成・可視化するクロスプラットフォーム Flutter アプリ。
- フォーム入力・テンプレート YAML（`assets/chart_rules`）・入力補完データを組み合わせ、信号波形（Input／Output／HW Trigger 等）を自動生成。
- 多言語 UI（日本語・英語）、ダークモード、アクセントカラー変更をサポート。

## 2. 主な機能
| カテゴリ | 機能 | 詳細 |
| --- | --- | --- |
| 入力フォーム | フォームタブ (`FormTab`) | トリガ種別・IO ポート数・カメラ台数などを入力し `TimingFormState` へ保持。入力候補を `SuggestionTextField` で表示。 |
| チャート描画 | `TimingChart` ウィジェット | Grid・Signal・Annotation コンポーネントで構成。ピンチ・スクロール操作、凡例、コメント描画に対応。 |
| テンプレート生成 | `chart_template_engine.dart` | YAML DSL (`assets/chart_rules/template_v1.yaml`) をパースし `SignalData` を生成。「Template」ボタンで即時描画。 |
| エクスポート | `wavedrom_converter.dart` | 内部データ → WaveDrom JSON へ変換。`share_plus` で外部共有。 |
| 設定画面 | `SettingsWindow` & `SettingsNotifier` | ダークモード、アクセントカラー、言語設定を保持。`ThemeData` をカスタマイズ。 |

## 3. 技術スタック
- Flutter 3.7 / Dart 3 系
- Provider (状態管理)
- intl + intl_utils（多言語）
- path_provider, file_picker, share_plus, cross_file（ファイル操作）
- google_fonts, dotted_line（UI）

## 4. ディレクトリ構成（主要）
```
lib/
├ models/                # データ構造 (SignalData, TimingFormState ...)
├ providers/             # 状態管理 (FormStateNotifier 等)
├ utils/                 # 汎用ロジック (テンプレートパーサ, WaveDrom 変換)
├ widgets/
│  ├ chart/           # チャート描画部品
│  ├ form/            # 入力フォーム UI
│  ├ common/          # 共通 UI
│  └ settings/        # 設定画面
├ l10n/ & generated/    # 多言語リソース
└ main.dart             # アプリエントリ
```

## 5. アーキテクチャ
1. **UI 層 (Widgets)** ⇔ 2. **状態層 (Providers / Notifiers)** ⇔ 3. **ドメイン層 (Models / Utils)**
- UI 変更やフォーム更新は `notifyListeners()` でチャートへ反映。
- テンプレート → Signal 生成も同パイプラインに統合。

## 6. コーディング・運用ルール
- `RULES.md` にコーディング規約、Git 運用、UI / Chart デザイン指針を記載。
- チャート DSL 拡張方針やバージョン管理も同ファイル 5 章に整理。

## 7. ビルド & 実行
```bash
flutter pub get
flutter run             # -d windows|android|macos など指定可
```
- 国際化コードは `flutter intl` タスクで自動生成。

## 8. テスト
- `test/` 配下にユニットテスト (フォーム状態, チャート生成, WaveDrom 変換)。
- 実行: `flutter test`

## 9. 将来の拡張案
- チャートの PNG / SVG エクスポート
- Undo / Redo・レイヤ機能・複数テンプレート対応
- GitHub Actions による CI (linter & テスト)

---
このドキュメントは随時更新してください。 