import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:jhentai/src/config/ui_config.dart';
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
  required ListMode listMode,
  required LoadingState loadingState,
  required CardCallback handleTapCard,
  CardCallback? handleLongPressCard,
  CardCallback? handleSecondaryTapCard,
  VoidCallback? handleLoadMore,
  ValueChanged<Gallery>? onScrolled,
}) {
  Widget _buildGalleryList() {
    /// use FlutterSliverList to [keepPosition] when insert items at top
    return FlutterSliverList(
      key: key,
      controller: FlutterSliverListController()
        ..onPaintItemPositionsCallback = (_, List<FlutterListViewItemPosition> positions) {
          if (positions.isNotEmpty) {
            onScrolled?.call(gallerys[positions.last.index]);
          }
        },
      delegate: FlutterListViewDelegate(
        (_, int index) {
          if (index == gallerys.length - 1 && loadingState == LoadingState.idle && handleLoadMore != null) {
            SchedulerBinding.instance.addPostFrameCallback((_) => handleLoadMore());
          }
          return Container(
            decoration: listMode == ListMode.flat || listMode == ListMode.flatWithoutTags
                ? BoxDecoration(
                    color: UIConfig.backGroundColor(context),
                    border: Border(bottom: BorderSide(width: 0.5, color: Theme.of(context).dividerColor)),
                  )
                : null,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            child: EHGalleryListCard(
              gallery: gallerys[index],
              listMode: listMode,
              handleTapCard: (gallery) => handleTapCard(gallery),
              handleLongPressCard: handleLongPressCard == null ? null : (gallery) => handleLongPressCard(gallery),
              handleSecondaryTapCard: handleSecondaryTapCard == null ? null : (gallery) => handleSecondaryTapCard(gallery),
              withTags: listMode == ListMode.listWithTags || listMode == ListMode.flat,
            ),
          );
        },
        childCount: gallerys.length,
        keepPosition: true,
        onItemKey: (index) => gallerys[index].galleryUrl,
        preferItemHeight: listMode == ListMode.listWithTags ? 200 : 125,
      ),
    );
  }

  Widget _buildGalleryWaterfallFlow() {
    return SliverPadding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      sliver: SliverWaterfallFlow(
        gridDelegate: StyleSetting.crossAxisCountInWaterFallFlow.value == null
            ? SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: listMode == ListMode.waterfallFlowBig ? 225 : 150,
                mainAxisSpacing: listMode == ListMode.waterfallFlowBig ? 10 : 5,
                crossAxisSpacing: 5,
                collectGarbage: (List<int> garbages) {
                  if (gallerys.isNotEmpty) {
                    onScrolled?.call(gallerys[garbages.last]);
                  }
                },
              )
            : SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                crossAxisCount: StyleSetting.crossAxisCountInWaterFallFlow.value!,
                mainAxisSpacing: listMode == ListMode.waterfallFlowBig ? 10 : 5,
                crossAxisSpacing: 5,
                collectGarbage: (List<int> garbages) {
                  if (gallerys.isNotEmpty) {
                    onScrolled?.call(gallerys[garbages.last]);
                  }
                },
              ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            if (index == gallerys.length - 1 && loadingState == LoadingState.idle && handleLoadMore != null) {
              SchedulerBinding.instance.addPostFrameCallback((_) => handleLoadMore());
            }

            return EHGalleryWaterFlowCard(
              gallery: gallerys[index],
              listMode: listMode,
              handleTapCard: handleTapCard,
            );
          },
          childCount: gallerys.length,
        ),
      ),
    );
  }

  if (listMode == ListMode.flat ||
      listMode == ListMode.flatWithoutTags ||
      listMode == ListMode.listWithoutTags ||
      listMode == ListMode.listWithTags) {
    return _buildGalleryList();
  }

  return _buildGalleryWaterfallFlow();
}
