# 描画ユーティリティ（`chart_drawing_util.dart`）

`lib/widgets/chart/chart_drawing_util.dart` は、キャンバス上に破線や矢印、コメントボックス等を描画する
**ユーティリティ関数（トップレベル関数）** を提供します。

## 主要な機能

- 破線の描画
- 矢印の描画
- コメントボックスの描画

## 関数一覧

### drawDashedLine()
破線を描画します。

**パラメータ:**
- `canvas`: キャンバス
- `start`: 開始位置
- `end`: 終了位置
- `paint`: ペイントオブジェクト
- `dashWidth`: 破線の幅（デフォルト: 5.0）
- `dashSpace`: 破線間のスペース（デフォルト: 3.0）

**処理の流れ:**
1. 総距離を計算
2. パターン長を計算（`dashWidth + dashSpace`）
3. 破線の数を計算
4. 各破線セグメントを描画

**補足:**
- 実装ではデバッグ用に `debugPrint` が多めに入っています（必要なら将来的に抑制/削減できます）

### drawArrowhead()
矢印ヘッドを描画します。

**パラメータ:**
- `canvas`: キャンバス
- `tip`: 矢印の先端位置
- `angle`: 角度
- `length`: 矢印の長さ
- `paint`: ペイントオブジェクト

**処理:**
- 矢印の左右の線を描画
- 角度から左右の終点を計算

### drawArrowLine()
矢印付きの直線を描画します。

**パラメータ:**
- `canvas`: キャンバス
- `start`: 開始位置
- `end`: 終了位置
- `color`: 色（デフォルト: Colors.blue）
- `strokeWidth`: 線の幅（デフォルト: 2.0）

**処理の流れ:**
1. 直線を描画
2. 角度を計算
3. 矢印ヘッドを描画

### drawCommentBox()
コメントボックスを描画します。

**パラメータ:**
- `canvas`: キャンバス
- `rect`: 矩形
- `textPainter`: テキストペインター
- `annId`: アノテーションID
- `selectedAnnotationId`: 選択中のアノテーションID
- `borderColor`: コメントごとの枠線色（非選択時、null可）

**処理:**
- 矩形を描画
- テキストを描画
- 選択中の場合は強調表示

### drawArrow()
左右に矢印ヘッドが付いた水平矢印を描画します。

### drawWavyVerticalLine()
垂直方向の波線を描画します（開始点→終了点）。

### drawDoubleWavyVerticalLine()
2本の波線を垂直に並べ、その間を塗りつぶして描画します（省略表現などに使用）。

## 使用例

### 破線の描画
```dart
drawDashedLine(
  canvas,
  Offset(100, 100),
  Offset(200, 200),
  Paint()..color = Colors.black,
  dashWidth: 5.0,
  dashSpace: 3.0,
);
```

### 矢印の描画
```dart
drawArrowLine(
  canvas,
  Offset(100, 100),
  Offset(200, 200),
  color: Colors.blue,
  strokeWidth: 2.0,
);
```

## 関連ファイル

- `lib/widgets/chart/chart_drawing_util.dart` - 実装ファイル
- [chart_annotations.md](chart_annotations.md) - ChartAnnotationsManagerでの使用例

