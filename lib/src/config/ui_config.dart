import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../utils/screen_size_util.dart';

class UIConfig {
  /// common
  static ScrollBehavior scrollBehaviourWithScrollBar = EHScrollBehaviourWithScrollBar().copyWith(
    dragDevices: {
      PointerDeviceKind.mouse,
      PointerDeviceKind.touch,
      PointerDeviceKind.stylus,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.unknown,
    },
    scrollbars: true,
  );

  static ScrollBehavior scrollBehaviourWithoutScrollBar = const MaterialScrollBehavior().copyWith(
    dragDevices: {
      PointerDeviceKind.mouse,
      PointerDeviceKind.touch,
      PointerDeviceKind.stylus,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.unknown,
    },
    scrollbars: false,
  );

  static Widget get loadingAnimation =>
      LoadingAnimationWidget.horizontalRotatingDots(color: Get.isDarkMode ? Colors.grey.shade200 : Colors.grey.shade800, size: 32);

  /// layout
  static const double appBarHeight = 40;
  static const double tabBarHeight = 36;
  static const double searchBarHeight = 40;
  static const double refreshTriggerPullDistance = 100;

  static const double desktopLeftTabBarWidth = 56;
  static const double desktopLeftTabBarItemHeight = 60;
  static const double desktopLeftTabBarTextHeight = 18;

  /// Gallery card
  static const double galleryCardHeight = 200;
  static const double galleryCardHeightWithoutTags = 125;
  static const double galleryCardCoverWidth = 140;
  static const double galleryCardCoverWidthWithoutTags = 85;
  static const double galleryCardTitleSize = 15;
  static const double galleryCardTextSize = 12;

  static Color get galleryCardTextColor => Get.theme.colorScheme.outline;
  static const double galleryCardTagsHeight = 70;

  static const double dashboardCardSize = 210;

  static const double waterFallFlowCardInfoHeight = 68;
  static const double waterFallFlowCardTitleSize = 12;
  static const double waterFallFlowCardTagsMaxHeight = 18;
  static const double waterFallFlowCardTagTextSize = 10;

  /// Login page
  static Color get loginPageForegroundColor => Get.theme.colorScheme.background;

  static Color get loginPageFormColor => Get.isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100;

  static Color get loginPageBackgroundColor => Get.isDarkMode ? Colors.blue.shade900 : Colors.blue;

  static Color get loginPageFieldColor => Get.theme.colorScheme.secondaryContainer;

  static Color get loginPageHintColor => Get.isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;

  static Color get loginPagePrefixIconColor => Get.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

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
  static const double detailsPageInfoIconSize = 12;
  static const double detailsPageInfoTextSize = 10;
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
  static const double detailsPageCommentsRegionHeight = 160;
  static const double detailsPageCommentsWidth = 300;

  static Color get detailsPageThumbnailIndexColor => Get.theme.colorScheme.outline;
  static const double detailsPageThumbnailHeight = 200;
  static const double detailsPageThumbnailWidth = 150;

  static const int detailsPageAnimationDuration = 150;

  /// Download page
  static const double downloadPageSegmentedControlWidth = 52;
  static const double downloadPageSegmentedTextSize = 13;

  static Color get resumeButtonColor => Colors.blue;

  static Color get pauseButtonColor => Get.theme.colorScheme.primary;

  static const double downloadPageGroupHeight = 50;

  static Color downloadPageGroupColor(BuildContext context) => Theme.of(context).colorScheme.secondaryContainer;

