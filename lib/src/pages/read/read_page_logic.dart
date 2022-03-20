import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/download_service.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../database/database.dart';
import 'read_page_state.dart';

class ReadPageLogic extends GetxController {
  final ReadPageState state = ReadPageState();
  final DownloadService downloadService = Get.find();

  @override
  void onInit() {
    state.type = Get.parameters['type']!;
    state.gid = int.parse(Get.parameters['gid']!);
    state.initialIndex = int.parse(Get.parameters['initialIndex']!);
    state.pageCount = int.parse(Get.parameters['pageCount']!);
    state.galleryUrl = Get.parameters['galleryUrl']!;


    if (state.type == 'local') {
      GalleryDownloadedData gallery = Get.arguments as GalleryDownloadedData;
      state.thumbnails = downloadService.gid2ImageHrefs[gallery.gid]!;
      state.images = downloadService.gid2Images[gallery.gid]!;
    } else if (state.type == 'online') {
      if (Get.arguments == null) {
        state.thumbnails = List.generate(state.pageCount, (index) => Rxn(null), growable: true);
      } else {
        List<GalleryThumbnail> parsedThumbnails = Get.arguments as List<GalleryThumbnail>;
        state.thumbnails = List.generate(
          state.pageCount,
          (index) => index < parsedThumbnails.length ? Rxn(parsedThumbnails[index]) : Rxn(null),
          growable: true,
        );
      }
      state.images = List.generate(state.pageCount, (index) => Rxn(null));
      state.imageUrlParsingStates = List.generate(state.pageCount, (index) => LoadingState.idle.obs);
    }
  }

  Future<void> beginParsingImageHref(int index) async {
    if (state.imageHrefParsingState.value == LoadingState.loading) {
      return;
    }
    Log.info('begin to load Thumbnails from $index', false);

    state.imageHrefParsingState.value = LoadingState.loading;

    List<GalleryThumbnail> newThumbnails;
    try {
      newThumbnails = await EHRequest.getGalleryDetailsThumbnailByPageNo(
        galleryUrl: state.galleryUrl,
        thumbnailsPageNo: index ~/ 40,
      );
    } on DioError catch (e) {
      Log.error('get thumbnails error!', e);
      state.imageHrefParsingState.value = LoadingState.error;
      return;
    }

    for (int i = 0; i < newThumbnails.length; i++) {
      state.thumbnails[index + i].value = newThumbnails[i];
    }
    state.imageHrefParsingState.value = LoadingState.success;
    return;
  }

  Future<void> beginParsingImageUrl(int index) async {
    if (state.imageUrlParsingStates![index].value == LoadingState.loading) {
      return;
    }

    state.imageUrlParsingStates![index].value = LoadingState.loading;

    EHRequest.getGalleryImage(state.thumbnails[index].value!.href).then((image) {
      state.images[index].value = image;
      state.imageUrlParsingStates![index].value = LoadingState.success;
    }).catchError((error) {
      Log.error('parse gallery image failed, index: ${index.toString()}', error);
      state.imageUrlParsingStates![index].value = LoadingState.error;
    });
  }
}
