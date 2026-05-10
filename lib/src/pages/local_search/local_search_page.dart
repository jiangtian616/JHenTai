import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/base/base_page.dart';
import 'package:jhentai/src/pages/local_search/local_search_logic.dart';
import 'package:jhentai/src/pages/local_search/local_search_state.dart';

class LocalSearchPage extends BasePage<LocalSearchLogic, LocalSearchState> {
  static const String tag = 'localSearch';

  LocalSearchPage({Key? key}) : super(key: key, showJumpButton: false, showScroll2TopButton: true) {
    logic = Get.isRegistered<LocalSearchLogic>(tag: tag)
        ? Get.find<LocalSearchLogic>(tag: tag)
        : Get.put(LocalSearchLogic(), tag: tag, permanent: true);
    state = logic.state;
  }

  @override
  late final LocalSearchLogic logic;

  @override
  late final LocalSearchState state;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocalSearchLogic>(
      tag: tag,
      builder: (_) => Scaffold(
        appBar: buildAppBar(context),
        body: SafeArea(child: buildBody(context)),
      ),
    );
  }

  @override
  AppBar? buildAppBar(BuildContext context) {
    return AppBar(
      title: TextField(
        controller: logic.textEditingController,
        focusNode: logic.searchFocusNode,
        decoration: InputDecoration(
          hintText: 'localSearch'.tr,
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => logic.handleSearch(logic.textEditingController.text),
          ),
        ),
        onSubmitted: logic.handleSearch,
        onTapOutside: (_) => logic.searchFocusNode.unfocus(),
      ),
    );
  }

  @override
  Widget buildBody(BuildContext context) {
    if (!state.hasSearched) {
      return Center(child: Text('inputKeyword2Search'.tr));
    }
    return super.buildBody(context);
  }
}
