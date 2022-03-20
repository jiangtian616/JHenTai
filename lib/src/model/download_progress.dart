import 'package:jhentai/src/model/gallery_image.dart';

/// progress of gallery download
class DownloadProgress {
  DownloadStatus downloadStatus;

  /// total images count
  int totalCount;

  /// downloaded images count
  int curCount;

  List<bool> hasDownloaded;

  DownloadProgress({
    this.downloadStatus = DownloadStatus.downloading,
    required this.totalCount,
    this.curCount = 0,
  }) : hasDownloaded = List.generate(totalCount, (index) => false);
}
