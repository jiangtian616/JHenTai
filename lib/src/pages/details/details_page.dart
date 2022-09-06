import 'dart:collection';
import 'dart:math';

import 'package:animate_do/animate_do.dart';
import 'package:flukit/flukit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/consts/color_consts.dart';
import 'package:jhentai/src/consts/locale_consts.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/pages/details/comment/eh_comment.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_layout_page_logic.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/widget/eh_image.dart';
import 'package:jhentai/src/widget/eh_tag.dart';
import 'package:jhentai/src/widget/eh_thumbnail.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/widget/icon_text_button.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../database/database.dart';
import '../../model/gallery_comment.dart';
import '../../service/gallery_download_service.dart';
import '../../setting/style_setting.dart';
import '../../utils/date_util.dart';
import '../../utils/route_util.dart';
import '../../widget/eh_gallery_category_tag.dart';
import 'details_page_logic.dart';
import 'details_page_state.dart';

class DetailsPage extends StatelessWidget {
  final String tag = UniqueKey().toString();

  late final DetailsPageLogic logic;
  late final DetailsPageState state;

  DetailsPage({Key? key}) : super(key: key) {
    logic = Get.put(DetailsPageLogic(tag), tag: tag);
    state = logic.state;
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      tag: tag,
      builder: (_) => Scaffold(
        appBar: buildAppBar(),
        body: buildBody(),
        floatingActionButton: buildFloatingButton(),
      ),
    );
  }

  AppBar buildAppBar() {
    return AppBar(
      title: Text(state.gallery?.title ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      actions: [
        ExcludeFocus(child: IconButton(icon: const Icon(Icons.share), onPressed: logic.shareGallery)),
      ],
    );
  }

  Widget buildBody() {
    if (state.gallery == null) {
      return LoadingStateIndicator(
        indicatorRadius: 18,
        loadingState: state.loadingState,
        errorTapCallback: logic.handleRefresh,
      );
    }

    return FocusScope(
      node: Get.isRegistered<DesktopLayoutPageLogic>()
          ? (Get.find<DesktopLayoutPageLogic>().state.rightColumnFocusScopeNode..onKeyEvent = logic.onKeyEvent)
          : null,
      child: EHWheelSpeedController(
        scrollController: state.scrollController,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          controller: state.scrollController,
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: logic.handleRefresh),
            _buildHeader(),
            _buildDivider(),
            _buildNewVersionHint(),
            _buildActions(),
            _buildTags(),
            _buildLoadingDetailsIndicator(),
            _buildCommentsIndicator(),
            _buildComments(),
            _buildThumbnails(),
            if (state.galleryDetails != null) _buildLoadingThumbnailIndicator(),
          ],
        ).paddingOnly(left: 15, right: 15),
      ),
    );
  }

  Widget? buildFloatingButton() {
    if (state.galleryDetails == null) {
      return null;
    }

    return ExcludeFocus(
      child: FloatingActionButton(
        child: const Icon(Icons.arrow_upward, size: 26),
        onPressed: DetailsPageLogic.current?.scroll2Top,
      ),
    );
  }

  Widget _buildHeader() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 12),
      sliver: SliverToBoxAdapter(child: _DetailsPageHeader(logic: logic, state: state)),
    );
  }

  Widget _buildNewVersionHint() {
    if (state.galleryDetails?.newVersionGalleryUrl == null) {
      return const SliverToBoxAdapter();
    }

    return SliverPadding(
      padding: const EdgeInsets.only(top: 12),
      sliver: SliverToBoxAdapter(
        child: _NewVersionHint(newGalleryUrl: state.galleryDetails!.newVersionGalleryUrl!),
      ),
    );
  }

  Widget _buildDivider() {
    return const SliverPadding(padding: EdgeInsets.only(top: 24), sliver: SliverToBoxAdapter(child: Divider(height: 1)));
  }

  Widget _buildActions() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 20),
      sliver: SliverToBoxAdapter(child: _ActionButtons()),
    );
  }

  Widget _buildTags() {
    LinkedHashMap<String, List<GalleryTag>>? tagList = state.galleryDetails?.fullTags;
    if (tagList?.isEmpty ?? true) {
      return const SliverToBoxAdapter();
    }

    return SliverPadding(
      padding: const EdgeInsets.only(top: 16),
      sliver: SliverToBoxAdapter(
        child: _GalleryTags(
          tagList: tagList!,
          gid: state.gallery!.gid,
          token: state.gallery!.token,
          apikey: state.apikey,
        ),
      ),
    );
  }

  Widget _buildLoadingDetailsIndicator() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 24),
      sliver: SliverToBoxAdapter(
        child: GetBuilder<DetailsPageLogic>(
          id: DetailsPageLogic.loadingStateId,
          tag: tag,
          builder: (_) => LoadingStateIndicator(
            indicatorRadius: 16,
            loadingState: state.loadingState,
            errorTapCallback: logic.getDetails,
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsIndicator() {
    if (state.galleryDetails == null) {
      return const SliverToBoxAdapter();
    }

    return SliverToBoxAdapter(
      child: FadeIn(
        child: SizedBox(
          height: UIConfig.detailsPageCommentIndicatorHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ExcludeFocus(
                child: TextButton(
                  onPressed: () => toRoute(Routes.comment, arguments: state.galleryDetails!.comments),
                  child: Text(state.galleryDetails!.comments.isEmpty ? 'noComments'.tr : 'allComments'.tr),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComments() {
    if (state.galleryDetails?.comments.isEmpty ?? true) {
      return const SliverToBoxAdapter();
    }

    return SliverToBoxAdapter(
      child: _Comments(comments: state.galleryDetails!.comments),
    );
  }

  Widget _buildLoadingThumbnailIndicator() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 12, bottom: 40),
      sliver: SliverToBoxAdapter(
        child: GetBuilder<DetailsPageLogic>(
          id: DetailsPageLogic.loadingThumbnailsStateId,
          tag: tag,
          builder: (_) => LoadingStateIndicator(
            loadingState: state.loadingThumbnailsState,
            errorTapCallback: logic.loadMoreThumbnails,
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnails() {
    if (state.galleryDetails == null) {
      return const SliverToBoxAdapter();
    }

    return SliverPadding(
      padding: const EdgeInsets.only(top: 36),
      sliver: _Thumbnails(logic: logic, state: state),
    );
  }
}

class _DetailsPageHeader extends StatelessWidget {
  final DetailsPageLogic logic;

  final DetailsPageState state;

  const _DetailsPageHeader({Key? key, required this.logic, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: UIConfig.detailsPageHeaderHeight,
      child: Row(
        children: [
          _buildCover(),
          Expanded(child: _buildDetails().marginOnly(left: 10)),
        ],
      ),
    );
  }

  Widget _buildCover() {
    return GestureDetector(
      onTap: () => toRoute(Routes.singleImagePage, arguments: state.gallery!.cover),
      child: EHImage.network(
        containerHeight: UIConfig.detailsPageCoverHeight,
        containerWidth: UIConfig.detailsPageCoverWidth,
        galleryImage: state.gallery!.cover,
        borderRadius: BorderRadius.circular(UIConfig.detailsPageCoverBorderRadius),
        heroTag: state.gallery!.cover,
        shadows: [
          BoxShadow(
            color: Get.theme.colorScheme.onPrimaryContainer.withOpacity(0.3),
            blurRadius: 5,
            offset: const Offset(3, 5),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(),
        _buildUploader(),
        const Expanded(child: SizedBox()),
        _buildInfo().marginOnly(bottom: 4),
        _buildRatingAndCategory(),
      ],
    );
  }

  Widget _buildTitle() {
    return SelectableText(
      state.gallery!.title,
      minLines: 1,
      maxLines: 5,
      style: const TextStyle(
        fontSize: UIConfig.detailsPageTitleTextSize,
        letterSpacing: UIConfig.detailsPageTitleLetterSpacing,
        height: UIConfig.detailsPageTitleTextHeight,
      ),
    );
  }

  Widget _buildUploader() {
    if (state.gallery?.uploader == null) {
      return const SizedBox();
    }

    return SelectableText(
      state.gallery!.uploader!,
      style: TextStyle(fontSize: UIConfig.detailsPageUploaderTextSize, color: UIConfig.detailsPageUploaderTextColor),
      onTap: logic.searchUploader,
    ).marginOnly(top: 10);
  }

  Widget _buildInfo() {
    return LayoutBuilder(
      builder: (_, BoxConstraints constraints) {
        double minWidth = constraints.maxWidth / 6;
        return Wrap(
          runSpacing: 2,
          children: [
            SizedBox(
              width: max(UIConfig.detailsPageFirstSpanWidthSize, constraints.maxWidth / 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.language, size: 10, color: UIConfig.detailsPageIconColor),
                  Text(state.gallery!.language?.capitalizeFirst ?? 'Japanese',
                          style: const TextStyle(fontSize: UIConfig.detailsPageDetailsTextSize))
                      .marginOnly(left: 2),
                ],
              ),
            ),
            SizedBox(
              width: max(UIConfig.detailsPageSecondSpanWidthSize, minWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, size: 10, color: UIConfig.detailsPageIconColor),
                  Text(
                    state.galleryDetails?.favoriteCount.toString() ?? '...',
                    style: const TextStyle(fontSize: UIConfig.detailsPageDetailsTextSize),
                  )
                ],
              ),
            ),
            SizedBox(
              width: max(UIConfig.detailsPageFirstSpanWidthSize, minWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.archive, size: 10, color: UIConfig.detailsPageIconColor).marginOnly(right: 2),
                  Text(state.galleryDetails?.size ?? '...', style: const TextStyle(fontSize: UIConfig.detailsPageDetailsTextSize)),
                ],
              ),
            ),
            SizedBox(
              width: max(UIConfig.detailsPageFirstSpanWidthSize, minWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.collections, size: 10, color: UIConfig.detailsPageIconColor),
                  Text(
                    state.gallery!.pageCount == null ? '...' : state.gallery!.pageCount.toString(),
                    style: const TextStyle(fontSize: UIConfig.detailsPageDetailsTextSize),
                  ).marginOnly(left: 2),
                ],
              ),
            ),
            SizedBox(
              width: max(UIConfig.detailsPageSecondSpanWidthSize, minWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 10, color: UIConfig.detailsPageIconColor),
                  Text(
                    state.galleryDetails?.ratingCount.toString() ?? '...',
                    style: const TextStyle(fontSize: UIConfig.detailsPageDetailsTextSize),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: max(UIConfig.detailsPageThirdSpanWidthSize, minWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_upload, size: 10, color: UIConfig.detailsPageIconColor).marginOnly(right: 2),
                  Text(
                    DateUtil.transform2LocalTimeString(state.gallery!.publishTime),
                    style: const TextStyle(fontSize: UIConfig.detailsPageDetailsTextSize),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRatingAndCategory() {
    return Row(
      children: [
        _buildRatingBar(),
        Text(state.galleryDetails?.realRating.toString() ?? '...', style: const TextStyle(fontSize: UIConfig.detailsPageRatingTextSize)),
        const Expanded(child: SizedBox()),
        EHGalleryCategoryTag(category: state.gallery!.category)
      ],
    );
  }

  Widget _buildRatingBar() {
    return RatingBar.builder(
      unratedColor: Colors.grey.shade300,
      initialRating: state.galleryDetails == null ? 0 : state.gallery!.rating,
      itemCount: 5,
      allowHalfRating: true,
      itemSize: 18,
      ignoreGestures: true,
      itemBuilder: (context, index) => Icon(Icons.star, color: state.gallery!.hasRated ? Get.theme.colorScheme.error : Colors.amber.shade800),
      onRatingUpdate: (_) {},
    );
  }
}

class _NewVersionHint extends StatelessWidget {
  final String newGalleryUrl;

  const _NewVersionHint({Key? key, required this.newGalleryUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: UIConfig.detailsPageNewVersionHintHeight,
      child: FadeIn(
        child: TextButton(
          child: Text('thisGalleryHasANewVersion'.tr),
          onPressed: () => toRoute(
            Routes.details,
            arguments: {'galleryUrl': newGalleryUrl},
            offAllBefore: false,
            preventDuplicates: false,
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final DetailsPageLogic logic = DetailsPageLogic.current!;
  final DetailsPageState state = DetailsPageLogic.current!.state;

  _ActionButtons({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: SizedBox(
        height: UIConfig.detailsPageActionsHeight,
        child: LayoutBuilder(
          builder: (_, BoxConstraints constraints) => ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            itemExtent: max(UIConfig.detailsPageActionExtent, (constraints.maxWidth - 15 * 2) / 8),
            padding: EdgeInsets.zero,
            children: [
              _buildReadButton(),
              _buildDownloadButton(),
              _buildFavoriteButton(),
              _buildRatingButton(),
              _buildArchiveButton(),
              _buildSimilarButton(),
              _buildTorrentButton(),
              _buildStatisticButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadButton() {
    bool disabled = state.gallery?.pageCount == null;

    int readIndexRecord = logic.getReadIndexRecord();
    String text = (readIndexRecord == 0 ? 'read'.tr : 'P${readIndexRecord + 1}');

    return IconTextButton(
      icon: Icon(Icons.visibility, color: disabled ? Get.theme.disabledColor : UIConfig.detailsPageActionIconColor),
      text: Text(
        text,
        style: TextStyle(
          fontSize: UIConfig.detailsPageActionTextSize,
          color: disabled ? Get.theme.disabledColor : UIConfig.detailsPageActionTextColor,
          height: 1,
        ),
      ),
      onPressed: disabled ? null : logic.goToReadPage,
    );
  }

  Widget _buildDownloadButton() {
    return GetBuilder<GalleryDownloadService>(
      id: '$galleryDownloadProgressId::${state.gallery!.gid}',
      builder: (_) {
        bool disabled = state.gallery?.pageCount == null;

        GalleryDownloadProgress? downloadProgress = logic.galleryDownloadService.galleryDownloadInfos[state.gallery?.gid]?.downloadProgress;

        String text = downloadProgress == null
            ? 'download'.tr
            : downloadProgress.downloadStatus == DownloadStatus.paused
                ? 'resume'.tr
                : downloadProgress.downloadStatus == DownloadStatus.downloading
                    ? 'pause'.tr
                    : state.galleryDetails?.newVersionGalleryUrl == null
                        ? 'finished'.tr
                        : 'update'.tr;

        Icon icon = downloadProgress == null
            ? Icon(Icons.download, color: disabled ? Get.theme.disabledColor : UIConfig.detailsPageActionIconColor)
            : downloadProgress.downloadStatus == DownloadStatus.paused
                ? Icon(Icons.play_circle_outline, color: Get.theme.colorScheme.error)
                : downloadProgress.downloadStatus == DownloadStatus.downloading
                    ? Icon(Icons.pause_circle_outline, color: Get.theme.colorScheme.error)
                    : state.galleryDetails?.newVersionGalleryUrl == null
                        ? const Icon(Icons.done, color: Colors.green)
                        : Icon(Icons.auto_awesome, color: Get.theme.colorScheme.error);

        return IconTextButton(
          icon: icon,
          text: Text(
            text,
            style: TextStyle(
              fontSize: UIConfig.detailsPageActionTextSize,
              color: disabled ? Get.theme.disabledColor : UIConfig.detailsPageActionTextColor,
              height: 1,
            ),
          ),
          onPressed: disabled ? null : logic.handleTapDownload,
          onLongPress: () => toRoute(Routes.download),
        );
      },
    );
  }

  Widget _buildFavoriteButton() {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.addFavoriteStateId,
      tag: logic.tag,
      builder: (_) {
        bool disabled = state.gallery == null;

        return LoadingStateIndicator(
          loadingState: state.favoriteState,
          idleWidget: IconTextButton(
            icon: Icon(
              state.gallery!.favoriteTagIndex != null ? Icons.favorite : Icons.favorite_border,
              color: disabled
                  ? Get.theme.disabledColor
                  : state.gallery!.favoriteTagIndex != null
                      ? ColorConsts.favoriteTagColor[state.gallery!.favoriteTagIndex!]
                      : UIConfig.detailsPageActionIconColor,
            ),
            text: Text(
              state.gallery!.isFavorite ? state.gallery!.favoriteTagName! : 'favorite'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: UIConfig.detailsPageActionTextSize,
                color: disabled ? Get.theme.disabledColor : UIConfig.detailsPageActionTextColor,
                height: 1,
              ),
            ),
            onPressed: disabled ? null : logic.handleTapFavorite,
          ),
          errorWidgetSameWithIdle: true,
        );
      },
    );
  }

  Widget _buildRatingButton() {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.ratingStateId,
      tag: logic.tag,
      builder: (_) {
        bool disabled = state.galleryDetails == null;

        return LoadingStateIndicator(
          loadingState: state.ratingState,
          idleWidget: IconTextButton(
            icon: Icon(
              state.gallery!.hasRated ? Icons.star : Icons.star_border,
              color: disabled
                  ? Get.theme.disabledColor
                  : state.gallery!.hasRated
                      ? Get.theme.colorScheme.error
                      : UIConfig.detailsPageActionIconColor,
            ),
            text: Text(
              state.gallery!.hasRated ? state.gallery!.rating.toString() : 'rating'.tr,
              style: TextStyle(
                fontSize: UIConfig.detailsPageActionTextSize,
                color: disabled ? Get.theme.disabledColor : UIConfig.detailsPageActionTextColor,
                height: 1,
              ),
            ),
            onPressed: disabled ? null : logic.handleTapRating,
          ),
          errorWidgetSameWithIdle: true,
        );
      },
    );
  }

  Widget _buildArchiveButton() {
    return GetBuilder<ArchiveDownloadService>(
      id: '${ArchiveDownloadService.archiveStatusId}::${state.gallery!.gid}',
      builder: (_) {
        bool disabled = state.galleryDetails == null;

        ArchiveStatus? archiveStatus = Get.find<ArchiveDownloadService>().archiveDownloadInfos[state.gallery!.gid]?.archiveStatus;

        String text = archiveStatus == null ? 'archive'.tr : archiveStatus.name.tr;

        Icon icon = archiveStatus == null
            ? Icon(Icons.archive, color: disabled ? Get.theme.disabledColor : UIConfig.detailsPageActionIconColor)
            : archiveStatus == ArchiveStatus.paused
                ? Icon(Icons.play_circle_outline, color: Get.theme.colorScheme.error)
                : archiveStatus == ArchiveStatus.completed
                    ? const Icon(Icons.done, color: Colors.green)
                    : Icon(Icons.pause_circle_outline, color: Get.theme.colorScheme.error);

        return IconTextButton(
          icon: icon,
          text: Text(
            text,
            style: TextStyle(
              fontSize: UIConfig.detailsPageActionTextSize,
              color: disabled ? Get.theme.disabledColor : UIConfig.detailsPageActionTextColor,
              height: 1,
            ),
          ),
          onPressed: disabled ? null : logic.handleTapArchive,
          onLongPress: () => toRoute(Routes.download),
        );
      },
    );
  }

  Widget _buildSimilarButton() {
    bool disabled = state.galleryDetails == null;

    return IconTextButton(
      icon: Icon(Icons.saved_search, color: disabled ? Get.theme.disabledColor : UIConfig.detailsPageActionIconColor),
      text: Text(
        'similar'.tr,
        style: TextStyle(
          fontSize: UIConfig.detailsPageActionTextSize,
          color: disabled ? Get.theme.disabledColor : UIConfig.detailsPageActionTextColor,
          height: 1,
        ),
      ),
      onPressed: disabled ? null : logic.searchSimilar,
    );
  }

  Widget _buildTorrentButton() {
    bool disabled = state.galleryDetails == null || state.galleryDetails!.torrentCount == '0';

    String text = '${'torrent'.tr}(${state.galleryDetails?.torrentCount ?? '.'})';

    return IconTextButton(
      icon: Icon(Icons.file_present, color: disabled ? Get.theme.disabledColor : UIConfig.detailsPageActionIconColor),
      text: Text(
        text,
        style: TextStyle(
          fontSize: UIConfig.detailsPageActionTextSize,
          color: disabled ? Get.theme.disabledColor : UIConfig.detailsPageActionTextColor,
          height: 1,
        ),
      ),
      onPressed: disabled || state.galleryDetails!.torrentCount == '0' ? null : logic.handleTapTorrent,
    );
  }

  Widget _buildStatisticButton() {
    bool disabled = state.galleryDetails == null;

    return IconTextButton(
      icon: Icon(Icons.analytics, color: disabled ? Get.theme.disabledColor : UIConfig.detailsPageActionIconColor),
      text: Text(
        'statistic'.tr,
        style: TextStyle(
          fontSize: UIConfig.detailsPageActionTextSize,
          color: disabled ? Get.theme.disabledColor : UIConfig.detailsPageActionTextColor,
          height: 1,
        ),
      ),
      onPressed: state.galleryDetails == null ? null : logic.handleTapStatistic,
    );
  }
}

class _GalleryTags extends StatelessWidget {
  final LinkedHashMap<String, List<GalleryTag>> tagList;
  final int gid;
  final String token;
  final String apikey;

  const _GalleryTags({
    Key? key,
    required this.tagList,
    required this.gid,
    required this.token,
    required this.apikey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: tagList.entries
          .map(
            (entry) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryTag(entry.key).marginOnly(right: 10),
                Expanded(
                  child: Wrap(spacing: 5, runSpacing: 5, children: _buildTags(entry.value)),
                ),
              ],
            ).marginOnly(top: 10),
          )
          .toList(),
    );
  }

  Widget _buildCategoryTag(String category) {
    return EHTag(
      tag: GalleryTag(
        tagData: TagData(
          namespace: 'rows',
          key: category,
          tagName: StyleSetting.enableTagZHTranslation.isTrue ? LocaleConsts.tagNamespace[category] : null,
        ),
      ),
      addNameSpaceColor: true,
    );
  }

  List<Widget> _buildTags(List<GalleryTag> tags) {
    return tags
        .map((tag) => EHTag(
              tag: tag,
              enableTapping: true,
              gid: gid,
              token: token,
              apikey: apikey,
            ))
        .toList();
  }
}

class _Comments extends StatelessWidget {
  final List<GalleryComment> comments;

  const _Comments({Key? key, required this.comments}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool disableButtons = comments.any((comment) => comment.fromMe);

    return FadeIn(
      child: SizedBox(
        height: UIConfig.detailsPageCommentsHeight,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemExtent: UIConfig.detailsPageCommentsWidth,
          children: comments
              .map(
                (comment) => GestureDetector(
                  onTap: () => toRoute(Routes.comment, arguments: comments),
                  child: EHComment(
                    comment: comment,
                    maxLines: 4,
                    bodyHeight: UIConfig.detailsPageCommentBodyHeight,
                    disableButtons: disableButtons,
                  ),
                ).marginOnly(right: 10),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _Thumbnails extends StatelessWidget {
  final DetailsPageLogic logic;
  final DetailsPageState state;

  const _Thumbnails({Key? key, required this.logic, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.thumbnailsId,
      tag: logic.tag,
      builder: (_) => SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, index) {
            if (index == state.galleryDetails!.thumbnails.length - 1 && state.loadingThumbnailsState == LoadingState.idle) {
              /// 1. shouldn't call directly, because SliverGrid is building, if we call [setState] here will cause a exception
              /// that hints circular build.
              /// 2. when callback is called, the SliverGrid's state will call [setState], it'll rebuild all child by index, it means
              /// that this callback will be added again and again! so add a condition to check loadingState so that make sure
              /// the callback is added once.
              SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
                logic.loadMoreThumbnails();
              });
            }

            return KeepAliveWrapper(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: () => logic.goToReadPage(index),
                        child: EHThumbnail(
                          thumbnail: state.galleryDetails!.thumbnails[index],
                          image: logic.galleryDownloadService.galleryDownloadInfos[state.gallery!.gid]?.images[index],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    (index + 1).toString(),
                    style: TextStyle(color: UIConfig.detailsPageThumbnailIndexColor),
                  ).paddingOnly(top: 3),
                ],
              ),
            );
          },
          childCount: state.galleryDetails!.thumbnails.length,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          mainAxisExtent: UIConfig.detailsPageThumbnailHeight,
          maxCrossAxisExtent: UIConfig.detailsPageThumbnailWidth,
          mainAxisSpacing: 20,
          crossAxisSpacing: 5,
        ),
      ),
    );
  }
}
