import 'package:get/get.dart';

class GalleryCount {
  final String? count;
  final GalleryCountType type;

  const GalleryCount({this.count, required this.type});

  String toPrintString() {
    switch (type) {
      case GalleryCountType.accurate:
        return 'accurateCountTemplate'.trArgs([count!]);
      case GalleryCountType.hundreds:
        return 'hundredsOfCountTemplate'.tr;
      case GalleryCountType.thousands:
        return 'thousandsOfCountTemplate'.tr;
    }
  }

  @override
  String toString() {
    return 'GalleryCount{count: $count, type: $type}';
  }
}

enum GalleryCountType {
  /// 1,465,200
  /// about 232,805
  /// 50,000+
  accurate,

  /// hundreds of
  hundreds,

  /// thousands of
  thousands,
  ;
}
