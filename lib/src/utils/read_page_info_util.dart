import 'package:collection/collection.dart';

import '../database/database.dart';
import '../enum/config_enum.dart';
import '../model/gallery_image.dart';
import '../model/read_page_info.dart';
import '../service/archive_download_service.dart';
import '../service/gallery_download/gallery_download_service.dart';
import '../service/local_config_service.dart';
import '../service/local_gallery_service.dart';
import '../service/read_progress_service.dart';
import '../service/super_resolution_service.dart';
import '../setting/read_setting.dart';
import 'convert_util.dart';

/// Build [ReadPageInfo] for galleries in download page, which can switch to the previous or next gallery in read page.
///
/// [initialIndex] defaults to the read progress recorded before.

Future<ReadPageInfo> buildDownloadedGalleryReadPageInfo(GalleryDownloadInfo gallery, {int? initialIndex}) async {
  initialIndex ??= await readProgressService.getReadProgress(gallery.gid);

  /// Ensure the gallery's image list is resident before entering read
  /// page — ReadPageState's constructor reads [imageAtSync] synchronously
  /// to build the initial snapshot. If images has been evicted (gallery
  /// was fully downloaded), this reloads from DB.
  await gallery.ensureImagesLoaded();

  return ReadPageInfo(
    mode: ReadMode.downloaded,
    gid: gallery.gid,
    token: gallery.token,
    galleryTitle: gallery.title,
    galleryUrl: gallery.galleryUrl,
    initialIndex: initialIndex,
    readProgressRecordStorageKey: gallery.gid.toString(),
    pageCount: gallery.pageCount,
    useSuperResolution: superResolutionService.get(gallery.gid, SuperResolutionType.gallery) != null,
    readDirection: isWebtoonGalleryFromTagString(gallery.tags) ? ReadDirection.top2bottomList : null,
    adjacentGalleryFinder: (bool next) => findAdjacentDownloadedGallery(gallery.gid, next),
  );
}

Future<ReadPageInfo> buildArchiveReadPageInfo(ArchiveDownloadedData archive, {int? initialIndex}) async {
  initialIndex ??= await readProgressService.getReadProgress(archive.gid);

  List<GalleryImage> images = await archiveDownloadService.getUnpackedImages(archive.gid);

  return ReadPageInfo(
    mode: ReadMode.archive,
    gid: archive.gid,
    galleryTitle: archive.title,
    galleryUrl: archive.galleryUrl,
    initialIndex: initialIndex,
    pageCount: images.length,
    isOriginal: archive.isOriginal,
    readProgressRecordStorageKey: archive.gid.toString(),
    images: images,
    useSuperResolution: superResolutionService.get(archive.gid, SuperResolutionType.archive) != null,
    readDirection: isWebtoonGalleryFromTagString(archive.tags) ? ReadDirection.top2bottomList : null,
    adjacentGalleryFinder: (bool next) => findAdjacentArchive(archive.gid, next),
  );
}

Future<ReadPageInfo> buildLocalGalleryReadPageInfo(LocalGallery gallery, {int? initialIndex}) async {
  if (initialIndex == null) {
    String? string = await localConfigService.read(configKey: ConfigEnum.readIndexRecord, subConfigKey: gallery.cover.path!);
    initialIndex = string == null ? 0 : (int.tryParse(string) ?? 0);
  }

  List<GalleryImage> images = localGalleryService.getGalleryImages(gallery);

  return ReadPageInfo(
    mode: ReadMode.local,
    galleryTitle: gallery.title,
    initialIndex: initialIndex,
    pageCount: images.length,
    readProgressRecordStorageKey: gallery.cover.path!,
    images: images,
    useSuperResolution: false,
    adjacentGalleryFinder: (bool next) => findAdjacentLocalGallery(gallery.path, next),
  );
}

