import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/gallery_image_page_url.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/gallery_image/gallery_image_page_state.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../config/ui_config.dart';
import '../../exception/eh_site_exception.dart';
import '../../model/gallery_detail.dart';
import '../../model/gallery_tag.dart';
import '../../model/tag_set.dart';
import '../../setting/eh_setting.dart';
import '../../setting/my_tags_setting.dart';
import '../../setting/user_setting.dart';
import '../../service/log.dart';
import '../../utils/snack_util.dart';

class GalleryImagePageArgument {
  final GalleryImagePageUrl galleryImagePageUrl;

  const GalleryImagePageArgument({required this.galleryImagePageUrl});
}

class GalleryImagePageLogic extends GetxController {
  GalleryImagePageState state = GalleryImagePageState();

  final StorageService storageService = Get.find();
  final GalleryDownloadService galleryDownloadService = Get.find();
  final SuperResolutionService superResolutionService = Get.find();
  final TagTranslationService tagTranslationService = Get.find();

  @override
  void onInit() {
    super.onInit();

    if (Get.arguments is! GalleryImagePageArgument) {
      return;
    }

    GalleryImagePageArgument argument = Get.arguments;
    state.galleryImagePageUrl = argument.galleryImagePageUrl;
  }

  @override
  void onReady() async {
    super.onReady();

    getPageInfoAndRedirect();
  }

  Future<void> getPageInfoAndRedirect() async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    state.loadingState = LoadingState.loading;
    updateSafely();

    GalleryUrl galleryUrl;
    try {
      galleryUrl = await EHRequest.requestImagePage<GalleryUrl>(
        state.galleryImagePageUrl.url,
        parser: EHSpiderParser.imagePage2GalleryUrl,
      );
    } on DioException catch (e) {
      log.error('Get gallery image page info Failed', e.errorMsg, e.stackTrace);
      snack('failed'.tr, e.errorMsg ?? '', isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely();
      return;
    } on EHSiteException catch (e) {
      log.error('Get gallery image page info Failed', e.message);
      snack('failed'.tr, e.message, isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely();
      return;
    } catch (e, s) {
      log.error('Get gallery image page info Failed', e, s);
      snack('failed'.tr, e.toString(), isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely();
      return;
    }

    ({GalleryDetail galleryDetails, String apikey}) detailsPageInfo;
    try {
      detailsPageInfo = await _getDetailsWithRedirectAndFallback(galleryUrl: galleryUrl);
      galleryUrl = detailsPageInfo.galleryDetails.galleryUrl;
    } on DioException catch (e) {
      log.error('Get gallery detail failed in image page', e.errorMsg, e.stackTrace);
      snack('getGalleryDetailFailed'.tr, e.errorMsg ?? '', isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely();
      return;
    } on EHSiteException catch (e) {
      log.error('Get gallery detail failed in image page', e.message);
      snack('getGalleryDetailFailed'.tr, e.message, isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely();
      return;
    } catch (e, s) {
      log.error('Get gallery detail failed in image page', e, s);
      snack('getGalleryDetailFailed'.tr, e.toString(), isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely();
      return;
    }

    await tagTranslationService.translateTagsIfNeeded(detailsPageInfo.galleryDetails.tags);

    _addColor2WatchedTags(detailsPageInfo.galleryDetails!.tags);

    if (isClosed) {
      return;
    }

    backRoute(currentRoute: Routes.imagePage);

    await toRoute(
      Routes.details,
      arguments: DetailsPageArgument(
        galleryUrl: galleryUrl,
        detailsPageInfo: detailsPageInfo,
      ),
    );
  }

  Future<({GalleryDetail galleryDetails, String apikey})> _getDetailsWithRedirectAndFallback({required GalleryUrl galleryUrl, bool useCache = true}) async {
    final GalleryUrl? firstLink;
    final GalleryUrl secondLink;

    /// 1. if redirect is enabled, try EH site first for EX link
    /// 2. if a gallery can't be found in EH site, it may be moved into EX site
    if (!galleryUrl.isEH) {
      if (EHSetting.redirect2Eh.isTrue) {
        firstLink = galleryUrl.copyWith(isEH: true);
        secondLink = galleryUrl;
      } else {
        firstLink = null;
        secondLink = galleryUrl;
      }
    } else {
      /// fallback to EX site only if user has logged in
      firstLink = userSetting.hasLoggedIn() ? galleryUrl : null;
      secondLink = userSetting.hasLoggedIn() ? galleryUrl.copyWith(isEH: false) : galleryUrl;
    }

    /// if we can't find gallery via firstLink, try second link
    EHSiteException? firstException;
    if (firstLink != null) {
      log.trace('Try to find gallery via firstLink: $firstLink');
      try {
        ({GalleryDetail galleryDetails, String apikey}) detailPageInfo = await EHRequest.requestDetailPage<({GalleryDetail galleryDetails, String apikey})>(
          galleryUrl: firstLink.url,
          parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
          useCacheIfAvailable: useCache,
        );
        return detailPageInfo;
      } on EHSiteException catch (e) {
        log.trace('Can\'t find gallery, firstLink: $firstLink, reason: ${e.message}');
        firstException = e;
      }
    }

    try {
      log.trace('Try to find gallery via secondLink: $secondLink');
      ({GalleryDetail galleryDetails, String apikey}) detailPageInfo = await EHRequest.requestDetailPage<({GalleryDetail galleryDetails, String apikey})>(
        galleryUrl: secondLink.url,
        parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
        useCacheIfAvailable: useCache,
      );
      return detailPageInfo;
    } on EHSiteException catch (e) {
      log.trace('Can\'t find gallery, secondLink: $secondLink, reason: ${e.message}');
      throw firstException ?? e;
    }
  }

  void _addColor2WatchedTags(LinkedHashMap<String, List<GalleryTag>> fullTags) {
    for (List<GalleryTag> tags in fullTags.values) {
      for (GalleryTag tag in tags) {
        if (tag.color != null || tag.backgroundColor != null) {
          continue;
        }

        ({Color? tagSetBackGroundColor, WatchedTag tag})? tagInfo = MyTagsSetting.getOnlineTagSetByTagData(tag.tagData);
        if (tagInfo == null) {
          continue;
        }

        Color? backGroundColor = tagInfo.tag.backgroundColor ?? tagInfo.tagSetBackGroundColor;
        tag.backgroundColor = backGroundColor ?? UIConfig.ehWatchedTagDefaultBackGroundColor;
        tag.color = backGroundColor == null
            ? const Color(0xFFF1F1F1)
            : ThemeData.estimateBrightnessForColor(backGroundColor) == Brightness.light
                ? const Color.fromRGBO(9, 9, 9, 1)
                : const Color(0xFFF1F1F1);
      }
    }
  }
}
