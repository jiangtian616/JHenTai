import '../../../network/eh_request.dart';
import '../../../utils/eh_spider_parser.dart';
import '../../../utils/log.dart';
import '../../base/base_page_logic.dart';
import 'gallerys_page_state.dart';

class GallerysPageLogic extends BasePageLogic {
  @override
  final String pageId = 'pageId';
  @override
  final String appBarId = 'appBarId';
  @override
  final String bodyId = 'bodyId';
  @override
  final String refreshStateId = 'refreshStateId';
  @override
  final String loadingStateId = 'loadingStateId';

  @override
  int get tabIndex => 0;

  @override
  bool get useSearchConfig => true;

  @override
  final GallerysPageState state = GallerysPageState();

  @override
  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageNo) async {
    Log.info('get gallery data, pageNo:$pageNo', false);

    List<dynamic> gallerysAndPageInfo = await EHRequest.requestGalleryPage(
      pageNo: pageNo,
      searchConfig: state.searchConfig,
      parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
    );

    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);
    return gallerysAndPageInfo;
  }

  void updateBody() {
    update([bodyId]);
  }
}
