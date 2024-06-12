import 'package:jhentai/src/database/database.dart';

class DownloadSearchState {
  DownloadSearchConfigTypeEnum searchType = DownloadSearchConfigTypeEnum.simple;

  List<GalleryDownloadedData> gallerys = [];
  List<ArchiveDownloadedData> archives = [];
}

enum DownloadSearchConfigTypeEnum {
  simple(1, 'simpleSearch'),
  regex(2, 'regexSearch'),
  ;

  final int code;
  final String desc;

  const DownloadSearchConfigTypeEnum(this.code, this.desc);
  
  static DownloadSearchConfigTypeEnum fromCode(int code) {
    return DownloadSearchConfigTypeEnum.values.firstWhere((e) => e.code == code);
  }
}
