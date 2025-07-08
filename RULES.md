# プロジェクト共通ルール集

このドキュメントは、プロジェクトを円滑に進めるために **必ず守るルール** を整理する場所です。チームで新しいルールを追加する場合は、以下のフォーマットに従って項目を追記してください。

---

## 1. ルール記載フォーマット

```text
- [カテゴリ] ルール名
  - 概要   : ルールの簡潔な説明 (1 ～ 2 行)
  - 目的   : このルールを設ける背景や意図
  - 詳細   : 遵守方法を具体的に (コード例やコマンド例を含めても良い)
  - 例外   : 例外が許容される条件 (なければ "なし")
  - 追加日 : YYYY-MM-DD (著者名)
```

> **補足**
> - 「カテゴリ」は `コード`, `Git`, `UI`, `ドキュメント` など自由に設定できます。
> - ルールを更新・修正した場合は「追加日」を「更新日」に置き換え、履歴を残すと読みやすくなります。

---

## 2. サンプルルール

以下は実際のルール記載イメージです。新しいルールを追加する際の参考にしてください。

### 2.1 コーディング規約

- [コード] 命名規則
  - 概要   : 変数・メソッド・クラスの命名は Dart の公式スタイルガイドに従う。
  - 目的   : 可読性と一貫性を保つため。
  - 詳細   :
    1. `lowerCamelCase` → 変数, メソッド.
    2. `UpperCamelCase` → クラス, enum.
    3. `SCREAMING_SNAKE_CASE` → 定数.
  - 例外   : なし
  - 追加日 : 2024-07-05 (Alice)

- [コード] TODO コメントの書式
  - 概要   : TODO には期限と担当者を必ず記載する。
  - 目的   : 放置される TODO を減らす。
  - 詳細   : `// TODO(担当者名, YYYY-MM-DD): やること`
  - 例外   : 一時的なデバッグ時 (速やかに削除すること)
  - 追加日 : 2024-07-05 (Bob)

### 2.2 Git 運用

- [Git] コミットメッセージ
  - 概要   : Conventional Commits を採用する。
  - 目的   : 自動リリースと CHANGELOG 生成を容易にするため。
  - 詳細   :
    - 形式: `<type>(scope): <subject>`
    - `type` は `feat`, `fix`, `docs`, `chore`, `refactor` など。
    - 例: `feat(chart): add template waveform generator`.
  - 例外   : リリースタグ用コミットは `chore(release): <version>` とする。
  - 追加日 : 2024-07-05 (Charlie)

- [Git] Pull Request (PR) ルール
  - 概要   : 各 PR は 1 つの目的に絞り、スクリーンショットまたは GIF を添付する。
  - 目的   : レビュー効率を高め、UI 変更を視覚的に確認できるようにする。
  - 詳細   :
    - Draft → レビュー依頼 → Approve → Merge のフローを徹底。
    - CI を必ずパスさせること。
  - 例外   : ドキュメントのみの修正ではスクリーンショットは不要。
  - 追加日 : 2024-07-05 (Dana)

### 2.3 UI / UX

- [UI] 色の使用
  - 概要   : カラーパレットは `assets/design/colors.pdf` に定義されたもののみ使用する。
  - 目的   : ブランディングを一貫させるため。
  - 詳細   : Flutter では `Theme.of(context).colorScheme` から取得する。
  - 例外   : プロトタイプ段階の検証 UI では暫定色を許可。ただし PR 時に TODO コメントを追加。
  - 追加日 : 2024-07-05 (Eve)

---

## 3. ルール追加・更新手順

1. 本ファイルを編集し、上記フォーマットでルールを追記または更新。
2. PR を作成し、**ルール変更用テンプレート** を使用して背景・影響範囲を明記。
3. チーム全員のレビュー承認後に `master` (または `main`) へマージ。

---

## 4. 参考リンク

- Dart Style Guide: <https://dart.dev/guides/language/effective-dart>
- Conventional Commits: <https://www.conventionalcommits.org/ja/v1.0.0/> 

