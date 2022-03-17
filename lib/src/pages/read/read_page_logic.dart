import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import 'read_page_state.dart';

class ReadPageLogic extends GetxController {
  final ReadPageState state = ReadPageState();

  @override
  void onInit() {
    state.initialIndex = int.parse(Get.parameters['initialIndex']!);
    state.pageCount = int.parse(Get.parameters['pageCount']!);
    state.galleryUrl = Get.parameters['galleryUrl']!;
    if (Get.arguments == null) {
      state.thumbnails = List.empty(growable: true);
    } else {
      state.thumbnails = List.generate(
          state.pageCount,
          (index) => index < (Get.arguments as List<GalleryThumbnail>).length
              ? (Get.arguments as List<GalleryThumbnail>)[index]
              : null,
          growable: true);
    }

    state.images = List.filled(state.pageCount, null);
    state.imageParsingStates = List.filled(state.pageCount, LoadingState.idle);
  }

  /// step 1: check thumbnail info whether exists, if not, [parse] one page of thumbnails
  /// step 2: [parse] one image's raw data
  /// step 3：use raw data to [load] image
  Future<void> beginParseGalleryImage(int index) async {
    if (state.imageParsingStates[index] == LoadingState.loading || state.imageParsingStates[index] == LoadingState.error) {
      return;
    }

    Log.info('begin to load image $index');

    LoadingState prevState = state.imageParsingStates[index]!;
    state.imageParsingStates[index] = LoadingState.loading;
    if (prevState == LoadingState.error) {
      update([index]);
    }

    EHRequest.getGalleryImage(state.thumbnails[index]!.href).then((image) {
      state.images[index] = image;
      state.imageParsingStates[index] = LoadingState.success;
      update([index]);
    }).catchError((error) {
      Log.shout('parse gallery image failed, index: ${index.toString()}', error);
      state.imageParsingStates[index] = LoadingState.error;
      update([index]);
    });
    // GalleryImage galleryImage = await EHRequest.getGalleryImage(state.thumbnails[index]!.href);
    // state.images[index] = galleryImage;
    // update([index]);
  }

  Future<bool> beginParseThumbnails(int index) async {
    if (state.thumbnailsParsingState == LoadingState.loading) {
      return false;
    }
    Log.info('begin to load Thumbnails begin at $index');

    state.thumbnailsParsingState = LoadingState.loading;
    update(List.generate(40, (index) => index));

    List<GalleryThumbnail> newThumbnails;
    try {
      newThumbnails = await EHRequest.getGalleryDetailsThumbnailByPageNo(
        galleryUrl: state.galleryUrl,
        thumbnailsPageNo: index ~/ 40,
      );
    } on DioError catch (e) {
      Log.shout('get thumbnails while reading error!', e);
      state.thumbnailsParsingState = LoadingState.error;
      update(List.generate(40, (index) => index));
      return false;
    }
    state.thumbnails.addAll(newThumbnails);
    state.thumbnailsParsingState = LoadingState.success;

    update(List.generate(40, (index) => index));
    return true;
  }
}
