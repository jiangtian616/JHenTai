import 'package:jhentai/src/model/gallery_image.dart';

/// progress of gallery download
class DownloadProgress {
  DownloadStatus downloadStatus;

  /// total images count
  int totalCount;

  /// downloaded images count
  int curCount;

  List<bool> hasDownloaded;

  /// download speed
  String speed;

  DownloadProgress({
    this.downloadStatus = DownloadStatus.downloading,
    required this.totalCount,
    required this.curCount,
    required this.speed,
  }) : hasDownloaded = List.generate(totalCount, (index) => false);

  @override
  String toString() {
    return 'DownloadProgress{downloadStatus: $downloadStatus, totalCount: $totalCount, curCount: $curCount, speed: $speed}';
  }

  Map<String, dynamic> toMap() {
    return {
      'downloadStatus': downloadStatus.index,
      'totalCount': totalCount,
      'curCount': curCount,
      'speed': speed,
    };
  }

  factory DownloadProgress.fromMap(Map<String, dynamic> map) {
    return DownloadProgress(
      downloadStatus: DownloadStatus.values[map['downloadStatus']],
      totalCount: map['totalCount'] as int,
      curCount: map['curCount'] as int,
      speed: map['speed'] as String,
    );
  }
}
