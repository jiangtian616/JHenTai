import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/model/gallery_history_model.dart';
import 'package:jhentai/src/model/gallery_image.dart';

import '../database/database.dart';
import '../model/gallery.dart';
import '../model/gallery_tag.dart';
import '../setting/site_setting.dart';

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

GalleryHistoryModel gallery2GalleryHistoryModel(Gallery gallery) {
  return GalleryHistoryModel(
    galleryUrl: gallery.galleryUrl,
    title: gallery.title,
    category: gallery.category,
    coverUrl: gallery.cover.url,
    pageCount: gallery.pageCount ?? 0,
    rating: gallery.rating,
    language: gallery.language ?? '',
    uploader: gallery.uploader ?? '',
    publishTime: gallery.publishTime,
    isExpunged: gallery.isExpunged,
    tags: gallery.tags.values.flattened.map((tag) => '${tag.tagData.namespace}:${tag.tagData.key}').toList(),
  );
}

Gallery galleryHistoryModel2Gallery(GalleryHistoryModel model) {
  return Gallery(
    galleryUrl: model.galleryUrl,
    title: model.title,
    category: model.category,
    cover: GalleryImage(url: model.coverUrl),
    pageCount: model.pageCount,
    rating: model.rating,
    hasRated: false,
    language: model.language.toLowerCase(),
    uploader: model.uploader,
    publishTime: model.publishTime,
    isExpunged: model.isExpunged,
    tags: LinkedHashMap.from(
      model.tags.map<GalleryTag>((str) {
        List<String> tagDataSplit = str.split(':');
        return GalleryTag(tagData: TagData(namespace: tagDataSplit[0], key: tagDataSplit[1]));
      }).groupListsBy((tag) => tag.tagData.namespace),
    ),
  );
}

GalleryHistoryModel galleryDetail2GalleryHistoryModel(GalleryDetail galleryDetail) {
  return GalleryHistoryModel(
    galleryUrl: galleryDetail.galleryUrl,
    title: SiteSetting.preferJapaneseTitle.isTrue ? (galleryDetail.japaneseTitle ?? galleryDetail.rawTitle) : galleryDetail.rawTitle,
    category: galleryDetail.category,
    coverUrl: galleryDetail.cover.url,
    pageCount: galleryDetail.pageCount,
    rating: galleryDetail.rating,
    language: galleryDetail.language,
    uploader: galleryDetail.uploader ?? '',
    publishTime: galleryDetail.publishTime,
    isExpunged: galleryDetail.isExpunged,
    tags: galleryDetail.tags.values.flattened.map((tag) => '${tag.tagData.namespace}:${tag.tagData.key}').toList(),
  );
}
