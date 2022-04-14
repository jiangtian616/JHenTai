import 'dart:convert';

import 'package:jhentai/src/model/gallery_image.dart';

/// progress of gallery download
class GalleryDownloadProgress {
  DownloadStatus downloadStatus;

  /// total images count
  int totalCount;

  /// downloaded images count
  late int curCount;

  late List<bool> hasDownloaded;

  GalleryDownloadProgress({
    this.downloadStatus = DownloadStatus.downloading,
    required this.totalCount,
    List<bool>? hasDownloaded,
  }) {
    this.hasDownloaded = hasDownloaded ?? List.generate(totalCount, (index) => false);
    this.curCount = hasDownloaded?.where((e) => e == true).length ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      "downloadStatus": downloadStatus.index,
      "totalCount": totalCount,
      "curCount": curCount,
      "hasDownloaded": jsonEncode(hasDownloaded),
    };
  }

  factory GalleryDownloadProgress.fromJson(Map<String, dynamic> json) {
    return GalleryDownloadProgress(
      downloadStatus: DownloadStatus.values[json["downloadStatus"]],
      totalCount: json["totalCount"],
      hasDownloaded: (jsonDecode(json["hasDownloaded"]) as List).cast<bool>(),
    );
  }
//
}
