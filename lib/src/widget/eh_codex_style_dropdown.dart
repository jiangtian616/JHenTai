import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// A dropdown trigger that keeps the normal Material [DropdownButton] when the
/// Apple visual style is off, and opens an iOS 26 liquid-glass [GlassMenu]
/// that morphs from the trigger when it is on.
class EHCodexStyleDropdown<T> extends StatefulWidget {
  const EHCodexStyleDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.elevation = 4,
    this.alignment,
    this.isExpanded = false,
    this.menuMaxHeight,
    this.enabled = true,
    this.menuAlignment,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final int elevation;
  final AlignmentGeometry? alignment;
  final bool isExpanded;
  final double? menuMaxHeight;
  final bool enabled;

  /// Apple-mode only: the expanded glass menu's anchor relative to the trigger.
  ///
  /// Every in-app usage of this dropdown sits on the right side of the screen
  /// (a right-aligned drawer or the trailing of a settings row), so the default
  /// [GlassMenuAlignment.topRight] anchors the menu's top-right corner to the
  /// trigger and expands it toward the bottom-left — inside the panel — instead
  /// of relying on the package's screen-position auto-detection, which can pick
  /// the opposite side in some windows. Pass another value to override.
  final GlassMenuAlignment? menuAlignment;

  @override
  State<EHCodexStyleDropdown<T>> createState() =>
      _EHCodexStyleDropdownState<T>();
}

class _EHCodexStyleDropdownState<T> extends State<EHCodexStyleDropdown<T>> {
  @override
  Widget build(BuildContext context) {
    if (!ThemeConfig.isApple) {
      return DropdownButton<T>(
        value: widget.value,
        items: widget.items,
        onChanged: widget.enabled ? widget.onChanged : null,
        elevation: widget.elevation,
        alignment: widget.alignment ?? AlignmentDirectional.centerStart,
        isExpanded: widget.isExpanded,
        menuMaxHeight: widget.menuMaxHeight,
      );
    }

    DropdownMenuItem<T>? selectedItem;
    for (final DropdownMenuItem<T> item in widget.items) {
      if (item.value == widget.value) {
        selectedItem = item;
        break;
      }
    }

    return EHGlassMenu(
      // GlassMenu performs arithmetic on menuWidth (SizedBox width), so a
      // finite value is required even when the trigger is full width. For the
      // compact case the menu widens to fit its longest item instead of a
      // fixed 220px that truncates long labels.
      menuAlignment: widget.menuAlignment ?? GlassMenuAlignment.topRight,
      menuWidth: _menuWidth(),
      trigger: IgnorePointer(
        ignoring: !widget.enabled,
        child: InkWell(
          onTap: null,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: widget.isExpanded
                ? SizedBox(
                    width: double.infinity,
                    child: Row(
                      children: [
                        if (selectedItem != null)
                          DefaultTextStyle.merge(
                            style: const TextStyle(fontSize: 15),
                            child: selectedItem.child,
                          ),
                        const Spacer(),
                        Icon(
                          CupertinoIcons.chevron_down,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedItem != null)
                        DefaultTextStyle.merge(
                          style: const TextStyle(fontSize: 15),
                          child: selectedItem.child,
                        ),
                      const SizedBox(width: 2),
                      Icon(
                        CupertinoIcons.chevron_down,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
          ),
        ),
      ),
      items: [
        for (final DropdownMenuItem<T> item in widget.items)
          _buildGlassMenuItem(item),
      ],
    );
  }

  /// The expanded menu's width. The full-width ([isExpanded]) case keeps a
  /// fixed 480px; otherwise the menu grows to fit its widest item label (with
  /// icon and padding) instead of staying at a fixed 220px that truncates long
  /// text, bounded to a sane range and the screen width.
  double _menuWidth() {
    if (widget.isExpanded) {
      return 480;
    }
    double widest = 0;
    bool hasIcon = false;
    for (final DropdownMenuItem<T> item in widget.items) {
      final ({String title, Widget? icon}) extracted =
          _extractFromChild(item.child);
      if (extracted.icon != null) {
        hasIcon = true;
      }
      if (extracted.title.isEmpty) {
        continue;
      }
      // GlassMenuItem renders titles at 17px by default.
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: extracted.title,
          style: const TextStyle(fontSize: 17),
        ),
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
    }
    // Icon column + menu/item horizontal padding + a little breathing room.
    final double iconExtra = hasIcon ? 36 : 0;
    final double natural = widest + iconExtra + 72;
    final double screenCap = (MediaQuery.sizeOf(context).width - 40).clamp(
      220.0,
      420.0,
    );
    return natural.clamp(220.0, screenCap);
  }

  GlassMenuItem _buildGlassMenuItem(DropdownMenuItem<T> item) {
    final ({String title, Widget? icon}) extracted =
        _extractFromChild(item.child);
    return GlassMenuItem(
      title: extracted.title,
      icon: extracted.icon,
      isSelected: item.value == widget.value,
      enabled: item.enabled,
      onTap: () => widget.onChanged?.call(item.value),
    );
  }

  /// Pulls the display text (and any leading icon) out of a
  /// [DropdownMenuItem] child. Most callers pass a plain [Text]; a few wrap it
  /// in a [Row] that may carry an icon.
  ({String title, Widget? icon}) _extractFromChild(Widget child) {
    String? title;
    Widget? icon;

    void walk(Widget w) {
      if (title != null && icon != null) {
        return;
      }
      if (w is Text) {
        title ??= w.data ?? '';
        return;
      }
      if (w is Icon) {
        icon ??= w;
        return;
      }
      // [Widget.visitChildren] is a no-op for render-object widgets, so descend
      // through the common `child` / `children` container fields directly.
      final Widget? single = (w as dynamic).child;
      if (single != null) {
        walk(single);
      }
      final Object? multiple = (w as dynamic).children;
      if (multiple is List<Widget>) {
        for (final Widget c in multiple) {
          walk(c);
        }
      }
    }

    walk(child);
    return (title: title ?? '', icon: icon);
  }
}
