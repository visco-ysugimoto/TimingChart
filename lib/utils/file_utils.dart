import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../models/backup/app_config.dart';

/// ファイル操作ユーティリティクラス
class FileUtils {
  /// アプリケーション設定をJSONファイルとしてエクスポート
  static Future<bool> exportAppConfig(
    AppConfig config, {
    String? customFileName,
  }) async {
    try {
      // ファイル名の生成（現在の日時を使用）
      final now = DateTime.now();
      final formattedDate =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final defaultFileName = 'timing_config_$formattedDate.json';
      final fileName = customFileName ?? defaultFileName;

      // JSONデータの取得
      final jsonString = config.toJsonString();

      // ファイル保存ダイアログを表示して保存先を選択
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'JSONファイルの保存先を選択',
        fileName: fileName,
        allowedExtensions: ['json'],
        type: FileType.custom,
      );

      if (outputFile == null) {
        return false; // ユーザーがキャンセルした場合
      }

      // 拡張子の確認と追加
      if (!outputFile.toLowerCase().endsWith('.json')) {
        outputFile += '.json';
      }

      // ファイルへの書き込み
      final file = File(outputFile);
      await file.writeAsString(jsonString);

      return true;
    } catch (e) {
      print('Error exporting app config: $e');
      return false;
    }
  }

  /// 以前の共有方式によるエクスポート（シェアダイアログを表示）
  static Future<bool> shareAppConfig(
    AppConfig config, {
    String? customFileName,
  }) async {
    try {
      // ファイル名の生成（現在の日時を使用）
      final now = DateTime.now();
      final formattedDate =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = customFileName ?? 'timing_config_$formattedDate.json';

      // 一時ディレクトリの取得
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';

      // JSONデータの取得
      final jsonString = config.toJsonString();

      // ファイルへの書き込み
      final file = File(filePath);
      await file.writeAsString(jsonString);

      // ファイル共有ダイアログを表示
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Timing Configuration Export',
        text: 'Exported timing configuration data.',
      );

      return true;
    } catch (e) {
      print('Error sharing app config: $e');
      return false;
    }
  }

  /// JSONファイルからアプリケーション設定をインポート
  static Future<AppConfig?> importAppConfig() async {
    try {
      // ファイル選択ダイアログを表示
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null; // ユーザーがキャンセルした場合
      }

      // 選択されたファイルパスを取得
      final filePath = result.files.first.path;
      if (filePath == null) {
        return null;
      }

      // ファイルからJSONを読み込み
      final file = File(filePath);
      final jsonString = await file.readAsString();

      // JSONからAppConfigを生成
      return AppConfig.fromJsonString(jsonString);
    } catch (e) {
      print('Error importing app config: $e');
      return null;
    }
  }
}
