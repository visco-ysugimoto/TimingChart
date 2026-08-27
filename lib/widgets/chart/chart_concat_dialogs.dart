import 'package:flutter/material.dart';

import '../../generated/l10n.dart';
import '../../services/chart_concat_service.dart';

/// チャート末尾結合時の確認ダイアログ
class ChartConcatDialogs {
  ChartConcatDialogs._();

  static Future<bool> confirmTimeUnitMismatch(BuildContext context) async {
    final s = S.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(s.concat_time_unit_title),
            content: Text(s.concat_time_unit_message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.common_cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.concat_continue),
              ),
            ],
          ),
    );
    return result == true;
  }

  static Future<UnmatchedIncomingPolicy?> chooseUnmatchedPolicy({
    required BuildContext context,
    required List<String> incomingOnlyNames,
  }) async {
    final s = S.of(context);
    return showDialog<UnmatchedIncomingPolicy>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(s.concat_unmatched_title),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.concat_unmatched_message),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: incomingOnlyNames.length,
                      itemBuilder:
                          (context, index) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.timeline, size: 18),
                            title: Text(incomingOnlyNames[index]),
                          ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s.common_cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, UnmatchedIncomingPolicy.drop),
                child: Text(s.concat_unmatched_drop),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(ctx, UnmatchedIncomingPolicy.padAndAdd),
                child: Text(s.concat_unmatched_add),
              ),
            ],
          ),
    );
  }
}
