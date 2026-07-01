// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// Web専用。package:web への移行は今後のタスク。
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

Future<Uint8List> pngToJpegBytes(
  Uint8List pngBytes, {
  required int quality,
  required int backgroundColorValue,
}) async {
  final q = quality.clamp(0, 100) / 100.0;
  final rBg = (backgroundColorValue >> 16) & 0xFF;
  final gBg = (backgroundColorValue >> 8) & 0xFF;
  final bBg = backgroundColorValue & 0xFF;

  final pngBlob = html.Blob([pngBytes], 'image/png');
  final pngUrl = html.Url.createObjectUrlFromBlob(pngBlob);

  try {
    final imgEl = html.ImageElement(src: pngUrl);
    final loaded = Completer<void>();
    late html.EventListener onLoad;
    late html.EventListener onError;

    onLoad = (html.Event _) {
      imgEl.removeEventListener('load', onLoad);
      imgEl.removeEventListener('error', onError);
      if (!loaded.isCompleted) loaded.complete();
    };
    onError = (html.Event _) {
      imgEl.removeEventListener('load', onLoad);
      imgEl.removeEventListener('error', onError);
      if (!loaded.isCompleted) {
        loaded.completeError(StateError('Failed to decode PNG in browser'));
      }
    };

    imgEl.addEventListener('load', onLoad);
    imgEl.addEventListener('error', onError);
    await loaded.future;

    final width = imgEl.naturalWidth;
    final height = imgEl.naturalHeight;
    if (width <= 0 || height <= 0) {
      throw StateError('Invalid decoded image size: ${width}x$height');
    }

    final canvas = html.CanvasElement(width: width, height: height);
    final ctx = canvas.context2D;
    ctx.imageSmoothingEnabled = true;
    ctx.fillStyle = 'rgb($rBg,$gBg,$bBg)';
    ctx.fillRect(0, 0, width, height);
    ctx.drawImageScaled(imgEl, 0, 0, width, height);

    late final html.Blob jpegBlob;
    try {
      jpegBlob = await canvas.toBlob('image/jpeg', q);
    } catch (_) {
      final dataUrl = canvas.toDataUrl('image/jpeg', q);
      final comma = dataUrl.indexOf(',');
      if (comma < 0) {
        throw StateError('Invalid data URL returned from canvas.toDataUrl()');
      }
      final b64 = dataUrl.substring(comma + 1);
      return Uint8List.fromList(base64Decode(b64));
    }

    final reader = html.FileReader();
    final readCompleter = Completer<Uint8List>();
    reader.onLoad.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        readCompleter.complete(Uint8List.view(result));
      } else if (result is Uint8List) {
        readCompleter.complete(result);
      } else {
        readCompleter.completeError(
          StateError('Unexpected FileReader result type: ${result.runtimeType}'),
        );
      }
    });
    reader.onError.listen((_) {
      readCompleter.completeError(StateError('Failed to read JPEG blob'));
    });
    reader.readAsArrayBuffer(jpegBlob);
    return await readCompleter.future;
  } finally {
    html.Url.revokeObjectUrl(pngUrl);
  }
}
