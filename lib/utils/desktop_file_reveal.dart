import 'dart:io';

import 'package:flutter/foundation.dart';

/// 保存したファイルを OS のファイルマネージャで表示する
Future<void> revealFileInFileManager(String filePath) async {
  if (kIsWeb) return;
  final file = File(filePath);
  if (!await file.exists()) return;

  try {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [file.parent.path]);
    }
  } catch (_) {
    // 失敗してもエクスポート自体は成功扱い
  }
}
