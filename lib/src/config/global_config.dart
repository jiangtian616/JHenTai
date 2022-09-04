import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GlobalConfig {
  /// layout
  static const double appBarHeight = 40;
  static const double tabBarHeight = 36;
  static const double searchBarHeight = 40;
  static const double refreshTriggerPullDistance = 100;

  static const double desktopLeftTabBarWidth = 56;

  static const double bottomMenuHeight = 220;
  static const double bottomMenuHeightWithoutThumbnails = 100;

  static const double dashboardCardSize = 210;

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
  static const double detailsPageCommentsHeight = 150;
  static const double detailsPageCommentsWidth = 300;

  static Color get detailsPageThumbnailIndexColor => Get.theme.colorScheme.outline;
  static const double detailsPageThumbnailHeight = 200;
  static const double detailsPageThumbnailWidth = 150;

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

  /// Group name dialog
  static const double groupDialogHeight = 50;
  static const double groupDialogCheckBoxHeight = 20;
  static const double groupDialogWidth = 230;
  static const double groupDialogChipTextSize = 11;

  static Color get groupDialogChipColor => Get.theme.colorScheme.secondaryContainer;

  static const double groupDialogTextFieldLabelTextSize = 12;
  static const double groupDialogTextFieldTextSize = 16;
  static const double groupDialogCheckBoxTextSize = 12;

  static Color get groupDialogCheckBoxColor => Get.theme.colorScheme.primary;

  /// Download original image dialog
  static Color get downloadOriginalImageDialogColor => Get.theme.colorScheme.surfaceVariant;

  /// Favorite dialog
  static const double favoriteDialogHeight = 400;
  static const double favoriteDialogCountTextSize = 12;

  static Color get favoriteDialogCountTextColor => Get.theme.colorScheme.outline;

  static Color get favoriteDialogTileColor => Get.theme.colorScheme.secondaryContainer;
}
