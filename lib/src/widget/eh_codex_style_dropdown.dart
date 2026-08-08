import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/config/theme_config.dart';

/// A dropdown trigger that keeps the normal Material [DropdownButton] when the
/// Apple visual style is off, and opens a frosted-glass Apple-style rounded
/// rectangle menu when it is on. The menu expands downward when it fits below
/// the control, and flips upward when it would otherwise be clipped by the
/// window edge.
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
  final OverlayPortalController _controller = OverlayPortalController();

  bool get _isEndAligned {
    final AlignmentGeometry? alignment = widget.alignment;
    if (alignment is Alignment) {
      return alignment.x > 0;
    }
    if (alignment is AlignmentDirectional) {
      return alignment.start > 0;
    }
    return false;
  }

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

    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _controller,
      overlayChildBuilder: _buildOverlay,
      child: InkWell(
        onTap: widget.enabled ? _controller.show : null,
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
    );
  }

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    if (info.childPaintTransform.determinant() == 0.0) {
      return const SizedBox.shrink();
    }

    final Size triggerSize = info.childSize;
    final Size overlaySize = info.overlaySize;
    final Offset triggerOrigin =
        MatrixUtils.transformPoint(info.childPaintTransform, Offset.zero);

    final double maxMenuWidth = math.max(0.0, overlaySize.width - 16);
    final double menuWidth = widget.isExpanded
        ? triggerSize.width
        : math.max(triggerSize.width, 220).clamp(0.0, maxMenuWidth).toDouble();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _controller.hide,
          ),
        ),
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _DropdownPositionDelegate(
              triggerRect: Rect.fromLTWH(triggerOrigin.dx, triggerOrigin.dy,
                  triggerSize.width, triggerSize.height),
              menuWidth: menuWidth,
              menuMaxHeight: widget.menuMaxHeight ?? 320,
              isEndAligned: _isEndAligned,
              overlaySize: overlaySize,
            ),
            child: SizedBox(
              width: menuWidth,
              child: _buildMenu(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenu(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - t)),
          child: Transform.scale(
            scale: 0.96 + 0.04 * t,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: widget.menuMaxHeight ?? 320,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0;
                        index < widget.items.length;
                        index++) ...[
                      _buildMenuItem(context, widget.items[index]),
                      if (index != widget.items.length - 1)
                        Divider(
                          height: 0.5,
                          indent: 16,
                          endIndent: 16,
                          color: scheme.outline.withValues(alpha: 0.18),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, DropdownMenuItem<T> item) {
    final bool selected = item.value == widget.value;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: item.enabled
          ? () {
              _controller.hide();
              widget.onChanged?.call(item.value);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 15,
                  color: item.enabled
                      ? null
                      : scheme.onSurface.withValues(alpha: 0.35),
                ),
                child: item.child,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.check_mark,
                size: 16,
                color: scheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DropdownPositionDelegate extends SingleChildLayoutDelegate {
  _DropdownPositionDelegate({
    required this.triggerRect,
    required this.menuWidth,
    required this.menuMaxHeight,
    required this.isEndAligned,
    required this.overlaySize,
  });

  final Rect triggerRect;
  final double menuWidth;
  final double menuMaxHeight;
  final bool isEndAligned;
  final Size overlaySize;

  static const double _gap = 4;
  static const double _margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: menuWidth, maxHeight: menuMaxHeight);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double rawX =
        isEndAligned ? triggerRect.right - menuWidth : triggerRect.left;
    final double x = rawX
        .clamp(
            _margin, math.max(_margin, overlaySize.width - menuWidth - _margin))
        .toDouble();

    final double belowY = triggerRect.bottom + _gap;
    final double aboveY = triggerRect.top - childSize.height - _gap;
    final double spaceBelow = size.height - belowY;
    final double spaceAbove = triggerRect.top - _gap;

    final double y;
    if (childSize.height <= spaceBelow) {
      y = belowY;
    } else if (childSize.height <= spaceAbove) {
      y = aboveY;
    } else if (spaceBelow >= spaceAbove) {
      y = belowY;
    } else {
      y = aboveY;
    }

    return Offset(
      x,
      y.clamp(0.0, math.max(0.0, size.height - childSize.height)).toDouble(),
    );
  }

  @override
  bool shouldRelayout(covariant _DropdownPositionDelegate oldDelegate) =>
      oldDelegate.triggerRect != triggerRect ||
      oldDelegate.menuWidth != menuWidth ||
      oldDelegate.menuMaxHeight != menuMaxHeight ||
      oldDelegate.isEndAligned != isEndAligned ||
      oldDelegate.overlaySize != overlaySize;
}
