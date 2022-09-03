import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GlobalConfig {
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
  static final Color detailsPageUploaderTextColor = Get.theme.colorScheme.outline;
  static final Color detailsPageIconColor = Get.theme.colorScheme.outline;
  static const double detailsPageRatingTextSize = 12;
  static const double detailsPageDetailsTextSize = 8;
  static const double detailsPageFirstSpanWidthSize = 72;
  static const double detailsPageSecondSpanWidthSize = 55;
  static const double detailsPageThirdSpanWidthSize = 80;
  static const double detailsPageNewVersionHintHeight = 36;
  static const double detailsPageActionsHeight = 64;
  static const double detailsPageActionExtent = 72;
  static final Color detailsPageActionIconColor = Get.theme.colorScheme.primary;
  static final Color detailsPageActionTextColor = Get.theme.colorScheme.secondary;
  static const double detailsPageActionTextSize = 11;
  static const double detailsPageCommentIndicatorHeight = 50;
  static const double detailsPageCommentsHeight = 150;
  static const double detailsPageCommentsWidth = 300;
  static final Color detailsPageThumbnailIndexColor = Get.theme.colorScheme.outline;
  static const double detailsPageThumbnailHeight = 200;
  static const double detailsPageThumbnailWidth = 150;

  /// Comment
  static const double commentAuthorTextSize = 13;
  static final Color commentUnknownAuthorTextColor = Get.theme.colorScheme.outline;
  static final Color commentOtherAuthorTextColor = Get.theme.colorScheme.onSecondaryContainer;
  static final Color commentOwnAuthorTextColor = Get.theme.colorScheme.error;
  static const double commentTimeTextSize = 10;
  static final Color commentTimeTextColor = Get.theme.colorScheme.outline;
  static const double commentBodyTextSize = 12;
  static const double commentLastEditTimeTextSize = 9;
  static const double commentButtonSize = 14;
  static final Color commentButtonColor = Get.theme.colorScheme.outline;
  static const double commentScoreSize = 12;
  static final Color commentFooterTextColor = Get.theme.colorScheme.outline;
}