---

## 5. チャート作成用ルール

以下の手順・書式で **チャート作成用ルール** を追記すると分かりやすく整理できます。

1. 「カテゴリ」に `[Chart]` や `[Chart/UI]` などを設定し、既存フォーマットに合わせて記述  
2. 「目的」で “読みやすさを担保する”“開発者間で表記ゆれを防ぐ” など背景を明示  
3. 「詳細」に  
   • 軸ラベルや単位の書き方  
   • カラーパレット・線種の使い分け  
   • データサンプリング間隔・補間方法  
   • 凡例やタイトルの配置ルール  
   • リサイズ時／モバイル表示時の振る舞い  
   など具体的なチェックリストを列挙  
4. 例外がある場合は明示  
5. 追加日・著者を必ず記載

―― 追記イメージ ――

```text
- [Chart] 軸ラベルと単位
  - 概要   : すべてのチャートに X/Y 軸ラベルと単位を必ず表示する。
  - 目的   : 実験条件やデータ解釈ミスを防ぐため。
  - 詳細   :
    1. X 軸 : 「時間 [ms]」「フレーム [idx]」など角括弧で単位を入れる。
    2. Y 軸 : 信号名＋単位 (例: 「電圧 [V]」)。
    3. 追加の軸 (右 Y 軸) がある場合は凡例で区別し、色を変える。
  - 例外   : プレースホルダープレビューでは省略可 (PR 説明に明記)。
  - 追加日 : 2024-07-05 (Alice)

- [Chart] カラー & 線種ガイドライン
  - 概要   : 信号タイプごとに色・線種を固定する。
  - 目的   : 視認性と一貫性を確保。
  - 詳細   :
    - Input   : 青系 (#1E88E5) / 実線
    - Output  : 赤系 (#E53935) / 破線 (dash)
    - HWTrig  : 緑系 (#43A047) / 点線 (dot)
    - 参考 : `assets/design/chart_colors.pdf`
  - 例外   : 障害者向けカラーモードでは ColorBlind Palette を優先。
  - 追加日 : 2024-07-05 (Bob)

- [Chart/UI] レスポンシブ対応
  - 概要   : 画面幅 < 600px では凡例を下部に折り畳む。
  - 目的   : モバイル環境での可読性向上。
  - 詳細   :
    1. `MediaQuery.of(context).size.width` で判定。
    2. 折り畳み時はアイコン＋信号名を 2 列表示。
  - 例外   : なし
  - 追加日 : 2024-07-05 (Charlie) 
```

## 5. チャート作成用ルール（Template ボタン用）

> **目的**: Template ボタン押下時に自動生成されるタイミングチャートの振る舞いを一元的に定義する。実装側ではここに書かれたルールをパースして `SignalData` を生成するだけに留め、ロジックが肥大化しないようにする。

### 5.1 記述フォーマット

以下の YAML ライクな DSL でルールを表現する。*

```yaml
# グローバル設定 ------------------------------------------------------------
unit: idx           # 時間単位 (idx: サンプルインデックス, ms: ミリ秒等)
param:
  x: 2              # 可変パラメータ (整数)。必要に応じて UI 側で変更可。

# シグナル定義 --------------------------------------------------------------
signals:
  BUSY:
    init: 0                     # 初期状態
    transitions:
      - when: TRIGGER ↑         # 立ち上がりエッジ
        to:   1
      - when: last_exposure_end + (x+2)
        to:   0
      - when: ENABLE_RESULT_SIGNAL ↓
        to:   1

  INSPECTION_BUSY: alias BUSY    # 完全に BUSY と同じ

  CAMERA_#_IMAGE_EXPOSURE:       # # はカメラ番号 (1..N)
    init: 0
    mode_map:
      mode1:
        pattern: seq             # n 回 1→0 を順次 (x+3 以上の間隔)
      mode2:
        pattern: contact_wait    # CONTACT_INPUT_WAITING ↑ で 1
      mode3:
        pattern: hw_trigger      # 対応 HWTrigger ↑ で 1

  CAMERA_#_IMAGE_ACQUISITION:
    init: 0
    transitions:
      - when: CAMERA_#_IMAGE_EXPOSURE ↑
        to:   1
      - when: CAMERA_#_IMAGE_EXPOSURE ↓ + (x+1)
        to:   0

  AUTO_MODE:
    init: 0
    transitions:
      - at: 2                    # x=2 タイミングで 1
        to: 1
    sticky: true                # 立ち下がらない

  ENABLE_RESULT_SIGNAL:
    init: 0
    transitions:
      - when: BATCH_EXPOSURE_COMPLETE ↓ + (x+4)
        to:   1
      - duration: 3             # 1 → 0 に戻るまでの長さ (x=3)

  TOTAL_RESULT_OK: alias ENABLE_RESULT_SIGNAL
  BATCH_EXPOSURE_COMPLETE: alias BATCH_EXPOSURE
```

