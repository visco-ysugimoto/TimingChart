import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';

/// 利用可能な言語コード
enum SuggestionLanguage { en, ja }

/// 現在選択されている言語（デフォルト: 日本語）
SuggestionLanguage _currentLang = SuggestionLanguage.ja;

/// 他ウィジェットが言語変更を検知できるようにする Notifier
final ValueNotifier<int> suggestionLanguageVersion = ValueNotifier<int>(0);

/// キャッシュ: 言語 -> id -> label
final Map<SuggestionLanguage, Map<String, String>> _translationCache = {};

/// メニューなどから呼び出して言語を変更する
void setSuggestionLanguage(SuggestionLanguage lang) {
  _currentLang = lang;
  // 変更を通知
  suggestionLanguageVersion.value++;
}

String _folderByLang() {
  switch (_currentLang) {
    case SuggestionLanguage.ja:
      return 'ja';
    case SuggestionLanguage.en:
    default:
      return 'en';
  }
}

// --------------------- Data Class ---------------------
class SuggestionItem {
  final String id;
  final String label;

  const SuggestionItem(this.id, this.label);

  factory SuggestionItem.fromJson(Map<String, dynamic> json) =>
      SuggestionItem(json['id'] as String, json['label'] as String);
}

// --------------------- Loader -------------------------

List<SuggestionItem> _parseJsonToItems(dynamic decoded) {
  if (decoded is List) {
    // 新フォーマット: List<dynamic>
    return decoded
        .map((e) {
          if (e is Map<String, dynamic>) {
            return SuggestionItem.fromJson(e);
          } else if (e is String) {
            return SuggestionItem(e, e);
          } else {
            return null;
          }
        })
        .whereType<SuggestionItem>()
        .toList();
  } else if (decoded is Map<String, dynamic>) {
    // 旧フォーマット: { "suggestions": [ ... ] }
    if (decoded.containsKey('suggestions')) {
      final list = List<String>.from(decoded['suggestions']);
      return list.map((s) => SuggestionItem(s, s)).toList();
    }
  }
  return [];
}

Future<List<SuggestionItem>> _tryLoad(String path) async {
  final jsonString = await rootBundle.loadString(path);
  final decoded = json.decode(jsonString);
  return _parseJsonToItems(decoded);
}

Future<List<SuggestionItem>> _loadSuggestions(String filename) async {
  // 1. language specific path
  final langPath = 'assets/suggestions/${_folderByLang()}/$filename';
  try {
    final items = await _tryLoad(langPath);
    if (items.isNotEmpty) return items;
  } catch (_) {}

  // 2. root path fallback
  try {
    final fallbackPath = 'assets/$filename';
    return await _tryLoad(fallbackPath);
  } catch (_) {
    return [];
  }
}

Future<List<SuggestionItem>> loadInputSuggestions() async {
  return _loadSuggestions('input_suggestions.json');
}

Future<List<SuggestionItem>> loadOutputSuggestions() async {
  return _loadSuggestions('output_suggestions.json');
}

/// HW Trigger 用の候補を読み込む
/// ファイルが存在しない場合は Input 候補をフォールバックとして返す
Future<List<SuggestionItem>> loadHwTriggerSuggestions() async {
  final items = await _loadSuggestions('hw_trigger_suggestions.json');
  if (items.isNotEmpty) return items;
  // フォールバック: Input 候補
  return loadInputSuggestions();
}

// ----------------- Translation helper -----------------

Future<String> labelOfId(String id) async {
  // 1) キャッシュがあれば即返す
  final cache = _translationCache[_currentLang];
  if (cache != null && cache.containsKey(id)) {
    return cache[id]!;
  }

  // 2) 必要な3種の候補をロードしてマージ
  final lists = await Future.wait([
    loadInputSuggestions(),
    loadOutputSuggestions(),
    loadHwTriggerSuggestions(),
  ]);

  final Map<String, String> map = {};
  for (var list in lists) {
    for (var item in list) {
      map[item.id] = item.label;
    }
  }

  _translationCache[_currentLang] = map;

  return map[id] ?? id;
}
