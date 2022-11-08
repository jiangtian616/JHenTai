class GalleryHHArchive {
  /// 1280x、Original
  final String resolutionDesc;

  /// 1280、org
  final String? resolution;

  final String size;

  final String cost;

  const GalleryHHArchive({
    required this.resolutionDesc,
    this.resolution,
    required this.size,
    required this.cost,
  });
}
