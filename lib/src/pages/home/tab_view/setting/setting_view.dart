import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';

import '../../../../utils/route_util.dart';

LinkedHashMap<String, IconData> items = LinkedHashMap.of({
  'account': Icons.account_circle,
  'EH': Icons.mood,
  'style': Icons.style,
  'read': Icons.local_library,
  'download': Icons.download,
  'advanced': Icons.settings_suggest,
  'security': Icons.security,
  'about': Icons.info,
});

class SettingView extends StatelessWidget {
  const SettingView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('setting'.tr),
        elevation: 1,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: items.entries
            .map(
              (entry) => ListTile(
                leading: Icon(entry.value),
                title: Text(entry.key.tr),
                onTap: () => toNamed(Routes.settingPrefix + entry.key),
              ),
            )
            .toList(),
      ).paddingSymmetric(vertical: 16),
    );
  }
}
