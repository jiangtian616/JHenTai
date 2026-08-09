import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/enum/config_type_enum.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../utils/route_util.dart';

class EHConfigTypeSelectDialog extends StatefulWidget {
  final String title;

  const EHConfigTypeSelectDialog({super.key, required this.title});

  @override
  State<EHConfigTypeSelectDialog> createState() => _EHConfigTypeSelectDialogState();
}

class _EHConfigTypeSelectDialogState extends State<EHConfigTypeSelectDialog> {
  List<CloudConfigTypeEnum> selected = [...CloudConfigTypeEnum.values];

  @override
  Widget build(BuildContext context) {
    if (ThemeConfig.isApple) {
      return GlassDialog(
        settings: UIConfig.glassDialogSettings(context),
        title: widget.title,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: CloudConfigTypeEnum.values
              .map((e) => CheckboxListTile(
                    title: Text(e.name.tr),
                    value: selected.contains(e),
                    onChanged: (bool? value) {
                      setStateSafely(() {
                        if (value ?? false) {
                          selected.add(e);
                        } else {
                          selected.remove(e);
                        }
                      });
                    },
                  ))
              .toList(),
        ),
        actions: [
          GlassDialogAction(label: 'cancel'.tr, onPressed: backRoute),
          GlassDialogAction(
            label: 'OK'.tr,
            onPressed: () => backRoute(result: selected),
            isPrimary: true,
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.only(top: 24, left: 24, right: 24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: CloudConfigTypeEnum.values
            .map((e) => CheckboxListTile(
                  title: Text(e.name.tr),
                  value: selected.contains(e),
                  onChanged: (bool? value) {
                    setStateSafely(() {
                      if (value ?? false) {
                        selected.add(e);
                      } else {
                        selected.remove(e);
                      }
                    });
                  },
                ))
            .toList(),
      ),
      actions: [
        EHAppleTextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        EHAppleTextButton(
          onPressed: () {
            backRoute(result: selected);
          },
          child: Text('OK'.tr),
        ),
      ],
    );
  }
}
