import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../config/theme_config.dart';

/// One action inside [EHAppleGlassToolbar].
class EHAppleToolbarItem {
  const EHAppleToolbarItem({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.iconSize,
    this.color,
    this.padding,
    this.visualDensity,
    this.constraints,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double? iconSize;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final VisualDensity? visualDensity;
  final BoxConstraints? constraints;
}

/// Groups adjacent Apple-style actions on one shared liquid-glass pill.
///
/// Material mode keeps conventional independent [IconButton]s, so enabling
/// Apple style is the only visual switch that changes the grouping.
class EHAppleGlassToolbar extends StatelessWidget {
  const EHAppleGlassToolbar({
    super.key,
    required this.items,
    this.materialSpacing = 8,
    this.itemPadding = const EdgeInsets.all(9),
  });

  final List<EHAppleToolbarItem> items;
  final double materialSpacing;
  final EdgeInsetsGeometry itemPadding;

  @override
  Widget build(BuildContext context) {
    if (ThemeConfig.isApple) {
      return GlassButtonGroup.icons(
        key: const ValueKey<String>('apple-glass-toolbar-group'),
        showDividers: true,
        itemPadding: itemPadding,
        items: items
            .map(
              (EHAppleToolbarItem item) => GlassButtonGroupItem(
                icon:
                    item.color == null
                        ? item.icon
                        : IconTheme(
                          data: IconThemeData(
                            color: item.color,
                            size: item.iconSize,
                          ),
                          child: item.icon,
                        ),
                onTap: item.onPressed ?? () {},
                enabled: item.onPressed != null,
                label: item.tooltip,
              ),
            )
            .toList(growable: false),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int index = 0; index < items.length; index++) ...<Widget>[
          if (index > 0) SizedBox(width: materialSpacing),
          IconButton(
            icon: items[index].icon,
            onPressed: items[index].onPressed,
            tooltip: items[index].tooltip,
            iconSize: items[index].iconSize,
            color: items[index].color,
            padding: items[index].padding,
            visualDensity: items[index].visualDensity,
            constraints: items[index].constraints,
          ),
        ],
      ],
    );
  }
}