/// Galleries are ordered as they are displayed in download page: group by group, and continue with the adjacent group at
/// the first or last gallery of a group.
AdjacentGallery? findAdjacentDownloadedGallery(int gid, bool next) {
  Map<String, List<GalleryDownloadInfo>> group2Galleries = galleryDownloadService.galleries.groupListsBy((gallery) => gallery.group);
  List<GalleryDownloadInfo> galleries = [
    for (String group in galleryDownloadService.allGroups) ...?group2Galleries.remove(group),
    ...group2Galleries.values.flattened,
  ];

  GalleryDownloadInfo? adjacent = _findAdjacent(galleries, (gallery) => gallery.gid == gid, next);
  if (adjacent == null) {
    return null;
  }

  return AdjacentGallery(
    title: adjacent.title,
    loadReadPageInfo: () async {
      GalleryDownloadInfo? gallery = galleryDownloadService.galleryDownloadInfos[adjacent.gid];
      return gallery == null ? null : buildDownloadedGalleryReadPageInfo(gallery, initialIndex: 0);
    },
  );
}

/// Same order as [findAdjacentDownloadedGallery], archives which haven't been unpacked are skipped because they can't be read.
AdjacentGallery? findAdjacentArchive(int gid, bool next) {
  Map<String, List<ArchiveDownloadedData>> group2Archives = archiveDownloadService.archives
      .where((archive) => archive.gid == gid || archiveDownloadService.archiveDownloadInfos[archive.gid]?.archiveStatus == ArchiveStatus.completed)
      .groupListsBy((archive) => archiveDownloadService.archiveDownloadInfos[archive.gid]?.group ?? archive.groupName);
  List<ArchiveDownloadedData> archives = [
    for (String group in archiveDownloadService.allGroups) ...?group2Archives.remove(group),
    ...group2Archives.values.flattened,
  ];

  ArchiveDownloadedData? adjacent = _findAdjacent(archives, (archive) => archive.gid == gid, next);
  if (adjacent == null) {
    return null;
  }

  return AdjacentGallery(
    title: adjacent.title,
    loadReadPageInfo: () async {
      ArchiveDownloadedData? archive = archiveDownloadService.archives.firstWhereOrNull((archive) => archive.gid == adjacent.gid);
      if (archive == null || archiveDownloadService.archiveDownloadInfos[archive.gid]?.archiveStatus != ArchiveStatus.completed) {
        return null;
      }
      return buildArchiveReadPageInfo(archive, initialIndex: 0);
    },
  );
}

/// Galleries are ordered as they are displayed in download page: sub directories first, then galleries in the directory itself.
AdjacentGallery? findAdjacentLocalGallery(String galleryPath, bool next) {
  List<LocalGallery> galleries = [];
  Set<String> visitedDirectories = {};

  void visit(String directory) {
    if (!visitedDirectories.add(directory)) {
      return;
    }
    for (String subDirectory in localGalleryService.path2SubDir[directory] ?? const <String>[]) {
      visit(subDirectory);
    }
    galleries.addAll(localGalleryService.path2GalleryDir[directory] ?? const <LocalGallery>[]);
  }

  visit(LocalGalleryService.rootPath);

  LocalGallery? adjacent = _findAdjacent(galleries, (gallery) => gallery.path == galleryPath, next);
  if (adjacent == null) {
    return null;
  }

  return AdjacentGallery(
    title: adjacent.title,
    loadReadPageInfo: () async {
      ReadPageInfo readPageInfo = await buildLocalGalleryReadPageInfo(adjacent, initialIndex: 0);
      return readPageInfo.pageCount == 0 ? null : readPageInfo;
    },
  );
}

T? _findAdjacent<T>(List<T> items, bool Function(T) isCurrent, bool next) {
  int index = items.indexWhere(isCurrent);
  if (index == -1) {
    return null;
  }

  int adjacentIndex = next ? index + 1 : index - 1;
  return adjacentIndex < 0 || adjacentIndex >= items.length ? null : items[adjacentIndex];
}
