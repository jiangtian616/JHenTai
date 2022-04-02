import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../model/gallery.dart';
import '../pages/home/tab_view/widget/gallery_card.dart';
import '../setting/style_setting.dart';

SliverList EHGalleryCollection({
  required List<Gallery> gallerys,
  required LoadingState loadingState,
  required TapCardCallback handleTapCard,
  VoidCallback? handleLoadMore,
}) {
  void _handleLoadMoreIfAtLast(int index) {
    if (index == gallerys.length - 1 && loadingState == LoadingState.idle && handleLoadMore != null) {
      /// 1. shouldn't call directly, because SliverList is building, if we call [setState] here will cause a exception
      /// that hints circular build.
      /// 2. when callback is called, the SliverGrid's state will call [setState], it'll rebuild all sliver child by index, it means
      /// that this callback will be added again and again! so add a condition to check loadingState so that make sure
      /// the callback is added only once.
      SchedulerBinding.instance?.addPostFrameCallback((timeStamp) {
        handleLoadMore();
      });
    }
  }

  SliverList _buildGalleryList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          _handleLoadMoreIfAtLast(index);

          Gallery gallery = gallerys[index];
          return Obx(() {
            return GalleryCard(
              gallery: gallery,
              handleTapCard: (gallery) => handleTapCard(gallery),
              withTags: StyleSetting.listMode.value == ListMode.listWithTags,
            ).marginOnly(top: 5, bottom: 5, left: 10, right: 10);
          });
        },
        childCount: gallerys.length,
      ),
    );
  }

  return _buildGalleryList();
}
