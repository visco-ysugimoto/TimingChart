// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ja locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'ja';

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "accent_color": MessageLookupByLibrary.simpleMessage("アクセントカラー"),
    "appTitle": MessageLookupByLibrary.simpleMessage("タイミングチャートジェネレータ"),
    "auxiliary_signal_color": MessageLookupByLibrary.simpleMessage("補助信号の色"),
    "cameraLabel": MessageLookupByLibrary.simpleMessage("カメラ総数"),
    "chartNameLabel": MessageLookupByLibrary.simpleMessage("チャート名"),
    "chartTabTitle": MessageLookupByLibrary.simpleMessage("タイミングチャート"),
    "chart_edit_lock_tooltip": MessageLookupByLibrary.simpleMessage(
      "チャート編集をロック",
    ),
    "chart_edit_unlock_tooltip": MessageLookupByLibrary.simpleMessage(
      "チャート編集のロックを解除",
    ),
    "color_picker_selected": MessageLookupByLibrary.simpleMessage("選択中:"),
    "color_picker_title": MessageLookupByLibrary.simpleMessage("色を選択"),
    "color_picker_transparent": MessageLookupByLibrary.simpleMessage("透明"),
    "comment_add_range_title": MessageLookupByLibrary.simpleMessage(
      "範囲コメントを追加",
    ),
    "comment_add_title": MessageLookupByLibrary.simpleMessage("コメントを追加"),
    "comment_arrow_color": MessageLookupByLibrary.simpleMessage("コメント矢印の色"),
    "comment_clear_selection_color": MessageLookupByLibrary.simpleMessage(
      "色を戻す",
    ),
    "comment_dashed_color": MessageLookupByLibrary.simpleMessage("コメント破線の色"),
    "comment_edit_title": MessageLookupByLibrary.simpleMessage("コメントを編集"),
    "comment_input_hint": MessageLookupByLibrary.simpleMessage("コメントを入力"),
    "comment_properties_arrow_color": MessageLookupByLibrary.simpleMessage(
      "矢印の色",
    ),
    "comment_properties_background_color": MessageLookupByLibrary.simpleMessage(
      "背景色",
    ),
    "comment_properties_bold": MessageLookupByLibrary.simpleMessage("太字"),
    "comment_properties_border_color": MessageLookupByLibrary.simpleMessage(
      "枠線の色",
    ),
    "comment_properties_dashed_color": MessageLookupByLibrary.simpleMessage(
      "破線の色",
    ),
    "comment_properties_ellipsis": MessageLookupByLibrary.simpleMessage(
      "省略記号 (...)",
    ),
    "comment_properties_font_size": MessageLookupByLibrary.simpleMessage(
      "フォントサイズ",
    ),
    "comment_properties_max_lines": MessageLookupByLibrary.simpleMessage(
      "最大行数",
    ),
    "comment_properties_max_lines_unlimited":
        MessageLookupByLibrary.simpleMessage("無制限"),
    "comment_properties_show_arrow": MessageLookupByLibrary.simpleMessage(
      "矢印を表示",
    ),
    "comment_properties_show_border": MessageLookupByLibrary.simpleMessage(
      "枠線を表示",
    ),
    "comment_properties_show_dashed": MessageLookupByLibrary.simpleMessage(
      "破線を表示",
    ),
    "comment_properties_text_color": MessageLookupByLibrary.simpleMessage(
      "文字色",
    ),
    "comment_properties_title": MessageLookupByLibrary.simpleMessage(
      "コメントのプロパティ",
    ),
    "comment_properties_wrap_width": MessageLookupByLibrary.simpleMessage(
      "折り返し幅",
    ),
    "comment_selection_color": MessageLookupByLibrary.simpleMessage("選択範囲の色"),
    "common_cancel": MessageLookupByLibrary.simpleMessage("キャンセル"),
    "common_change": MessageLookupByLibrary.simpleMessage("変更"),
    "common_default": MessageLookupByLibrary.simpleMessage("デフォルト"),
    "common_ok": MessageLookupByLibrary.simpleMessage("OK"),
    "concat_continue": MessageLookupByLibrary.simpleMessage("結合する"),
    "concat_failed_empty": MessageLookupByLibrary.simpleMessage(
      "結合するチャートに信号がありません",
    ),
    "concat_failed_load": MessageLookupByLibrary.simpleMessage(
      "チャートファイルの読み込みに失敗しました",
    ),
    "concat_join_default": MessageLookupByLibrary.simpleMessage("結合チャート"),
    "concat_success": MessageLookupByLibrary.simpleMessage("チャートを末尾に結合しました"),
    "concat_time_unit_message": MessageLookupByLibrary.simpleMessage(
      "現在のチャートと結合するチャートの時間単位（ステップ / ms）が異なります。現在の単位のまま結合しますか？",
    ),
    "concat_time_unit_title": MessageLookupByLibrary.simpleMessage(
      "時間単位が異なります",
    ),
    "concat_unmatched_add": MessageLookupByLibrary.simpleMessage("0埋めして追加"),
    "concat_unmatched_drop": MessageLookupByLibrary.simpleMessage("追加しない"),
    "concat_unmatched_message": MessageLookupByLibrary.simpleMessage(
      "結合するチャートにだけ存在する信号です。0埋めして行を追加するか、これらの信号を無視できます。",
    ),
    "concat_unmatched_title": MessageLookupByLibrary.simpleMessage(
      "一致しない信号があります",
    ),
    "createTemplateButton": MessageLookupByLibrary.simpleMessage("テンプレートを作成"),
    "ctx_add_comment": MessageLookupByLibrary.simpleMessage("コメントを追加"),
    "ctx_arrow_horizontal_off_to_on": MessageLookupByLibrary.simpleMessage(
      "水平矢印をオンにする",
    ),
    "ctx_arrow_horizontal_on_to_off": MessageLookupByLibrary.simpleMessage(
      "水平矢印をオフにする",
    ),
    "ctx_comment_properties": MessageLookupByLibrary.simpleMessage("プロパティ"),
    "ctx_delete_columns": MessageLookupByLibrary.simpleMessage("選択列を削除"),
    "ctx_delete_comment": MessageLookupByLibrary.simpleMessage("コメントを削除"),
    "ctx_delete_selection": MessageLookupByLibrary.simpleMessage("選択範囲を削除"),
    "ctx_draw_omission": MessageLookupByLibrary.simpleMessage("省略記号"),
    "ctx_duplicate_to_tail": MessageLookupByLibrary.simpleMessage("末尾に複製"),
    "ctx_edit_comment": MessageLookupByLibrary.simpleMessage("コメント編集"),
    "ctx_insert_zeros": MessageLookupByLibrary.simpleMessage("0 を挿入"),
    "ctx_placement_bottom_to_top": MessageLookupByLibrary.simpleMessage(
      "チャート上部に配置",
    ),
    "ctx_placement_top_to_bottom": MessageLookupByLibrary.simpleMessage(
      "チャート下部に配置",
    ),
    "ctx_select_all_signals": MessageLookupByLibrary.simpleMessage("すべての信号を選択"),
    "ctx_set_arrow_tip_to_row": MessageLookupByLibrary.simpleMessage(
      "矢印の先端をこの行に設定",
    ),
    "ctx_signal_properties": MessageLookupByLibrary.simpleMessage("プロパティ"),
    "dark_mode": MessageLookupByLibrary.simpleMessage("ダークモード"),
    "default_camera_count": MessageLookupByLibrary.simpleMessage("デフォルトのカメラ数"),
    "default_chart_length": MessageLookupByLibrary.simpleMessage("デフォルトのチャート長"),
    "default_export_folder": MessageLookupByLibrary.simpleMessage(
      "デフォルトのエクスポートフォルダー",
    ),
    "drawer_concat_chart": MessageLookupByLibrary.simpleMessage(
      "チャートを末尾に結合...",
    ),
    "drawer_export": MessageLookupByLibrary.simpleMessage("エクスポート"),
    "drawer_export_chart_jpeg": MessageLookupByLibrary.simpleMessage(
      "チャート画像をエクスポート (JPEG)",
    ),
    "drawer_export_html": MessageLookupByLibrary.simpleMessage(
      "レポートをエクスポート (HTML)",
    ),
    "drawer_export_xlsx": MessageLookupByLibrary.simpleMessage(
      "XLSX としてエクスポート",
    ),
    "drawer_import": MessageLookupByLibrary.simpleMessage("インポート"),
    "drawer_import_ziq": MessageLookupByLibrary.simpleMessage("インポート (.ziq)"),
    "drawer_import_ziq_cancelled": MessageLookupByLibrary.simpleMessage(
      ".ziq の選択はキャンセルされました",
    ),
    "drawer_preferences": MessageLookupByLibrary.simpleMessage("設定"),
    "export_failed_html": MessageLookupByLibrary.simpleMessage(
      "HTMLレポートのエクスポートに失敗しました",
    ),
    "export_failed_jpeg": MessageLookupByLibrary.simpleMessage(
      "JPEGのエクスポートに失敗しました",
    ),
    "export_failed_json": MessageLookupByLibrary.simpleMessage(
      "JSONのエクスポートに失敗しました",
    ),
    "export_failed_xlsx": MessageLookupByLibrary.simpleMessage(
      "XLSXのエクスポートに失敗しました",
    ),
    "export_open_folder": MessageLookupByLibrary.simpleMessage("フォルダを開く"),
    "export_success_html": MessageLookupByLibrary.simpleMessage(
      "HTMLレポートをエクスポートしました",
    ),
    "export_success_jpeg": MessageLookupByLibrary.simpleMessage(
      "JPEGをエクスポートしました",
    ),
    "export_success_json": MessageLookupByLibrary.simpleMessage(
      "JSONをエクスポートしました",
    ),
    "export_success_xlsx": MessageLookupByLibrary.simpleMessage(
      "XLSXをエクスポートしました",
    ),
    "file_name_prefix": MessageLookupByLibrary.simpleMessage("ファイル名の接頭辞"),
    "formTabTitle": MessageLookupByLibrary.simpleMessage("入力フォーム"),
    "hint_export_folder": MessageLookupByLibrary.simpleMessage("Export Chart"),
    "hint_filename_prefix": MessageLookupByLibrary.simpleMessage("prefix_"),
    "hwPortLabel": MessageLookupByLibrary.simpleMessage("HW ポート総数"),
    "hwTriggerPrefix": MessageLookupByLibrary.simpleMessage("HW トリガー"),
    "hwTriggerSectionTitle": MessageLookupByLibrary.simpleMessage("HW トリガー信号"),
    "hw_trigger_signal_color": MessageLookupByLibrary.simpleMessage(
      "HW トリガー信号の色",
    ),
    "import_success_config": MessageLookupByLibrary.simpleMessage(
      "設定をインポートしました",
    ),
    "importing_wait": MessageLookupByLibrary.simpleMessage(
      "インポート中... しばらくお待ちください",
    ),
    "inputSignalPrefix": MessageLookupByLibrary.simpleMessage("入力"),
    "inputSignalSectionTitle": MessageLookupByLibrary.simpleMessage("入力信号"),
    "input_signal_color": MessageLookupByLibrary.simpleMessage("入力信号の色"),
    "ioPortLabel": MessageLookupByLibrary.simpleMessage("I/O ポート総数"),
    "language_english": MessageLookupByLibrary.simpleMessage("英語"),
    "language_japanese": MessageLookupByLibrary.simpleMessage("日本語"),
    "menu_edit": MessageLookupByLibrary.simpleMessage("編集"),
    "menu_file": MessageLookupByLibrary.simpleMessage("ファイル"),
    "menu_help": MessageLookupByLibrary.simpleMessage("ヘルプ"),
    "menu_item_about": MessageLookupByLibrary.simpleMessage("バージョン情報"),
    "menu_item_copy": MessageLookupByLibrary.simpleMessage("コピー"),
    "menu_item_cut": MessageLookupByLibrary.simpleMessage("切り取り"),
    "menu_item_new": MessageLookupByLibrary.simpleMessage("新規作成"),
    "menu_item_open": MessageLookupByLibrary.simpleMessage("開く..."),
    "menu_item_paste": MessageLookupByLibrary.simpleMessage("貼り付け"),
    "menu_item_save": MessageLookupByLibrary.simpleMessage("保存"),
    "menu_item_save_as": MessageLookupByLibrary.simpleMessage("名前を付けて保存..."),
    "omission_line_color": MessageLookupByLibrary.simpleMessage("省略記号の色"),
    "outputSignalPrefix": MessageLookupByLibrary.simpleMessage("出力"),
    "outputSignalSectionTitle": MessageLookupByLibrary.simpleMessage("出力信号"),
    "output_signal_color": MessageLookupByLibrary.simpleMessage("出力信号の色"),
    "reset_default_colors": MessageLookupByLibrary.simpleMessage(
      "デフォルトの色にリセット",
    ),
    "settings_export_base_directory": MessageLookupByLibrary.simpleMessage(
      "エクスポート先フォルダ（フルパス）",
    ),
    "settings_export_base_directory_not_set":
        MessageLookupByLibrary.simpleMessage("未設定（保存時にダイアログ表示）"),
    "settings_nav_appearance": MessageLookupByLibrary.simpleMessage("表示"),
    "settings_nav_chart": MessageLookupByLibrary.simpleMessage("チャート"),
    "settings_nav_general": MessageLookupByLibrary.simpleMessage("全般"),
    "settings_nav_io": MessageLookupByLibrary.simpleMessage("I/O"),
    "settings_nav_language": MessageLookupByLibrary.simpleMessage("言語"),
    "settings_pick_export_directory": MessageLookupByLibrary.simpleMessage(
      "フォルダを選択",
    ),
    "settings_quick_export": MessageLookupByLibrary.simpleMessage(
      "クイック保存（ダイアログを省略）",
    ),
    "settings_title": MessageLookupByLibrary.simpleMessage("設定"),
    "show_grid_lines": MessageLookupByLibrary.simpleMessage("グリッド線を表示"),
    "show_io_numbers": MessageLookupByLibrary.simpleMessage("IO 番号を表示"),
    "signal_label_properties_color": MessageLookupByLibrary.simpleMessage("色"),
    "signal_label_properties_global_io_off":
        MessageLookupByLibrary.simpleMessage("設定の「IO番号を表示」がオフのため変更できません"),
    "signal_label_properties_name": MessageLookupByLibrary.simpleMessage(
      "ラベル名",
    ),
    "signal_label_properties_name_duplicate":
        MessageLookupByLibrary.simpleMessage("この名前は既に使われています"),
    "signal_label_properties_name_empty": MessageLookupByLibrary.simpleMessage(
      "ラベル名を入力してください",
    ),
    "signal_label_properties_show_io_number":
        MessageLookupByLibrary.simpleMessage("IO番号を表示"),
    "signal_label_properties_title": MessageLookupByLibrary.simpleMessage(
      "信号ラベルのプロパティ",
    ),
    "triggerOptionLabel": MessageLookupByLibrary.simpleMessage("トリガーオプション"),
    "updateChartButton": MessageLookupByLibrary.simpleMessage("チャート更新"),
  };
}
