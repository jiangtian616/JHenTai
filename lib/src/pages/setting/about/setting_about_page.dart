import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingAboutPage extends StatelessWidget {
  const SettingAboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('JHenTai'),
        elevation: 1,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: [
          ListTile(
            title: Text('version'.tr),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            title: Text('author'.tr),
            subtitle: const SelectableText('JT <jiangtian616@qq.com>'),
          ),
          const ListTile(
            title: Text('Github'),
            subtitle: SelectableText('https://github.com/jiangtian616/JHenTai'),
          ),
        ],
      ).paddingSymmetric(horizontal: 6),
    );
  }
}
