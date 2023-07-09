import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';
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
          IconButton(
            icon: const Icon(Icons.help),
            onPressed: () => toast('localTagsHint2'.tr, isShort: false),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  Widget _buildBody() {
    return GetBuilder<LocalTagSetsLogic>(
      id: logic.bodyId,
      builder: (_) => EHWheelSpeedController(
        controller: state.scrollController,
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: MyTagsSetting.localTagSets.length,
            controller: state.scrollController,
            itemBuilder: (_, int index) => ListTile(
              dense: true,
              title: Text(MyTagsSetting.localTagSets[index].translatedNamespace == null
                  ? '${MyTagsSetting.localTagSets[index].namespace}:${MyTagsSetting.localTagSets[index].key}'
                  : '${MyTagsSetting.localTagSets[index].translatedNamespace}:${MyTagsSetting.localTagSets[index].tagName}'),
              subtitle: MyTagsSetting.localTagSets[index].translatedNamespace == null ? null : Text('${MyTagsSetting.localTagSets[index].namespace}:${MyTagsSetting.localTagSets[index].key}'),
              onTap: () => logic.handleDeleteLocalTag(index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      child: const Icon(Icons.add),
      onPressed: () {
        toRoute(Routes.addLocalTag)?.then((_) => logic.updateSafely([logic.bodyId]));
      },
    );
  }
}
