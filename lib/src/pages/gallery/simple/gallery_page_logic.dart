import '../../base/base_page_logic.dart';
import 'gallery_page_state.dart';

class GalleryPageLogic extends BasePageLogic {
  @override
  bool get useSearchConfig => true;

  @override
  final GalleryPageState state = GalleryPageState();
}
