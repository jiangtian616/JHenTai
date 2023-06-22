import 'package:jhentai/src/setting/read_setting.dart';
import 'package:photo_view/photo_view.dart';

class HorizontalDoubleColumnLayoutState {
  late final List<PhotoViewController> photoViewControllers;

  bool displayFirstPageAlone = ReadSetting.displayFirstPageAlone.value;
}
