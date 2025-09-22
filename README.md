## TimingChart Generator

TimingChart は、フォーム入力からデジタル信号のタイミングチャートを生成・編集・エクスポートする Flutter アプリです。多言語対応（日本語/英語）、テンプレート生成、CSV/INI（ziq zip）からの取り込み、注釈付与、画像/XLSX 出力に対応します。

リポジトリ: `https://github.com/visco-ysugimoto/TimingChart.git`

### 主な機能
- フォーム入力（入出力/HW Trigger 名、ポート数、カメラ数、Trigger モード）
- Camera Configuration Table による取込スケジューリング
- Code/Command Trigger 用の補助信号（CODE_OPTION など）の自動生成
- チャート編集（クリックで反転、範囲選択で挿入/削除/複製、ラベルドラッグで行並べ替え）
- 注釈（コメント）の追加・編集・移動、波線（省略区間）の描画
- エクスポート（WaveDrom JSON、JPEG 画像、XLSX）/ インポート（JSON、ziq zip）
- 多言語 UI（日本語/英語）切替

### 画面構成（概要）
- Form タブ（`lib/widgets/form/form_tab.dart`）: 入力・設定・テンプレート生成・チャート更新
- TimingChart タブ（`lib/widgets/chart/timing_chart.dart`）: 波形表示・編集・注釈・画像出力

---

## セットアップ

前提: Flutter/Dart がインストールされていること

1) 依存解決
```
flutter pub get
```

2) 実行
```
flutter run
```

3) ビルド
```
flutter build windows   # Windows デスクトップ
flutter build apk       # Android
flutter build ios       # iOS (macOS 環境)
flutter build macos     # macOS
```

### 動作確認環境
- Dart SDK: `^3.7.2`（`pubspec.yaml` 参照）
- 主要パッケージ: `provider`, `google_fonts`, `excel`, `image`, `archive`, `file_picker`, `share_plus` ほか

---

## 使い方

1) アプリ起動後、Form タブで以下を設定
- Trigger Option: `Single / Code / Command`
- Input/Output/HW Port, Camera 数
- 入出力/HW Trigger の名称（ID）をテキスト欄に入力

2) Camera Configuration Table を編集
- 各カメラ列に対して、行ごとにモードを選択
- 行番号セルをクリックで「同時取込」切替（RowMode）

3) チャート生成/更新
- Template: 現在のテーブルと設定からテンプレート波形を生成
- Update Chart: 現在のフォーム内容からチャートへ反映（手動編集を優先保持）

4) TimingChart タブで編集
- クリックでビット反転、ドラッグで範囲選択→右クリックメニュー
- 注釈（コメント）追加/編集/削除、ドラッグで位置調整
- ラベル（左側）ドラッグで行並べ替え

5) エクスポート/インポート
- Drawer メニューから JSON（WaveDrom）、JPEG、XLSX をエクスポート
- JSON のインポート / ziq(zip) 読み込み（`vxVisMgr.ini`, `DioMonitorLog.csv`, `Plc_DioMonitorLog.csv`）

ヒント
- エクスポート前はチャートを最新にするために Update を推奨
- Code/Command Trigger では `CODE_OPTION` 等の補助信号を自動生成

---

## ローカライズ
- 文言は `lib/l10n/*.arb` → `lib/generated/` にコード生成（`flutter gen-l10n`/`intl_utils`）
- 画面から言語切替可能（Drawer メニュー）

---

## データ/ファイル
- エクスポート: WaveDrom JSON, 画像(JPEG), XLSX
- インポート: JSON, ziq(zip) 内の `vxVisMgr.ini`/`DioMonitorLog.csv`/`Plc_DioMonitorLog.csv`
- アセット: `assets/suggestions/*`, `assets/chart_rules/*`, `assets/mappings/*`

---

## 開発メモ

主要ソース
- エントリ: `lib/main.dart`
- フォーム: `lib/widgets/form/form_tab.dart`
- チャート: `lib/widgets/chart/timing_chart.dart`
- ユーティリティ: `lib/utils/*`（ファイル I/O、CSV パース、マッピング、テンプレート生成）
- モデル: `lib/models/*`（`SignalData`, `TimingFormState`, 注釈 など）
- 状態管理: `lib/providers/*`（`FormStateNotifier`, `LocaleNotifier`, `SettingsNotifier`）

.gitignore
- 生成物（`build/`, `.dart_tool/`, `android/.gradle/`, `ios/Pods/` など）を除外済み
- 秘密鍵やキーストア類（`*.keystore`, `*.jks`, `*.p12`, `*.pem`, `*.key` など）を除外

テスト
```
flutter test
```

---

## ライセンス
本リポジトリのライセンス形態が未定の場合は、必要に応じて `LICENSE` を追加してください。
