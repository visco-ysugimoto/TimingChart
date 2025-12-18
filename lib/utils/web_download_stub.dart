import 'dart:typed_data';

void downloadBytes(
  Uint8List bytes,
  String fileName, {
  String mimeType = 'application/octet-stream',
}) {
  throw UnsupportedError('downloadBytes is only supported on web.');
}



