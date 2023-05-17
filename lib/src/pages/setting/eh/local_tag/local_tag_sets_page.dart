import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';

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
      body: EHWheelSpeedController(
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
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {},
      ),
      bottomSheet: BottomSheet(
        onClosing: () {},
        builder: (context) => SizedBox(),
      ),
    );
  }
}
