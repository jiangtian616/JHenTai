class GalleryTorrent {
  String title;
  String postTime;
  String size;
  int seeds;
  int peers;
  int downloads;
  String uploader;
  String torrentUrl;
  String magnetUrl;
  bool outdated;

  GalleryTorrent({
    required this.title,
    required this.postTime,
    required this.size,
    required this.seeds,
    required this.peers,
    required this.downloads,
    required this.uploader,
    required this.torrentUrl,
    required this.magnetUrl,
    required this.outdated,
  });
}
