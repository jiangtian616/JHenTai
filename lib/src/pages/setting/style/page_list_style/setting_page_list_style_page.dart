import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/routes.dart';
import '../../../../setting/style_setting.dart';

class SettingPageListStylePage extends StatelessWidget {
  SettingPageListStylePage({Key? key}) : super(key: key);

  final List<PageListStyleItem> items = [
    PageListStyleItem(name: 'home'.tr, route: Routes.gallerys, show: () => StyleSetting.isInDesktopLayout),
    PageListStyleItem(name: 'home'.tr, route: Routes.dashboard, show: () => StyleSetting.isInMobileLayout || StyleSetting.isInTabletLayout),
    PageListStyleItem(name: 'search'.tr, route: Routes.desktopSearch, show: () => StyleSetting.isInDesktopLayout),
    PageListStyleItem(name: 'search'.tr, route: Routes.mobileV2Search, show: () => StyleSetting.isInMobileLayout || StyleSetting.isInTabletLayout),
    PageListStyleItem(name: 'popular'.tr, route: Routes.popular, show: () => true),
    PageListStyleItem(name: 'ranklist'.tr, route: Routes.ranklist, show: () => true),
    PageListStyleItem(name: 'favorite'.tr, route: Routes.favorite, show: () => true),
    PageListStyleItem(name: 'watched'.tr, route: Routes.watched, show: () => true),
    PageListStyleItem(name: 'history'.tr, route: Routes.history, show: () => true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('pageListStyle'.tr)),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: items
              .where((item) => item.show())
              .map(
                (item) => ListTile(
                  title: Text(item.name),
                  trailing: DropdownButton<ListMode?>(
                    value: StyleSetting.pageListMode[item.route],
                    elevation: 4,
                    alignment: AlignmentDirectional.centerEnd,
                    onChanged: (value) => StyleSetting.savePageListMode(item.route, value),
                    items: [
                      DropdownMenuItem(child: Text('global'.tr), value: null),
                      DropdownMenuItem(child: Text('flat'.tr), value: ListMode.flat),
                      DropdownMenuItem(child: Text('flatWithoutTags'.tr), value: ListMode.flatWithoutTags),
                      DropdownMenuItem(child: Text('listWithTags'.tr), value: ListMode.listWithTags),
                      DropdownMenuItem(child: Text('listWithoutTags'.tr), value: ListMode.listWithoutTags),
                      DropdownMenuItem(child: Text('waterfallFlowSmall'.tr), value: ListMode.waterfallFlowSmall),
                      DropdownMenuItem(child: Text('waterfallFlowMedium'.tr), value: ListMode.waterfallFlowMedium),
                      DropdownMenuItem(child: Text('waterfallFlowBig'.tr), value: ListMode.waterfallFlowBig),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class PageListStyleItem {
  final String name;
  final String route;
  final ValueGetter<bool> show;

  const PageListStyleItem({required this.name, required this.route, required this.show});
}
