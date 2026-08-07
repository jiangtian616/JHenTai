import 'package:flutter/material.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';

/// A group of setting tiles rendered inside one rounded Apple-style card.
class EHAppleSettingsGroup {
  const EHAppleSettingsGroup({this.title, required this.children});

  final String? title;
  final List<Widget> children;
}

/// Unified settings list.
///
/// When the Apple visual style is enabled the tiles are rendered in grouped
/// rounded cards (macOS/iOS Settings look). Otherwise it keeps the original
/// Material flat list so existing behavior is unchanged.
class EHAppleSettingsListView extends StatelessWidget {
  const EHAppleSettingsListView({
    super.key,
    required this.groups,
    this.padding = const EdgeInsets.only(top: 16),
    this.controller,
    this.safeArea = false,
  });

  final List<EHAppleSettingsGroup> groups;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    Widget list;

    if (ThemeConfig.isApple) {
      list = ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
        children: [
          for (var index = 0; index < groups.length; index++) ...[
            if (groups[index].title != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  groups[index].title!.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            _EHAppleSettingsCard(children: groups[index].children),
            if (index != groups.length - 1) const SizedBox(height: 16),
          ],
        ],
      );
    } else {
      list = ListView(
        controller: controller,
        padding: padding,
        children: [
          for (final group in groups) ...group.children,
        ],
      );
    }

    if (safeArea) {
      list = SafeArea(child: list);
    } else if (ThemeConfig.isApple) {
      list = SafeArea(top: false, child: list);
    }

    return list.withListTileTheme(context);
  }
}

class _EHAppleSettingsCard extends StatelessWidget {
  const _EHAppleSettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index < children.length - 1)
                Divider(
                  height: 0.5,
                  indent: 56,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
