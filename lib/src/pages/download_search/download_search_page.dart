import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/pages/download_search/download_search_state.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/widget/eh_image.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../../config/ui_config.dart';
import '../../model/gallery_image.dart';
import '../../model/gallery_url.dart';
import '../../routes/routes.dart';
import '../../service/gallery_download_service.dart';
import '../../service/super_resolution_service.dart';
import '../../utils/byte_util.dart';
import '../../utils/date_util.dart';
import '../../utils/route_util.dart';
import '../../widget/eh_gallery_category_tag.dart';
import '../details/details_page_logic.dart';
import 'download_search_logic.dart';

class DownloadSearchPage extends StatelessWidget {
  DownloadSearchPage({Key? key}) : super(key: key);

  final DownloadSearchLogic logic = Get.put(DownloadSearchLogic());
  final DownloadSearchState state = Get.find<DownloadSearchLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('search'.tr)),
      body: Column(
        children: [
          _buildSearchField(),
          const SizedBox(height: 10),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return GetBuilder<DownloadSearchLogic>(
      id: logic.searchFieldId,
      builder: (_) => TextField(
        controller: logic.textEditingController,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        focusNode: logic.searchFocusNode,
        onTapOutside: (_) => logic.searchFocusNode.unfocus(),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          prefixIcon: FutureBuilder(
            future: state.searchTypeCompleter.future,
            builder: (_, __) => !state.searchTypeCompleter.isCompleted
                ? const SizedBox()
                : TextButton(child: Text(state.searchType.desc.tr), onPressed: logic.toggleSearchType),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 52),
          suffixIcon: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(child: const Icon(Icons.cancel), onTap: logic.handleTapClearButton),
          ),
        ),
        onChanged: logic.handleSearchFieldChanged,
      ),
    );
  }

  Widget _buildBody() {
    return GetBuilder<DownloadSearchLogic>(
      id: logic.bodyId,
      builder: (_) => EHWheelSpeedController(
        controller: logic.scrollController,
        child: CustomScrollView(
          controller: logic.scrollController,
          scrollBehavior: UIConfig.scrollBehaviourWithScrollBarWithMouse,
          slivers: [
            SliverList.separated(
              itemBuilder: (context, index) => _buildGallery(context, state.gallerys[index]),
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemCount: state.gallerys.length,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverList.separated(
              itemBuilder: (context, index) => _buildArchive(context, state.archives[index]),
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemCount: state.archives.length,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildGallery(BuildContext context, GallerySearchVO gallery) {
    return SizedBox(
      height: 160,
      child: GetBuilder<GalleryDownloadService>(
        id: '${galleryDownloadService.galleryDownloadProgressId}::${gallery.gid}',
        builder: (_) {
          GalleryImage? cover = galleryDownloadService.galleryDownloadInfos[gallery.gid]?.images[0];
          GalleryDownloadProgress? downloadProgress = galleryDownloadService.galleryDownloadInfos[gallery.gid]?.downloadProgress;
          String? groupName = galleryDownloadService.galleryDownloadInfos[gallery.gid]?.group;

          return Row(
            children: [
              _buildGalleryCover(gallery, context),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => logic.goToGalleryReadPage(gallery),
                  onLongPress: () => logic.onLongPressGallery(context, gallery),
                  onSecondaryTap: () => logic.onLongPressGallery(context, gallery),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGalleryTitle(gallery),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildGalleryUploader(gallery, context),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Expanded(child: buildTags(context, gallery.tags)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          EHGalleryCategoryTag(category: gallery.category),
                          const Expanded(child: SizedBox()),
                          _buildGalleryIsOriginal(context, gallery),
                          const SizedBox(width: 6),
                          _buildGallerySuperResolutionLabel(context, gallery),
                          const SizedBox(width: 6),
                          _buildGalleryPublishTime(gallery, context),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SizedBox(width: 2),
                          _buildGalleryGroup(groupName, context),
                          const Expanded(child: SizedBox()),
                          _buildGalleryDownloadProgressText(downloadProgress, context),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _buildGalleryDownloadProgressIndicator(downloadProgress, context),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ).paddingOnly(left: 4, right: 16);
  }

  Text _buildGalleryPublishTime(GallerySearchVO gallery, BuildContext context) {
    return Text(
      DateUtil.transformUtc2LocalTimeString(gallery.publishTime),
      style: TextStyle(
        fontSize: UIConfig.galleryCardTextSize,
        color: UIConfig.galleryCardTextColor(context),
      ),
    );
  }

  Widget _buildGalleryCover(GallerySearchVO gallery, BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => toRoute(
        Routes.details,
        arguments: DetailsPageArgument(galleryUrl: GalleryUrl.parse(gallery.galleryUrl)),
      ),
      child: GetBuilder<GalleryDownloadService>(
        id: '${galleryDownloadService.downloadImageUrlId}::${gallery.gid}::0',
        builder: (_) {
          GalleryImage? image = galleryDownloadService.galleryDownloadInfos[gallery.gid]?.images[0];

          /// cover is the first image, if we haven't downloaded first image, then return a [UIConfig.loadingAnimation]
          if (image?.downloadStatus != DownloadStatus.downloaded) {
            return SizedBox(
              width: UIConfig.downloadSearchPageCoverWidth,
              height: UIConfig.downloadSearchPageCoverHeight,
              child: Center(child: UIConfig.loadingAnimation(context)),
            );
          }

          return EHImage(
            galleryImage: image!,
            containerWidth: UIConfig.downloadSearchPageCoverWidth,
            containerHeight: UIConfig.downloadSearchPageCoverHeight,
            containerColor: UIConfig.galleryCardBackGroundColor(context),
            borderRadius: BorderRadius.circular(UIConfig.downloadPageCardBorderRadius),
            fit: BoxFit.fitWidth,
            maxBytes: 2 * 1024 * 1024,
          );
        },
      ),
    );
  }

  Widget _buildGalleryTitle(GallerySearchVO gallery) {
    return Text(
      gallery.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: UIConfig.galleryCardTitleSize, height: 1.2),
    );
  }

  Widget _buildGalleryUploader(GallerySearchVO gallery, BuildContext context) {
    if (gallery.uploader == null) {
      return const SizedBox();
    }

    return Text(
      gallery.uploader!,
      style: TextStyle(fontSize: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor(context)),
    );
  }

  Widget buildTags(BuildContext context, List<TagData> tags) {
    return Center(
      child: SizedBox(
        height: 44,
        child: WaterfallFlow.builder(
          scrollDirection: Axis.horizontal,
          gridDelegate: const SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: tags.length,
          itemBuilder: (_, int index) => Container(
            decoration: BoxDecoration(
              color: UIConfig.ehTagBackGroundColor(context),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            child: Text(
              tags[index].tagName ?? tags[index].key,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, height: 1, color: UIConfig.ehTagTextColor(context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryIsOriginal(BuildContext context, GallerySearchVO gallery) {
    bool isOriginal = gallery.downloadOriginalImage;
    if (!isOriginal) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: UIConfig.resumePauseButtonColor(context)),
      ),
      child: Text(
        'original'.tr,
        style: TextStyle(color: UIConfig.resumePauseButtonColor(context), fontWeight: FontWeight.bold, fontSize: 9),
      ),
    );
  }

  Widget _buildGallerySuperResolutionLabel(BuildContext context, GallerySearchVO gallery) {
    return GetBuilder<SuperResolutionService>(
      id: '${SuperResolutionService.superResolutionId}::${gallery.gid}',
      builder: (_) {
        SuperResolutionInfo? superResolutionInfo = superResolutionService.get(gallery.gid, SuperResolutionType.gallery);

        if (superResolutionInfo == null) {
          return const SizedBox();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: superResolutionInfo.status == SuperResolutionStatus.success ? null : BorderRadius.circular(4),
            border: Border.all(color: UIConfig.resumePauseButtonColor(context)),
            shape: superResolutionInfo.status == SuperResolutionStatus.success ? BoxShape.circle : BoxShape.rectangle,
          ),
          child: Text(
            superResolutionInfo.status == SuperResolutionStatus.paused
                ? 'AI'
                : superResolutionInfo.status == SuperResolutionStatus.success
                    ? 'AI'
                    : 'AI(${superResolutionInfo.imageStatuses.fold<int>(0, (previousValue, element) => previousValue + (element == SuperResolutionStatus.success ? 1 : 0))}/${superResolutionInfo.imageStatuses.length})',
            style: TextStyle(
              fontSize: 9,
              color: UIConfig.resumePauseButtonColor(context),
              decoration: superResolutionInfo.status == SuperResolutionStatus.paused ? TextDecoration.lineThrough : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGalleryDownloadProgressText(GalleryDownloadProgress? downloadProgress, BuildContext context) {
    if (downloadProgress == null) {
      return const SizedBox();
    }

    return Text(
      '${downloadProgress.curCount}/${downloadProgress.totalCount}',
      style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor(context)),
    );
  }

  Widget _buildGalleryDownloadProgressIndicator(GalleryDownloadProgress? downloadProgress, BuildContext context) {
    if (downloadProgress == null || downloadProgress.downloadStatus == DownloadStatus.downloaded) {
      return const SizedBox();
    }

    return SizedBox(
      height: UIConfig.downloadPageProgressIndicatorHeight,
      child: LinearProgressIndicator(
        value: downloadProgress.curCount / downloadProgress.totalCount,
        color: UIConfig.downloadPageProgressIndicatorColor(context),
      ),
    );
  }

  Widget _buildGalleryGroup(String? groupName, BuildContext context) {
    return Text(
      '${'gallery'.tr} > $groupName',
      style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor(context)),
    );
  }

  Widget _buildArchive(BuildContext context, ArchiveSearchVO archive) {
    return SizedBox(
      height: 160,
      child: GetBuilder<ArchiveDownloadService>(
        id: '${ArchiveDownloadService.archiveStatusId}::${archive.gid}',
        builder: (_) {
          ArchiveDownloadInfo? archiveDownloadInfo = archiveDownloadService.archiveDownloadInfos[archive.gid];
          String? groupName = archiveDownloadInfo?.group;

          return Row(
            children: [
              _buildArchiveCover(archive, context),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => logic.goToArchiveReadPage(archive),
                  onLongPress: () => logic.onLongPressArchive(context, archive),
                  onSecondaryTap: () => logic.onLongPressArchive(context, archive),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildArchiveTitle(archive),
                      _buildArchiveUploader(archive, context),
                      Expanded(child: buildTags(context, archive.tags)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          EHGalleryCategoryTag(category: archive.category),
                          const Expanded(child: SizedBox()),
                          _buildArchiveIsOriginal(context, archive),
                          const SizedBox(width: 6),
                          _buildArchiveSuperResolutionLabel(context, archive),
                          const SizedBox(width: 6),
                          _buildArchivePublishTime(context, archive),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SizedBox(width: 2),
                          _buildArchiveGroup(groupName, context),
                          const Expanded(child: SizedBox()),
                          _buildArchiveDownloadProgressText(archive, archiveDownloadInfo, context),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _buildArchiveDownloadProgressIndicator(archive, archiveDownloadInfo, context),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ).paddingOnly(left: 4, right: 16);
  }

  Widget _buildArchiveCover(ArchiveSearchVO archive, BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => toRoute(
        Routes.details,
        arguments: DetailsPageArgument(galleryUrl: GalleryUrl.parse(archive.galleryUrl)),
      ),
      child: EHImage(
        galleryImage: GalleryImage(url: archive.coverUrl),
        containerWidth: UIConfig.downloadSearchPageCoverWidth,
        containerHeight: UIConfig.downloadSearchPageCoverHeight,
        containerColor: UIConfig.galleryCardBackGroundColor(context),
        borderRadius: BorderRadius.circular(UIConfig.downloadPageCardBorderRadius),
        fit: BoxFit.fitWidth,
        maxBytes: 2 * 1024 * 1024,
      ),
    );
  }

  Widget _buildArchiveTitle(ArchiveSearchVO archive) {
    return Text(
      archive.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: UIConfig.galleryCardTitleSize, height: 1.2),
    );
  }

  Widget _buildArchiveUploader(ArchiveSearchVO archive, BuildContext context) {
    if (archive.uploader == null) {
      return const SizedBox();
    }

    return Text(
      archive.uploader!,
      style: TextStyle(fontSize: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor(context)),
    );
  }

  Widget _buildArchiveIsOriginal(BuildContext context, ArchiveSearchVO archive) {
    bool isOriginal = archive.isOriginal;
    if (!isOriginal) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: UIConfig.resumePauseButtonColor(context)),
      ),
      child: Text(
        'original'.tr,
        style: TextStyle(color: UIConfig.resumePauseButtonColor(context), fontWeight: FontWeight.bold, fontSize: 9),
      ),
    );
  }

  Widget _buildArchiveSuperResolutionLabel(BuildContext context, ArchiveSearchVO archive) {
    return GetBuilder<SuperResolutionService>(
      id: '${SuperResolutionService.superResolutionId}::${archive.gid}',
      builder: (_) {
        SuperResolutionInfo? superResolutionInfo = superResolutionService.get(archive.gid, SuperResolutionType.archive);

        if (superResolutionInfo == null) {
          return const SizedBox();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: superResolutionInfo.status == SuperResolutionStatus.success ? null : BorderRadius.circular(4),
            border: Border.all(color: UIConfig.resumePauseButtonColor(context)),
            shape: superResolutionInfo.status == SuperResolutionStatus.success ? BoxShape.circle : BoxShape.rectangle,
          ),
          child: Text(
            superResolutionInfo.status == SuperResolutionStatus.paused
                ? 'AI'
                : superResolutionInfo.status == SuperResolutionStatus.success
                    ? 'AI'
                    : 'AI(${superResolutionInfo.imageStatuses.fold<int>(0, (previousValue, element) => previousValue + (element == SuperResolutionStatus.success ? 1 : 0))}/${superResolutionInfo.imageStatuses.length})',
            style: TextStyle(
              fontSize: 9,
              color: UIConfig.resumePauseButtonColor(context),
              decoration: superResolutionInfo.status == SuperResolutionStatus.paused ? TextDecoration.lineThrough : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildArchivePublishTime(BuildContext context, ArchiveSearchVO archive) {
    return Text(
      DateUtil.transformUtc2LocalTimeString(archive.publishTime),
      style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor(context)),
    );
  }

  Widget _buildArchiveGroup(String? groupName, BuildContext context) {
    return Text(
      '${'archive'.tr} > $groupName',
      style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor(context)),
    );
  }

  Widget _buildArchiveDownloadProgressText(ArchiveSearchVO archive, ArchiveDownloadInfo? archiveDownloadInfo, BuildContext context) {
    if (archiveDownloadInfo == null || archiveDownloadInfo.archiveStatus.code > ArchiveStatus.downloading.code) {
      return const SizedBox();
    }

    return GetBuilder<ArchiveDownloadService>(
      id: '${ArchiveDownloadService.archiveSpeedComputerId}::${archive.gid}::${archive.isOriginal}',
      builder: (_) => Text(
        '${byte2String(archiveDownloadInfo.speedComputer.downloadedBytes.toDouble())}/${byte2String(archiveDownloadInfo.size.toDouble())}',
        style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor(context)),
      ),
    );
  }

  Widget _buildArchiveDownloadProgressIndicator(ArchiveSearchVO archive, ArchiveDownloadInfo? archiveDownloadInfo, BuildContext context) {
    if (archiveDownloadInfo == null || archiveDownloadInfo.archiveStatus.code > ArchiveStatus.downloading.code) {
      return const SizedBox();
    }

    return SizedBox(
      height: UIConfig.downloadPageProgressIndicatorHeight,
      child: GetBuilder<ArchiveDownloadService>(
        id: '${ArchiveDownloadService.archiveSpeedComputerId}::${archive.gid}::${archive.isOriginal}',
        builder: (_) => LinearProgressIndicator(
          value: archiveDownloadInfo.speedComputer.downloadedBytes / archiveDownloadInfo.size,
          color: archiveDownloadInfo.archiveStatus.code <= ArchiveStatus.paused.code
              ? UIConfig.downloadPageProgressPausedIndicatorColor(context)
              : UIConfig.downloadPageProgressIndicatorColor(context),
        ),
      ),
    );
  }
}
