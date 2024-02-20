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
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/consts/color_consts.dart';
import 'package:jhentai/src/consts/locale_consts.dart';
import 'package:jhentai/src/extension/string_extension.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/mixin/scroll_to_top_page_mixin.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/pages/details/comment/eh_comment.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/utils/convert_util.dart';
import 'package:jhentai/src/widget/eh_gallery_detail_dialog.dart';
import 'package:jhentai/src/widget/eh_image.dart';
import 'package:jhentai/src/widget/eh_tag.dart';
import 'package:jhentai/src/widget/eh_thumbnail.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/widget/icon_text_button.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../database/database.dart';
import '../../mixin/scroll_to_top_logic_mixin.dart';
import '../../mixin/scroll_to_top_state_mixin.dart';
import '../../service/gallery_download_service.dart';
import '../../service/local_gallery_service.dart';
import '../../setting/preference_setting.dart';
import '../../setting/style_setting.dart';
import '../../utils/date_util.dart';
import '../../utils/route_util.dart';
import '../../widget/eh_gallery_category_tag.dart';
import 'details_page_logic.dart';
import 'details_page_state.dart';

class DetailsPage extends StatelessWidget with Scroll2TopPageMixin {
  final String tag = UniqueKey().toString();

  late final DetailsPageLogic logic;
  late final DetailsPageState state;

  @override
  Scroll2TopLogicMixin get scroll2TopLogic => logic;

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  DetailsPage({super.key}) {
    logic = Get.put(DetailsPageLogic(), tag: tag);
    state = logic.state;
  }

  DetailsPage.preview({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      global: false,
      init: logic,
      builder: (_) => Scaffold(
        appBar: buildAppBar(context),
        body: buildBody(context),
        floatingActionButton: buildFloatingActionButton(),
      ),
    );
  }