*実装では YAML パーサを使うか、上記と同等構造の JSON に変換して利用しても良い。

### 5.2 不足・検討ポイント

- **時間単位**: `idx` を採用したが、ms など物理時間が必要な場合は `unit` を拡張する。
- **パラメータ `x`**: UI で入力させる／設定ファイルで指定するなど運用ルールが必要。
- **`last_exposure_end` の定義**: 最終カメラ露光 `↓` の時点で良いか要確認。
- **`BATCH_EXPOSURE` / `BATCH_EXPOSURE_COMPLETE`**: 生成アルゴリズム未定義。別途ルールを追記すること。
- **モード別パターン `seq`, `contact_wait`, `hw_trigger`**: 詳細パラメータ（幅・間隔）を定義するか検討。
- **可読性**: 複雑になったらサブ YAML へ分割しインポート機能を検討。

上記をベースに **Template ボタン用ルール** を記載し、追加・変更があればこの節へ追記してください。実装側では、

1. YAML (または JSON) を読み込み → `Map` 化
2. `signals` をイテレートし `SignalData` を構築
3. 生成後に `_onUpdateChart()` を呼び出して描画

の 3 ステップで拡張に耐えられる構成を推奨します。 

# -------------------------------------------------------
# グローバル設定
# -------------------------------------------------------
meta:
  version: 1            # ルールファイルのバージョン (マイグレーション用)
  unit: idx             # 時間単位 (idx: インデックス, ms: ミリ秒 など)
  param:                # 可変パラメータはここに集約
    x: 2

# -------------------------------------------------------
# シグナル定義
# -------------------------------------------------------
signals:

  BUSY:
    init: 0
    transitions:
      - when: TRIGGER ↑
        to:   1
      - when: last_exposure_end + (x+2)
        to:   0
      - when: ENABLE_RESULT_SIGNAL ↓
        to:   1

  INSPECTION_BUSY: { alias: BUSY }

  CAMERA_#_IMAGE_EXPOSURE:             # # はカメラ番号を表す
    init: 0
    mode_map:
      mode1: { pattern: seq, min_gap: x+3 }
      mode2: { pattern: contact_wait }
      mode3: { pattern: hw_trigger }

  CAMERA_#_IMAGE_ACQUISITION:
    init: 0
    transitions:
      - when: CAMERA_#_IMAGE_EXPOSURE ↑
        to:   1
      - when: CAMERA_#_IMAGE_EXPOSURE ↓ + (x+1)
        to:   0

  AUTO_MODE:
    init: 0
    transitions:
      - at: 2
        to: 1
    sticky: true                       # 立ち下がらない

  ENABLE_RESULT_SIGNAL:
    init: 0
    transitions:
      - when: BATCH_EXPOSURE_COMPLETE ↓ + (x+4)
        to:   1
      - duration: 3                    # 1 でいる長さ

  TOTAL_RESULT_OK:      { alias: ENABLE_RESULT_SIGNAL }
  BATCH_EXPOSURE_COMPLETE: { alias: BATCH_EXPOSURE } 