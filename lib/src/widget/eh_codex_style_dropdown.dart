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
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final int elevation;
  final AlignmentGeometry? alignment;
  final bool isExpanded;
  final double? menuMaxHeight;
  final bool enabled;

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
      // finite value is required even when the trigger is full width.
      menuWidth: widget.isExpanded ? 480 : 220,
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
