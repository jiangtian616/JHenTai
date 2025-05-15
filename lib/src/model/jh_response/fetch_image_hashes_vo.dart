class FetchImageHashesVO {
  List<String> hashes;

  FetchImageHashesVO({required this.hashes});

  factory FetchImageHashesVO.fromResponse(Map<String, dynamic> json) {
    return FetchImageHashesVO(
      hashes: (json["hashes"] as List).cast<String>(),
    );
  }
}
