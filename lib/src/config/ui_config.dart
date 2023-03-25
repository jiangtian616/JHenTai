import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/style_setting.dart';
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

  static Widget get loadingAnimation => LoadingAnimationWidget.horizontalRotatingDots(color: Get.theme.colorScheme.onSurfaceVariant, size: 32);

  static Color get alertColor => Get.theme.colorScheme.error;

  static Color get primaryColor => Get.theme.colorScheme.primary;

  static Color get onPrimaryColor => Get.theme.colorScheme.onPrimary;

  static Color backGroundColor(BuildContext context) => Theme.of(context).colorScheme.background;

  static Color onBackGroundColor(BuildContext context) => Theme.of(context).colorScheme.onBackground;

  /// snack
  static Color get snackBackGroundColor => Colors.black.withOpacity(0.7);
  static const Color snackTextColor = Colors.white70;

  /// toast
  static Color get toastBackGroundColor => Get.theme.colorScheme.onBackground;

  static Color get toastTextColor => Get.theme.colorScheme.background;

  /// window
  static const Color windowBorderColor = Colors.black;

  /// layout
  static const double appBarHeight = 40;
  static const double tabBarHeight = 36;
  static const double searchBarHeight = 40;
  static const double refreshTriggerPullDistance = 100;

  static Color get layoutDividerColor => Get.theme.colorScheme.surfaceVariant;

  static Color get desktopLeftTabIconDashColor => Get.theme.colorScheme.onBackground;
  static const double desktopLeftTabBarWidth = 56;
  static const double desktopLeftTabBarItemHeight = 60;
  static const double desktopLeftTabBarTextHeight = 18;

  /// mobile home page
  static Color get loginAvatarBackGroundColor => Get.theme.colorScheme.surfaceVariant;

  static Color get loginAvatarForeGroundColor => Get.theme.colorScheme.onSurfaceVariant.withOpacity(0.6);

  static Color get mobileDrawerSelectedTileColor => Get.theme.colorScheme.primaryContainer;

  /// Gallery card
  static const double galleryCardHeight = 200;
  static const double galleryCardHeightWithoutTags = 125;
  static const double galleryCardCoverWidth = 140;
  static const double galleryCardCoverWidthWithoutTags = 85;
  static const double galleryCardTitleSize = 15;
  static const double galleryCardTextSize = 12;

  static Color get galleryCardBackGroundColor => Get.theme.colorScheme.surfaceVariant.withOpacity(0.8);

  static Color get galleryCardShadowColor => Get.theme.colorScheme.onBackground.withOpacity(0.2);

  static Color get galleryCardTextColor => Get.theme.colorScheme.outline;
  static const double galleryCardTagsHeight = 70;

  static const double dashboardCardSize = 210;
  static const Color dashboardCardTextColor = Colors.white;
  static Color dashboardCardFooterTextColor = Colors.grey.shade300;
  static const Color dashboardCardShadeColor = Colors.black87;

  static const double waterFallFlowCardInfoHeight = 68;
  static const double waterFallFlowCardTitleSize = 12;
  static const double waterFallFlowCardTagsMaxHeight = 18;
  static const double waterFallFlowCardTagTextSize = 10;

  static Color get waterFallFlowCardBackGroundColor => Get.theme.colorScheme.onPrimaryContainer.withOpacity(0.05);

  static const Color waterFallFlowCardLanguageChipTextColor = Colors.white;

  /// Login page
  static Color get loginPageForegroundColor => Get.theme.colorScheme.onSurfaceVariant;

  static Color get loginPageBackgroundColor => Get.theme.colorScheme.background;

  static Color get loginPageFormIconColor => Get.theme.colorScheme.onSurfaceVariant;

  static Color get loginPageTextHintColor => Get.theme.colorScheme.onSurfaceVariant;

  static Color get loginPagePrefixIconColor => Get.theme.colorScheme.onSurfaceVariant;

  static Color get loginPageFormHintColor => Get.theme.colorScheme.outline;

  static Color get loginPageIndicatorColor => Get.theme.colorScheme.background;

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

  static Color get resumeButtonColor => Get.theme.colorScheme.primary;

  static Color get pauseButtonColor => Get.theme.colorScheme.primary;

  static const double downloadPageGroupHeight = 50;

  static Color downloadPageGroupColor(BuildContext context) => Theme.of(context).colorScheme.secondaryContainer;

  static BoxShadow get downloadPageGroupShadow => BoxShadow(
        color: Get.theme.colorScheme.onBackground.withOpacity(0.3),
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

  static Color get downloadPageProgressIndicatorColor => Get.theme.colorScheme.primary;

  static Color get downloadPageProgressPausedIndicatorColor => Get.theme.colorScheme.surfaceVariant;

  static Color get downloadPageLoadingIndicatorColor => Get.theme.colorScheme.onSurfaceVariant;

  /// download page with gridview
  static Color get downloadPageGridViewGroupBackGroundColor => Get.theme.colorScheme.secondaryContainer.withOpacity(0.6);

  static const double downloadPageGridViewCardAspectRatio = 0.8;
  static const double downloadPageGridViewCardWidth = 180;
  static const double downloadPageGridViewCardHeight = 180 / 0.8;

  static const double downloadPageGridViewGroupPadding = 6;
  static const double downloadPageGridViewInfoTextSize = 12;
  static const double downloadPageGridViewSpeedTextSize = 8;
  static const double downloadPageGridViewCircularProgressSize = 40;

  static Color get downloadPageGridViewCardDragBorderColor => Get.theme.colorScheme.onBackground;

  /// Search page
  static const double desktopSearchBarHeight = 32;
  static const double mobileV2SearchBarHeight = 28;

  static const double desktopSearchTabHeight = 32;
  static const double desktopSearchTabWidth = 130;
  static const double desktopSearchTabRemainingWidth = 42;
  static const double desktopSearchTabDividerWidth = 16;
  static const double desktopSearchTabDividerBorderRadius = 8;
  static const double desktopSearchTabIconSize = 16;

  static Color get desktopSearchTabSelectedBackGroundColor => Get.theme.colorScheme.onBackground;

  static Color get desktopSearchTabUnSelectedBackGroundColor => Get.theme.colorScheme.secondaryContainer;

  static Color get desktopSearchTabSelectedTextColor => Get.theme.colorScheme.background;

  static Color get desktopSearchTabUnSelectedTextColor => Get.theme.colorScheme.onBackground;

  static Color get desktopSearchTabDividerBackGroundColor => Get.theme.colorScheme.background;

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
  static const Color readPageForeGroundColor = Colors.white;

  static Color get readPageMenuColor => Colors.black.withOpacity(0.8);

  static const Color readPageButtonColor = Colors.white;

  static Color get readPageActiveButtonColor => Get.theme.colorScheme.primary;
  static const double readPageBottomThumbnailsRegionHeight = 134;
  static const double readPageThumbnailHeight = 102;
  static const double readPageThumbnailWidth = 80;

  static Color get readPageBottomCurrentImageHighlightBackgroundColor => Get.theme.colorScheme.primary;

  static Color get readPageBottomCurrentImageHighlightForegroundColor => Get.theme.colorScheme.onPrimary;

  static const double readPageBottomSliderHeight = 56;
  static const double readPageBottomSpacingHeight = 36;

  static const Color readPageWarningButtonColor = Colors.yellow;

  static Color get readPageRightBottomRegionColor => Colors.grey.withOpacity(0.8);

  /// Blank page
  static Color get jHentaiIconColor => Get.theme.colorScheme.outline;

  /// Dashboard page
  static Color get dashboardPageSeeAllTextColor => Get.theme.colorScheme.outline;

  static Color get dashboardPageArrowButtonColor => Get.theme.colorScheme.primary;

  static Color get dashboardPageGalleryDescButtonColor => Get.theme.colorScheme.onSurfaceVariant;

  /// Download page
  static const Color downloadPageGridCoverOverlayColor = Colors.white;
  static const Color downloadPageGridCoverBlurColor = Colors.black;
  static const Color downloadPageGridProgressColor = Colors.white;

  static Color get downloadPageGridProgressBackGroundColor => Colors.grey.shade800;

  static const Color downloadPageGridTextColor = Colors.white;

  static Color get downloadPageActionBackGroundColor => Get.theme.colorScheme.background;

  /// Detail page
  static const double detailPagePadding = 15;

  static Color get detailPageCoverShadowColor => Get.theme.colorScheme.primary.withOpacity(0.3);

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

  static const Color commentLinkColor = Colors.blue;

  static const Color galleryCategoryTagTextColor = Colors.white;

  static Color get galleryCategoryTagDisabledBackGroundColor => Get.theme.colorScheme.outline.withOpacity(0.2);

  static Color get galleryCategoryTagDisabledTextColor => Get.theme.colorScheme.onSurfaceVariant.withOpacity(0.2);

  static Color galleryRatingStarColor = Colors.amber.shade800;

  static Color get galleryRatingStarUnRatedColor => Get.theme.colorScheme.outline.withOpacity(0.5);

  static Color get galleryRatingStarRatedColor => Get.theme.colorScheme.error;

  /// Setting page
  static Color get settingPageLayoutSelectorUnSupportColor => Get.theme.colorScheme.outline.withOpacity(0.5);

  /// Group selector
  static const double groupSelectorHeight = 100;
  static const double groupSelectorWidth = 230;
  static const double groupSelectorChipsHeight = 40;
  static const double groupSelectorChipTextSize = 11;

  static Color get groupSelectorSelectedChipColor => Get.theme.colorScheme.secondaryContainer;

  static Color get groupSelectorChipColor => Get.theme.colorScheme.background;

  static Color get groupSelectorTextColor => Get.theme.colorScheme.onSecondaryContainer;
  static const double groupSelectorTextFieldLabelTextSize = 12;
  static const double groupSelectorTextFieldTextSize = 14;

  /// EH Tag
  static Color get ehTagBackGroundColor => Get.theme.colorScheme.secondary.withOpacity(0.15);

  static Color get ehTagTextColor => Get.theme.colorScheme.onBackground;

  /// Gallery card favorite tag
  static const Color galleryCardFavoriteTagTextColor = Colors.white;

  /// Warning image
  static const Color warningImageBlurColor = Colors.black;

  static const Color warningImageTextColor = Colors.white;

  /// Loading state indicator
  static Color get loadingStateIndicatorButtonColor => Get.theme.colorScheme.outline;

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
  static Color get tagDialogButtonColor => Get.theme.colorScheme.primary;

  static Color get tagDialogLikedButtonColor => Get.theme.colorScheme.error;
  static const double tagDialogButtonSize = 20;

  /// Tag sets page
  static Color get tagSetsPageIconColor => Get.theme.colorScheme.primary;

  /// auth dialog
  static const double authDialogPinWidth = 300;
  static const double authDialogPinHeight = 120;
  static const double authDialogPinCodeRegionWidth = 60;
  static const double authDialogCursorHeight = 2;

  /// search config dialog
  static Color get searchConfigDialogSuggestionShadowColor => Get.theme.colorScheme.onBackground.withOpacity(0.6);

  static Color get searchConfigDialogFieldHintTextColor => Get.theme.colorScheme.outline.withOpacity(0.5);

  /// lock page
  static const double lockPagePinCodeRegionWidth = 60;
  static const double lockPageCursorHeight = 2;

  static Color get lockPageFilledDashColor => Get.theme.colorScheme.secondaryContainer;

  static Color get lockPageUnfilledDashColor => Get.theme.colorScheme.onSecondaryContainer;
}

class EHScrollBehaviourWithScrollBar extends MaterialScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return child;
      case Axis.vertical:
        return ScrollbarTheme(
          data: ScrollbarThemeData(
            radius: StyleSetting.isInMobileLayout ? CupertinoScrollbar.defaultRadius : const Radius.circular(8),
            thickness: MaterialStateProperty.all(StyleSetting.isInMobileLayout ? CupertinoScrollbar.defaultThickness : 8),
          ),
          child: Scrollbar(controller: details.controller, child: child),
        );
    }
  }
}
