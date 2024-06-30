import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_type_enum.dart';
import 'package:jhentai/src/extension/widget_extension.dart';

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
        TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () {
            backRoute(result: selected);
          },
          child: Text('OK'.tr),
        ),
      ],
    );
  }
}
