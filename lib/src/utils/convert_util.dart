import 'package:collection/collection.dart';

import '../model/gallery_tag.dart';

String tagMap2TagString(Map<String, List<GalleryTag>> tagMap) {
  return tagMap.values.flattened.map((galleryTag) => galleryTag.tagData).map((tagData) => '${tagData.namespace}: ${tagData.key}').join(',');
}
