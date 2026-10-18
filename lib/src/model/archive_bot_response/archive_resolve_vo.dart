class ArchiveResolveVO {
  String url;

  ArchiveResolveVO({required this.url});

  factory ArchiveResolveVO.fromEhArBotResponse(Map<String, dynamic> json) {
    return ArchiveResolveVO(
      url: json['archive_url'],
    );
  }

  factory ArchiveResolveVO.fromArchiveAtHomeResponse(Map<String, dynamic> json) {
    return ArchiveResolveVO(
      url: json['archive_url'],
    );
  }
}
