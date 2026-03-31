import 'dart:collection';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/gallery_tag.dart';

import 'jh_service.dart';

NHentaiTagIdService nhentaiTagIdService = NHentaiTagIdService();

class NHentaiTagIdService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  static const String _assetPath = 'assets/nhentai/tags.json';

  final Map<int, _NHentaiTagRecord> _recordsById = <int, _NHentaiTagRecord>{};

  @override
  Future<void> doInitBean() async {
    String jsonString = await rootBundle.loadString(_assetPath);
    dynamic decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      return;
    }

    _recordsById.clear();
    for (dynamic row in decoded) {
      if (row is! List || row.length < 4) {
        continue;
      }

      int? id = row[0] is int ? row[0] as int : int.tryParse(row[0].toString());
      String? name = row[1]?.toString();
      int? typeCode = row[3] is int ? row[3] as int : int.tryParse(row[3].toString());
      if (id == null || name == null || name.isEmpty || typeCode == null) {
        continue;
      }

      String? namespace = _typeCodeToNamespace(typeCode);
      if (namespace == null) {
        continue;
      }

      _recordsById[id] = _NHentaiTagRecord(
        id: id,
        namespace: namespace,
        key: name,
      );
    }
  }

  @override
  Future<void> doAfterBeanReady() async {}

  LinkedHashMap<String, List<GalleryTag>> mapTagIds(List<int> tagIds) {
    LinkedHashMap<String, List<GalleryTag>> result = LinkedHashMap();

    for (int id in tagIds) {
      _NHentaiTagRecord? record = _recordsById[id];
      if (record == null) {
        continue;
      }

      result.putIfAbsent(record.namespace, () => <GalleryTag>[]).add(
            GalleryTag(
              tagData: TagData(namespace: record.namespace, key: record.key),
            ),
          );
    }

    return result;
  }

  String? _typeCodeToNamespace(int typeCode) {
    switch (typeCode) {
      case 1:
        return 'parody';
      case 2:
        return 'character';
      case 3:
        return 'tag';
      case 4:
        return 'artist';
      case 5:
        return 'group';
      case 6:
        return 'language';
      case 7:
        return 'category';
      default:
        return null;
    }
  }
}

class _NHentaiTagRecord {
  final int id;
  final String namespace;
  final String key;

  const _NHentaiTagRecord({
    required this.id,
    required this.namespace,
    required this.key,
  });
}
