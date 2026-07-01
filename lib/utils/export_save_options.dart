/// デスクトップ向けエクスポート保存オプション
class ExportSaveOptions {
  /// クイック保存のベースディレクトリ（フルパス）
  final String? lastExportDirectory;

  /// ベース直下のサブフォルダ名（環境設定の exportFolder）
  final String exportSubFolder;

  /// ファイル名の接頭辞
  final String? fileNamePrefix;

  /// true のとき lastExportDirectory があればダイアログを省略
  final bool quickExportEnabled;

  /// 保存成功時に呼ばれる（フルパス、[quickSave] はダイアログ無し保存）
  final void Function(String savedPath, {required bool quickSave})? onSaved;

  const ExportSaveOptions({
    this.lastExportDirectory,
    this.exportSubFolder = 'Export Chart',
    this.fileNamePrefix,
    this.quickExportEnabled = true,
    this.onSaved,
  });
}
