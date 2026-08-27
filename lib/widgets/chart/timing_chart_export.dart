part of 'timing_chart.dart';

/// 画像エクスポート（PNG/JPEG）関連をまとめた `part` ファイル。
///
/// - **目的**: `TimingChartState` から画像生成/エクスポートの関心を分離する。
/// - **実装**: `extension TimingChartExportExt on TimingChartState` として提供する。
/// - **注意**:
///   - `export_service.dart` など別ライブラリから拡張メソッド解決できるよう、extension 名は **公開**（先頭 `_` なし）。
///   - `extension` から `static` メンバー参照する場合は `TimingChartState.` 修飾が必要。
///   - `BuildContext` lint（`use_build_context_synchronously`）を避けるため、`await` 前に必要情報を取り出す。
extension TimingChartExportExt on TimingChartState {
  /// チャートをPNG画像としてキャプチャします
  ///
  /// スクロールで隠れている部分も含め、チャート全体を画像にレンダリングします。
  /// より良い品質のために高いピクセル比を使用します。
  ///
  /// [pixelRatio] - オプションのピクセル比（デフォルトはデバイス比または3.0）
  /// PNG画像バイトを返します。キャプチャに失敗した場合はnullを返します
  Future<Uint8List?> captureChartPng({double? pixelRatio}) async {
    try {
      final ui.Image? image = await _captureFullChartUiImage(
        pixelRatio: pixelRatio,
      );
      if (image == null) return null;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing chart PNG: $e');
      return null;
    }
  }

