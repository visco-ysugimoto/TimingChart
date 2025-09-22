import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

/// vxvismgr_mapping_template.yaml を読み込んで Map 化
class VxVisMgrMappingLoader {
  /// 戻り値: vxVisMgr.ini 側のシグナル名(キー) -> suggestions の id(値)
  static Future<Map<String, String>> loadMapping() async {
    final text = await rootBundle.loadString(
      'assets/mappings/vxvismgr_mapping_template.yaml',
    );
    final data = loadYaml(text);
    if (data is! YamlMap) return {};
    final mappings = data['mappings'];
    if (mappings is! YamlMap) return {};

    // YamlMap -> Map<String, String>
    final result = <String, String>{};
    for (final entry in mappings.entries) {
      final k = entry.key?.toString();
      final v = entry.value?.toString() ?? '';
      if (k != null && k.isNotEmpty) {
        result[k] = v;
      }
    }
    return result;
  }
}


