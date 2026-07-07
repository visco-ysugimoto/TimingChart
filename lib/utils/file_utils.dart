import 'dart:io';
import 'dart:typed_data' show BytesBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, Colors;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as excel;
import 'compute_workers.dart';
import 'export_save_options.dart';
// Remove unused imports and dependencies on Flutter Material for this utility file
import '../models/backup/app_config.dart';
import '../models/chart/timing_chart_annotation.dart';
import '../models/chart/signal_data.dart';
import '../models/chart/signal_type.dart';
import 'wavedrom_converter.dart';
import 'dart:convert';

import 'web_download.dart' as web;

/// ファイル操作ユーティリティクラス
class FileUtils {
  /// 拡張子が無ければ付与する（`ext` は `.json` のようにドット付き）
  static String _ensureExtension(String name, String ext) {
    final normalized =
        ext.startsWith('.') ? ext.toLowerCase() : '.${ext.toLowerCase()}';
    if (name.toLowerCase().endsWith(normalized)) return name;
    return '$name$normalized';
  }

  /// 選択ファイルのバイト列を取得（path / bytes / readStream のいずれか）
  static Future<Uint8List?> _readPlatformFileBytes(PlatformFile file) async {
    final cached = file.bytes;
    if (cached != null) return cached;

    final path = file.path;
    if (path != null && !kIsWeb) {
      final f = File(path);
      if (await f.exists()) {
        return f.readAsBytes();
      }
    }

    final stream = file.readStream;
    if (stream != null) {
      final builder = BytesBuilder();
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }

    return null;
  }

  static String _prefixedFileName(String fileName, String? prefix) {
    if (prefix == null || prefix.isEmpty) return fileName;
    return '${prefix}_$fileName';
  }

  /// ダイアログ保存のパスからクイック保存用ベースディレクトリを更新
  static void rememberExportDirectoryFromPath({
    required String savedFilePath,
    required String exportSubFolder,
    required void Function(String baseDirectory) onBaseDirectoryResolved,
  }) {
    final parent = File(savedFilePath).parent.path;
    final sub = exportSubFolder.replaceAll('/', Platform.pathSeparator);
    if (parent.endsWith(sub)) {
      onBaseDirectoryResolved(Directory(parent).parent.path);
    } else {
      onBaseDirectoryResolved(parent);
    }
  }

