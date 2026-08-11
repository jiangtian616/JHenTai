import 'dart:convert';

/// A page-level reader bookmark.
///
/// The optional fields are deliberately part of the first wire shape so the
/// LAN history synchronizer can merge records without a schema rewrite. The
/// first UI does not expose notes, but it must preserve them on round-trip.
class ReaderBookmark {
  const ReaderBookmark({
    required this.galleryKey,
    required this.pageIndex,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.sourceDeviceId,
    this.deletedAt,
  });

  final String galleryKey;
  final int pageIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? note;
  final String? sourceDeviceId;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  ReaderBookmark copyWith({
    DateTime? updatedAt,
    String? note,
    String? sourceDeviceId,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return ReaderBookmark(
      galleryKey: galleryKey,
      pageIndex: pageIndex,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
      sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': 1,
    'type': 'reader_page_bookmark',
    'galleryKey': galleryKey,
    'pageIndex': pageIndex,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'note': note,
    'sourceDeviceId': sourceDeviceId,
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  factory ReaderBookmark.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? value, {required DateTime fallback}) {
      return DateTime.tryParse(value?.toString() ?? '') ?? fallback;
    }

    final DateTime now = DateTime.now().toUtc();
    return ReaderBookmark(
      galleryKey: json['galleryKey'] as String,
      pageIndex: (json['pageIndex'] as num).toInt(),
      createdAt: parseDate(json['createdAt'], fallback: now),
      updatedAt: parseDate(json['updatedAt'], fallback: now),
      note: json['note'] as String?,
      sourceDeviceId: json['sourceDeviceId'] as String?,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.tryParse(json['deletedAt'].toString()),
    );
  }

  factory ReaderBookmark.decode(String value) =>
      ReaderBookmark.fromJson(jsonDecode(value) as Map<String, dynamic>);
}
