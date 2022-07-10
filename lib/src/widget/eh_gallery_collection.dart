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

/// act as a List or WaterfallFlow according to Style Setting
Widget EHGalleryCollection({
  Key? key,
  required List<Gallery> gallerys,
  required LoadingState loadingState,
  required TapCardCallback handleTapCard,
  VoidCallback? handleLoadMore,
  bool keepPosition = false,
}) {
  Widget _buildGalleryList() {
    /// use FlutterSliverList to [keepPosition] when insert items at top
    return FlutterSliverList(
      key: key,
      delegate: FlutterListViewDelegate(
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
          return EHGalleryListCard(
            gallery: gallerys[index],
            handleTapCard: (gallery) => handleTapCard(gallery),
            withTags: StyleSetting.listMode.value == ListMode.listWithTags,
          ).marginOnly(top: 5, bottom: 5, left: 10, right: 10);
        },
        childCount: gallerys.length,
        keepPosition: keepPosition,
        onItemKey: (index) => gallerys[index].galleryUrl,
        onIsPermanent: (_) => true,
        preferItemHeight: StyleSetting.listMode.value == ListMode.listWithTags ? 200 : 125,
      ),
    );
  }

  Widget _buildGalleryList2() {
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
          ).marginOnly(top: 5, bottom: 5, left: 10, right: 10);
        },
        childCount: gallerys.length,
      ),
    );

    return FlutterSliverList(
      key: key,
      delegate: FlutterListViewDelegate(
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
          return EHGalleryListCard(
            gallery: gallerys[index],
            handleTapCard: (gallery) => handleTapCard(gallery),
            withTags: StyleSetting.listMode.value == ListMode.listWithTags,
          ).marginOnly(top: 5, bottom: 5, left: 10, right: 10);
        },
        childCount: gallerys.length,
        keepPosition: keepPosition,
        onItemKey: (index) => gallerys[index].galleryUrl,
        onIsPermanent: (_) => true,
        preferItemHeight: StyleSetting.listMode.value == ListMode.listWithTags ? 200 : 125,
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

            return EHGalleryWaterFlowCard(
              gallery: gallerys[index],
              handleTapCard: handleTapCard,
            );
          },
          childCount: gallerys.length,
        ),
      ),
    );
  }

  return Obx(() {
    if (StyleSetting.listMode.value == ListMode.listWithoutTags || StyleSetting.listMode.value == ListMode.listWithTags) {
      return _buildGalleryList();
    }
    return _buildGalleryWaterfallFlow();
  });
}
