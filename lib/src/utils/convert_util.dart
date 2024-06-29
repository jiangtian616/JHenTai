import 'package:collection/collection.dart';

import '../database/database.dart';
import '../model/gallery_tag.dart';

String tagMap2TagString(Map<String, List<GalleryTag>> tagMap) {
  return tagMap.values.flattened.map((galleryTag) => galleryTag.tagData).map((tagData) => '${tagData.namespace}:${tagData.key}').join(',');
}

List<TagData> tagDataString2TagDataList(String tagDataString) {
  if (tagDataString.isEmpty) {
    return [];
  }
  
  List<String> tagDataList = tagDataString.split(',');
  return tagDataList.map((tagData) {
    List<String> tagDataSplit = tagData.split(':');
    return TagData(namespace: tagDataSplit[0], key: tagDataSplit[1].trim());
  }).toList();
}
