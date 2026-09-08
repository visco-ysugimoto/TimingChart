import 'package:flutter/material.dart';

/// フォーム・チャートで共有する操作部品のサイズと見た目。
class AppControls {
  AppControls._();

  static const double height = 40;
  static const double iconSize = 20;
  static const BorderRadius borderRadius = BorderRadius.all(Radius.circular(8));
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 8,
  );
  static const Duration tooltipDelay = Duration(milliseconds: 300);

  static OutlinedBorder get shape =>
      const RoundedRectangleBorder(borderRadius: borderRadius);

  static ButtonStyle filled({
    required Color background,
    required Color foreground,
    Size minimumSize = const Size(88, height),
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      minimumSize: minimumSize,
      padding: padding,
      elevation: 0,
      shape: shape,
      iconSize: iconSize,
    );
  }

  static ButtonStyle tonal(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return filled(
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurface,
    );
  }

  static Widget toolbarIcon({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool selected = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      waitDuration: tooltipDelay,
      child: IconButton(
        icon: Icon(icon, size: iconSize),
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          minimumSize: const Size(height, height),
          maximumSize: const Size(height, height),
          shape: shape,
          foregroundColor: selected ? scheme.primary : scheme.onSurface,
          backgroundColor: selected
              ? scheme.primary.withValues(alpha: 0.12)
              : null,
        ),
        onPressed: onPressed,
      ),
    );
  }

  static Widget toolbarDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        height: 24,
        child: VerticalDivider(width: 1, thickness: 1),
      ),
    );
  }
}
