import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';

import '../../../../config/ui_config.dart';
import '../../../../setting/my_tags_setting.dart';
import '../../../../utils/toast_util.dart';
import 'local_tag_sets_page_logic.dart';
import 'local_tag_sets_page_state.dart';

class LocalTagSetsPage extends StatelessWidget {
  final LocalTagSetsLogic logic = Get.put<LocalTagSetsLogic>(LocalTagSetsLogic());
  final LocalTagSetsState state = Get.find<LocalTagSetsLogic>().state;

  LocalTagSetsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('localTags'.tr),
        actions: [
          IconButton(onPressed: () => toast('localTagsHint2'.tr, isShort: false), icon: const Icon(Icons.help)),
        ],
      ),
      body: Column(
        children: [
          SearchAnchor.bar(
            barElevation: MaterialStateProperty.all(0),
            barBackgroundColor: MaterialStateProperty.all(UIConfig.backGroundColor(context)),
            barOverlayColor: MaterialStateProperty.all(UIConfig.backGroundColor(context)),
            viewBackgroundColor: UIConfig.backGroundColor(context),
            viewElevation: 0,
            barHintText: 'addLocalTagHint'.tr,
            barSide: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.pressed) || states.contains(MaterialState.focused)) return BorderSide(color: UIConfig.primaryColor(context));
              return const BorderSide();
            }),
            barShape: const MaterialStatePropertyAll(LinearBorder(bottom: LinearBorderEdge())),
            suggestionsBuilder: (BuildContext context, SearchController controller) {
              if (controller.text.isEmpty) {
                return [];
              }
              return MyTagsSetting.localTagSets.where((tag) => tag.namespace.contains(controller.text) || tag.key.contains(controller.text)).map(
                    (tag) => ListTile(
                      title: Text(tag.namespace),
                      subtitle: Text(tag.key),
                    ),
                  );
            },
          ),
          Expanded(
            child: EHWheelSpeedController(
              controller: state.scrollController,
              child: SafeArea(
                child: ListView.builder(
                  itemExtent: 64,
                  cacheExtent: 3000,
                  itemCount: MyTagsSetting.localTagSets.length,
                  controller: state.scrollController,
                  itemBuilder: (_, int index) => ListTile(
                    dense: true,
                    title: Text(MyTagsSetting.localTagSets[index].translatedNamespace == null
                        ? '${MyTagsSetting.localTagSets[index].namespace}:${MyTagsSetting.localTagSets[index].key}'
                        : '${MyTagsSetting.localTagSets[index].translatedNamespace}:${MyTagsSetting.localTagSets[index].tagName}'),
                    subtitle: MyTagsSetting.localTagSets[index].translatedNamespace == null ? null : Text('${MyTagsSetting.localTagSets[index].namespace}:${MyTagsSetting.localTagSets[index].key}'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
