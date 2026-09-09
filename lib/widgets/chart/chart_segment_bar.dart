import 'package:flutter/material.dart';

import '../../generated/l10n.dart';
import '../../models/chart/chart_segment.dart';

/// 結合セグメントの並べ替え・削除バー。2本以上のときだけ表示する。
class ChartSegmentBar extends StatelessWidget {
  final List<ChartSegment> segments;
  final bool enabled;
  final void Function(int fromIndex, int toIndex) onReorder;
  final void Function(ChartSegment segment) onDelete;

  const ChartSegmentBar({
    super.key,
    required this.segments,
    required this.enabled,
    required this.onReorder,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.length < 2) return const SizedBox.shrink();
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: s.segment_bar_hint,
      waitDuration: const Duration(milliseconds: 400),
      child: SizedBox(
        height: 36,
        child: ReorderableListView.builder(
          scrollDirection: Axis.horizontal,
          buildDefaultDragHandles: false,
          padding: EdgeInsets.zero,
          onReorderItem: enabled
              ? (oldIndex, newIndex) {
                  if (oldIndex == newIndex) return;
                  onReorder(oldIndex, newIndex);
                }
              : (_, _) {},
          itemCount: segments.length,
          itemBuilder: (context, index) {
            final segment = segments[index];
            final chip = InputChip(
              label: Text(
                segment.label.isEmpty ? s.segment_unnamed : segment.label,
                overflow: TextOverflow.ellipsis,
              ),
              avatar: Icon(
                Icons.drag_indicator,
                size: 16,
                color: scheme.onSecondaryContainer,
              ),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: enabled && segments.length > 1
                  ? () => onDelete(segment)
                  : null,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: scheme.secondaryContainer,
              side: BorderSide(color: scheme.outlineVariant),
            );
            return Padding(
              key: ValueKey(segment.id),
              padding: const EdgeInsets.only(right: 6),
              child: enabled
                  ? ReorderableDragStartListener(index: index, child: chip)
                  : chip,
            );
          },
        ),
      ),
    );
  }
}
