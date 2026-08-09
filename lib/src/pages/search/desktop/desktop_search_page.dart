import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/extension/string_extension.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/widget/fade_slide_widget.dart';

import '../../../config/theme_config.dart';
import '../../../config/ui_config.dart';
import '../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../mixin/scroll_to_top_page_mixin.dart';
import '../../../mixin/scroll_to_top_state_mixin.dart';
import 'desktop_search_page_logic.dart';
import 'desktop_search_page_state.dart';
import 'desktop_search_page_tab_logic.dart';

class DesktopSearchPage extends StatelessWidget with Scroll2TopPageMixin {
  const DesktopSearchPage({Key? key}) : super(key: key);

  DesktopSearchPageLogic get logic =>
      Get.put<DesktopSearchPageLogic>(DesktopSearchPageLogic(),
          permanent: true);

  DesktopSearchPageState get state => Get.find<DesktopSearchPageLogic>().state;

  @override
  Scroll2TopLogicMixin get scroll2TopLogic => logic;

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DesktopSearchPageLogic>(
      global: false,
      init: logic,
      id: logic.pageId,
      builder: (_) => Scaffold(
        backgroundColor: UIConfig.backGroundColor(context),
        body: SafeArea(
          child: Column(
            children: [
              buildTabBar(context).marginOnly(bottom: 8),
              buildTabView(),
            ],
          ),
        ),
        floatingActionButton: buildFloatingActionButton(),
      ),
    );
  }

  Widget buildTabBar(BuildContext context) {
    return GetBuilder<DesktopSearchPageLogic>(
      id: logic.tabBarId,
      builder: (_) => SizedBox(
        height: UIConfig.desktopSearchTabHeight,
        child: DecoratedBox(
          decoration: ThemeConfig.isApple
              ? BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.45),
                  border: Border(
                      bottom: BorderSide(
                          width: 0.5,
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.75))),
                )
              : const BoxDecoration(),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth -
                          UIConfig.desktopSearchTabRemainingWidth),
                  child: Padding(
                    // Align the first tab with the search field directly below.
                    padding: EdgeInsets.only(left: ThemeConfig.isApple ? 8 : 0),
                    child: EHWheelSpeedController(
                      controller: state.tabController,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        controller: state.tabController,
                        shrinkWrap: true,
                        children: _buildTabs(context),
                      ).enableMouseDrag(withScrollBar: false),
                    ),
                  ),
                ),
                EHAppleIconButton(
                  onPressed: () => logic.addNewTab(
                      keyword: '', loadImmediately: ThemeConfig.isApple),
                  icon: const Icon(Icons.add, size: 18),
                  constraints:
                      const BoxConstraints.tightFor(width: 24, height: 24),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTabs(BuildContext context) {
    final tabs = state.tabLogics
        .mapIndexed<Widget>(
          (index, tabLogic) => FadeSlideWidget(
            key: ValueKey(tabLogic),
            show: true,
            animateWhenInitialization: true,
            enableOpacityTransition: false,
            slideCurve: Curves.ease,
            axis: Axis.horizontal,
            duration: UIConfig.desktopSearchTabAnimationDuration,
            child: GetBuilder<DesktopSearchPageTabLogic>(
              global: false,
              init: tabLogic,
              builder: (_) => FutureBuilder(
                future: tabLogic.state.searchConfigInitCompleter.future,
                builder: (_, __) => _SearchTab(
                  name: index == state.currentTabIndex
                      ? (tabLogic.state.totalCount != null
                          ? tabLogic.state.totalCount!.toPrintString()
                          : tabLogic.state.searchConfig
                              .computeFullKeywords()
                              .defaultIfEmpty('${'tab'.tr} ${index + 1}'))
                      : tabLogic.state.searchConfig
                          .computeFullKeywords()
                          .defaultIfEmpty('${'tab'.tr} ${index + 1}'),
                  selected: index == state.currentTabIndex,
                  selectedColor:
                      UIConfig.desktopSearchTabSelectedBackGroundColor(context),
                  unSelectedColor:
                      UIConfig.desktopSearchTabUnSelectedBackGroundColor(
                          context),
                  selectedTextColor:
                      UIConfig.desktopSearchTabSelectedTextColor(context),
                  unSelectedTextColor:
                      UIConfig.desktopSearchTabUnSelectedTextColor(context),
                  onTap: () => logic.handleTapTab(index),
                  onDelete: () => logic.deleteTab(index),
                ),
              ),
            ),
          ),
        )
        .toList();

    if (ThemeConfig.isApple) {
      return tabs;
    }

    return tabs.joinNewElementIndexed(
      (index) => _SearchTabDivider(
        hasLeftTab: index >= 0,
        hasRightTab: index != state.tabLogics.length - 1,
        leftTabIsSelected: index == state.currentTabIndex,
        rightTabIsSelected: index == state.currentTabIndex - 1,
        selectedColor:
            UIConfig.desktopSearchTabSelectedBackGroundColor(context),
        unSelectedColor:
            UIConfig.desktopSearchTabUnSelectedBackGroundColor(context),
        backgroundColor:
            UIConfig.desktopSearchTabDividerBackGroundColor(context),
      ),
      joinAtFirst: true,
      joinAtLast: true,
    );
  }

  Widget buildTabView() {
    return GetBuilder<DesktopSearchPageLogic>(
      id: logic.tabViewId,
      builder: (_) => Expanded(
        key: state.tabViewKey,
        child: PageView(
          controller: state.pageController,
          physics: GetPlatform.isDesktop
              ? const NeverScrollableScrollPhysics()
              : null,
          onPageChanged: logic.onPageChanged,
          children: state.tabs,
        ),
      ),
    );
  }
}

