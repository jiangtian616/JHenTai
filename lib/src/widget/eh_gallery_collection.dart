import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../model/gallery.dart';
import 'eh_gallery_list_card_.dart';
import '../setting/style_setting.dart';
import 'eh_gallery_waterflow_card.dart';

/// Act as a List or WaterfallFlow according to Style Setting
Widget EHGalleryCollection({
  Key? key,
  required BuildContext context,
  required List<Gallery> gallerys,
  required LoadingState loadingState,
  required CardCallback handleTapCard,
  CardCallback? handleLongPressCard,
  CardCallback? handleSecondaryTapCard,
  VoidCallback? handleLoadMore,
}) {
  Widget _buildGalleryList() {
    /// use FlutterSliverList to [keepPosition] when insert items at top
    return FlutterSliverList(
      key: key,
      delegate: FlutterListViewDelegate(
        (_, int index) {
          if (index == gallerys.length - 1 && loadingState == LoadingState.idle && handleLoadMore != null) {
            /// 1. shouldn't call directly, because SliverList is building, if we call [setState] here will cause a exception
            /// that hints circular build.
            /// 2. when callback is called, the SliverGrid's state will call [setState], it'll rebuild all sliver child by index, it means
            /// that this callback will be added again and again! so add a condition to check loadingState so that make sure
            /// the callback is added only once.
            SchedulerBinding.instance.addPostFrameCallback((_) => handleLoadMore());
          }
          return Container(
            decoration: StyleSetting.listMode.value == ListMode.flat
                ? BoxDecoration(
                    color: Theme.of(context).colorScheme.background,
                    border: Border(bottom: BorderSide(width: 0.5, color: Theme.of(context).dividerColor)),
                  )
                : null,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            child: EHGalleryListCard(
              gallery: gallerys[index],
              handleTapCard: (gallery) => handleTapCard(gallery),
              handleLongPressCard: handleLongPressCard == null ? null : (gallery) => handleLongPressCard(gallery),
              handleSecondaryTapCard: handleSecondaryTapCard == null ? null : (gallery) => handleSecondaryTapCard(gallery),
              withTags: StyleSetting.listMode.value == ListMode.listWithTags || StyleSetting.listMode.value == ListMode.flat,
            ),
          );
        },
        childCount: gallerys.length,
        keepPosition: true,
        onItemKey: (index) => gallerys[index].galleryUrl,
        preferItemHeight: StyleSetting.listMode.value == ListMode.listWithTags ? 200 : 125,
      ),
    );
  }

  Widget _buildGalleryListWithNative() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, index) {
          if (index == gallerys.length - 1 && loadingState == LoadingState.idle && handleLoadMore != null) {
            /// 1. shouldn't call directly, because SliverList is building, if we call [setState] here will cause a exception
            /// that hints circular build.
            /// 2. when callback is called, the SliverGrid's state will call [setState], it'll rebuild all sliver child by index, it means
            /// that this callback will be added again and again! so add a condition to check loadingState so that make sure
            /// the callback is added only once.
            SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
              handleLoadMore();
            });
          }
          return EHGalleryListCard(
            gallery: gallerys[index],
            handleTapCard: (gallery) => handleTapCard(gallery),
            withTags: StyleSetting.listMode.value == ListMode.listWithTags,
            handleLongPressCard: handleLongPressCard == null ? null : (gallery) => handleLongPressCard(gallery),
            handleSecondaryTapCard: handleSecondaryTapCard == null ? null : (gallery) => handleSecondaryTapCard(gallery),
          ).marginOnly(top: 5, bottom: 5, left: 10, right: 10);
        },
        childCount: gallerys.length,
      ),
    );
  }

  Widget _buildGalleryWaterfallFlow() {
    return SliverPadding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      sliver: SliverWaterfallFlow(
        gridDelegate: const SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            if (index == gallerys.length - 1 && loadingState == LoadingState.idle && handleLoadMore != null) {
              /// 1. shouldn't call directly, because SliverList is building, if we call [setState] here will cause a exception
              /// that hints circular build.
              /// 2. when callback is called, the SliverGrid's state will call [setState], it'll rebuild all sliver child by index, it means
              /// that this callback will be added again and again! so add a condition to check loadingState so that make sure
              /// the callback is added only once.
              SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
                handleLoadMore();
              });
            }

            return EHGalleryWaterFlowCard(gallery: gallerys[index], handleTapCard: handleTapCard);
          },
          childCount: gallerys.length,
        ),
      ),
    );
  }

  return Obx(() {
    if (StyleSetting.listMode.value == ListMode.flat ||
        StyleSetting.listMode.value == ListMode.listWithoutTags ||
        StyleSetting.listMode.value == ListMode.listWithTags) {
      return _buildGalleryList();
    }

    return _buildGalleryWaterfallFlow();
  });
}
