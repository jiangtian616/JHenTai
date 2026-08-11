import 'package:drift/drift.dart';
import 'package:jhentai/src/database/dao/reader_bookmark_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/reader_bookmark.dart';

abstract class ReaderBookmarkRepository {
  Future<List<ReaderBookmark>> list(String galleryKey);

  Future<void> save(ReaderBookmark bookmark);
}

class DriftReaderBookmarkRepository implements ReaderBookmarkRepository {
  @override
  Future<List<ReaderBookmark>> list(String galleryKey) async {
    final rows = await ReaderBookmarkDao.selectByGalleryKey(galleryKey);
    return rows
        .map(
          (row) => ReaderBookmark(
            galleryKey: row.galleryKey,
            pageIndex: row.pageIndex,
            createdAt: DateTime.parse(row.createdAt),
            updatedAt: DateTime.parse(row.updatedAt),
            note: row.note,
            sourceDeviceId: row.sourceDeviceId,
            deletedAt:
                row.deletedAt == null ? null : DateTime.parse(row.deletedAt!),
          ),
        )
        .toList();
  }

  @override
  Future<void> save(ReaderBookmark bookmark) async {
    await ReaderBookmarkDao.upsert(
      ReaderBookmarkTableCompanion.insert(
        galleryKey: bookmark.galleryKey,
        pageIndex: bookmark.pageIndex,
        createdAt: bookmark.createdAt.toUtc().toIso8601String(),
        updatedAt: bookmark.updatedAt.toUtc().toIso8601String(),
        note: Value(bookmark.note),
        sourceDeviceId: Value(bookmark.sourceDeviceId),
        deletedAt: Value(bookmark.deletedAt?.toUtc().toIso8601String()),
      ),
    );
  }
}

class ReaderBookmarkService {
  ReaderBookmarkService({ReaderBookmarkRepository? repository})
    : _repository = repository ?? DriftReaderBookmarkRepository();

  final ReaderBookmarkRepository _repository;
  final Map<String, List<ReaderBookmark>> _cache = {};

  Future<List<ReaderBookmark>> load(String galleryKey) async {
    final rows = await _repository.list(galleryKey);
    final active = rows.where((bookmark) => !bookmark.isDeleted).toList();
    _cache[galleryKey] = active;
    return List.unmodifiable(active);
  }

  List<ReaderBookmark> cached(String galleryKey) =>
      List.unmodifiable(_cache[galleryKey] ?? const <ReaderBookmark>[]);

  Future<bool> toggle({
    required String galleryKey,
    required int pageIndex,
    String? sourceDeviceId,
  }) async {
    final List<ReaderBookmark> all = await _repository.list(galleryKey);
    final ReaderBookmark? existing = all
        .where((bookmark) => bookmark.pageIndex == pageIndex)
        .fold<ReaderBookmark?>(null, (previous, current) {
          if (previous == null ||
              current.updatedAt.isAfter(previous.updatedAt)) {
            return current;
          }
          return previous;
        });
    final DateTime now = DateTime.now().toUtc();
    final bool adding = existing == null || existing.isDeleted;
    final ReaderBookmark next =
        existing == null
            ? ReaderBookmark(
              galleryKey: galleryKey,
              pageIndex: pageIndex,
              createdAt: now,
              updatedAt: now,
              sourceDeviceId: sourceDeviceId,
            )
            : existing.copyWith(
              updatedAt: now,
              sourceDeviceId: sourceDeviceId,
              clearDeletedAt: adding,
              deletedAt: adding ? null : now,
            );
    await _repository.save(next);
    await load(galleryKey);
    return adding;
  }
}

ReaderBookmarkService readerBookmarkService = ReaderBookmarkService();
