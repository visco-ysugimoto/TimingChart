import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../models/backup/app_config.dart';
import '../models/chart/timing_chart_annotation.dart';
import 'wavedrom_converter.dart';
import '../suggestion_loader.dart';
import '../models/chart/signal_data.dart';

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
      try {
        // まず従来形式(AppConfig JSON)を試す
        return AppConfig.fromJsonString(jsonString);
      } catch (_) {
        // 失敗したら WaveDrom 形式を試す
        try {
          return WaveDromConverter.fromWaveDromJson(jsonString);
        } catch (_) {
          return null;
        }
      }
    } catch (e) {
      print('Error importing app config: $e');
      return null;
    }
  }

  /// AppConfig を WaveDrom JSON としてエクスポート
  static Future<bool> exportWaveDrom(
    AppConfig config, {
    List<TimingChartAnnotation>? annotations,
    String? customFileName,
  }) async {
    // --- 追加: ID を現在の言語のラベルへ置き換えた Config を作成 ---
    Future<AppConfig> _translatedConfig(AppConfig cfg) async {
      // 信号名を変換
      final translatedSignals = <SignalData>[];
      for (final s in cfg.signals) {
        translatedSignals.add(s.copyWith(name: await labelOfId(s.name)));
      }

      // 各名前リストを変換
      Future<List<String>> _translateList(List<String> list) async {
        return Future.wait(list.map((id) => labelOfId(id)));
      }

      final inputNames = await _translateList(cfg.inputNames);
      final outputNames = await _translateList(cfg.outputNames);
      final hwTriggerNames = await _translateList(cfg.hwTriggerNames);

      return AppConfig(
        formState: cfg.formState,
        signals: translatedSignals,
        tableData: cfg.tableData,
        inputNames: inputNames,
        outputNames: outputNames,
        hwTriggerNames: hwTriggerNames,
        inputVisibility: cfg.inputVisibility,
        outputVisibility: cfg.outputVisibility,
        hwTriggerVisibility: cfg.hwTriggerVisibility,
        rowModes: cfg.rowModes,
      );
    }

    try {
      // まず変換済み Config を取得
      final translated = await _translatedConfig(config);

      // ファイル名生成
      final now = DateTime.now();
      final formattedDate =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final defaultFileName = 'timing_wave_$formattedDate.json';
      final fileName = customFileName ?? defaultFileName;

      // WaveDrom JSON 文字列を取得
      final wavedromJson = WaveDromConverter.toWaveDromJson(
        translated,
        annotations: annotations,
      );

      // 保存先選択
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'WaveDrom JSON の保存先を選択',
        fileName: fileName,
        allowedExtensions: ['json'],
        type: FileType.custom,
      );

      if (outputFile == null) {
        return false; // キャンセル
      }

      // 拡張子強制
      if (!outputFile.toLowerCase().endsWith('.json')) {
        outputFile += '.json';
      }

      // 書き込み
      final file = File(outputFile);
      await file.writeAsString(wavedromJson);

      return true;
    } catch (e) {
      print('Error exporting WaveDrom: $e');
      return false;
    }
  }
}
