import '../../base/base_page_logic.dart';
import 'gallerys_page_state.dart';

class GallerysPageLogic extends BasePageLogic {
  @override
  bool get useSearchConfig => true;

  @override
  final GallerysPageState state = GallerysPageState();
}