  /// チャートをJPEG画像としてキャプチャします
  ///
  /// スクロールで隠れている部分も含め、チャート全体を画像にレンダリングし、
  /// JPEG形式に変換します。背景色とのアルファチャネル合成を処理します。
  ///
  /// [pixelRatio] - オプションのピクセル比（デフォルトはデバイス比または3.0）
  /// [backgroundColor] - アルファ合成用の背景色（デフォルトはテーマ）
  /// [quality] - JPEG品質0-100（デフォルトは90）
  /// JPEG画像バイトを返します。キャプチャに失敗した場合はnullを返します
  Future<Uint8List?> captureChartJpeg({
    double? pixelRatio,
    Color? backgroundColor,
    int quality = 90,
  }) async {
    try {
      // avoid `use_build_context_synchronously`（await後のcontext参照）対策として先に評価
      final Brightness brightness = Theme.of(context).brightness;

      final ui.Image? image = await _captureFullChartUiImage(
        pixelRatio: pixelRatio,
      );
      if (image == null) return null;

      final width = image.width;
      final height = image.height;

      final Color bg =
          backgroundColor ??
          (brightness == Brightness.dark ? Colors.black : Colors.white);

      // WebではDart側のJPEGエンコード（package:image）が非常に重いので、
      // ブラウザネイティブのCanvasエンコードに逃がす。
      if (kIsWeb) {
        final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (pngData == null) return null;
        final jpeg = await web_jpeg.pngToJpegBytes(
          pngData.buffer.asUint8List(),
          quality: quality,
          backgroundColorValue: bg.toARGB32(),
        );
        return jpeg;
      }

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;

      final rgbaBytes = byteData.buffer.asUint8List();

      final int rBg = (bg.r * 255).round();
      final int gBg = (bg.g * 255).round();
      final int bBg = (bg.b * 255).round();

      final Uint8List rgbBytes = Uint8List(width * height * 3);
      int si = 0; // source index
      int di = 0; // dest index
      for (int i = 0; i < width * height; i++) {
        final int r = rgbaBytes[si];
        final int g = rgbaBytes[si + 1];
        final int b = rgbaBytes[si + 2];
        final int a = rgbaBytes[si + 3];
        final int outR = ((r * a + rBg * (255 - a)) / 255).round();
        final int outG = ((g * a + gBg * (255 - a)) / 255).round();
        final int outB = ((b * a + bBg * (255 - a)) / 255).round();
        rgbBytes[di] = outR;
        rgbBytes[di + 1] = outG;
        rgbBytes[di + 2] = outB;
        si += 4;
        di += 3;
      }

      final img.Image rgbImage = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgbBytes.buffer,
        numChannels: 3,
      );
      final jpg = img.encodeJpg(rgbImage, quality: quality);
      return Uint8List.fromList(jpg);
    } catch (e) {
      debugPrint('Error capturing chart JPEG: $e');
      return null;
    }
  }

  /// 表示中のビューポートではなく、チャート全体を画像化する。
  ///
  /// 縦/横スクロールで画面外にある行・時間軸も含めるため、
  /// CustomPaint の painter をオフスクリーンへ再描画する。
  Future<ui.Image?> _captureFullChartUiImage({double? pixelRatio}) async {
    final Size? logicalSize = _exportLogicalChartSize();
    if (logicalSize == null) return null;

    final double pr = _resolveExportPixelRatio(pixelRatio, logicalSize);

    try {
      final ui.Image? painted = await _paintChartToImage(logicalSize, pr);
      if (painted != null) return painted;
    } catch (e) {
      debugPrint('Offscreen chart paint failed, falling back: $e');
    }

    return _captureRepaintBoundaryToImage(pr);
  }

  Size? _exportLogicalChartSize() {
    final renderObject = _customPaintKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox &&
        renderObject.hasSize &&
        renderObject.size.width.isFinite &&
        renderObject.size.height.isFinite &&
        renderObject.size.width > 0 &&
        renderObject.size.height > 0) {
      return renderObject.size;
    }

    final contentBoundary =
        _repaintBoundaryKey.currentContext?.findRenderObject();
    if (contentBoundary is RenderBox &&
        contentBoundary.hasSize &&
        contentBoundary.size.width.isFinite &&
        contentBoundary.size.height.isFinite &&
        contentBoundary.size.width > 0 &&
        contentBoundary.size.height > 0) {
      return contentBoundary.size;
    }
    return null;
  }

  double _resolveExportPixelRatio(double? pixelRatio, Size logicalSize) {
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final double defaultRatio =
        kIsWeb
            ? 2.0
            : TimingChartState._defaultExportPixelRatio;
    final double maxRatio =
        kIsWeb ? 3.0 : TimingChartState._maxExportPixelRatio;
    double pr =
        (pixelRatio ?? math.max(devicePixelRatio, defaultRatio))
            .clamp(1.0, maxRatio)
            .toDouble();
    final double maxDim = math.max(logicalSize.width, logicalSize.height);
    if (maxDim > 0 &&
        maxDim * pr > TimingChartState._maxExportImageDimension) {
      pr = TimingChartState._maxExportImageDimension / maxDim;
    }
    return pr;
  }

  Future<ui.Image?> _paintChartToImage(Size logicalSize, double pixelRatio) async {
    final renderObject = _customPaintKey.currentContext?.findRenderObject();
    if (renderObject is! RenderCustomPaint) return null;
    final CustomPainter? painter = renderObject.painter;
    if (painter == null) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);
    painter.paint(canvas, logicalSize);
    _paintLabelsOverlayForExport(canvas);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(
        math.max(1, (logicalSize.width * pixelRatio).ceil()),
        math.max(1, (logicalSize.height * pixelRatio).ceil()),
      );
    } finally {
      picture.dispose();
    }
  }

  /// 画面では別レイヤーの信号ラベルを、チャート全体座標に乗せて描画する。
  /// 縦スクロールオフセットは含めない（全行のラベルが波形と揃うようにする）。
  void _paintLabelsOverlayForExport(Canvas canvas) {
    final overlayObject =
        _labelsOverlayKey.currentContext?.findRenderObject();
    if (overlayObject is! RenderCustomPaint) return;
    final CustomPainter? overlayPainter = overlayObject.painter;
    if (overlayPainter == null) return;

    final double labelAreaHeight = math.max(
      0.0,
      _visibleIndexes.length * _cellHeight,
    );
    if (labelAreaHeight <= 0) return;

    final Size overlaySize = Size(
      chartMarginLeft + labelWidth,
      labelAreaHeight,
    );
    canvas.save();
    canvas.translate(0, chartMarginTop + _topCommentAreaHeight);
    canvas.clipRect(Offset.zero & overlaySize);
    overlayPainter.paint(canvas, overlaySize);
    canvas.restore();
  }

  Future<ui.Image?> _captureRepaintBoundaryToImage(double pixelRatio) async {
    RenderRepaintBoundary? boundary =
        _repaintBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    boundary ??=
        _viewportBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    return boundary.toImage(pixelRatio: pixelRatio);
  }
}
