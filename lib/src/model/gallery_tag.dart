import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/database/database.dart';

enum EHTagStatus { confidence, skepticism, incorrect }

enum EHTagVoteStatus { none, up, down }

class GalleryTag {
  Color? color;
  Color? backgroundColor;
  TagData tagData;
  EHTagStatus? tagStatus;
  EHTagVoteStatus? voteStatus;

  GalleryTag({
    this.color,
    this.backgroundColor,
    required this.tagData,
    this.tagStatus,
    this.voteStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'color': color?.value,
      'backgroundColor': backgroundColor?.value,
      'tagData': tagData.toJson()..removeWhere((key, value) => value == null),
      'tagStatus': tagStatus?.index,
      'voteStatus': voteStatus?.index,
    }..removeWhere((key, value) => value == null);
  }

  factory GalleryTag.fromJson(Map<String, dynamic> map) {
    return GalleryTag(
      color: map['color'] == null ? null : Color(map['color']),
      backgroundColor: map['backgroundColor'] == null ? null : Color(map['backgroundColor']),
      tagData: TagData.fromJson(map['tagData']),
      tagStatus: map['tagStatus'] == null ? null : EHTagStatus.values[map['tagStatus']],
      voteStatus: EHTagVoteStatus.values[map['voteStatus'] ?? EHTagVoteStatus.none.index],
    );
  }

  @override
  String toString() {
    return 'GalleryTag{color: $color, backgroundColor: $backgroundColor, tagData: $tagData, tagStatus: $tagStatus, voteStatus: $voteStatus}';
  }

  GalleryTag copyWith({
    Color? color,
    Color? backgroundColor,
    TagData? tagData,
    EHTagStatus? tagStatus,
    EHTagVoteStatus? voteStatus,
  }) {
    return GalleryTag(
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      tagData: tagData ?? this.tagData,
      tagStatus: tagStatus ?? this.tagStatus,
      voteStatus: voteStatus ?? this.voteStatus,
    );
  }
}
