import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

import '../models/chart/signal_data.dart';
import '../models/chart/signal_type.dart';
import '../suggestion_loader.dart';

class ChartTemplateEngine {
  static const String _defaultAssetPath =
      'assets/chart_rules/template_v1.yaml';

  final int sampleLength;

  ChartTemplateEngine({this.sampleLength = 32});

  /// YAML ルールを読み込み、Single Trigger 用の主要信号(TRIGGER, AUTO_MODE, BUSY, INSPECTION_BUSY)を生成
  Future<List<SignalData>> generateSingleTriggerSignals({
    String assetPath = _defaultAssetPath,
    int cameraCount = 1,
    List<int>? exposureCounts,
    Map<int, List<int>>? exposureTimes,
    Map<int, List<int>>? contactWaitTimes,
    Map<int, List<int>>? hwTriggerTimes,
  }) async {
    // 1. YAML 読み込み
    final yamlStr = await rootBundle.loadString(assetPath);
    final YamlMap yamlMap = loadYaml(yamlStr);
    final Map<String, dynamic> ruleMap =
        jsonDecode(jsonEncode(yamlMap)) as Map<String, dynamic>;

    // 2. グローバル param 取得
    final int x = ruleMap['meta']?['param']?['x'] ?? 2;
    final String triggerOption =
        ruleMap['meta']?['param']?['trigger_option'] ?? 'single';

    // Single Trigger 以外はまだ非対応
    if (triggerOption != 'single') {
      return [];
    }

    final Map<String, dynamic> signalsDef =
        (ruleMap['signals'] as Map<String, dynamic>);

    var waves = <String, List<int>>{};

    // ファーストパス: init & at/duration transitions
    signalsDef.forEach((name, def) {
      if (def is Map<String, dynamic>) {
        // condition 判定
        if (def.containsKey('condition')) {
          final cond = def['condition'] as String;
          if (!_evaluateCondition(cond, triggerOption)) return;
        }

        if (def.containsKey('alias')) return; // alias later

        int initVal = def['init'] ?? 0;
        final bool sticky = def['sticky'] == true;
        List<int> arr = List.filled(sampleLength, initVal);

        if (def.containsKey('transitions')) {
          for (var tr in def['transitions']) {
            if (tr is Map<String, dynamic> && tr.containsKey('at')) {
              final atExpr = tr['at'];
              int atIdx = _evalIntExpr(atExpr, x);
              int toVal = tr['to'] ?? 0;
              int duration = tr['duration'] ?? 1;
              if (atIdx < sampleLength) {
                for (int d = 0; d < duration && atIdx + d < sampleLength; d++) {
                  arr[atIdx + d] = toVal;
                }
                // sticky=true の場合は duration 無視して末尾まで toVal
                if (sticky) {
                  for (int idx = atIdx + duration; idx < sampleLength; idx++) {
                    arr[idx] = toVal;
                  }
                } else {
                  // revert after duration if duration < length
                  if (duration > 0 && atIdx + duration < sampleLength) {
                    arr[atIdx + duration] = initVal;
                  }
                }
              }
            }
          }
        }

        waves[name] = arr;
      }
    });

    // BUSY の簡易ロジック: TRIGGER ↑ で 1 継続
    final int minGapSeq = ruleMap['meta']?['scheduling']?['min_gap_seq'] ?? 3;

    if (waves.containsKey('TRIGGER')) {
      final triggerWave = waves['TRIGGER']!;
      int riseIdx = triggerWave.indexWhere((v) => v == 1);
      if (riseIdx != -1) {
        List<int> busy = List.filled(sampleLength, 0);
        for (int i = riseIdx; i < sampleLength; i++) busy[i] = 1;
        waves['BUSY'] = busy;
        waves['INSPECTION_BUSY'] = List<int>.from(busy);

        // Sequential exposures per camera based on exposureCounts
        if (exposureTimes != null && exposureTimes.isNotEmpty) {
          // Use provided times
          exposureTimes.forEach((camIdx, times) {
            String expName = 'CAMERA_${camIdx}_IMAGE_EXPOSURE';
            waves.putIfAbsent(expName, () => List.filled(sampleLength, 0));
            for (final t in times) {
              if (t < sampleLength) waves[expName]![t] = 1;
            }
          });
        } else {
          // fallback: counts based sequential scheduling
          final counts = exposureCounts ?? List.filled(cameraCount, 1);
          int currentTime = riseIdx + 1 + 2; // TRIGGER↓ +2

          for (int cam = 1; cam <= cameraCount; cam++) {
            int count = cam <= counts.length ? counts[cam - 1] : 1;
            if (count <= 0) continue;

            String expName = 'CAMERA_${cam}_IMAGE_EXPOSURE';
            waves.putIfAbsent(expName, () => List.filled(sampleLength, 0));

            for (int n = 0; n < count; n++) {
              if (currentTime < sampleLength) {
                waves[expName]![currentTime] = 1;
              }
              currentTime += minGapSeq + 1; // 次エッジまでギャップ
            }
          }
        }
      }
    }

    // alias 反映
    signalsDef.forEach((name, def) {
      if (def is Map<String, dynamic> && def.containsKey('alias')) {
        String target = def['alias'];
        if (waves.containsKey(target)) {
          waves[name] = List<int>.from(waves[target]!);
        }
      }
    });

    // プレースホルダー展開は不要になったが将来のために残す
    // （現時点では waves に '#' を含むキーは存在しない）
    final Map<String, List<int>> expanded = {};
    waves.forEach((name, values) {
      if (name.contains('#')) {
        for (int cam = 1; cam <= cameraCount; cam++) {
          String newName = name.replaceAll('#', cam.toString());
          expanded[newName] = List<int>.from(values);
        }
      } else {
        expanded[name] = values;
      }
    });

    waves = expanded;

    // IMAGE_ACQUISITION 生成: exposure ↑ で1, exposure↓+x+1で0
    final expRegex = RegExp(r'^CAMERA_(\d+)_IMAGE_EXPOSURE');
    waves.keys.where((k) => expRegex.hasMatch(k)).toList().forEach((expName) {
      final match = expRegex.firstMatch(expName)!;
      final camNum = match.group(1);
      final acqName = 'CAMERA_${camNum}_IMAGE_ACQUISITION';

      List<int> acqWave = List.filled(sampleLength, 0);
      List<int> expWave = waves[expName]!;
      for (int i = 0; i < sampleLength; i++) {
        if (expWave[i] == 1) {
          for (int d = 0; d <= x && i + d < sampleLength; d++) {
            acqWave[i + d] = 1;
          }
        }
      }
      waves[acqName] = acqWave;
    });

    // ----- CONTACT_INPUT_WAITING 生成 -----
    if (contactWaitTimes != null && contactWaitTimes.isNotEmpty) {
      List<int> contactWaitWave = List.filled(sampleLength, 0);
      contactWaitTimes.forEach((cam, times) {
        for (final t in times) {
          if (t < sampleLength) {
            contactWaitWave[t] = 1;
          }
        }
      });
      if (contactWaitWave.any((v) => v == 1)) {
        waves['CONTACT_INPUT_WAITING'] = contactWaitWave;
      }
    }

    // ----- HW_TRIGGER# 生成 -----
    if (hwTriggerTimes != null && hwTriggerTimes.isNotEmpty) {
      hwTriggerTimes.forEach((cam, times) {
        String hwName = 'HW_TRIGGER$cam';
        List<int> hwWave = List.filled(sampleLength, 0);
        for (final t in times) {
          if (t < sampleLength) {
            hwWave[t] = 1;
          }
        }
        if (hwWave.any((v) => v == 1)) {
          waves[hwName] = hwWave;
        }
      });
    }

    // ----- ACQ_TRIGGER_WAITING 生成 -----
    List<int> acqWait = List.filled(sampleLength, 0);
    final contactWave = waves['CONTACT_INPUT_WAITING'];
    //  HW_TRIGGER# keys
    final hwKeys = waves.keys.where((k) => k.startsWith('HW_TRIGGER'));

    for (int i = 0; i < sampleLength; i++) {
      bool isHigh = false;
      if (contactWave != null && contactWave[i] == 1) {
        isHigh = true;
      } else {
        for (final k in hwKeys) {
          if (waves[k]![i] == 1) {
            isHigh = true;
            break;
          }
        }
      }

      if (isHigh) {
        acqWait[i] = 1;
        if (i > 0) acqWait[i - 1] = 1; // 1サンプル前に立ち上げ
      }
    }

    if (acqWait.any((v) => v == 1)) {
      waves['ACQ_TRIGGER_WAITING'] = acqWait;
    }

    // BATCH_EXPOSURE 生成: 最初のEXPOSURE立上りから最後のEXPOSURE立上りまで High
    int firstExp = -1;
    int lastExp = -1;
    waves.forEach((name, values) {
      if (name.contains('_IMAGE_EXPOSURE')) {
        // 最初の High
        int firstIdx = values.indexWhere((v) => v == 1);
        if (firstIdx != -1 && (firstExp == -1 || firstIdx < firstExp)) {
          firstExp = firstIdx;
        }
        // 最後の High
        int lastIdx = values.lastIndexWhere((v) => v == 1);
        if (lastIdx != -1 && lastIdx > lastExp) {
          lastExp = lastIdx;
        }
      }
    });

    if (firstExp != -1 && lastExp != -1 && lastExp >= firstExp) {
      List<int> batchExp = List.filled(sampleLength, 0);
      for (int i = firstExp; i <= lastExp && i < sampleLength; i++) {
        batchExp[i] = 1;
      }
      waves['BATCH_EXPOSURE'] = batchExp;
      waves['BATCH_EXPOSURE_COMPLETE'] = List<int>.from(batchExp);

      // ENABLE_RESULT_SIGNAL 生成
      final int delayAfterBatch =
          ruleMap['meta']?['param']?['delay_after_batch'] ?? (x + 4);
      final int enableDur =
          ruleMap['meta']?['param']?['enable_result_duration'] ?? 3;

      int riseIdx = lastExp + 1 + delayAfterBatch;
      if (riseIdx < sampleLength) {
        List<int> enableWave = List.filled(sampleLength, 0);
        for (int i = 0; i < enableDur && riseIdx + i < sampleLength; i++) {
          enableWave[riseIdx + i] = 1;
        }
        waves['ENABLE_RESULT_SIGNAL'] = enableWave;
        waves['TOTAL_RESULT_OK'] = List<int>.from(enableWave);

        // ----- BUSY を ENABLE_RESULT_SIGNAL 立上りで Low にする -----
        if (waves.containsKey('BUSY')) {
          List<int> busy = waves['BUSY']!;
          for (int i = riseIdx; i < sampleLength; i++) {
            busy[i] = 0;
          }
          waves['BUSY'] = busy;
        }
        if (waves.containsKey('INSPECTION_BUSY')) {
          List<int> ibusy = waves['INSPECTION_BUSY']!;
          for (int i = riseIdx; i < sampleLength; i++) {
            ibusy[i] = 0;
          }
          waves['INSPECTION_BUSY'] = ibusy;
        }
      }
    }

    // ----- BATCH_EXPOSURE_COMPLETE (based on ACQUISITION) -----
    int firstAcq = -1;
    int lastAcqHigh = -1;
    waves.forEach((name, values) {
      if (name.contains('_IMAGE_ACQUISITION')) {
        int firstIdx = values.indexWhere((v) => v == 1);
        if (firstIdx != -1 && (firstAcq == -1 || firstIdx < firstAcq)) {
          firstAcq = firstIdx;
        }
        int lastIdx = values.lastIndexWhere((v) => v == 1);
        if (lastIdx != -1 && lastIdx > lastAcqHigh) {
          lastAcqHigh = lastIdx;
        }
      }
    });

    if (firstAcq != -1 && lastAcqHigh != -1 && lastAcqHigh >= firstAcq) {
      List<int> batchComp = List.filled(sampleLength, 0);
      for (int i = firstAcq; i <= lastAcqHigh && i < sampleLength; i++) {
        batchComp[i] = 1;
      }
      waves['BATCH_EXPOSURE_COMPLETE'] = batchComp;
    }

    // ----- Wave arrays auto-extend if needed -----
    int maxIdx = 0;
    waves.forEach((_, vals) {
      int idx = vals.lastIndexWhere((v) => v != 0);
      if (idx > maxIdx) maxIdx = idx;
    });
    if (maxIdx >= sampleLength) {
      int newLen = maxIdx + 1;
      waves.forEach((k, vals) {
        if (vals.length < newLen) {
          vals.addAll(List.filled(newLen - vals.length, 0));
          waves[k] = vals;
        }
      });
    }

    // SignalData へ
    List<SignalData> result = [];
    // Suggestion IDs を取得して色分けに利用
    final outputIds = (await loadOutputSuggestions()).map((e) => e.id).toSet();
    final hwIds = (await loadHwTriggerSuggestions()).map((e) => e.id).toSet();

    waves.forEach((name, values) {
      final type = hwIds.contains(name)
          ? SignalType.hwTrigger
          : outputIds.contains(name)
              ? SignalType.output
              : SignalType.input;
      result.add(SignalData(
        name: name,
        signalType: type,
        values: values,
        isVisible: true,
      ));
    });
    // カスタム並び替え: TRIGGER → AUTO_MODE → BUSY → EXPOSURE → ACQUISITION → BATCH_EXPOSURE → その他
    int _priority(SignalData s) {
      // --- 第一階層: 明示的な特別扱い ---
      if (s.name == 'TRIGGER') return 0;
      if (s.name == 'CONTACT_INPUT_WAITING') return 1;

      // --- 第二階層: signalType による大分類 ---
      switch (s.signalType) {
        case SignalType.input:
          return 2;
        case SignalType.hwTrigger:
          return 3;
        case SignalType.output:
          return 4;
        default:
          break;
      }

      // --- 第三階層: 既存の優先度ロジック（その他） ---
      if (s.name == 'AUTO_MODE') return 5;
      if (s.name == 'BUSY' || s.name == 'INSPECTION_BUSY') return 6;
      if (s.name.contains('_IMAGE_EXPOSURE')) return 7;
      if (s.name.contains('_IMAGE_ACQUISITION')) return 8;
      if (s.name.startsWith('BATCH_EXPOSURE')) return 9;
      return 10;
    }
    final camRegex = RegExp(r'^CAMERA_(\d+)_IMAGE_(EXPOSURE|ACQUISITION)');
    int camOrder(String name) {
      final m = camRegex.firstMatch(name);
      if (m != null) return int.parse(m.group(1)!);
      return 9999;
    }
    int expFirst(String name) {
      final m = camRegex.firstMatch(name);
      if (m != null) {
        return m.group(2) == 'EXPOSURE' ? 0 : 1;
      }
      return 0;
    }

    result.sort((a, b) {
      int pa = _priority(a), pb = _priority(b);
      if (pa != pb) return pa - pb;

      // Within camera signals
      bool aCam = camRegex.hasMatch(a.name);
      bool bCam = camRegex.hasMatch(b.name);
      if (aCam && bCam) {
        int keyA = camOrder(a.name) * 2 + expFirst(a.name);
        int keyB = camOrder(b.name) * 2 + expFirst(b.name);
        return keyA - keyB;
      }

      return a.name.compareTo(b.name);
    });
    return result;
  }

  bool _evaluateCondition(String cond, String triggerOption) {
    // 現状 param.trigger_option == 'single'
    final regex = RegExp(r"param\.trigger_option\s*==\s*'([^']+)'\s*");
    final m = regex.firstMatch(cond);
    if (m != null) {
      return triggerOption == m.group(1);
    }
    return true; // 未知条件は true
  }

  int _evalIntExpr(dynamic expr, int x) {
    if (expr is int) return expr;
    if (expr is String) {
      String e = expr.trim();
      e = e.replaceAll('(', '').replaceAll(')', '');
      if (e == 'x') return x;
      if (e.startsWith('x+')) {
        int val = int.parse(e.substring(2));
        return x + val;
      }
      return int.tryParse(e) ?? 0;
    }
    return 0;
  }

  // _detectType 削除。outputSuggestions に基づく方式へ移行
} 