  /// デスクトップ: クイック保存または保存ダイアログ
  static Future<String?> _saveBytesOnDesktop({
    required Uint8List bytes,
    required String fileName,
    required String extensionWithDot,
    required List<String> allowedExtensions,
    required String dialogTitle,
    ExportSaveOptions? options,
  }) async {
    final opts = options ?? const ExportSaveOptions();
    final effectiveName = _prefixedFileName(fileName, opts.fileNamePrefix);
    final nameWithExt = _ensureExtension(effectiveName, extensionWithDot);

    if (opts.quickExportEnabled &&
        opts.lastExportDirectory != null &&
        opts.lastExportDirectory!.isNotEmpty) {
      try {
        final dir = Directory(
          p.join(opts.lastExportDirectory!, opts.exportSubFolder),
        );
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final path = p.join(dir.path, nameWithExt);
        await File(path).writeAsBytes(bytes);
        opts.onSaved?.call(path, quickSave: true);
        return path;
      } catch (e) {
        debugPrint('Quick export failed, falling back to dialog: $e');
      }
    }

    final savedPath = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: nameWithExt,
      allowedExtensions: allowedExtensions,
      type: FileType.custom,
      bytes: bytes,
    );
    if (savedPath != null) {
      opts.onSaved?.call(savedPath, quickSave: false);
    }
    return savedPath;
  }

  /// アプリケーション設定をJSONファイルとしてエクスポート
  static Future<bool> exportAppConfig(
    AppConfig config, {
    String? customFileName,
    ExportSaveOptions? saveOptions,
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

      // Web はブラウザダウンロード
      if (kIsWeb) {
        final bytes = Uint8List.fromList(utf8.encode(jsonString));
        web.downloadBytes(bytes, fileName, mimeType: 'application/json');
        return true;
      }

      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      final savedPath = await _saveBytesOnDesktop(
        bytes: bytes,
        fileName: fileName,
        extensionWithDot: '.json',
        allowedExtensions: ['json'],
        dialogTitle: 'JSONファイルの保存先を選択',
        options: saveOptions,
      );

      return savedPath != null;
    } catch (e) {
      debugPrint('Error exporting app config: $e');
      return false;
    }
  }

  /// 以前の共有方式によるエクスポート（シェアダイアログを表示）
  static Future<bool> shareAppConfig(
    AppConfig config, {
    String? customFileName,
  }) async {
    try {
      // Web は share_plus が制約されやすいのでダウンロードに寄せる
      if (kIsWeb) {
        return exportAppConfig(config, customFileName: customFileName);
      }

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
      debugPrint('Error sharing app config: $e');
      return false;
    }
  }

  /// JSONファイルからアプリケーション設定をインポート
  static Future<AppConfig?> importAppConfig() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) {
        return null; // ユーザーがキャンセルした場合
      }

      final picked = result.files.first;
      final bytes = await _readPlatformFileBytes(picked);
      if (bytes == null) return null;
      final jsonString = utf8.decode(bytes);

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
      debugPrint('Error importing app config: $e');
      return null;
    }
  }

  /// AppConfig を WaveDrom JSON としてエクスポート
  static Future<bool> exportWaveDrom(
    AppConfig config, {
    List<TimingChartAnnotation>? annotations,
    List<int>? omissionIndices,
    String? customFileName,
    ExportSaveOptions? saveOptions,
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

      // Web はブラウザダウンロード
      if (kIsWeb) {
        final bytes = Uint8List.fromList(utf8.encode(wavedromJson));
        web.downloadBytes(bytes, fileName, mimeType: 'application/json');
        return true;
      }

      final savedPath = await _saveBytesOnDesktop(
        bytes: Uint8List.fromList(utf8.encode(wavedromJson)),
        fileName: fileName,
        extensionWithDot: '.json',
        allowedExtensions: ['json'],
        dialogTitle: 'WaveDrom JSON の保存先を選択',
        options: saveOptions,
      );

      return savedPath != null;
    } catch (e) {
      debugPrint('Error exporting WaveDrom: $e');
      return false;
    }
  }

  /// PNG バイト列を保存する（保存ダイアログあり）
  static Future<bool> exportPngBytes(
    Uint8List bytes, {
    String? customFileName,
    ExportSaveOptions? saveOptions,
  }) async {
    try {
      final now = DateTime.now();
      final formattedDate =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final defaultFileName = 'timing_chart_$formattedDate.png';
      final fileName = customFileName ?? defaultFileName;

      if (kIsWeb) {
        web.downloadBytes(bytes, fileName, mimeType: 'image/png');
        return true;
      }

      final savedPath = await _saveBytesOnDesktop(
        bytes: bytes,
        fileName: fileName,
        extensionWithDot: '.png',
        allowedExtensions: ['png'],
        dialogTitle: 'チャート画像 (PNG) の保存先を選択',
        options: saveOptions,
      );

      return savedPath != null;
    } catch (e) {
      debugPrint('Error exporting PNG: $e');
      return false;
    }
  }

  /// JPEG バイト列を保存する（保存ダイアログあり）
  static Future<bool> exportJpegBytes(
    Uint8List bytes, {
    String? customFileName,
    ExportSaveOptions? saveOptions,
  }) async {
    try {
      final now = DateTime.now();
      final formattedDate =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final defaultFileName = 'timing_chart_$formattedDate.jpg';
      final fileName = customFileName ?? defaultFileName;

      if (kIsWeb) {
        web.downloadBytes(bytes, fileName, mimeType: 'image/jpeg');
        return true;
      }

      final savedPath = await _saveBytesOnDesktop(
        bytes: bytes,
        fileName: fileName,
        extensionWithDot: '.jpg',
        allowedExtensions: ['jpg', 'jpeg'],
        dialogTitle: 'チャート画像 (JPEG) の保存先を選択',
        options: saveOptions,
      );

      return savedPath != null;
    } catch (e) {
      debugPrint('Error exporting JPEG: $e');
      return false;
    }
  }

  /// XLSX形式でIO情報とチャートデータをエクスポート
  static Future<bool> exportXlsx({
    required List<String> inputNames,
    required List<String> outputNames,
    required List<String> hwTriggerNames,
    required List<SignalData> chartSignals,
    required List<int> chartPorts,
    Map<SignalType, Color>? signalColors,
    List<TimingChartAnnotation> chartAnnotations = const [],
    List<int> omissionIndices = const [],
    String? customFileName,
    ExportSaveOptions? saveOptions,
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
      const int chartRowStart = 1;
      final int waveStartCol = chartStartCol + 1; // K列
      final excel.ExcelColor fallbackCommentColor = excel.ExcelColor.grey700;

      excel.ExcelColor toExcelColorFromInt(int? argb) {
        if (argb == null) return fallbackCommentColor;
        final hex = argb.toRadixString(16).padLeft(8, '0').toUpperCase();
        return excel.ExcelColor.fromHexString(hex);
      }

      int clampStepIndex(int idx, int maxLength) {
        if (maxLength <= 0) return 0;
        if (idx < 0) return 0;
        if (idx >= maxLength) return maxLength - 1;
        return idx;
      }

      int allocateTrack(List<int> trackEndIndices, int start, int end) {
        for (int i = 0; i < trackEndIndices.length; i++) {
          if (start > trackEndIndices[i]) {
            trackEndIndices[i] = end;
            return i;
          }
        }
        trackEndIndices.add(end);
        return trackEndIndices.length - 1;
      }

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

      int maxSignalLength = 0;

      // 2. チャート情報の記載（10列目以降）
      if (chartSignals.isNotEmpty) {
        // 信号名と種別＋ポート情報をI,J列に記載（各信号の間に1行空ける）
        for (int i = 0; i < chartSignals.length; i++) {
          final signal = chartSignals[i];
          final int rowIndex = chartRowStart + i * 2; // 1行おきに配置

          // 左セル（I列）: 種別＋ポート (例: Input1, Output10, HW Trigger1)
          final int port = (i < chartPorts.length) ? chartPorts[i] : 0;
          String typeLabel;
          switch (signal.signalType) {
            case SignalType.input:
              typeLabel = 'Input';
              break;
            case SignalType.output:
              typeLabel = 'Output';
              break;
            case SignalType.hwTrigger:
              typeLabel = 'HW Trigger';
              break;
            case SignalType.control:
              typeLabel = 'Control';
              break;
            case SignalType.group:
              typeLabel = 'Group';
              break;
            case SignalType.task:
              typeLabel = 'Task';
              break;
          }
          final String typePortText = port > 0 ? '$typeLabel$port' : typeLabel;

          sheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: chartStartCol - 1, // I列
                  rowIndex: rowIndex,
                ),
              )
              .value = excel.TextCellValue(typePortText);

          // 信号名をJ列（10列目）に記載
          sheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: chartStartCol,
                  rowIndex: rowIndex,
                ),
              )
              .value = excel.TextCellValue(signal.name);
        }

        // 各信号の波形をK列（11列目）以降に描画（信号ごとに1行分の空白行を挿入）
        maxSignalLength =
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
          final List<int> values = signal.values;
          final int rowIndex = chartRowStart + signalIndex * 2;
          final Color signalColor =
              signalColors?[signal.signalType] ?? Colors.black;
          final excel.ExcelColor excelSignalColor = excel.ExcelColor.fromHexString(
            signalColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase(),
          );
          final excel.Border waveBorder = excel.Border(
            borderStyle: excel.BorderStyle.Medium,
            borderColorHex: excelSignalColor,
          );

          for (int timeIndex = 0; timeIndex < maxSignalLength; timeIndex++) {
            final int colIndex = chartStartCol + 1 + timeIndex; // K列から開始

            final bool isHigh =
                (timeIndex < values.length) ? values[timeIndex] != 0 : false;
            final bool prevHigh =
                (timeIndex > 0 && timeIndex - 1 < values.length)
                    ? values[timeIndex - 1] != 0
                    : isHigh;
            final bool nextHigh =
                (timeIndex + 1 < values.length)
                    ? values[timeIndex + 1] != 0
                    : isHigh;

            final cellIndex = excel.CellIndex.indexByColumnRow(
              columnIndex: colIndex,
              rowIndex: rowIndex,
            );
            final cell = sheet.cell(cellIndex);

            // 値自体は 0/1 を残しておく（必要に応じて空にしてもよい）
            cell.value = excel.IntCellValue(isHigh ? 1 : 0);

            // 既存スタイルを維持しつつ罫線だけ追加
            final style = cell.cellStyle ?? excel.CellStyle();

            // 水平線: High -> 上線, Low -> 下線
            if (isHigh) {
              style.topBorder = waveBorder;
            } else {
              style.bottomBorder = waveBorder;
            }

            // 垂直線: 隣との値が変わる境界で左/右に線を引く
            if (timeIndex > 0 && prevHigh != isHigh) {
              style.leftBorder = waveBorder;
            }
            if (timeIndex + 1 < maxSignalLength && isHigh != nextHigh) {
              style.rightBorder = waveBorder;
            }

            cell.cellStyle = style;
          }
        }

        // 2-1. 波形セルの列幅・行高を調整して、できるだけ正方形に近づける
        //
        // Excel の列幅と行の高さは単位が異なるため完全な正方形にはなりませんが、
        // ここである程度見やすい比率に揃えておきます。
        const double waveformColumnWidth = 2.0; // 時間方向の1ステップの幅（列幅）
        const double waveformRowHeight = 15.0; // 1信号行の高さ

        // 時間軸側の列幅（K列以降）を揃える
        for (int timeIndex = 0; timeIndex < maxSignalLength; timeIndex++) {
          final int colIndex = chartStartCol + 1 + timeIndex; // K列から開始
          sheet.setColumnWidth(colIndex, waveformColumnWidth);
        }

        // 各信号行（波形を描画している行）の高さを揃える
        for (int signalIndex = 0;
            signalIndex < chartSignals.length;
            signalIndex++) {
          final int rowIndex = chartRowStart + signalIndex * 2;
          sheet.setRowHeight(rowIndex, waveformRowHeight);
        }
      }

      // 2-2. コメントレイヤーの近似描画（Sheet1内）
      if (chartAnnotations.isNotEmpty && maxSignalLength > 0) {
        final int waveformLastRow = chartRowStart + (chartSignals.length - 1) * 2;
        final int commentHeaderRow = waveformLastRow + 2;
        const int rowSpanPerTrack = 2;
        const int maxTracksPerPlacement = 4;
        final topTrackEnd = <int>[];
        final bottomTrackEnd = <int>[];

        sheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: chartStartCol,
                rowIndex: commentHeaderRow,
              ),
            )
            .value = excel.TextCellValue('Comment Layer');
        sheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: chartStartCol - 1,
                rowIndex: commentHeaderRow + 1,
              ),
            )
            .value = excel.TextCellValue('Top');
        sheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: chartStartCol - 1,
                rowIndex: commentHeaderRow + 1 + maxTracksPerPlacement * rowSpanPerTrack + 1,
              ),
            )
            .value = excel.TextCellValue('Bottom');

        final int topBaseRow = commentHeaderRow + 1;
        final int bottomBaseRow =
            topBaseRow + maxTracksPerPlacement * rowSpanPerTrack + 1;

        for (final ann in chartAnnotations) {
          final int logicalStart = clampStepIndex(ann.startTimeIndex, maxSignalLength);
          final int logicalEnd = clampStepIndex(
            ann.endTimeIndex ?? ann.startTimeIndex,
            maxSignalLength,
          );
          final int start = logicalStart <= logicalEnd ? logicalStart : logicalEnd;
          final int end = logicalStart <= logicalEnd ? logicalEnd : logicalStart;
          final bool isTop = ann.placement == 'top';
          final tracks = isTop ? topTrackEnd : bottomTrackEnd;
          final int allocatedTrack = allocateTrack(tracks, start, end);
          final int track = allocatedTrack % maxTracksPerPlacement;
          final int row = (isTop ? topBaseRow : bottomBaseRow) + track * rowSpanPerTrack;
          final int startCol = waveStartCol + start;
          final int endCol = waveStartCol + end;

          final bool borderVisible =
              ann.borderColorValue == null ||
              ((ann.borderColorValue! >> 24) & 0xFF) > 0;
          final excel.ExcelColor borderColor = toExcelColorFromInt(
            ann.borderColorValue,
          );
          final excel.ExcelColor dashedColor = toExcelColorFromInt(
            ann.dashedLineColorValue,
          );
          final bool backgroundVisible =
              ann.backgroundColorValue != null &&
              ((ann.backgroundColorValue! >> 24) & 0xFF) > 0;
          final bool isBold = ann.isBold ?? false;
          final int? fontSize = ann.fontSize?.round();

          final style = excel.CellStyle(
            bold: isBold,
            fontSize: fontSize,
            fontColorHex: toExcelColorFromInt(ann.textColorValue),
            horizontalAlign: excel.HorizontalAlign.Left,
            verticalAlign: excel.VerticalAlign.Top,
            textWrapping: excel.TextWrapping.WrapText,
            backgroundColorHex:
                backgroundVisible
                    ? toExcelColorFromInt(ann.backgroundColorValue)
                    : excel.ExcelColor.white,
            leftBorder:
                borderVisible
                    ? excel.Border(
                      borderStyle: excel.BorderStyle.Medium,
                      borderColorHex: borderColor,
                    )
                    : null,
            rightBorder:
                borderVisible
                    ? excel.Border(
                      borderStyle: excel.BorderStyle.Medium,
                      borderColorHex: borderColor,
                    )
                    : null,
            topBorder:
                borderVisible
                    ? excel.Border(
                      borderStyle: excel.BorderStyle.Medium,
                      borderColorHex: borderColor,
                    )
                    : null,
            bottomBorder:
                borderVisible
                    ? excel.Border(
                      borderStyle: excel.BorderStyle.Medium,
                      borderColorHex: borderColor,
                    )
                    : null,
          );

          final textCell = sheet.cell(
            excel.CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
          );
          textCell.value = excel.TextCellValue(ann.text);
          textCell.cellStyle = style;

          if (endCol > startCol) {
            sheet.merge(
              excel.CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
              excel.CellIndex.indexByColumnRow(columnIndex: endCol, rowIndex: row),
            );
            sheet.setMergedCellStyle(
              excel.CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
              style,
            );
          }

          // 境界の破線を近似的に描画（コメント上下領域の縦マーカー）
          final boundaryStyle = excel.CellStyle(
            leftBorder: excel.Border(
              borderStyle: excel.BorderStyle.Dashed,
              borderColorHex: dashedColor,
            ),
          );
          for (int r = topBaseRow;
              r <= bottomBaseRow + maxTracksPerPlacement * rowSpanPerTrack;
              r++) {
            final markerStart = sheet.cell(
              excel.CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: r),
            );
            final markerStartStyle = markerStart.cellStyle ?? excel.CellStyle();
            markerStartStyle.leftBorder = boundaryStyle.leftBorder;
            markerStart.cellStyle = markerStartStyle;

            if (ann.endTimeIndex != null) {
              final markerEnd = sheet.cell(
                excel.CellIndex.indexByColumnRow(columnIndex: endCol, rowIndex: r),
              );
              final markerEndStyle = markerEnd.cellStyle ?? excel.CellStyle();
              markerEndStyle.leftBorder = boundaryStyle.leftBorder;
              markerEnd.cellStyle = markerEndStyle;
            }
          }

          // 矢印はセル表現で近似（横矢印/縦矢印）
          final String arrowSymbol = (ann.arrowHorizontal ?? false)
              ? (isTop ? '→' : '←')
              : (isTop ? '▼' : '▲');
          final int arrowRow = row + 1;
          final int arrowCol = startCol;
          final arrowCell = sheet.cell(
            excel.CellIndex.indexByColumnRow(columnIndex: arrowCol, rowIndex: arrowRow),
          );
          arrowCell.value = excel.TextCellValue(arrowSymbol);
          final arrowStyle = arrowCell.cellStyle ?? excel.CellStyle();
          arrowStyle.horizontalAlignment = excel.HorizontalAlign.Center;
          arrowStyle.verticalAlignment = excel.VerticalAlign.Center;
          if (ann.arrowColorValue != null) {
            arrowStyle.fontColor = toExcelColorFromInt(ann.arrowColorValue);
          }
          arrowCell.cellStyle = arrowStyle;

          sheet.setRowHeight(row, 22);
          sheet.setRowHeight(arrowRow, 16);
        }
      }

      // 3. コメント情報の記載（別シート）
      if (chartAnnotations.isNotEmpty) {
        final annotationsSheet = excelFile['Annotations'];
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
            .value = excel.TextCellValue('ID');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
            .value = excel.TextCellValue('Start Index');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
            .value = excel.TextCellValue('End Index');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0))
            .value = excel.TextCellValue('Comment');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0))
            .value = excel.TextCellValue('Offset X');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0))
            .value = excel.TextCellValue('Offset Y');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0))
            .value = excel.TextCellValue('Arrow Tip Y');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0))
            .value = excel.TextCellValue('Arrow Horizontal');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 0))
            .value = excel.TextCellValue('Arrow Tip Row Index');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 0))
            .value = excel.TextCellValue('Font Size');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 0))
            .value = excel.TextCellValue('Bold');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 0))
            .value = excel.TextCellValue('Border Color ARGB');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 0))
            .value = excel.TextCellValue('Dashed Color ARGB');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: 0))
            .value = excel.TextCellValue('Arrow Color ARGB');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: 0))
            .value = excel.TextCellValue('Max Width');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: 0))
            .value = excel.TextCellValue('Max Lines');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 16, rowIndex: 0))
            .value = excel.TextCellValue('Ellipsis');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 17, rowIndex: 0))
            .value = excel.TextCellValue('Placement');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 18, rowIndex: 0))
            .value = excel.TextCellValue('Background Color');
        annotationsSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 19, rowIndex: 0))
            .value = excel.TextCellValue('Text Color');

        for (int i = 0; i < chartAnnotations.length; i++) {
          final ann = chartAnnotations[i];
          final rowIndex = i + 1;

          annotationsSheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: rowIndex,
                ),
              )
              .value = excel.TextCellValue(ann.id);

          annotationsSheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 1,
                  rowIndex: rowIndex,
                ),
              )
              .value = excel.IntCellValue(ann.startTimeIndex);

          if (ann.endTimeIndex != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 2,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.IntCellValue(ann.endTimeIndex!);
          }

          annotationsSheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 3,
                  rowIndex: rowIndex,
                ),
              )
              .value = excel.TextCellValue(ann.text);

          if (ann.offsetX != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 4,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.TextCellValue(ann.offsetX!.toString());
          }

          if (ann.offsetY != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 5,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.TextCellValue(ann.offsetY!.toString());
          }

          if (ann.arrowTipY != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 6,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.TextCellValue(ann.arrowTipY!.toString());
          }

          if (ann.arrowHorizontal != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 7,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.TextCellValue(
              ann.arrowHorizontal! ? 'true' : 'false',
            );
          }

          if (ann.arrowTipRowIndex != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 8,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.IntCellValue(ann.arrowTipRowIndex!);
          }

          if (ann.fontSize != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 9,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.TextCellValue(ann.fontSize!.toString());
          }

          if (ann.isBold != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 10,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.TextCellValue(ann.isBold! ? 'true' : 'false');
          }

          if (ann.borderColorValue != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 11,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.TextCellValue(ann.borderColorValue!.toString());
          }

          if (ann.backgroundColorValue != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 18,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.TextCellValue(
              ann.backgroundColorValue!.toString(),
            );
          }

          if (ann.textColorValue != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 19,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.TextCellValue(ann.textColorValue!.toString());
          }

          if (ann.dashedLineColorValue != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 12,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.TextCellValue(
              ann.dashedLineColorValue!.toString(),
            );
          }

          if (ann.arrowColorValue != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 13,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.TextCellValue(ann.arrowColorValue!.toString());
          }

          if (ann.maxWidth != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 14,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.TextCellValue(ann.maxWidth!.toString());
          }

          if (ann.maxLines != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 15,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.IntCellValue(ann.maxLines!);
          }

          if (ann.ellipsisEnabled != null) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 16,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.TextCellValue(
              ann.ellipsisEnabled! ? 'true' : 'false',
            );
          }

          if (ann.placement != null && ann.placement!.isNotEmpty) {
            annotationsSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 17,
                    rowIndex: rowIndex,
                  ),
                )
                .value = excel.TextCellValue(ann.placement!);
          }
        }
      }

      // 4. 省略記号（省略区間）の記載（別シート）
      if (omissionIndices.isNotEmpty) {
        final omissionSheet = excelFile['Omissions'];
        omissionSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
            .value = excel.TextCellValue('Time Index');

        for (int i = 0; i < omissionIndices.length; i++) {
          omissionSheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: i + 1,
                ),
              )
              .value = excel.IntCellValue(omissionIndices[i]);
        }
      }

      // ファイルへの書き込み用にバイト列へエンコード
      // excelFile.save() を引数なしで呼び出すと、ライブラリのデフォルト名
      // （FlutterExcel.xlsx）でファイルを書き出してしまうため、
      // ここでは encode() を使ってバイト列のみ取得し、自前で保存する。
      final fileBytes = excelFile.encode();
      if (fileBytes != null) {
        if (kIsWeb) {
          web.downloadBytes(
            Uint8List.fromList(fileBytes),
            fileName,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          );
          return true;
        }

        final savedPath = await _saveBytesOnDesktop(
          bytes: Uint8List.fromList(fileBytes),
          fileName: fileName,
          extensionWithDot: '.xlsx',
          allowedExtensions: ['xlsx'],
          dialogTitle: 'XLSXファイルの保存先を選択',
          options: saveOptions,
        );

        return savedPath != null;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Error exporting XLSX: $e');
      return false;
    }
  }

  /// `.ziq` ファイルを選択し、ZIP として必要ファイルを読み込んで返す。
  /// Web/デスクトップ共通で動くように bytes ベースで処理する。
  static Future<Map<String, String>?> pickZiqAndReadRequiredFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ziq'],
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return null;

      final zipBytes = await _readPlatformFileBytes(result.files.first);
      if (zipBytes == null) return null;

      return readRequiredFilesFromZipBytesAsync(zipBytes);
    } catch (e) {
      debugPrint('Error picking ziq and reading required files: $e');
      return null;
    }
  }

  /// 指定した ZIP ファイルパスから、目的のファイルを読み込んで返す
  /// - keys:
  ///   - 'vxVisMgr.ini' => viscotech/bin/vxVisMgr.ini の内容（テキスト）
  ///   - 'DioMonitorLog.csv' => viscotech/Support/DioMonitorLog.csv の内容（テキスト）
  ///   - 'Plc_DioMonitorLog.csv' => viscotech/Support/Plc_DioMonitorLog.csv の内容（テキスト）
  ///   - 'FNL_DioMonitorLog.csv' => viscotech/Support/FNL_DioMonitorLog.csv の内容（テキスト）
  static Future<Map<String, String>> readRequiredFilesFromZip(
    String zipPath,
  ) async {
    final result = <String, String>{};
    try {
      final file = File(zipPath);
      if (!await file.exists()) return result;

      final bytes = await file.readAsBytes();
      return readRequiredFilesFromZipBytesAsync(bytes);
    } catch (e) {
      debugPrint('Error reading required files from zip: $e');
      return result;
    }
  }

  /// ZIPバイト列から、目的のファイルを読み込んで返す（Isolate で実行）
  static Future<Map<String, String>> readRequiredFilesFromZipBytesAsync(
    Uint8List bytes,
  ) {
    return compute(readRequiredFilesFromZipBytesIsolate, bytes);
  }
}