  static BoxShadow get downloadPageGroupShadow => BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 2,
        offset: const Offset(0.3, 1),
      );

  static const double downloadPageGroupHeaderWidth = 100;
  static const double downloadPageCardHeight = 130;

  static Color get downloadPageCardColor => Get.theme.colorScheme.surface;

  static BoxShadow get downloadPageCardShadow => BoxShadow(
        color: Get.theme.colorScheme.onBackground.withOpacity(0.1),
        blurRadius: 2,
        spreadRadius: 1,
        offset: const Offset(0.3, 1),
      );
  static const double downloadPageCoverWidth = 110;
  static const double downloadPageCoverHeight = 130;
  static const double downloadPageCardTitleSize = 14;

  static const double downloadPageCardTextSize = 11;

  static Color get downloadPageCardTextColor => Get.theme.colorScheme.outline;
  static const double downloadPageProgressIndicatorHeight = 3;

  static Color get downloadPageProgressIndicatorColor => Colors.blue;

  static Color get downloadPageProgressIndicatorPausedColor => Get.theme.colorScheme.surfaceVariant;

  /// download page with gridview
  static const double downloadPageGridViewCardAspectRatio = 0.8;
  static const double downloadPageGridViewCardWidth = 180;
  static const double downloadPageGridViewCardHeight = 180 / 0.8;

  static const double downloadPageGridViewGroupPadding = 6;
  static const double downloadPageGridViewInfoTextSize = 12;
  static const double downloadPageGridViewSpeedTextSize = 8;
  static const double downloadPageGridViewCircularProgressSize = 40;
  /// Search page
  static const double desktopSearchBarHeight = 32;
  static const double mobileV2SearchBarHeight = 28;

  static const double desktopSearchTabHeight = 32;
  static const double desktopSearchTabWidth = 130;
  static const double desktopSearchTabRemainingWidth = 42;
  static const double desktopSearchTabDividerWidth = 16;
  static const double desktopSearchTabDividerBorderRadius = 8;
  static const double desktopSearchTabIconSize = 16;

  static Duration desktopSearchTabAnimationDuration = const Duration(milliseconds: 200);

  static Color get searchPageSuggestionHighlightColor => Colors.red;

  static Color get searchPageSuggestionTitleColor => Get.theme.colorScheme.secondary.withOpacity(0.8);

  static Color get searchPageSuggestionSubTitleColor => Get.theme.colorScheme.secondary.withOpacity(0.5);

  static const double searchPageSuggestionTitleTextSize = 15;
  static const double searchPageSuggestionSubTitleTextSize = 12;

  static const double searchDialogSuggestionTitleTextSize = 13;
  static const double searchDialogSuggestionSubTitleTextSize = 11;

  static const int searchPageAnimationDuration = 250;

  /// Read page
  static Color get readPageMenuColor => Colors.black.withOpacity(0.8);

  static Color get readPageButtonColor => Colors.white;
  static const double readPageBottomThumbnailsRegionHeight = 134;
  static const double readPageThumbnailHeight = 102;
  static const double readPageThumbnailWidth = 80;

  static Color get readPageThumbnailShadowColor => Colors.white.withOpacity(0.8);
  static const double readPageBottomSliderHeight = 56;
  static const double readPageBottomSpacingHeight = 36;

  /// Comment
  static const double commentAuthorTextSizeInDetailPage = 12;
  static const double commentAuthorTextSizeInCommentPage = 13;

  static Color get commentUnknownAuthorTextColor => Get.theme.colorScheme.outline;

  static Color get commentOtherAuthorTextColor => Get.theme.colorScheme.onSecondaryContainer;

  static Color get commentOwnAuthorTextColor => Get.theme.colorScheme.error;
  static const double commentTimeTextSizeInDetailPage = 9;
  static const double commentTimeTextSizeInCommentPage = 10;

  static Color get commentTimeTextColor => Get.theme.colorScheme.outline;
  static const double commentBodyTextSizeInDetailPage = 12;
  static const double commentBodyTextSizeInCommentPage = 12;

  static Color get commentBodyTextColor => Get.theme.colorScheme.onBackground;
  static const double commentLastEditTimeTextSize = 9;
  static const double commentButtonSizeInDetailPage = 12;
  static const double commentButtonSizeInCommentPage = 14;

  static Color get commentButtonColor => Get.theme.colorScheme.outline;
  static const double commentScoreSizeInDetailPage = 10;
  static const double commentScoreSizeInCommentPage = 10;

  static Color get commentFooterTextColor => Get.theme.colorScheme.outline;

  /// Group selector
  static const double groupSelectorHeight = 100;
  static const double groupSelectorWidth = 230;
  static const double groupSelectorChipsHeight = 40;
  static const double groupSelectorChipTextSize = 11;

  static const Color groupSelectorSelectedChipColor = Color(0xFFEADDFF);

  static Color get groupSelectorChipColor => groupSelectorSelectedChipColor.withOpacity(0.3);
  static const Color groupSelectorTextColor = Colors.black;
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

  /// HH download dialog
  static const double hhDialogBodyHeight = 220;
  static const double hhDialogTextSize = 9;
  static const double hhDialogTextButtonWidth = 60;

  static Color get hhDialogCostTextColor => Get.theme.colorScheme.outline;

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

  /// detail page
  static const double detailPagePadding = 15;
}

class EHScrollBehaviourWithScrollBar extends MaterialScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return child;
      case Axis.vertical:
        return GetPlatform.isMobile
            ? CupertinoScrollbar(controller: details.controller, child: child)
            : Scrollbar(controller: details.controller, child: child);
    }
  }
}