/// imitate chrome style
class _SearchTab extends StatefulWidget {
  const _SearchTab({
    Key? key,
    required this.name,
    required this.selected,
    required this.selectedColor,
    required this.unSelectedColor,
    required this.selectedTextColor,
    required this.unSelectedTextColor,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  final String name;
  final bool selected;
  final Color selectedColor;
  final Color unSelectedColor;
  final Color selectedTextColor;
  final Color unSelectedTextColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  bool selected = false;

  @override
  void initState() {
    super.initState();
    selected = widget.selected;
  }

  @override
  void didUpdateWidget(covariant _SearchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    if (ThemeConfig.isApple) {
      final colors = Theme.of(context).colorScheme;
      return GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: UIConfig.desktopSearchTabWidth,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          padding: const EdgeInsets.only(left: 9),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: selected
                    ? colors.primary.withValues(alpha: 0.45)
                    : Colors.transparent),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color:
                          selected ? colors.onSurface : colors.onSurfaceVariant,
                      letterSpacing: 0.1),
                ),
              ),
              EHAppleIconButton(
                onPressed: widget.onDelete,
                icon: Icon(Icons.close,
                    color: colors.onSurfaceVariant,
                    size: UIConfig.desktopSearchTabIconSize),
                constraints:
                    const BoxConstraints.tightFor(width: 20, height: 20),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: UIConfig.desktopSearchTabWidth,
        decoration: BoxDecoration(
          color: selected ? widget.selectedColor : widget.unSelectedColor,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: selected
                        ? widget.selectedTextColor
                        : widget.unSelectedTextColor,
                    letterSpacing: 0.1),
              ).marginOnly(left: 2),
            ),
            EHAppleIconButton(
              onPressed: widget.onDelete,
              icon: Icon(
                Icons.clear,
                color: selected
                    ? widget.selectedTextColor
                    : widget.unSelectedTextColor,
                size: UIConfig.desktopSearchTabIconSize,
              ),
              constraints:
                  const BoxConstraints.tightFor(width: 20, height: 20),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

/// implemented by 5 container
class _SearchTabDivider extends StatelessWidget {
  const _SearchTabDivider({
    Key? key,
    required this.hasLeftTab,
    required this.hasRightTab,
    required this.leftTabIsSelected,
    required this.rightTabIsSelected,
    required this.selectedColor,
    required this.unSelectedColor,
    required this.backgroundColor,
  }) : super(key: key);

  final bool hasLeftTab;

  final bool hasRightTab;

  final bool leftTabIsSelected;

  final bool rightTabIsSelected;

  final Color selectedColor;

  final Color unSelectedColor;

  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: UIConfig.desktopSearchTabDividerWidth / 2,
              height: UIConfig.desktopSearchTabHeight / 2,
              foregroundDecoration: hasLeftTab
                  ? BoxDecoration(
                      color:
                          leftTabIsSelected ? selectedColor : unSelectedColor,
                      borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(
                              UIConfig.desktopSearchTabDividerBorderRadius)),
                    )
                  : null,
            ),
            Container(
              width: UIConfig.desktopSearchTabDividerWidth / 2,
              height: UIConfig.desktopSearchTabHeight / 2,
              color: leftTabIsSelected || rightTabIsSelected
                  ? selectedColor
                  : unSelectedColor,
              foregroundDecoration: BoxDecoration(
                color: !hasLeftTab
                    ? backgroundColor
                    : rightTabIsSelected
                        ? unSelectedColor
                        : null,
                borderRadius: !hasLeftTab || rightTabIsSelected
                    ? const BorderRadius.only(
                        bottomRight: Radius.circular(
                            UIConfig.desktopSearchTabDividerBorderRadius))
                    : null,
              ),
            ),
          ],
        ),
        Column(
          children: [
            Container(
              width: UIConfig.desktopSearchTabDividerWidth / 2,
              height: UIConfig.desktopSearchTabHeight / 2,
              foregroundDecoration: hasRightTab
                  ? BoxDecoration(
                      color:
                          rightTabIsSelected ? selectedColor : unSelectedColor,
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(
                              UIConfig.desktopSearchTabDividerBorderRadius)),
                    )
                  : null,
            ),
            Container(
              width: UIConfig.desktopSearchTabDividerWidth / 2,
              height: UIConfig.desktopSearchTabHeight / 2,
              color: leftTabIsSelected || rightTabIsSelected
                  ? selectedColor
                  : unSelectedColor,
              foregroundDecoration: BoxDecoration(
                color: !hasRightTab
                    ? backgroundColor
                    : rightTabIsSelected
                        ? selectedColor
                        : unSelectedColor,
                borderRadius: !hasRightTab || leftTabIsSelected
                    ? const BorderRadius.only(
                        bottomLeft: Radius.circular(
                            UIConfig.desktopSearchTabDividerBorderRadius))
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
