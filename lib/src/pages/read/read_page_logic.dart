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
      state.thumbnails = List.generate(
        state.pageCount,
        (index) => Rxn(null),
        growable: true,
      );
    } else {
      List<GalleryThumbnail> parsedThumbnails = Get.arguments as List<GalleryThumbnail>;
      state.thumbnails = List.generate(
        state.pageCount,
        (index) => index < parsedThumbnails.length ? Rxn(parsedThumbnails[index]) : Rxn(null),
        growable: true,
      );
    }

    state.images = List.generate(state.pageCount, (index) => Rxn(null));
    state.imageParsingStates = List.generate(state.pageCount, (index) => LoadingState.idle.obs);
  }

  Future<void> beginParseThumbnails(int index) async {
    if (state.thumbnailsParsingState.value == LoadingState.loading) {
      return;
    }
    Log.info('begin to load Thumbnails from $index');

    state.thumbnailsParsingState.value = LoadingState.loading;

    List<GalleryThumbnail> newThumbnails;
    try {
      newThumbnails = await EHRequest.getGalleryDetailsThumbnailByPageNo(
        galleryUrl: state.galleryUrl,
        thumbnailsPageNo: index ~/ 40,
      );
    } on DioError catch (e) {
      Log.error('get thumbnails error!', e);
      state.thumbnailsParsingState.value = LoadingState.error;
      return;
    }

    for (int i = 0; i < newThumbnails.length; i++) {
      state.thumbnails[index + i].value = newThumbnails[i];
    }
    state.thumbnailsParsingState.value = LoadingState.success;
    return;
  }

  Future<void> beginParseGalleryImage(int index) async {
    if (state.imageParsingStates[index].value == LoadingState.loading) {
      return;
    }

    state.imageParsingStates[index].value = LoadingState.loading;

    EHRequest.getGalleryImage(state.thumbnails[index].value!.href).then((image) {
      state.images[index].value = image;
      state.imageParsingStates[index].value = LoadingState.success;
    }).catchError((error) {
      Log.error('parse gallery image failed, index: ${index.toString()}', error);
      state.imageParsingStates[index].value = LoadingState.error;
    });
    // GalleryImage galleryImage = await EHRequest.getGalleryImage(state.thumbnails[index]!.href);
    // state.images[index] = galleryImage;
    // update([index]);
  }
}
