class ArchiveResolveVO {
  String url;

  ArchiveResolveVO({required this.url});

  factory ArchiveResolveVO.fromResponse(Map<String, dynamic> json) {
    return ArchiveResolveVO(
      url: json["archive_url"],
    );
  }
}
