import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/screen_size_util.dart';

class UIConfig {
  /// common
  static ScrollBehavior behaviorWithScrollBar = const MaterialScrollBehavior().copyWith(
    dragDevices: {
      PointerDeviceKind.mouse,
      PointerDeviceKind.touch,
      PointerDeviceKind.stylus,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.unknown,
    },
    scrollbars: true,
  );

  /// layout
  static const double appBarHeight = 40;
  static const double tabBarHeight = 36;
  static const double searchBarHeight = 40;
  static const double refreshTriggerPullDistance = 100;

  static const double desktopLeftTabBarWidth = 56;

  static const double bottomMenuHeight = 220;
  static const double bottomMenuHeightWithoutThumbnails = 100;

  static const double dashboardCardSize = 210;

  /// Gallery card
  static const double galleryCardHeight = 200;
  static const double galleryCardHeightWithoutTags = 125;
  static const double galleryCardCoverWidth = 140;
  static const double galleryCardCoverWidthWithoutTags = 85;
  static const double galleryCardTitleSize = 15;
  static const double galleryCardTextSize = 12;

  static Color get galleryCardTextColor => Get.theme.colorScheme.outline;
  static const double galleryCardTagsHeight = 70;

  /// Login page
  static const Color loginPageForegroundColor = Colors.white;

  static Color get loginPageBackgroundColor => Get.theme.primaryColor;

  static Color get loginPageFieldColor => Colors.grey.shade200;

  static Color get loginPageHintColor => Colors.grey.shade700;

  static Color get loginPagePrefixIconColor => Colors.grey.shade600;

  /// Detail page
  static const double detailsPageHeaderHeight = 200;
  static const double detailsPageCoverHeight = 200;
  static const double detailsPageCoverWidth = 140;
  static const double detailsPageCoverBorderRadius = 8;
  static const double detailsPageTitleTextSize = 15;
  static const double detailsPageTitleLetterSpacing = 0;
  static const double detailsPageTitleTextHeight = 1.3;
  static const double detailsPageUploaderTextSize = 12;

  static Color get detailsPageUploaderTextColor => Get.theme.colorScheme.outline;

  static Color get detailsPageIconColor => Get.theme.colorScheme.outline;
  static const double detailsPageRatingTextSize = 12;
  static const double detailsPageDetailsTextSize = 8;
  static const double detailsPageFirstSpanWidthSize = 72;
  static const double detailsPageSecondSpanWidthSize = 55;
  static const double detailsPageThirdSpanWidthSize = 80;
  static const double detailsPageNewVersionHintHeight = 36;
  static const double detailsPageActionsHeight = 64;
  static const double detailsPageActionExtent = 74;

  static Color get detailsPageActionIconColor => Get.theme.colorScheme.primary;

  static Color get detailsPageActionTextColor => Get.theme.colorScheme.secondary;
  static const double detailsPageActionTextSize = 11;
  static const double detailsPageCommentIndicatorHeight = 50;
  static const double detailsPageCommentsHeight = 154;
  static const double detailsPageCommentsWidth = 300;
  static const double detailsPageCommentBodyHeight = 74;

  static Color get detailsPageThumbnailIndexColor => Get.theme.colorScheme.outline;
  static const double detailsPageThumbnailHeight = 200;
  static const double detailsPageThumbnailWidth = 150;

  /// Search page
  static Color get searchPageSuggestionHighlightColor => Colors.red;

  static Color get searchPageSuggestionTitleColor => Get.theme.colorScheme.secondary.withOpacity(0.8);

  static Color get searchPageSuggestionSubTitleColor => Get.theme.colorScheme.secondary.withOpacity(0.5);

  static const double searchPageSuggestionTitleTextSize = 15;
  static const double searchPageSuggestionSubTitleTextSize = 12;

  /// Comment
  static const double commentAuthorTextSize = 13;

  static Color get commentUnknownAuthorTextColor => Get.theme.colorScheme.outline;

  static Color get commentOtherAuthorTextColor => Get.theme.colorScheme.onSecondaryContainer;

  static Color get commentOwnAuthorTextColor => Get.theme.colorScheme.error;
  static const double commentTimeTextSize = 10;

  static Color get commentTimeTextColor => Get.theme.colorScheme.outline;
  static const double commentBodyTextSize = 12;
  static const double commentLastEditTimeTextSize = 9;
  static const double commentButtonSize = 14;

  static Color get commentButtonColor => Get.theme.colorScheme.outline;
  static const double commentScoreSize = 12;

  static Color get commentFooterTextColor => Get.theme.colorScheme.outline;

  /// Group selector
  static const double groupSelectorHeight = 100;
  static const double groupSelectorWidth = 230;
  static const double groupSelectorChipsHeight = 40;
  static const double groupSelectorChipTextSize = 11;

  static Color get groupSelectorSelectedChipColor => Get.theme.colorScheme.primaryContainer;

  static Color get groupSelectorChipColor => Get.theme.colorScheme.primaryContainer.withOpacity(0.3);
  static const double groupSelectorTextFieldLabelTextSize = 12;
  static const double groupSelectorTextFieldTextSize = 14;

  /// Download dialog
  static const double downloadDialogWidth = 230;
  static const double downloadDialogBodyHeight = 140;
  static const double downloadDialogCheckBoxHeight = 20;

  static const double groupDialogCheckBoxTextSize = 14;

  static Color get groupDialogCheckBoxColor => Get.theme.colorScheme.primary;

  /// Archive dialog
  static const double archiveDialogBodyHeight = 230;
  static const double archiveDialogCostTextSize = 10;
  static const double archiveDialogDownloadTextSize = 14;
  static const double archiveDialogDownloadIconSize = 16;

  static Color get archiveDialogCostTextColor => Get.theme.colorScheme.outline;

  /// Download original image dialog
  static Color get downloadOriginalImageDialogColor => Get.theme.colorScheme.surfaceVariant;

  /// Favorite dialog
  static const double favoriteDialogHeight = 400;
  static const double favoriteDialogCountTextSize = 12;

  static Color get favoriteDialogCountTextColor => Get.theme.colorScheme.outline;

  static Color get favoriteDialogTileColor => Get.theme.colorScheme.secondaryContainer;

  /// Rating dialog
  static const double ratingDialogStarSize = 36;
  static const double ratingDialogButtonBoxHeight = 40;
  static const double ratingDialogButtonBoxWidth = 80;

  /// Torrent dialog
  static const double torrentDialogTitleSize = 12;
  static const double torrentDialogSubtitleIconSize = 10;
  static const double torrentDialogSubtitleTextSize = 9;

  /// Statistics dialog
  static const double statisticsDialogColumnSpacing = 40;
  static const double statisticsDialogColumnWidth = 50;
  static const double statisticsDialogGraphHeight = 300;

  static double get statisticsDialogGraphWidth => max(300, fullScreenWidth * 2 / 3);

  /// Tag dialog
  static Color get tagDialogButtonColor => Get.theme.colorScheme.onPrimaryContainer;
  static const double tagDialogButtonSize = 20;

  /// Tag sets page
  static Color get tagSetsPageIconColor => Get.theme.colorScheme.primary;
}
