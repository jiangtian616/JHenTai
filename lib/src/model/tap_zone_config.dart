import 'dart:convert';
import 'package:flutter/foundation.dart';

enum TapZoneAction {
  // Declaration order is frozen: it maps to the persisted action index in
  // each user's tap-zone config JSON. New actions must be appended at the end.
  none,
  prevPage,
  nextPage,
  toggleMenu,
  flipLeft,
  flipRight;

  /// Display order in the picker dialog: none, left/right flip, prev/next,
  /// then menu. Kept separate from [values] so presentation can differ from
  /// the storage layout.
  static const List<TapZoneAction> pickerOrder = [
    TapZoneAction.none,
    TapZoneAction.flipLeft,
    TapZoneAction.flipRight,
    TapZoneAction.prevPage,
    TapZoneAction.nextPage,
    TapZoneAction.toggleMenu,
  ];

  String get i18nKey => switch (this) {
        TapZoneAction.none => 'tapZoneActionNone',
        TapZoneAction.prevPage => 'tapZoneActionPrevPage',
        TapZoneAction.nextPage => 'tapZoneActionNextPage',
        TapZoneAction.toggleMenu => 'tapZoneActionToggleMenu',
        TapZoneAction.flipLeft => 'tapZoneActionFlipLeft',
        TapZoneAction.flipRight => 'tapZoneActionFlipRight',
      };
}

/// 3x3 tap zone grid on the reading page.
///
/// [actions] is row-major with length 9, index = row * 3 + col.
/// The right column width and bottom row height are derived as remainders.
class TapZoneConfig {
  final List<TapZoneAction> actions;
  final int leftColumnWidthRatio;
  final int middleColumnWidthRatio;
  final int topRowHeightRatio;
  final int middleRowHeightRatio;

  const TapZoneConfig._({
    required this.actions,
    this.leftColumnWidthRatio = 20,
    this.middleColumnWidthRatio = 60,
    this.topRowHeightRatio = 33,
    this.middleRowHeightRatio = 34,
  });

  /// Normalizing constructor: every ratio >= 1 and left+middle <= 99 /
  /// top+middle <= 99, so the derived right column and bottom row are
  /// always >= 1 and safe to use as [Expanded] flex.
  factory TapZoneConfig({
    required List<TapZoneAction> actions,
    int leftColumnWidthRatio = 20,
    int middleColumnWidthRatio = 60,
    int topRowHeightRatio = 33,
    int middleRowHeightRatio = 34,
  }) {
    int left = leftColumnWidthRatio.clamp(1, 98);
    int middle = middleColumnWidthRatio.clamp(1, 99 - left);
    int top = topRowHeightRatio.clamp(1, 98);
    int middleRow = middleRowHeightRatio.clamp(1, 99 - top);
    return TapZoneConfig._(
      actions: actions,
      leftColumnWidthRatio: left,
      middleColumnWidthRatio: middle,
      topRowHeightRatio: top,
      middleRowHeightRatio: middleRow,
    );
  }

  int get rightColumnWidthRatio => 100 - leftColumnWidthRatio - middleColumnWidthRatio;

  int get bottomRowHeightRatio => 100 - topRowHeightRatio - middleRowHeightRatio;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TapZoneConfig &&
          listEquals(other.actions, actions) &&
          other.leftColumnWidthRatio == leftColumnWidthRatio &&
          other.middleColumnWidthRatio == middleColumnWidthRatio &&
          other.topRowHeightRatio == topRowHeightRatio &&
          other.middleRowHeightRatio == middleRowHeightRatio;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(actions),
        leftColumnWidthRatio,
        middleColumnWidthRatio,
        topRowHeightRatio,
        middleRowHeightRatio,
      );

  /// Left zone flips left, middle column = menu, right zone flips right.
  /// Flip follows the current read direction, so in LTR this behaves like the
  /// old "left = prev / right = next"; in RTL the zones swap to match the page
  /// flow (the next page slides in from the left).
  factory TapZoneConfig.classic() => TapZoneConfig(
        actions: const [
          TapZoneAction.flipLeft,
          TapZoneAction.toggleMenu,
          TapZoneAction.flipRight,
          TapZoneAction.flipLeft,
          TapZoneAction.toggleMenu,
          TapZoneAction.flipRight,
          TapZoneAction.flipLeft,
          TapZoneAction.toggleMenu,
          TapZoneAction.flipRight,
        ],
        leftColumnWidthRatio: 20,
        middleColumnWidthRatio: 60,
        topRowHeightRatio: 33,
        middleRowHeightRatio: 34,
      );

  /// Top row = prev page, middle = menu, bottom row = next page.
  factory TapZoneConfig.vertical() => TapZoneConfig(
        actions: const [
          TapZoneAction.prevPage,
          TapZoneAction.prevPage,
          TapZoneAction.prevPage,
          TapZoneAction.toggleMenu,
          TapZoneAction.toggleMenu,
          TapZoneAction.toggleMenu,
          TapZoneAction.nextPage,
          TapZoneAction.nextPage,
          TapZoneAction.nextPage,
        ],
        leftColumnWidthRatio: 33,
        middleColumnWidthRatio: 34,
        topRowHeightRatio: 25,
        middleRowHeightRatio: 50,
      );

  TapZoneConfig copyWith({
    List<TapZoneAction>? actions,
    int? leftColumnWidthRatio,
    int? middleColumnWidthRatio,
    int? topRowHeightRatio,
    int? middleRowHeightRatio,
  }) =>
      TapZoneConfig(
        actions: actions ?? this.actions,
        leftColumnWidthRatio: leftColumnWidthRatio ?? this.leftColumnWidthRatio,
        middleColumnWidthRatio: middleColumnWidthRatio ?? this.middleColumnWidthRatio,
        topRowHeightRatio: topRowHeightRatio ?? this.topRowHeightRatio,
        middleRowHeightRatio: middleRowHeightRatio ?? this.middleRowHeightRatio,
      );

  Map<String, dynamic> toJson() => {
        'actions': actions.map((a) => a.index).toList(),
        'leftColumnWidthRatio': leftColumnWidthRatio,
        'middleColumnWidthRatio': middleColumnWidthRatio,
        'topRowHeightRatio': topRowHeightRatio,
        'middleRowHeightRatio': middleRowHeightRatio,
      };

  factory TapZoneConfig.fromJson(Map<dynamic, dynamic> map) {
    List<TapZoneAction> actions = TapZoneConfig.classic().actions;
    if (map['actions'] is List) {
      List<TapZoneAction> parsed =
          (map['actions'] as List).whereType<int>().map((i) => i >= 0 && i < TapZoneAction.values.length ? TapZoneAction.values[i] : TapZoneAction.none).toList();
      if (parsed.length == 9) {
        actions = parsed;
      }
    }
    return TapZoneConfig(
      actions: actions,
      leftColumnWidthRatio: map['leftColumnWidthRatio'] as int? ?? 20,
      middleColumnWidthRatio: map['middleColumnWidthRatio'] as int? ?? 60,
      topRowHeightRatio: map['topRowHeightRatio'] as int? ?? 33,
      middleRowHeightRatio: map['middleRowHeightRatio'] as int? ?? 34,
    );
  }

  String toJsonString() => json.encode(toJson());

  factory TapZoneConfig.fromJsonString(String s) => TapZoneConfig.fromJson(json.decode(s));
}
