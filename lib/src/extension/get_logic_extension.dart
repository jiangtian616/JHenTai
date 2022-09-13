import 'package:get/get.dart';

extension GetLogicExtension on GetxController {
  void updateSafely([List<Object>? ids, bool condition = true]) {
    update(ids, condition && !isClosed);
  }
}