  AppBar buildAppBar(BuildContext context) {
    return AppBar(
      title: GetBuilder<DetailsPageLogic>(
        id: DetailsPageLogic.galleryId,
        global: false,
        init: logic,
        builder: (_) => Text(_mainTitleText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      actions: [
        _buildMenuButton(context),
      ],
    );
  }

  String get _mainTitleText =>
      state.gallery?.title.breakWord ??
      state.galleryDetails?.japaneseTitle?.breakWord ??
      state.galleryDetails?.rawTitle.breakWord ??
      state.galleryMetadata?.japaneseTitle ??
      state.galleryMetadata?.title ??
      '';

  Widget _buildMenuButton(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.detailsId,
      global: false,
      init: logic,
      builder: (_) {
        if (state.galleryDetails == null && state.galleryMetadata == null) {
          return const SizedBox();
        }

        return GetBuilder<ArchiveDownloadService>(
          id: '${ArchiveDownloadService.archiveStatusId}::${state.galleryUrl.gid}',
          builder: (_) => GetBuilder<GalleryDownloadService>(
            id: '${Get.find<GalleryDownloadService>().galleryDownloadProgressId}::${state.galleryUrl.gid}',
            builder: (_) {
              GalleryDownloadProgress? downloadProgress = logic.galleryDownloadService.galleryDownloadInfos[state.galleryUrl.gid]?.downloadProgress;
              ArchiveStatus? archiveStatus = Get.find<ArchiveDownloadService>().archiveDownloadInfos[state.galleryUrl.gid]?.archiveStatus;

              return PopupMenuButton(
                itemBuilder: (context) {
                  return [
                    if (state.galleryDetails != null)
                      PopupMenuItem(
                        value: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [Text('jump'.tr), const Icon(FontAwesomeIcons.paperPlane, size: 20)],
                        ),
                      ),
                    PopupMenuItem(
                      value: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text('share'.tr), const Icon(Icons.share)],
                      ),
                    ),
                    if (state.galleryDetails != null)
                      PopupMenuItem(
                        value: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [Text('addTag'.tr), const Icon(Icons.bookmark_border)],
                        ),
                      ),
                    if (downloadProgress != null || archiveStatus != null)
                      PopupMenuItem(
                        value: 3,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [Text('delete'.tr), const Icon(Icons.delete)],
                        ),
                      ),
                    if (state.galleryDetails?.parentGalleryUrl != null || (state.galleryDetails?.childrenGallerys?.isNotEmpty ?? false))
                      PopupMenuItem(
                        value: 4,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [Text('history'.tr), const Icon(Icons.history)],
                        ),
                      ),
                  ];
                },
                onSelected: (value) {
                  if (value == 0) {
                    logic.handleTapJumpButton();
                  }
                  if (value == 1) {
                    logic.shareGallery();
                  }
                  if (value == 2) {
                    logic.handleAddTag(context);
                  }
                  if (value == 3) {
                    logic.handleTapDeleteDownload(
                      context,
                      state.galleryUrl.gid,
                      downloadProgress != null ? DownloadPageGalleryType.download : DownloadPageGalleryType.archive,
                    );
                  }
                  if (value == 4) {
                    logic.handleTapHistoryButton(context);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget buildBody(BuildContext context) {
    return NotificationListener<UserScrollNotification>(
      onNotification: logic.onUserScroll,
      child: EHWheelSpeedController(
        controller: state.scrollController,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          controller: state.scrollController,
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: logic.handleRefresh),
            if (PreferenceSetting.showAllGalleryTitles.isTrue) _buildSubTitle(context),
            buildDetail(context),
            buildDivider(),
            buildNewVersionHint(),
            buildActions(context),
            buildLoadingDetailsIndicator(),
            buildCopyRightRemovedHint(),
            buildTags(),
            if (PreferenceSetting.showComments.isTrue) buildComments(),
            buildThumbnails(),
            buildLoadingThumbnailIndicator(context),
          ],
        ),
      ),
    );
  }

  Widget buildDetail(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        height: UIConfig.detailsPageHeaderHeight,
        margin: const EdgeInsets.only(top: 12, left: UIConfig.detailPagePadding, right: UIConfig.detailPagePadding),
        child: Row(
          children: [
            _buildCover(context),
            const SizedBox(width: 10),
            Expanded(child: _buildInfo(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.galleryId,
      global: false,
      init: logic,
      builder: (_) {
        GalleryImage? cover = state.galleryDetails?.cover ?? state.gallery?.cover ?? state.galleryMetadata?.cover;

        if (cover == null) {
          return Container(
            height: UIConfig.detailsPageCoverHeight,
            width: UIConfig.detailsPageCoverWidth,
            alignment: Alignment.center,
            child: UIConfig.loadingAnimation(context),
          );
        }

        return GestureDetector(
          onTap: () => toRoute(Routes.singleImagePage, arguments: cover),
          child: EHImage(
            galleryImage: cover,
            containerHeight: UIConfig.detailsPageCoverHeight,
            containerWidth: UIConfig.detailsPageCoverWidth,
            borderRadius: BorderRadius.circular(UIConfig.detailsPageCoverBorderRadius),
            heroTag: cover,
            shadows: [
              BoxShadow(
                color: UIConfig.detailPageCoverShadowColor(context),
                blurRadius: 5,
                offset: const Offset(3, 5),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(),
        const SizedBox(height: 4),
        _buildUploader(context),
        const Expanded(child: SizedBox()),
        _buildDataInfo(context),
        const SizedBox(height: 4),
        _buildRatingAndCategory(context),
      ],
    );
  }

  Widget _buildTitle() {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.galleryId,
      global: false,
      init: logic,
      builder: (_) {
        return ScrollConfiguration(
          behavior: UIConfig.scrollBehaviourWithoutScrollBarWithMouse,
          child: SelectableText(
            _mainTitleText,
            minLines: 1,
            maxLines: 5,
            style: const TextStyle(
              fontSize: UIConfig.detailsPageTitleTextSize,
              letterSpacing: UIConfig.detailsPageTitleLetterSpacing,
              height: UIConfig.detailsPageTitleTextHeight,
            ),
            contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
              AdaptiveTextSelectionToolbar toolbar = AdaptiveTextSelectionToolbar.buttonItems(
                buttonItems: editableTextState.contextMenuButtonItems,
                anchors: editableTextState.contextMenuAnchors,
              );

              if (!editableTextState.currentTextEditingValue.selection.isCollapsed) {
                toolbar.buttonItems?.add(
                  ContextMenuButtonItem(
                    label: 'search'.tr,
                    onPressed: () {
                      ContextMenuController.removeAny();
                      logic.search(editableTextState.currentTextEditingValue.selection.textInside(editableTextState.currentTextEditingValue.text));
                    },
                  ),
                );
              }

              return toolbar;
            },
          ),
        );
      },
    );
  }

  Widget _buildSubTitle(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: UIConfig.detailPagePadding),
        alignment: Alignment.centerLeft,
        child: GetBuilder<DetailsPageLogic>(
          id: DetailsPageLogic.detailsId,
          global: false,
          init: logic,
          builder: (_) {
            if (state.galleryDetails == null && state.galleryMetadata == null) {
              return const AnimatedSwitcher(duration: Duration(milliseconds: UIConfig.detailsPageAnimationDuration), child: SizedBox());
            }

            String? subTitle;
            if (state.galleryDetails?.japaneseTitle != null && state.galleryDetails!.japaneseTitle!.breakWord != _mainTitleText) {
              subTitle = state.galleryDetails!.rawTitle.breakWord;
            } else if (state.galleryDetails?.japaneseTitle != null && state.galleryDetails!.japaneseTitle!.breakWord != _mainTitleText) {
              subTitle = state.galleryDetails!.japaneseTitle!.breakWord;
            } else if (state.galleryMetadata?.title != null && state.galleryMetadata!.title.breakWord != _mainTitleText) {
              subTitle = state.galleryMetadata!.title.breakWord;
            } else if (state.galleryMetadata?.japaneseTitle != null && state.galleryMetadata!.japaneseTitle.breakWord != _mainTitleText) {
              subTitle = state.galleryMetadata!.japaneseTitle.breakWord;
            }

            if (subTitle == null) {
              return const AnimatedSwitcher(duration: Duration(milliseconds: UIConfig.detailsPageAnimationDuration), child: SizedBox());
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: UIConfig.detailsPageAnimationDuration),
              child: SelectableText(
                subTitle,
                minLines: 1,
                maxLines: 2,
                style: UIConfig.detailsPageSubTitleTextStyle(context),
                contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
                  AdaptiveTextSelectionToolbar toolbar = AdaptiveTextSelectionToolbar.buttonItems(
                    buttonItems: editableTextState.contextMenuButtonItems,
                    anchors: editableTextState.contextMenuAnchors,
                  );

                  if (!editableTextState.currentTextEditingValue.selection.isCollapsed) {
                    toolbar.buttonItems?.add(
                      ContextMenuButtonItem(
                        label: 'search'.tr,
                        onPressed: () {
                          ContextMenuController.removeAny();
                          logic.search(editableTextState.currentTextEditingValue.selection.textInside(editableTextState.currentTextEditingValue.text));
                        },
                      ),
                    );
                  }

                  return toolbar;
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUploader(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.uploaderId,
      global: false,
      init: logic,
      builder: (_) {
        return SelectableText(
          state.galleryDetails?.uploader ?? state.gallery?.uploader ?? state.galleryMetadata?.uploader ?? '',
          style: TextStyle(fontSize: UIConfig.detailsPageUploaderTextSize, color: UIConfig.detailsPageUploaderTextColor(context)),
          onTap: logic.searchUploader,
        );
      },
    );
  }

  Widget _buildDataInfo(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (state.galleryDetails != null) {
          Get.dialog(EHGalleryDetailDialog(galleryDetail: state.galleryDetails!));
        }
      },
      child: StyleSetting.isInMobileLayout ? _buildInfoInThreeRows(context) : _buildInfoInTwoRows(),
    );
  }

  Widget _buildInfoInTwoRows() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double iconSize = 10 + constraints.maxWidth / 120;
        final double textSize = 6 + constraints.maxWidth / 120;
        final double space = 4 / 3 + constraints.maxWidth / 300;

        return DefaultTextStyle(
          style: DefaultTextStyle.of(context).style.copyWith(fontSize: textSize),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(flex: 9, child: _buildLanguage(iconSize, space, context)),
                  Expanded(flex: 7, child: _buildFavoriteCount(iconSize, space, context)),
                  Expanded(flex: 10, child: _buildSize(iconSize, space, context)),
                ],
              ),
              SizedBox(height: space),
              Row(
                children: [
                  Expanded(flex: 9, child: _buildPageCount(iconSize, space, context)),
                  Expanded(flex: 7, child: _buildRatingCount(iconSize, space, context)),
                  Expanded(flex: 10, child: _buildPublishTime(iconSize, space, context)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoInThreeRows(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLanguage(UIConfig.detailsPageInfoIconSize, 2, context),
              const SizedBox(height: 2),
              _buildRatingCount(UIConfig.detailsPageInfoIconSize, 2, context),
              const SizedBox(height: 2),
              _buildPageCount(UIConfig.detailsPageInfoIconSize, 2, context),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSize(UIConfig.detailsPageInfoIconSize, 2, context),
              const SizedBox(height: 2),
              _buildFavoriteCount(UIConfig.detailsPageInfoIconSize, 2, context),
              const SizedBox(height: 2),
              _buildPublishTime(UIConfig.detailsPageInfoIconSize, 2, context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguage(double iconSize, double space, BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.languageId,
      global: false,
      init: logic,
      builder: (_) {
        String language;
        if (state.galleryDetails != null) {
          language = state.galleryDetails!.language.capitalizeFirst!;
        } else if (state.gallery?.language != null) {
          language = state.gallery!.language!.capitalizeFirst!;
        } else if (state.gallery?.tags.isNotEmpty ?? false) {
          language = 'Japanese';
        } else if (state.galleryMetadata?.language != null) {
          language = state.galleryMetadata!.language.capitalizeFirst!;
        } else {
          language = '...';
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language, size: iconSize, color: UIConfig.detailsPageIconColor(context)),
            SizedBox(width: space),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: UIConfig.detailsPageAnimationDuration),
              child: Text(
                language,
                key: ValueKey(language),
                style: const TextStyle(fontSize: UIConfig.detailsPageInfoTextSize),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFavoriteCount(double iconSize, double space, BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.detailsId,
      global: false,
      init: logic,
      builder: (_) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite, size: iconSize, color: UIConfig.detailsPageIconColor(context)),
          SizedBox(width: space),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: UIConfig.detailsPageAnimationDuration),
            child: Text(
              state.galleryDetails?.favoriteCount.toString() ?? '...',
              key: ValueKey(state.galleryDetails?.favoriteCount.toString() ?? '...'),
              style: const TextStyle(fontSize: UIConfig.detailsPageInfoTextSize),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSize(double iconSize, double space, BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.detailsId,
      global: false,
      init: logic,
      builder: (_) {
        String size = state.galleryDetails?.size ?? state.galleryMetadata?.size ?? '...';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.archive, size: iconSize, color: UIConfig.detailsPageIconColor(context)),
            SizedBox(width: space),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: UIConfig.detailsPageAnimationDuration),
              child: Text(
                size,
                key: ValueKey(size),
                style: const TextStyle(fontSize: UIConfig.detailsPageInfoTextSize),
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildPageCount(double iconSize, double space, BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.pageCountId,
      global: false,
      init: logic,
      builder: (_) {
        String pageCount =
            state.galleryDetails?.pageCount.toString() ?? state.gallery?.pageCount?.toString() ?? state.galleryMetadata?.pageCount.toString() ?? '...';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.collections, size: iconSize, color: UIConfig.detailsPageIconColor(context)),
            SizedBox(width: space),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: UIConfig.detailsPageAnimationDuration),
              child: Text(
                pageCount,
                key: ValueKey(pageCount),
                style: const TextStyle(fontSize: UIConfig.detailsPageInfoTextSize),
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildRatingCount(double iconSize, double space, BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.detailsId,
      global: false,
      init: logic,
      builder: (_) {
        String ratingCount = state.galleryDetails?.ratingCount.toString() ?? '...';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: iconSize, color: UIConfig.detailsPageIconColor(context)),
            SizedBox(width: space),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: UIConfig.detailsPageAnimationDuration),
              child: Text(
                ratingCount,
                key: ValueKey(ratingCount),
                style: const TextStyle(fontSize: UIConfig.detailsPageInfoTextSize),
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildPublishTime(double iconSize, double space, BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.galleryId,
      global: false,
      init: logic,
      builder: (_) {
        String time = state.galleryDetails != null
            ? DateUtil.transform2LocalTimeString(state.galleryDetails!.publishTime)
            : state.gallery != null
                ? DateUtil.transform2LocalTimeString(state.gallery!.publishTime)
                : state.galleryMetadata != null
                    ? DateUtil.transform2LocalTimeString(state.galleryMetadata!.publishTime)
                    : '...';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_upload, size: iconSize, color: UIConfig.detailsPageIconColor(context)),
            SizedBox(width: space),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: UIConfig.detailsPageAnimationDuration),
              child: Text(
                time,
                key: ValueKey(time),
                style: const TextStyle(fontSize: UIConfig.detailsPageInfoTextSize),
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildRatingAndCategory(BuildContext context) {
    return Row(
      children: [
        _buildRatingBar(context),
        _buildRealRating(),
        const SizedBox(height: 1),
        const Expanded(child: SizedBox()),
        _buildCategory(),
      ],
    );
  }

  Widget _buildRatingBar(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.ratingId,
      global: false,
      init: logic,
      builder: (_) {
        double? rating = state.galleryDetails?.rating ?? state.gallery?.rating ?? state.galleryMetadata?.rating;
        bool hasRated = state.galleryDetails?.hasRated ?? state.gallery?.hasRated ?? false;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: UIConfig.detailsPageAnimationDuration),
          child: rating == null
              ? RatingBar.builder(
                  unratedColor: UIConfig.galleryRatingStarUnRatedColor(context),
                  initialRating: 0,
                  itemCount: 5,
                  allowHalfRating: true,
                  itemSize: 16,
                  ignoreGestures: true,
                  itemBuilder: (context, index) => const Icon(Icons.star),
                  onRatingUpdate: (_) {},
                )
              : KeyedSubtree(
                  child: RatingBar.builder(
                    unratedColor: UIConfig.galleryRatingStarUnRatedColor(context),
                    initialRating: rating,
                    itemCount: 5,
                    allowHalfRating: true,
                    itemSize: 16,
                    ignoreGestures: true,
                    itemBuilder: (context, index) => Icon(
                      Icons.star,
                      color: hasRated ? UIConfig.galleryRatingStarRatedColor(context) : UIConfig.galleryRatingStarColor,
                    ),
                    onRatingUpdate: (_) {},
                  ),
                ),
        );
      },
    );
  }

  Widget _buildRealRating() {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.detailsId,
      global: false,
      init: logic,
      builder: (_) {
        String realRating = state.galleryDetails?.realRating.toString() ?? state.galleryMetadata?.rating.toString() ?? '...';

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: UIConfig.detailsPageAnimationDuration),
          child: Text(
            realRating,
            key: Key(realRating),
            style: const TextStyle(fontSize: UIConfig.detailsPageRatingTextSize),
          ),
        );
      },
    );
  }

  Widget _buildCategory() {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.galleryId,
      global: false,
      init: logic,
      builder: (_) {
        String? category = state.galleryDetails?.category ?? state.gallery?.category ?? state.galleryMetadata?.category;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: UIConfig.detailsPageAnimationDuration),
          child: category == null
              ? const EHGalleryCategoryTag(
                  enabled: false,
                  category: '               ',
                  padding: EdgeInsets.only(top: 2, bottom: 4, left: 4, right: 4),
                  textStyle: TextStyle(fontSize: UIConfig.detailsPageRatingTextSize, color: UIConfig.galleryCategoryTagTextColor, height: 1),
                  borderRadius: 3,
                )
              : EHGalleryCategoryTag(
                  category: category,
                  padding: const EdgeInsets.only(top: 2, bottom: 4, left: 4, right: 4),
                  textStyle: const TextStyle(fontSize: UIConfig.detailsPageRatingTextSize, color: UIConfig.galleryCategoryTagTextColor, height: 1),
                  borderRadius: 3,
                ),
        );
      },
    );
  }

  Widget buildDivider() {
    return const SliverPadding(
      padding: EdgeInsets.only(top: 16, left: UIConfig.detailPagePadding, right: UIConfig.detailPagePadding),
      sliver: SliverToBoxAdapter(child: Divider(height: 1)),
    );
  }

  Widget buildNewVersionHint() {
    return SliverToBoxAdapter(
      child: GetBuilder<DetailsPageLogic>(
        id: DetailsPageLogic.detailsId,
        global: false,
        init: logic,
        builder: (_) {
          if (state.galleryDetails?.newVersionGalleryUrl == null) {
            return const SizedBox();
          }

          return Container(
            height: UIConfig.detailsPageNewVersionHintHeight,
            margin: const EdgeInsets.only(top: 12),
            child: FadeIn(
              child: TextButton(
                child: Text('thisGalleryHasANewVersion'.tr),
                onPressed: () => toRoute(
                  Routes.details,
                  arguments: {'galleryUrl': state.galleryDetails!.newVersionGalleryUrl!},
                  offAllBefore: false,
                  preventDuplicates: false,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildActions(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        height: UIConfig.detailsPageActionsHeight,
        margin: const EdgeInsets.only(top: 20, bottom: 16, left: UIConfig.detailPagePadding, right: UIConfig.detailPagePadding),
        child: LayoutBuilder(
          builder: (_, BoxConstraints constraints) => ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            itemExtent: max(UIConfig.detailsPageActionExtent, (constraints.maxWidth - UIConfig.detailPagePadding * 2) / 9),
            padding: EdgeInsets.zero,
            children: [
              _buildReadButton(context),
              _buildDownloadButton(context),
              _buildFavoriteButton(context),
              _buildRatingButton(context),
              _buildArchiveButton(context),
              _buildHHButton(context),
              _buildSimilarButton(context),
              _buildTorrentButton(context),
              _buildStatisticButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadButton(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.pageCountId,
      global: false,
      init: logic,
      builder: (_) {
        bool disabled = state.galleryDetails?.pageCount == null && state.gallery?.pageCount == null;

        return GetBuilder<DetailsPageLogic>(
          id: DetailsPageLogic.readButtonId,
          global: false,
          init: logic,
          builder: (_) {
            int readIndexRecord = logic.getReadIndexRecord();
            String text = (readIndexRecord == 0 ? 'read'.tr : 'P${readIndexRecord + 1}');

            return IconTextButton(
              width: UIConfig.detailsPageActionExtent,
              icon: Icon(
                Icons.visibility,
                color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionIconColor(context),
              ),
              text: Text(
                text,
                style: TextStyle(
                  fontSize: UIConfig.detailsPageActionTextSize,
                  color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionTextColor(context),
                  height: 1,
                ),
              ),
              onPressed: disabled ? null : logic.goToReadPage,
            );
          },
        );
      },
    );
  }

  Widget _buildDownloadButton(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.pageCountId,
      global: false,
      init: logic,
      builder: (_) {
        bool disabled = state.galleryDetails?.pageCount == null && state.gallery?.pageCount == null;

        return GetBuilder<GalleryDownloadService>(
          id: '${Get.find<GalleryDownloadService>().galleryDownloadProgressId}::${state.galleryUrl.gid}',
          builder: (_) {
            GalleryDownloadProgress? downloadProgress = logic.galleryDownloadService.galleryDownloadInfos[state.galleryUrl.gid]?.downloadProgress;

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
                ? Icon(Icons.download, color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionIconColor(context))
                : downloadProgress.downloadStatus == DownloadStatus.paused
                    ? Icon(Icons.play_circle_outline, color: UIConfig.resumePauseButtonColor(context))
                    : downloadProgress.downloadStatus == DownloadStatus.downloading
                        ? Icon(Icons.pause_circle_outline, color: UIConfig.resumePauseButtonColor(context))
                        : state.galleryDetails?.newVersionGalleryUrl == null
                            ? Icon(Icons.done, color: UIConfig.resumePauseButtonColor(context))
                            : Icon(Icons.auto_awesome, color: UIConfig.alertColor(context));

            return IconTextButton(
              width: UIConfig.detailsPageActionExtent,
              icon: icon,
              text: Text(
                text,
                style: TextStyle(
                  fontSize: UIConfig.detailsPageActionTextSize,
                  color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionTextColor(context),
                  height: 1,
                ),
              ),
              onPressed: disabled ? null : logic.handleTapDownload,
              onLongPress: () => toRoute(Routes.download),
            );
          },
        );
      },
    );
  }

  Widget _buildFavoriteButton(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.favoriteId,
      global: false,
      init: logic,
      builder: (_) {
        bool disabled = state.galleryDetails == null && state.gallery == null;
        int? favoriteTagIndex = state.galleryDetails?.favoriteTagIndex ?? state.gallery?.favoriteTagIndex;
        String? favoriteTagName = state.galleryDetails?.favoriteTagName ?? state.gallery?.favoriteTagName;

        return GetBuilder<DetailsPageLogic>(
          id: DetailsPageLogic.addFavoriteStateId,
          global: false,
          init: logic,
          builder: (_) => LoadingStateIndicator(
            loadingState: state.favoriteState,
            idleWidget: IconTextButton(
              width: UIConfig.detailsPageActionExtent,
              icon: Icon(
                favoriteTagIndex != null ? Icons.favorite : Icons.favorite_border,
                color: disabled
                    ? UIConfig.detailsPageActionDisabledIconColor(context)
                    : favoriteTagIndex != null
                        ? ColorConsts.favoriteTagColor[favoriteTagIndex]
                        : UIConfig.detailsPageActionIconColor(context),
              ),
              text: Text(
                favoriteTagName ?? 'favorite'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: UIConfig.detailsPageActionTextSize,
                  color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionTextColor(context),
                  height: 1,
                ),
              ),
              onPressed: disabled ? null : () => logic.handleTapFavorite(useDefault: PreferenceSetting.enableDefaultFavorite.isTrue),
              onLongPress: disabled || PreferenceSetting.enableDefaultFavorite.isFalse ? null : () => logic.handleTapFavorite(useDefault: false),
            ),
            errorWidgetSameWithIdle: true,
          ),
        );
      },
    );
  }

  Widget _buildRatingButton(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.ratingId,
      global: false,
      init: logic,
      builder: (_) {
        bool disabled = state.galleryDetails == null && state.gallery == null;
        bool hasRated = state.galleryDetails?.hasRated ?? state.gallery?.hasRated ?? false;
        double? rating = state.galleryDetails?.rating ?? state.gallery?.rating;

        return GetBuilder<DetailsPageLogic>(
          id: DetailsPageLogic.ratingStateId,
          global: false,
          init: logic,
          builder: (_) {
            return LoadingStateIndicator(
              loadingState: state.ratingState,
              idleWidget: IconTextButton(
                width: UIConfig.detailsPageActionExtent,
                icon: Icon(
                  hasRated ? Icons.star : Icons.star_border,
                  color: disabled
                      ? UIConfig.detailsPageActionDisabledIconColor(context)
                      : hasRated
                          ? UIConfig.alertColor(context)
                          : UIConfig.detailsPageActionIconColor(context),
                ),
                text: Text(
                  hasRated ? rating!.toString() : 'rating'.tr,
                  style: TextStyle(
                    fontSize: UIConfig.detailsPageActionTextSize,
                    color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionTextColor(context),
                    height: 1,
                  ),
                ),
                onPressed: disabled ? null : logic.handleTapRating,
              ),
              errorWidgetSameWithIdle: true,
            );
          },
        );
      },
    );
  }

  Widget _buildArchiveButton(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.detailsId,
      global: false,
      init: logic,
      builder: (_) {
        bool disabled = state.galleryDetails == null;

        return GetBuilder<ArchiveDownloadService>(
          id: '${ArchiveDownloadService.archiveStatusId}::${state.galleryUrl.gid}',
          builder: (_) {
            ArchiveStatus? archiveStatus = Get.find<ArchiveDownloadService>().archiveDownloadInfos[state.galleryUrl.gid]?.archiveStatus;

            String text = archiveStatus == null ? 'archive'.tr : archiveStatus.name.tr;

            Icon icon = archiveStatus == null
                ? Icon(Icons.archive, color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionIconColor(context))
                : archiveStatus == ArchiveStatus.paused
                    ? Icon(Icons.play_circle_outline, color: UIConfig.resumePauseButtonColor(context))
                    : archiveStatus == ArchiveStatus.completed
                        ? Icon(Icons.done, color: UIConfig.resumePauseButtonColor(context))
                        : Icon(Icons.pause_circle_outline, color: UIConfig.resumePauseButtonColor(context));

            return IconTextButton(
              width: UIConfig.detailsPageActionExtent,
              icon: icon,
              text: Text(
                text,
                style: TextStyle(
                  fontSize: UIConfig.detailsPageActionTextSize,
                  color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionTextColor(context),
                  height: 1,
                ),
              ),
              onPressed: disabled ? null : logic.handleTapArchive,
              onLongPress: () => toRoute(Routes.download),
            );
          },
        );
      },
    );
  }

  Widget _buildHHButton(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.detailsId,
      global: false,
      init: logic,
      builder: (_) {
        bool disabled = state.galleryDetails == null;

        return IconTextButton(
          width: UIConfig.detailsPageActionExtent,
          icon:
              Icon(Icons.cloud_download, color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionIconColor(context)),
          text: Text(
            'H@H',
            style: TextStyle(
              fontSize: UIConfig.detailsPageActionTextSize,
              color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionTextColor(context),
              height: 1,
            ),
          ),
          onPressed: disabled ? null : logic.handleTapHH,
        );
      },
    );
  }

  Widget _buildSimilarButton(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.detailsId,
      global: false,
      init: logic,
      builder: (_) {
        bool disabled = state.galleryDetails == null && state.galleryMetadata == null;

        return IconTextButton(
          width: UIConfig.detailsPageActionExtent,
          icon: Icon(Icons.saved_search, color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionIconColor(context)),
          text: Text(
            'similar'.tr,
            style: TextStyle(
              fontSize: UIConfig.detailsPageActionTextSize,
              color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionTextColor(context),
              height: 1,
            ),
          ),
          onPressed: disabled ? null : logic.searchSimilar,
        );
      },
    );
  }

  Widget _buildTorrentButton(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.detailsId,
      global: false,
      init: logic,
      builder: (_) {
        bool disabled = state.galleryDetails == null || state.galleryDetails!.torrentCount == '0';

        String text = '${'torrent'.tr}(${state.galleryDetails?.torrentCount ?? '.'})';

        return IconTextButton(
          width: UIConfig.detailsPageActionExtent,
          icon: Icon(Icons.file_present, color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionIconColor(context)),
          text: Text(
            text,
            style: TextStyle(
              fontSize: UIConfig.detailsPageActionTextSize,
              color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionTextColor(context),
              height: 1,
            ),
          ),
          onPressed: disabled || state.galleryDetails!.torrentCount == '0' ? null : logic.handleTapTorrent,
        );
      },
    );
  }

  Widget _buildStatisticButton(BuildContext context) {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.detailsId,
      global: false,
      init: logic,
      builder: (_) {
        bool disabled = state.galleryDetails == null;

        return IconTextButton(
          width: UIConfig.detailsPageActionExtent,
          icon: Icon(Icons.analytics, color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionIconColor(context)),
          text: Text(
            'statistic'.tr,
            style: TextStyle(
              fontSize: UIConfig.detailsPageActionTextSize,
              color: disabled ? UIConfig.detailsPageActionDisabledIconColor(context) : UIConfig.detailsPageActionTextColor(context),
              height: 1,
            ),
          ),
          onPressed: state.galleryDetails == null ? null : logic.handleTapStatistic,
        );
      },
    );
  }

  Widget buildLoadingDetailsIndicator() {
    return SliverToBoxAdapter(
      child: GetBuilder<DetailsPageLogic>(
        id: DetailsPageLogic.loadingStateId,
        global: false,
        init: logic,
        builder: (_) => LoadingStateIndicator(
          indicatorRadius: 16,
          loadingState: state.loadingState,
          errorTapCallback: () => logic.getDetails(useCacheIfAvailable: false),
        ),
      ),
    );
  }

  Widget buildCopyRightRemovedHint() {
    return SliverToBoxAdapter(
      child: GetBuilder<DetailsPageLogic>(
        id: DetailsPageLogic.metadataId,
        global: false,
        init: logic,
        builder: (_) {
          if (state.galleryMetadata == null || state.copyRighter == null) {
            return const SizedBox();
          }
          return Container(
            height: UIConfig.detailsPageCopyRightRemovedHintHeight,
            alignment: Alignment.center,
            child: Text(state.copyRighter!, style: const TextStyle(fontSize: UIConfig.detailsPageCopyRightRemovedHintTextSize)),
          ).fadeIn().marginSymmetric(horizontal: UIConfig.detailPagePadding);
        },
      ),
    );
  }

  Widget buildTags() {
    return SliverToBoxAdapter(
      child: GetBuilder<DetailsPageLogic>(
        id: DetailsPageLogic.detailsId,
        global: false,
        init: logic,
        builder: (_) {
          if (state.galleryDetails?.tags.isEmpty ?? true) {
            return const SizedBox();
          }

          return Column(
            children: state.galleryDetails!.tags.entries
                .map(
                  (entry) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategoryTag(entry.key),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: _buildSubTags(entry.value),
                        ),
                      ),
                    ],
                  ).marginOnly(top: 10),
                )
                .toList(),
          ).fadeIn().marginSymmetric(horizontal: UIConfig.detailPagePadding);
        },
      ),
    );
  }

  Widget _buildCategoryTag(String category) {
    return EHTag(
      tag: GalleryTag(
        tagData: TagData(
          namespace: 'rows',
          key: category,
          tagName: PreferenceSetting.enableTagZHTranslation.isTrue ? LocaleConsts.tagNamespace[category] : null,
        ),
      ),
      addNameSpaceColor: true,
    );
  }

  List<Widget> _buildSubTags(List<GalleryTag> tags) {
    return tags
        .map((tag) => EHTag(
              tag: tag,
              enableTapping: true,
              gid: state.galleryUrl.gid,
              token: state.galleryUrl.token,
              apikey: state.apikey,
              forceNewRoute: true,
            ))
        .toList();
  }

  Widget buildComments() {
    return SliverToBoxAdapter(
      child: GetBuilder<DetailsPageLogic>(
        id: DetailsPageLogic.detailsId,
        global: false,
        init: logic,
        builder: (_) {
          if (state.galleryDetails == null) {
            return const SizedBox();
          }

          bool disableButtons = state.galleryDetails!.comments.any((comment) => comment.fromMe);

          return Column(
            children: [
              SizedBox(
                height: UIConfig.detailsPageCommentIndicatorHeight,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => toRoute(Routes.comment, arguments: state.galleryDetails!.comments),
                    child: Text(state.galleryDetails!.comments.isEmpty ? 'noComments'.tr : 'allComments'.tr),
                  ),
                ),
              ),
              if (state.galleryDetails!.comments.isNotEmpty)
                GestureDetector(
                  onTap: () => toRoute(Routes.comment, arguments: state.galleryDetails!.comments),
                  child: SizedBox(
                    height: UIConfig.detailsPageCommentsRegionHeight,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      itemExtent: UIConfig.detailsPageCommentsWidth,
                      children: state.galleryDetails!.comments
                          .map(
                            (comment) => EHComment(comment: comment, inDetailPage: true, disableButtons: disableButtons),
                          )
                          .toList(),
                    ),
                  ),
                ),
            ],
          ).fadeIn().marginSymmetric(horizontal: UIConfig.detailPagePadding);
        },
      ),
    );
  }

  Widget buildThumbnails() {
    return GetBuilder<DetailsPageLogic>(
      id: DetailsPageLogic.detailsId,
      global: false,
      init: logic,
      builder: (_) => GetBuilder<DetailsPageLogic>(
        id: DetailsPageLogic.thumbnailsId,
        global: false,
        init: logic,
        builder: (_) => SliverPadding(
          padding: const EdgeInsets.only(top: 36, left: UIConfig.detailPagePadding, right: UIConfig.detailPagePadding),
          sliver: state.galleryDetails == null
              ? const SliverToBoxAdapter()
              : SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == state.galleryDetails!.thumbnails.length - 1 && state.loadingThumbnailsState == LoadingState.idle) {
                        SchedulerBinding.instance.addPostFrameCallback((_) {
                          logic.loadMoreThumbnails();
                        });
                      }

                      GalleryImage? downloadedImage = logic.galleryDownloadService.galleryDownloadInfos[state.galleryUrl.gid]?.images[index];

                      return KeepAliveWrapper(
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: GestureDetector(
                                  onTap: () => logic.goToReadPage(index),
                                  child: LayoutBuilder(
                                    builder: (_, constraints) => downloadedImage?.downloadStatus == DownloadStatus.downloaded
                                        ? EHImage(
                                            galleryImage: downloadedImage!,
                                            containerHeight: constraints.maxHeight,
                                            containerWidth: constraints.maxWidth,
                                            borderRadius: BorderRadius.circular(8),
                                            maxBytes: 1024 * 1024,
                                          )
                                        : EHThumbnail(
                                            thumbnail: state.galleryDetails!.thumbnails[index],
                                            containerHeight: constraints.maxHeight,
                                            containerWidth: constraints.maxWidth,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text((index + 1).toString(), style: TextStyle(color: UIConfig.detailsPageThumbnailIndexColor(context))),
                          ],
                        ),
                      );
                    },
                    childCount: state.galleryDetails?.thumbnails.length ?? 0,
                  ),
                  gridDelegate: StyleSetting.crossAxisCountInDetailPage.value == null
                      ? const SliverGridDelegateWithMaxCrossAxisExtent(
                          mainAxisExtent: UIConfig.detailsPageThumbnailHeight,
                          maxCrossAxisExtent: UIConfig.detailsPageThumbnailWidth,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 5,
                        )
                      : SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: StyleSetting.crossAxisCountInDetailPage.value!,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 5,
                          childAspectRatio: UIConfig.detailsPageGridViewCardAspectRatio,
                        ),
                ),
        ),
      ),
    );
  }

  Widget buildLoadingThumbnailIndicator(BuildContext context) {
    return SliverToBoxAdapter(
      child: GetBuilder<DetailsPageLogic>(
        id: DetailsPageLogic.detailsId,
        global: false,
        init: logic,
        builder: (_) {
          if (state.galleryDetails == null) {
            return const SizedBox();
          }

          return GetBuilder<DetailsPageLogic>(
            id: DetailsPageLogic.loadingThumbnailsStateId,
            global: false,
            init: logic,
            builder: (_) => LoadingStateIndicator(
              loadingState: state.loadingThumbnailsState,
              errorTapCallback: logic.loadMoreThumbnails,
            ),
          ).marginOnly(bottom: 200, top: 20);
        },
      ),
    );
  }
}
