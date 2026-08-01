import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';

import 'eh_action_sheet_text.dart';

/// A single action item of the context menu.
class EHContextMenuAction {
  final String text;
  final Widget? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool isDefault;

  const EHContextMenuAction({
    required this.text,
    this.icon,
    this.color,
    this.onTap,
    this.isDefault = false,
  });
}

/// Unified context menu: [CupertinoActionSheet] on mobile, [showMenu] next to the cursor on desktop.
///
/// [position] is the desktop menu anchor (cursor global position); falls back to the bottom of the [context] RenderBox when null.
Future<void> showEHContextMenu(
  BuildContext context, {
  Offset? position,
  required List<EHContextMenuAction> actions,
}) async {
  final target = position ?? _computeContextMenuPosition(context);

  if (styleSetting.isInDesktopLayout && target != null) {
    final selected = await showMenu<int>(
      context: context,

      /// On desktop layouts pages may sit in a nested Navigator (detail panel). [showMenu] puts the
      /// menu into the nearest overlay by default, which misinterprets global coordinates as inner-overlay
      /// coordinates and shifts the menu to the bottom-right of the cursor; the root overlay is required.
      useRootNavigator: true,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      position: RelativeRect.fromLTRB(target.dx, target.dy, target.dx, target.dy),
      items: [
        for (int i = 0; i < actions.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (actions[i].icon != null) ...[
                  actions[i].icon!,
                  const SizedBox(width: 8),
                ],
                Text(
                  actions[i].text,
                  style: TextStyle(
                    color: actions[i].color,
                    fontWeight: actions[i].isDefault ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (selected != null) {
      actions[selected].onTap?.call();
    }
  } else {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (action.icon != null) ...[
                    action.icon!,
                    const SizedBox(width: 4),
                  ],
                  SizedBox(
                    width: action.icon != null ? 56 : null,
                    child: ehActionSheetText(action.text, color: action.color),
                  ),
                ],
              ),
              isDefaultAction: action.isDefault,
              onPressed: () {
                backRoute();
                action.onTap?.call();
              },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(child: ehActionSheetText('cancel'.tr), onPressed: backRoute),
      ),
    );
  }
}

Offset? _computeContextMenuPosition(BuildContext context) {
  final RenderObject? renderObject = context.findRenderObject();
  if (renderObject is RenderBox) {
    return renderObject.localToGlobal(renderObject.size.bottomLeft(Offset.zero));
  }
  return null;
}
