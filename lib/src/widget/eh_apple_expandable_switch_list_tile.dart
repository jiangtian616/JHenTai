import 'package:flutter/material.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';

/// A master switch tile whose sub-options expand below it while the switch is
/// on, and collapse (hide) while it is off.
class EHAppleExpandableSwitchListTile extends StatelessWidget {
  const EHAppleExpandableSwitchListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    required this.children,
    this.enabled = true,
    this.dense = false,
    this.duration = const Duration(milliseconds: 220),
  });

  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final List<Widget> children;
  final bool enabled;
  final bool dense;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final Color dividerColor =
        Theme.of(context).dividerColor.withValues(alpha: 0.7);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EHAppleSwitchListTile(
          title: title,
          subtitle: subtitle,
          value: value,
          onChanged: enabled ? onChanged : null,
          dense: dense,
        ),
        AnimatedSize(
          duration: duration,
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: value
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(height: 0.5, indent: 56, color: dividerColor),
                    for (var index = 0; index < children.length; index++) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: children[index],
                      ),
                      if (index < children.length - 1)
                        Divider(
                          height: 0.5,
                          indent: 72,
                          color: dividerColor,
                        ),
                    ],
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
