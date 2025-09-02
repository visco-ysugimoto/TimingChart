import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:excel/excel.dart' as excel;
// Remove unused imports and dependencies on Flutter Material for this utility file
import '../models/backup/app_config.dart';
import '../models/chart/timing_chart_annotation.dart';
import '../models/chart/signal_data.dart';
import 'wavedrom_converter.dart';
import 'dart:typed_data';

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
    List<int>? omissionIndices,
    String? customFileName,
  }) async {
    // 以前は UI 言語に応じてラベルへ変換していたが、
    // デスクトップ運用では ID をそのまま保持した方が
    // インポート／エクスポート往復時に情報欠落がないため
    // 変換処理をスキップする。

    try {
      // ファイル名生成
      final now = DateTime.now();
      final formattedDate =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final defaultFileName = 'timing_wave_$formattedDate.json';
      final fileName = customFileName ?? defaultFileName;

      // WaveDrom JSON 文字列を取得（ID そのまま）
      final wavedromJson = WaveDromConverter.toWaveDromJson(
        config,
        annotations: annotations,
        omissionIndices: omissionIndices,
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

  /// PNG バイト列を保存する（保存ダイアログあり）
  static Future<bool> exportPngBytes(
    Uint8List bytes, {
    String? customFileName,
  }) async {
    try {
      final now = DateTime.now();
      final formattedDate =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final defaultFileName = 'timing_chart_$formattedDate.png';
      final fileName = customFileName ?? defaultFileName;

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'チャート画像 (PNG) の保存先を選択',
        fileName: fileName,
        allowedExtensions: ['png'],
        type: FileType.custom,
      );

      if (outputFile == null) return false;
      if (!outputFile.toLowerCase().endsWith('.png')) {
        outputFile += '.png';
      }

      final file = File(outputFile);
      await file.writeAsBytes(bytes);
      return true;
    } catch (e) {
      print('Error exporting PNG: $e');
      return false;
    }
  }

  /// JPEG バイト列を保存する（保存ダイアログあり）
  static Future<bool> exportJpegBytes(
    Uint8List bytes, {
    String? customFileName,
  }) async {
    try {
      final now = DateTime.now();
      final formattedDate =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final defaultFileName = 'timing_chart_$formattedDate.jpg';
      final fileName = customFileName ?? defaultFileName;

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'チャート画像 (JPEG) の保存先を選択',
        fileName: fileName,
        allowedExtensions: ['jpg', 'jpeg'],
        type: FileType.custom,
      );

      if (outputFile == null) return false;
      final lower = outputFile.toLowerCase();
      if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg')) {
        outputFile += '.jpg';
      }

      final file = File(outputFile);
      await file.writeAsBytes(bytes);
      return true;
    } catch (e) {
      print('Error exporting JPEG: $e');
      return false;
    }
  }

  /// XLSX形式でIO情報とチャートデータをエクスポート
  static Future<bool> exportXlsx({
    required List<String> inputNames,
    required List<String> outputNames,
    required List<String> hwTriggerNames,
    required List<SignalData> chartSignals,
    String? customFileName,
  }) async {
    try {
      final now = DateTime.now();
      final formattedDate =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final defaultFileName = 'timing_chart_export_$formattedDate.xlsx';
      final fileName = customFileName ?? defaultFileName;

      // Excel ワークブックを作成
      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['Sheet1'];

      // ヘッダー行の設定
      sheet
          .cell(excel.CellIndex.indexByString('A1'))
          .value = excel.TextCellValue('IO番号');
      sheet
          .cell(excel.CellIndex.indexByString('B1'))
          .value = excel.TextCellValue('Input');
      sheet
          .cell(excel.CellIndex.indexByString('C1'))
          .value = excel.TextCellValue('Output');
      sheet
          .cell(excel.CellIndex.indexByString('D1'))
          .value = excel.TextCellValue('HW Trigger');

      // チャート信号名のヘッダーを10列目（J列）から開始
      int chartStartCol = 9; // J列のインデックス（0ベース）
      sheet
          .cell(
            excel.CellIndex.indexByColumnRow(
              columnIndex: chartStartCol,
              rowIndex: 0,
            ),
          )
          .value = excel.TextCellValue('Signal Names');

      // 1. IO情報の記載（1-4列目）
      final maxIoRows = [
        inputNames.length,
        outputNames.length,
        hwTriggerNames.length,
      ].reduce((a, b) => a > b ? a : b);

      for (int i = 0; i < maxIoRows; i++) {
        // IO番号（A列）- 1から開始
        sheet
            .cell(
              excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1),
            )
            .value = excel.IntCellValue(i + 1);

        // Input名前（B列）
        if (i < inputNames.length && inputNames[i].isNotEmpty) {
          sheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 1,
                  rowIndex: i + 1,
                ),
              )
              .value = excel.TextCellValue(inputNames[i]);
        }

        // Output名前（C列）
        if (i < outputNames.length && outputNames[i].isNotEmpty) {
          sheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 2,
                  rowIndex: i + 1,
                ),
              )
              .value = excel.TextCellValue(outputNames[i]);
        }

        // HW Trigger名前（D列）
        if (i < hwTriggerNames.length && hwTriggerNames[i].isNotEmpty) {
          sheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 3,
                  rowIndex: i + 1,
                ),
              )
              .value = excel.TextCellValue(hwTriggerNames[i]);
        }
      }

      // 2. チャート情報の記載（10列目以降）
      if (chartSignals.isNotEmpty) {
        // 信号名をJ列（10列目）に記載
        for (int i = 0; i < chartSignals.length; i++) {
          sheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: chartStartCol,
                  rowIndex: i + 1,
                ),
              )
              .value = excel.TextCellValue(chartSignals[i].name);
        }

        // 各信号の波形をK列（11列目）以降に描画
        int maxSignalLength =
            chartSignals.isNotEmpty
                ? chartSignals
                    .map((s) => s.values.length)
                    .reduce((a, b) => a > b ? a : b)
                : 0;

        for (
          int signalIndex = 0;
          signalIndex < chartSignals.length;
          signalIndex++
        ) {
          final signal = chartSignals[signalIndex];
          int rowIndex = signalIndex + 1;

          for (int timeIndex = 0; timeIndex < maxSignalLength; timeIndex++) {
            int colIndex = chartStartCol + 1 + timeIndex; // K列から開始

            bool isHigh = false;
            if (timeIndex < signal.values.length) {
              isHigh = signal.values[timeIndex] != 0;
            }

            // セルの値を設定（1=High, 0=Low）
            final cellIndex = excel.CellIndex.indexByColumnRow(
              columnIndex: colIndex,
              rowIndex: rowIndex,
            );
            sheet.cell(cellIndex).value = excel.IntCellValue(isHigh ? 1 : 0);

            // セルの背景色でHigh/Lowを表現（スタイル設定は複雑なため、基本的な値のみ設定）
            // High=1, Low=0として値を設定することで、Excelでユーザが条件付き書式を適用可能
            // 必要に応じて後でスタイル設定を追加可能
          }
        }
      }

      // ファイル保存ダイアログを表示
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'XLSXファイルの保存先を選択',
        fileName: fileName,
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );

      if (outputFile == null) {
        return false; // ユーザーがキャンセルした場合
      }

      // 拡張子の確認と追加
      if (!outputFile.toLowerCase().endsWith('.xlsx')) {
        outputFile += '.xlsx';
      }

      // ファイルへの書き込み
      final fileBytes = excelFile.save();
      if (fileBytes != null) {
        final file = File(outputFile);
        await file.writeAsBytes(fileBytes);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error exporting XLSX: $e');
      return false;
    }
  }
}
