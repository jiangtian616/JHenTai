import 'dart:collection';
import 'dart:math';

import 'package:animate_do/animate_do.dart';
import 'package:flukit/flukit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/color_consts.dart';
import 'package:jhentai/src/consts/locale_consts.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/pages/details/widget/eh_comment.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_layout_page_logic.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/widget/eh_image.dart';
import 'package:jhentai/src/widget/eh_tag.dart';
import 'package:jhentai/src/widget/eh_thumbnail.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/widget/icon_text_button.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../database/database.dart';
import '../../model/download_progress.dart';
import '../../service/gallery_download_service.dart';
import '../../service/storage_service.dart';
import '../../setting/style_setting.dart';
import '../../utils/date_util.dart';
import '../../utils/route_util.dart';
import '../../utils/screen_size_util.dart';
import '../../widget/eh_gallery_category_tag.dart';
import 'details_page_logic.dart';
import 'details_page_state.dart';

class DetailsPage extends StatelessWidget {
  final String tag = UniqueKey().toString();

  late final DetailsPageLogic detailsPageLogic;
  late final DetailsPageState detailsPageState;

  final GalleryDownloadService downloadService = Get.find();
  final TagTranslationService tagTranslationService = Get.find();
  final StorageService storageService = Get.find();

  DetailsPage({Key? key}) : super(key: key) {
    detailsPageLogic = Get.put(DetailsPageLogic(tag), tag: tag);
    detailsPageState = detailsPageLogic.state;
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: bodyId,
      tag: tag,
      builder: (logic) {
        return Scaffold(
          appBar: AppBar(
            title: Text(detailsPageState.gallery?.title ?? ''),
            titleTextStyle: TextStyle(
              fontSize: 14,
              color: Theme.of(context).appBarTheme.titleTextStyle?.color,
              fontWeight: FontWeight.bold,
            ),
            actions: [
              ExcludeFocus(
                child: IconButton(onPressed: detailsPageLogic.shareGallery, icon: const Icon(Icons.share)),
              )
            ],
          ),
          body: () {
            Gallery? gallery = detailsPageState.gallery;
            if (gallery == null) {
              return _buildLoadingPageIndicator();
            }

            return FocusScope(
              node: Get.isRegistered<DesktopLayoutPageLogic>()
                  ? (Get.find<DesktopLayoutPageLogic>().state.rightColumnFocusScopeNode..onKeyEvent = detailsPageLogic.onKeyEvent)
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(width: 0.2, color: Get.theme.appBarTheme.foregroundColor!),
                  ),
                ),
                child: EHWheelSpeedController(
                  scrollController: detailsPageState.scrollController,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    controller: detailsPageState.scrollController,
                    slivers: [
                      CupertinoSliverRefreshControl(onRefresh: detailsPageLogic.handleRefresh),
                      _buildHeader(gallery, detailsPageState.galleryDetails, context),
                      _buildDetails(gallery, detailsPageState.galleryDetails),
                      if (detailsPageState.galleryDetails?.newVersionGalleryUrl != null)
                        _buildNewVersionHint(detailsPageState.galleryDetails!.newVersionGalleryUrl!),
                      _buildActions(gallery, detailsPageState.galleryDetails, context),
                      if (detailsPageState.galleryDetails?.fullTags.isNotEmpty ?? false) _buildTags(detailsPageState.galleryDetails!.fullTags),
                      _buildLoadingDetailsIndicator(),
                      if (detailsPageState.galleryDetails != null) _buildCommentsIndicator(detailsPageState.galleryDetails!),
                      if (detailsPageState.galleryDetails?.comments.isNotEmpty ?? false) _buildComments(detailsPageState.galleryDetails!),
                      if (detailsPageState.galleryDetails != null) _buildThumbnails(detailsPageState.galleryDetails!),
                      if (detailsPageState.galleryDetails != null) _buildLoadingThumbnailIndicator(),
                    ],
                  ).paddingOnly(top: 10, left: 15, right: 15),
                ),
              ),
            );
          }(),
        );
      },
    );
  }

  Widget _buildLoadingPageIndicator() {
    return GetBuilder<DetailsPageLogic>(
      id: loadingStateId,
      tag: tag,
      builder: (logic) {
        return LoadingStateIndicator(
          indicatorRadius: 18,
          loadingState: detailsPageState.loadingPageState,
          errorTapCallback: detailsPageLogic.getFullPage,
        );
      },
    );
  }

  Widget _buildHeader(Gallery gallery, GalleryDetail? galleryDetails, BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              GestureDetector(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Obx(() {
                    return EHImage.network(
                      containerHeight: 200,
                      containerWidth: 140,
                      galleryImage: gallery.cover,
                      adaptive: true,
                      fit: StyleSetting.coverMode.value == CoverMode.contain ? BoxFit.contain : BoxFit.cover,
                    );
                  }),
                ),
                onTap: () => toNamed(Routes.singleImagePage, arguments: gallery.cover),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      gallery.title,
                      minLines: 1,
                      maxLines: 7,
                      style: const TextStyle(fontSize: 16, height: 1.2),
                    ),
                    if (gallery.uploader != null)
                      SelectableText(
                        gallery.uploader!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        onTap: () => detailsPageLogic.searchUploader(gallery.uploader!),
                      ).marginOnly(top: 10),
                  ],
                ).paddingOnly(left: 6),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(Gallery gallery, GalleryDetail? galleryDetails) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 18),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        galleryDetails?.realRating.toString() ?? '    ',
                        style: const TextStyle(fontSize: 18),
                      ),
                      RatingBar.builder(
                        unratedColor: Colors.grey.shade300,
                        initialRating: galleryDetails == null ? 0 : gallery.rating,
                        itemCount: 5,
                        allowHalfRating: true,
                        itemSize: 18,
                        ignoreGestures: true,
                        itemBuilder: (context, index) => Icon(
                          Icons.star,
                          color: gallery.hasRated ? Get.theme.primaryColor : Colors.amber.shade800,
                        ),
                        onRatingUpdate: (rating) {},
                      ).marginOnly(left: 4),
                      Row(
                        children: [
                          Text(
                            galleryDetails?.ratingCount.toString() ?? '',
                            style: const TextStyle(fontSize: 8, color: Colors.grey),
                          ),
                        ],
                      )
                    ],
                  ),
                  EHGalleryCategoryTag(
                    category: gallery.category,
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.language,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      Text(
                        gallery.language ?? 'Japanese',
                        style: const TextStyle(fontSize: 13),
                      ).marginOnly(left: 2),
                    ],
                  ),
                  FadeIn(
                    child: Text(
                      galleryDetails?.size ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.collections,
                        size: 12,
                        color: Colors.grey,
                      ),
                      Text(
                        gallery.pageCount == null ? '...' : gallery.pageCount.toString(),
                        style: const TextStyle(fontSize: 13),
                      ).marginOnly(left: 2),
                    ],
                  ),
                ],
              ).marginOnly(top: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite,
                        size: 12,
                        color: Colors.red,
                      ),
                      Text(
                        galleryDetails?.favoriteCount.toString() ?? '...',
                        style: const TextStyle(fontSize: 13),
                      ).marginOnly(left: 2),
                    ],
                  ),
                  Text(
                    DateUtil.transform2LocalTimeString(gallery.publishTime),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewVersionHint(String parentGalleryUrl) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 24),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: 50,
          child: TextButton(
            child: Text('thisGalleryHasANewVersion'.tr),
            onPressed: () => toNamed(
              Routes.details,
              arguments: parentGalleryUrl,
              offAllBefore: false,
              preventDuplicates: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(Gallery gallery, GalleryDetail? galleryDetails, BuildContext context) {
    int readIndexRecord = storageService.read('readIndexRecord::${detailsPageState.gallery!.gid}') ?? 0;

    return SliverPadding(
      padding: const EdgeInsets.only(top: 24),
      sliver: SliverToBoxAdapter(
        child: ExcludeFocus(
          child: SizedBox(
            height: 70,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemExtent: max(77, (screenWidth - 15 * 2) / 8),
              children: [
                IconTextButton(
                  iconData: Icons.visibility,
                  iconSize: 28,
                  onPressed: detailsPageState.gallery?.pageCount == null ? null : () => detailsPageLogic.goToReadPage(),
                  text: Text(
                    (readIndexRecord == 0 ? 'read'.tr : 'P${readIndexRecord + 1}'),
                    style: TextStyle(fontSize: 12, color: Get.theme.appBarTheme.titleTextStyle?.color),
                  ),
                ),
                IconTextButton(
                  iconData: Icons.download,
                  iconSize: 30,
                  onPressed: detailsPageState.gallery?.pageCount == null ? null : () => detailsPageLogic.handleTapDownload(),
                  text: GetBuilder<GalleryDownloadService>(
                    id: '$galleryDownloadProgressId::${gallery.gid}',
                    builder: (_) {
                      GalleryDownloadProgress? downloadProgress = downloadService.gid2DownloadProgress[gallery.gid];
                      return Text(
                        downloadProgress == null
                            ? 'download'.tr
                            : downloadProgress.downloadStatus == DownloadStatus.paused
                                ? 'resume'.tr
                                : downloadProgress.downloadStatus == DownloadStatus.downloading
                                    ? 'pause'.tr
                                    : detailsPageState.galleryDetails?.newVersionGalleryUrl == null
                                        ? 'finished'.tr
                                        : 'update'.tr,
                        style: TextStyle(fontSize: 12, color: Get.theme.appBarTheme.titleTextStyle?.color),
                      );
                    },
                  ),
                ),
                GetBuilder<DetailsPageLogic>(
                    id: addFavoriteStateId,
                    tag: tag,
                    builder: (logic) {
                      return LoadingStateIndicator(
                        width: max(77, (screenWidth - 15 * 2) / 7),
                        loadingState: detailsPageState.favoriteState,
                        idleWidget: IconTextButton(
                          iconData: gallery.isFavorite && detailsPageState.galleryDetails != null ? Icons.favorite : Icons.favorite_border,
                          iconSize: 26,
                          iconColor: gallery.isFavorite && detailsPageState.galleryDetails != null
                              ? ColorConsts.favoriteTagColor[gallery.favoriteTagIndex!]
                              : null,
                          text: Text(
                            gallery.isFavorite ? gallery.favoriteTagName! : 'favorite'.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Get.theme.appBarTheme.titleTextStyle?.color,
                            ),
                          ),
                          onPressed: detailsPageState.galleryDetails == null
                              ? null
                              : UserSetting.hasLoggedIn()
                                  ? detailsPageLogic.handleTapFavorite
                                  : detailsPageLogic.showLoginSnack,
                        ),
                        errorWidgetSameWithIdle: true,
                      );
                    }),
                GetBuilder<DetailsPageLogic>(
                  id: ratingStateId,
                  tag: tag,
                  builder: (logic) {
                    return LoadingStateIndicator(
                      width: max(77, (screenWidth - 15 * 2) / 7),
                      loadingState: detailsPageState.ratingState,
                      idleWidget: IconTextButton(
                        iconData: gallery.hasRated && detailsPageState.galleryDetails != null ? Icons.star : Icons.star_border,
                        iconColor: gallery.hasRated && detailsPageState.galleryDetails != null ? Colors.red.shade700 : null,
                        iconSize: 28,
                        text: Text(
                          gallery.hasRated ? gallery.rating.toString() : 'rating'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Get.theme.appBarTheme.titleTextStyle?.color,
                          ),
                        ),
                        onPressed: detailsPageState.galleryDetails == null
                            ? null
                            : UserSetting.hasLoggedIn()
                                ? detailsPageLogic.handleTapRating
                                : detailsPageLogic.showLoginSnack,
                      ),
                      errorWidgetSameWithIdle: true,
                    );
                  },
                ),
                IconTextButton(
                  iconData: Icons.saved_search,
                  iconSize: 28,
                  text: Text(
                    'similar'.tr,
                    style: TextStyle(fontSize: 12, color: Get.theme.appBarTheme.titleTextStyle?.color),
                  ),
                  onPressed: detailsPageState.galleryDetails == null ? null : detailsPageLogic.searchSimilar,
                ),
                IconTextButton(
                  iconData: FontAwesomeIcons.magnet,
                  iconSize: 24,
                  text: Text(
                    '${'torrent'.tr}(${detailsPageState.galleryDetails?.torrentCount ?? '.'})',
                    style: TextStyle(fontSize: 12, color: Get.theme.appBarTheme.titleTextStyle?.color),
                  ),
                  onPressed: detailsPageState.galleryDetails == null ? null : detailsPageLogic.handleTapTorrent,
                ),
                IconTextButton(
                  iconData: Icons.folder_zip,
                  iconSize: 28,
                  text: Text(
                    'archive'.tr,
                    style: TextStyle(fontSize: 12, color: Get.theme.appBarTheme.titleTextStyle?.color),
                  ),
                  onPressed: detailsPageState.galleryDetails == null ? null : detailsPageLogic.handleTapArchive,
                ),
                IconTextButton(
                  iconData: Icons.analytics,
                  iconSize: 28,
                  text: Text(
                    'statistic'.tr,
                    style: TextStyle(fontSize: 12, color: Get.theme.appBarTheme.titleTextStyle?.color),
                  ),
                  onPressed: detailsPageState.galleryDetails == null ? null : detailsPageLogic.handleTapStatistic,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTags(LinkedHashMap<String, List<GalleryTag>> tagList) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 24),
      sliver: SliverToBoxAdapter(
        child: FadeIn(
          child: Column(
            children: tagList.entries
                .map(
                  (entry) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EHTag(
                        tag: GalleryTag(
                          tagData: TagData(
                            namespace: 'rows',
                            key: entry.key,
                            tagName: StyleSetting.enableTagZHTranslation.isTrue ? LocaleConsts.tagNamespace[entry.key] : null,
                          ),
                        ),
                        addNameSpaceColor: true,
                      ).marginOnly(right: 10),

                      /// use [expanded] and [wrap] to implement 'flex-wrap'
                      Expanded(
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: entry.value.map((tag) => EHTag(tag: tag, enableTapping: true)).toList(),
                        ),
                      ),
                    ],
                  ).marginOnly(top: 10),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingDetailsIndicator() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 24),
      sliver: SliverToBoxAdapter(
        child: GetBuilder<DetailsPageLogic>(
            id: loadingStateId,
            tag: tag,
            builder: (logic) {
              return LoadingStateIndicator(
                indicatorRadius: 16,
                loadingState: detailsPageState.loadingDetailsState,
                errorTapCallback: detailsPageLogic.getDetails,
              );
            }),
      ),
    );
  }

  Widget _buildCommentsIndicator(GalleryDetail galleryDetails) {
    return SliverToBoxAdapter(
      child: FadeIn(
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ExcludeFocus(
                child: TextButton(
                  onPressed: () => toNamed(Routes.comment, arguments: detailsPageState.galleryDetails!.comments),
                  child: Text(galleryDetails.comments.isEmpty ? 'noComments'.tr : 'allComments'.tr),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComments(GalleryDetail galleryDetails) {
    return SliverToBoxAdapter(
      child: FadeIn(
        child: SizedBox(
          height: 135,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemExtent: 300,
            children: galleryDetails.comments
                .map(
                  (comment) => GestureDetector(
                    onTap: () => toNamed(Routes.comment, arguments: detailsPageState.galleryDetails!.comments),
                    child: EHComment(
                      comment: comment,
                      maxLines: 4,
                      showVotingButtons: galleryDetails.comments.every((comment) => comment.userName != UserSetting.userName.value),
                    ),
                  ).marginOnly(right: 10),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingThumbnailIndicator() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 8, bottom: 40),
      sliver: SliverToBoxAdapter(
        child: GetBuilder<DetailsPageLogic>(
            id: loadingStateId,
            tag: tag,
            builder: (logic) {
              return LoadingStateIndicator(
                errorTapCallback: () => {detailsPageLogic.loadMoreThumbnails()},
                loadingState: detailsPageState.loadingThumbnailsState,
              );
            }),
      ),
    );
  }

  Widget _buildThumbnails(GalleryDetail galleryDetails) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 36),
      sliver: GetBuilder<DetailsPageLogic>(
          id: thumbnailsId,
          tag: tag,
          builder: (logic) {
            return SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == galleryDetails.thumbnails.length - 1 && detailsPageState.loadingThumbnailsState == LoadingState.idle) {
                    /// 1. shouldn't call directly, because SliverGrid is building, if we call [setState] here will cause a exception
                    /// that hints circular build.
                    /// 2. when callback is called, the SliverGrid's state will call [setState], it'll rebuild all child by index, it means
                    /// that this callback will be added again and again! so add a condition to check loadingState so that make sure
                    /// the callback is added once.
                    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
                      detailsPageLogic.loadMoreThumbnails();
                    });
                  }

                  return KeepAliveWrapper(
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              onTap: () => detailsPageLogic.goToReadPage(index),
                              child: EHThumbnail(
                                containerHeight: 200,
                                galleryThumbnail: galleryDetails.thumbnails[index],
                              ),
                            ),
                          ),
                        ),
                        Text(
                          (index + 1).toString(),
                          style: const TextStyle(color: Colors.grey),
                        ).paddingOnly(top: 3),
                      ],
                    ),
                  );
                },
                childCount: galleryDetails.thumbnails.length,
              ),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                mainAxisExtent: 220,
                maxCrossAxisExtent: 150,
                mainAxisSpacing: 20,
                crossAxisSpacing: 5,
              ),
            );
          }),
    );
  }
}
