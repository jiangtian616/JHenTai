import 'package:flukit/flukit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/mixin/scroll_to_top_page_mixin.dart';
import 'package:jhentai/src/pages/details/thumbnails/thumbnails_page_logic.dart';
import 'package:jhentai/src/pages/details/thumbnails/thumbnails_page_state.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/widget/eh_image.dart';

import '../../../config/ui_config.dart';
import '../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../model/gallery_image.dart';
import '../../../widget/eh_thumbnail.dart';
import '../../../widget/eh_wheel_speed_controller.dart';
import '../../../widget/loading_state_indicator.dart';

class ThumbnailsPage extends StatelessWidget with Scroll2TopPageMixin {
  final ThumbnailsPageLogic logic = Get.put<ThumbnailsPageLogic>(ThumbnailsPageLogic());
  final ThumbnailsPageState state = Get.find<ThumbnailsPageLogic>().state;

  @override
  Scroll2TopLogicMixin get scroll2TopLogic => logic;

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  ThumbnailsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThumbnailsPageLogic>(
      builder: (_) => Scaffold(
        backgroundColor: UIConfig.backGroundColor(context),
        appBar: buildAppBar(),
        body: buildBody(),
        floatingActionButton: buildFloatingActionButton(),
      ),
    );
  }

  AppBar buildAppBar() {
    return AppBar(
      title: Text(logic.detailsPageState.gallery?.title ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          icon: const Icon(FontAwesomeIcons.paperPlane, size: 21),
          visualDensity: const VisualDensity(vertical: -2),
          onPressed: logic.handleTapJumpButton,
        ),
      ],
    );
  }

  Widget buildBody() {
    return NotificationListener<UserScrollNotification>(
      onNotification: logic.onUserScroll,
      child: EHWheelSpeedController(
        controller: state.scrollController,
        child: CustomScrollView(
          controller: state.scrollController,
          slivers: [
            if (state.thumbnails.isNotEmpty) _buildThumbnails(),
            _buildLoadingThumbnailIndicator(),
          ],
        ).paddingOnly(left: 15, right: 15),
      ),
    );
  }

  Widget _buildThumbnails() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 36),
      sliver: GetBuilder<ThumbnailsPageLogic>(
        id: ThumbnailsPageLogic.thumbnailsId,
        builder: (_) {
          return SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == state.thumbnails.length - 1 && state.loadingState == LoadingState.idle) {
                  SchedulerBinding.instance.addPostFrameCallback((_) => logic.loadMoreThumbnails());
                }

                GalleryImage? downloadedImage = logic.detailsPageLogic.galleryDownloadService
                    .galleryDownloadInfos[logic.detailsPageState.gallery!.gid]?.images[state.absoluteIndexOfThumbnails[index]];

                return KeepAliveWrapper(
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: GestureDetector(
                            onTap: () => logic.detailsPageLogic.goToReadPage(state.absoluteIndexOfThumbnails[index]),
                            child: LayoutBuilder(
                              builder: (_, constraints) {
                                return downloadedImage?.downloadStatus == DownloadStatus.downloaded
                                    ? EHImage(
                                        galleryImage: downloadedImage!,
                                        containerHeight: constraints.maxHeight,
                                        containerWidth: constraints.maxWidth,
                                        borderRadius: BorderRadius.circular(8),
                                        maxBytes: 1024 * 1024,
                                      )
                                    : EHThumbnail(
                                        thumbnail: state.thumbnails[index],
                                        containerHeight: constraints.maxHeight,
                                        containerWidth: constraints.maxWidth,
                                        borderRadius: BorderRadius.circular(8),
                                      );
                              },
                            ),
                          ),
                        ),
                      ),
                      Text(
                        (state.absoluteIndexOfThumbnails[index] + 1).toString(),
                        style: TextStyle(color: UIConfig.detailsPageThumbnailIndexColor(context)),
                      ).paddingOnly(top: 3),
                    ],
                  ),
                );
              },
              childCount: state.thumbnails.length,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              mainAxisExtent: UIConfig.detailsPageThumbnailHeight,
              maxCrossAxisExtent: UIConfig.detailsPageThumbnailWidth,
              mainAxisSpacing: 20,
              crossAxisSpacing: 5,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingThumbnailIndicator() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 12, bottom: 40),
      sliver: SliverToBoxAdapter(
        child: GetBuilder<ThumbnailsPageLogic>(
          id: ThumbnailsPageLogic.loadingStateId,
          builder: (_) => LoadingStateIndicator(
            loadingState: state.loadingState,
            errorTapCallback: logic.loadMoreThumbnails,
          ),
        ),
      ),
    );
  }
}
