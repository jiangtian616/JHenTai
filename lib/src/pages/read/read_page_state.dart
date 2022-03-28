import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ReadPageState {
  /// local / online
  late String type;

  late int initialIndex;
  late int pageCount;
  late int readIndexRecord;

  late int gid;
  late String galleryUrl;
  late List<Rxn<GalleryThumbnail>> thumbnails;
  late Rx<LoadingState> imageHrefParsingState = LoadingState.idle.obs;
  late List<Rxn<GalleryImage>> images;
  List<Rx<LoadingState>>? imageUrlParsingStates;

  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
}
