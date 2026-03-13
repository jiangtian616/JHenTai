import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../utils/screen_size_util.dart';

class UIConfig {
  /// common
  static ScrollBehavior scrollBehaviourWithScrollBar = EHScrollBehaviourWithScrollBar().copyWith(
    scrollbars: true,
  );
  static ScrollBehavior scrollBehaviourWithoutScrollBar = const MaterialScrollBehavior().copyWith(
    scrollbars: false,
  );
  static ScrollBehavior scrollBehaviourWithScrollBarWithMouse = EHScrollBehaviourWithScrollBar().copyWith(
    dragDevices: {
      PointerDeviceKind.mouse,
      PointerDeviceKind.touch,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.unknown,
    },
    scrollbars: true,
  );
  static ScrollBehavior scrollBehaviourWithoutScrollBarWithMouse = const MaterialScrollBehavior().copyWith(
    dragDevices: {
      PointerDeviceKind.mouse,
      PointerDeviceKind.touch,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.unknown,
    },
    scrollbars: false,
  );

  static const Color defaultLightThemeColor = Color(0xFF6750A4);
  static const Color defaultDarkThemeColor = Color(0xFFD0BCFF);

  static const Map<String, Color> galleryCategoryColor = {
    'Doujinshi': Color(0xfffc4e4e),
    'Manga': Color(0xfffcb417),
    'Image Set': Color(0xff5050d7),
    'Game CG': Color(0xff05bf0b),
    'Artist CG': Color(0xffdde500),
    'Cosplay': Color(0xff9755f5),
    'Non-H': Color(0xff68c9de),
    'Asian Porn': Color(0xfffe93ff),
    'Western': Color(0xff14e723),
    'Misc': Color(0xff9e9e9e),
    'Private': Color(0xff000000),
    'other': Colors.white,
  };

  /// color for category tag text
  static const Color tagNameSpaceTextColor = Colors.black;

  /// background color for category tag
  static const Map<String, Color> tagNameSpaceColor = {
    'language': Color(0xfff5dff5),
    'artist': Color(0xffccd9cd),
    'character': Color(0xffc8c8e7),
    'female': Color(0xffdbceee),
    'male': Color(0xfffdd7d7),
    'parody': Color(0xffeed4c5),
    'group': Color(0xffdfd6f7),
    'mixed': Color(0xffd6e0f7),
    'Coser': Color(0xfff6dcf3),
    'cosplayer': Color(0xfff6dcf3),
    'reclass': Color(0xfff6dce9),
    'temp': Color(0xffe9dbfa),
    'other': Color(0xfffadcdb),
    'location': Color(0xfff5dff5),
    'default': Colors.white,
  };

  /// color for category tag
  static const Map<String, Color> zhTagNameSpaceColor = {
    '语言': Color(0xfff5dff5),
    '艺术家': Color(0xffccd9cd),
    '作者': Color(0xffccd9cd),
    '角色': Color(0xffc8c8e7),
    '女性': Color(0xffdbceee),
    '男性': Color(0xfffdd7d7),
    '原作': Color(0xffeed4c5),
    '团队': Color(0xffdfd6f7),
    '混合': Color(0xffd6e0f7),
    '角色扮演者': Color(0xfff6dcf3),
    '重新分类': Color(0xfff6dce9),
    '临时': Color(0xffe9dbfa),
    '其他': Color(0xfffadcdb),
    '地点': Color(0xfff5dff5),
    '默认': Colors.white,
  };

  /// raw tag color to tag index
  static const Map<String, int> favoriteTagIndex = <String, int>{
    '000': 0,
    'f00': 1,
    'fa0': 2,
    'dd0': 3,
    '080': 4,
    '9f4': 5,
    '4bf': 6,
    '00f': 7,
    '508': 8,
    'e8e': 9,
  };

  /// customized color for favorite tag
  static const List<Color> favoriteTagColor = <Color>[
    Color(0xff9e9e9e),
    Color(0xfffc4e4e),
    Color(0xfffcb417),
    Color(0xffdde500),
    Color(0xff17b91b),
    Color(0xff36b940),
    Color(0xff68c9de),
    Color(0xff5050d7),
    Color(0xff9755f5),
    Color(0xfffe93ff),
  ];

  static Widget loadingAnimation(BuildContext context) =>
      LoadingAnimationWidget.horizontalRotatingDots(color: Theme.of(context).colorScheme.onSurfaceVariant, size: 32);

  static Color alertColor(BuildContext context) => Theme.of(context).colorScheme.error;

  static Color primaryColor(BuildContext context) => Theme.of(context).colorScheme.primary;

  static Color onPrimaryColor(BuildContext context) => Theme.of(context).colorScheme.onPrimary;

  static Color backGroundColor(BuildContext context) => Theme.of(context).colorScheme.surface;

  static Color onBackGroundColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;

  /// snack
  static Color get snackBackGroundColor => Colors.black.withValues(alpha:0.7);
  static const Color snackTextColor = Colors.white70;
  static const double snackWidth = 400;

  /// toast
  static Color toastBackGroundColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;

  static Color toastTextColor(BuildContext context) => Theme.of(context).colorScheme.surface;

  /// window
  static const Color windowBorderColor = Colors.black;

  /// layout
  static const double appBarHeight = 40;
  static const double tabBarHeight = 36;
  static const double searchBarHeight = 40;
  static const double refreshTriggerPullDistance = 100;

  static Color layoutDividerColor(BuildContext context) => Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color desktopLeftTabIconColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  static const double desktopTitleBarHeight = 32;
  static const double desktopFullScreenTopPadding = 12;
  static const double desktopLeftTabBarWidth = 56;
  static const double desktopLeftTabBarItemHeight = 60;
  static const double desktopLeftTabBarTextHeight = 18;

  /// mobile home page
  static Color loginAvatarBackGroundColor(BuildContext context) => Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color loginAvatarForeGroundColor(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha:0.6);

  static Color mobileDrawerSelectedTileColor(BuildContext context) => Theme.of(context).colorScheme.primaryContainer;

  static ScrollBehavior leftDrawerPhysicsBehaviour = const MaterialScrollBehavior().copyWith(
    dragDevices: {
      PointerDeviceKind.mouse,
      PointerDeviceKind.touch,
      PointerDeviceKind.stylus,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.unknown,
    },
    scrollbars: false,
    overscroll: false,
  );

  /// Gallery card
  static const double galleryCardHeight = 200;
  static const double galleryCardHeightWithoutTags = 125;
  static const double galleryCardCoverWidth = 140;
  static const double galleryCardCoverWidthWithoutTags = 85;
  static const double galleryCardTitleSize = 15;
  static const double galleryCardTextSize = 12;
  static const double galleryCardReadProgressIndicatorSize = 9;

  static Color galleryCardBackGroundColor(BuildContext context) => Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha:0.8);

  static Color galleryCardShadowColor(BuildContext context) => Theme.of(context).colorScheme.onSurface.withValues(alpha:0.2);

  static Color galleryCardTextColor(BuildContext context) => Theme.of(context).colorScheme.outline;
  static const double galleryCardTagsHeight = 70;

  static const double dashboardCardSize = 210;
  static const Color dashboardCardTextColor = Colors.white;
  static Color dashboardCardFooterTextColor = Colors.grey.shade300;
  static const Color dashboardCardShadeColor = Colors.black87;

  static const double waterFallFlowCardWidthBig = 240;
  static const double waterFallFlowCardWidthSmall = 150;
  static const double waterFallFlowCardMaxHeightBig = 640;
  static const double waterFallFlowCardMaxHeightSmall = 400;
  static const double waterFallFlowCardInfoHeight = 68;
  static const double waterFallFlowCardTitleSize = 12;
  static const double waterFallFlowCardTagsMaxHeight = 18;
  static const double waterFallFlowCardTagTextSize = 10;

  static Color waterFallFlowCardBackGroundColor(BuildContext context) => Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha:0.05);

  static Color waterFallFlowCardLanguageChipTextColor(Color backGroundColor) => backGroundColor.computeLuminance() >= 0.5 ? Colors.black : Colors.white;

  static const double galleryCardFilteredIconSize = 24;

  /// Login page
  static Color loginPageForegroundColor(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;

  static Color loginPageBackgroundColor(BuildContext context) => Theme.of(context).colorScheme.surface;

  static Color loginPageFormIconColor(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;

  static const double loginPageTextHintSize = 13;

  static Color loginPageTextHintColor(BuildContext context) => Theme.of(context).colorScheme.outline;

  static Color loginPagePrefixIconColor(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;

  static Color loginPageFormHintColor(BuildContext context) => Theme.of(context).colorScheme.outline;

  static Color loginPageIndicatorColor(BuildContext context) => Theme.of(context).colorScheme.surface;

  static const double loginPageParseCookieTextSize = 10;

  /// Detail page
  static const double detailsPageHeaderHeight = 200;
  static const double detailsPageCoverHeight = 200;
  static const double detailsPageCoverWidth = 140;
  static const double detailsPageCoverBorderRadius = 8;
  static const double detailsPageTitleTextSize = 15;
  static const double detailsPageTitleLetterSpacing = 0;
  static const double detailsPageTitleTextHeight = 1.3;
  static const double detailsPageUploaderTextSize = 11;

  static TextStyle detailsPageSubTitleTextStyle(BuildContext context) => TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.outline);

  static Color detailsPageUploaderTextColor(BuildContext context) => Theme.of(context).colorScheme.outline;

  static Color detailsPageIconColor(BuildContext context) => Theme.of(context).colorScheme.outline;
  static const double detailsPageInfoIconSize = 12;
  static const double detailsPageInfoTextSize = 10;
  static const double detailsPageRatingTextSize = 12;
  static const double detailsPageDetailsTextSize = 8;
  static const double detailsPageFirstSpanWidthSize = 72;
  static const double detailsPageSecondSpanWidthSize = 55;
  static const double detailsPageThirdSpanWidthSize = 80;
  static const double detailsPageNewVersionHintHeight = 36;
  static const double detailsPageCopyRightRemovedHintHeight = 36;
  static const double detailsPageCopyRightRemovedHintTextSize = 13;
  static const double detailsPageActionsHeight = 64;
  static const double detailsPageActionExtent = 74;

  static Color detailsPageActionIconColor(BuildContext context) => Theme.of(context).colorScheme.primary;

  static Color detailsPageActionDisabledIconColor(BuildContext context) => Theme.of(context).disabledColor;

  static Color detailsPageActionTextColor(BuildContext context) => Theme.of(context).colorScheme.secondary;

  static const double detailsPageActionTextSize = 11;
  static const double detailsPageCommentIndicatorHeight = 50;
  static const double detailsPageCommentsRegionHeight = 160;
  static const double detailsPageCommentsWidth = 300;

  static Color detailsPageThumbnailIndexColor(BuildContext context) => Theme.of(context).colorScheme.outline;

  static const double detailsPageThumbnailHeight = 200;
  static const double detailsPageThumbnailWidth = 150;
  static const double detailsPageGridViewCardAspectRatio = 0.75;

  static const int detailsPageAnimationDuration = 150;

  /// Download page
  static const double downloadPageSegmentedControlWidth = 52;
  static const double downloadPageSegmentedTextSize = 13;

  static Color resumePauseButtonColor(BuildContext context) => Theme.of(context).colorScheme.primary;

  static const double groupListHeight = 50;

  static Color groupListColor(BuildContext context) => Theme.of(context).colorScheme.secondaryContainer;

  static BoxShadow groupListShadow(BuildContext context) => BoxShadow(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.3),
        blurRadius: 2,
        offset: const Offset(0.3, 1),
      );

  static const double downloadPageGroupHeaderWidth = 100;
  static const double downloadPageCardHeight = 130;

  static Color downloadPageCardSelectedColor(BuildContext context) => Theme.of(context).colorScheme.primaryContainer;

  static const double downloadPageCardBorderRadius = 12;

  static BoxShadow downloadPageCardShadow(BuildContext context) => BoxShadow(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.1),
        blurRadius: 2,
        spreadRadius: 1,
        offset: const Offset(0.3, 1),
      );
  static const double downloadPageCoverWidth = 110;
  static const double downloadPageCoverHeight = 130;
  static const double downloadPageCardTitleSize = 14;

  static const double downloadPageCardTextSize = 11;

  static Color downloadPageCardTextColor(BuildContext context) => Theme.of(context).colorScheme.outline;
  static const double downloadPageProgressIndicatorHeight = 3;

  static Color downloadPageProgressIndicatorColor(BuildContext context) => Theme.of(context).colorScheme.primary;

  static Color downloadPageProgressPausedIndicatorColor(BuildContext context) => Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color downloadPageLoadingIndicatorColor(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;

  static Duration downloadPageAnimationDuration = const Duration(milliseconds: 300);

  static const double downloadPageBotIconSize = 13;

  /// download page with gridview
  static Color downloadPageGridViewGroupBackGroundColor(BuildContext context) => Theme.of(context).colorScheme.secondaryContainer.withValues(alpha:0.6);

  static const double downloadPageGridViewCardAspectRatio = 0.8;
  static const double downloadPageGridViewCardWidth = 180;
  static const double downloadPageGridViewCardHeight = 180 / 0.8;

  static const double downloadPageGridViewGroupPadding = 6;
  static const double downloadPageGridViewInfoTextSize = 12;
  static const double downloadPageGridViewSpeedTextSize = 8;
  static const double downloadPageGridViewCircularProgressSize = 40;

  static Color downloadPageGridViewCardDragBorderColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;

  static const Color downloadPageGridViewSelectIconColor = Colors.white;
  static const Color downloadPageGridViewSelectIconBackGroundColor = Colors.black;

  /// Download search page
  static const double downloadSearchPageCoverWidth = 120;
  static const double downloadSearchPageCoverHeight = 160;

  /// Search page
  static const double desktopSearchBarHeight = 32;
  static const double mobileV2SearchBarHeight = 28;

  static const double desktopSearchTabHeight = 32;
  static const double desktopSearchTabWidth = 130;
  static const double desktopSearchTabRemainingWidth = 42;
  static const double desktopSearchTabDividerWidth = 16;
  static const double desktopSearchTabDividerBorderRadius = 8;
  static const double desktopSearchTabIconSize = 16;

  static Color desktopSearchTabSelectedBackGroundColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;

  static Color desktopSearchTabUnSelectedBackGroundColor(BuildContext context) => Theme.of(context).colorScheme.secondaryContainer;

  static Color desktopSearchTabSelectedTextColor(BuildContext context) => Theme.of(context).colorScheme.surface;

  static Color desktopSearchTabUnSelectedTextColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;

  static Color desktopSearchTabDividerBackGroundColor(BuildContext context) => Theme.of(context).colorScheme.surface;

  static Duration desktopSearchTabAnimationDuration = const Duration(milliseconds: 200);

  static const Color searchPageSuggestionHighlightColor = Colors.red;

  static Color searchPageSuggestionTitleColor(BuildContext context) => Theme.of(context).colorScheme.secondary.withValues(alpha:0.8);

  static Color searchPageSuggestionSubTitleColor(BuildContext context) => Theme.of(context).colorScheme.secondary.withValues(alpha:0.5);

  static const double searchPageSuggestionTitleTextSize = 15;
  static const double searchPageSuggestionSubTitleTextSize = 12;

  static const double searchDialogSuggestionTitleTextSize = 13;
  static const double searchDialogSuggestionSubTitleTextSize = 11;

  static const int searchPageAnimationDuration = 250;

  /// Read page
  static const Color readPageBackGroundColor = Colors.black;
  static const Color readPageForeGroundColor = Colors.white;

  static Color get readPageMenuColor => Colors.black.withValues(alpha:0.85);

  static const Color readPageButtonColor = Colors.white;

  static Color readPageActiveButtonColor(BuildContext context) => Theme.of(context).colorScheme.primary;
  static const double readPageBottomThumbnailsRegionHeight = 156;
  static const double readPageThumbnailHeight = 120;
  static const double readPageThumbnailWidth = 80;

  static Color readPageBottomCurrentImageHighlightBackgroundColor(BuildContext context) => Theme.of(context).colorScheme.primary;

  static Color readPageBottomCurrentImageHighlightForegroundColor(BuildContext context) => Theme.of(context).colorScheme.onPrimary;

  static const double readPageBottomSliderHeight = 54;
  static const double readPageBottomSpacingHeight = 36;

  static const double readPageBottomActionHeight = 52;

  static const Color readPageWarningButtonColor = Colors.yellow;

  static Color get readPageRightBottomRegionColor => Colors.grey.withValues(alpha:0.8);

  /// Blank page
  static Color jHentaiIconColor(BuildContext context) => Theme.of(context).colorScheme.outline;

  /// Dashboard page
  static Color dashboardPageSeeAllTextColor(BuildContext context) => Theme.of(context).colorScheme.outline;

  static Color dashboardPageArrowButtonColor(BuildContext context) => Theme.of(context).colorScheme.primary;

  static Color dashboardPageGalleryDescButtonColor(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;

  /// Download page
  static const Color downloadPageGridCoverOverlayColor = Colors.white;
  static const Color downloadPageGridCoverBlurColor = Colors.black;
  static const Color downloadPageGridProgressColor = Colors.white;

  static Color get downloadPageGridProgressBackGroundColor => Colors.grey.shade800;

  static const Color downloadPageGridTextColor = Colors.white;

  static Color downloadPageActionBackGroundColor(BuildContext context) => Theme.of(context).colorScheme.surface;

  /// Detail page
  static const double detailPagePadding = 15;

  static Color detailPageCoverShadowColor(BuildContext context) => Theme.of(context).colorScheme.primary.withValues(alpha:0.3);

  static const double addTagDialogWidth = 350;
  static const double addTagDialogHeight = 250;

  /// Comment
  static const double commentAuthorTextSizeInDetailPage = 12;
  static const double commentAuthorTextSizeInCommentPage = 13;

  static Color commentUnknownAuthorTextColor(BuildContext context) => Theme.of(context).colorScheme.outline;

  static Color commentOtherAuthorTextColor(BuildContext context) => Theme.of(context).colorScheme.onSecondaryContainer;

  static Color commentOwnAuthorTextColor(BuildContext context) => Theme.of(context).colorScheme.error;
  static const double commentTimeTextSizeInDetailPage = 9;
  static const double commentTimeTextSizeInCommentPage = 10;

  static Color commentTimeTextColor(BuildContext context) => Theme.of(context).colorScheme.outline;
  static const double commentBodyTextSizeInDetailPage = 12;
  static const double commentBodyTextSizeInCommentPage = 12;

  static Color commentBodyTextColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  static const double commentLastEditTimeTextSize = 9;
  static const double commentButtonSizeInDetailPage = 12;
  static const double commentButtonSizeInCommentPage = 14;

  static Color commentButtonVotedColor(BuildContext context) => Theme.of(context).colorScheme.error;

  static Color commentButtonColor(BuildContext context) => Theme.of(context).colorScheme.outline;
  static const double commentScoreSizeInDetailPage = 10;
  static const double commentScoreSizeInCommentPage = 10;

  static Color commentFooterTextColor(BuildContext context) => Theme.of(context).colorScheme.outline;

  static const double commentLinkFontSize = 12;
  static const Color commentLinkColor = Colors.blue;

  static const Color galleryCategoryTagTextColor = Colors.white;

  static Color galleryCategoryTagDisabledBackGroundColor(BuildContext context) => Theme.of(context).colorScheme.outline.withValues(alpha:0.2);

  static Color galleryCategoryTagDisabledTextColor(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha:0.2);

  static Color galleryRatingStarColor = Colors.amber.shade800;

  static Color galleryRatingStarUnRatedColor(BuildContext context) => Theme.of(context).colorScheme.outline.withValues(alpha:0.5);

  static Color galleryRatingStarRatedColor(BuildContext context) => Theme.of(context).colorScheme.error;

  /// Setting page
  static Color settingPageLayoutSelectorUnSupportColor(BuildContext context) => Theme.of(context).colorScheme.outline.withValues(alpha:0.5);
  static const double settingPageListTileSubTitleTextSize = 12;

  static Color settingPageListTileSubTitleColor(BuildContext context) => Theme.of(context).colorScheme.outline;

  static TextStyle settingPageListTileTrailingTextStyle(BuildContext context) => TextStyle(color: onBackGroundColor(context), fontSize: 14);

  /// Group selector
  static const double groupSelectorHeight = 116;
  static const double groupSelectorWidth = 230;
  static const double groupSelectorChipsHintHeight = 16;
  static const double groupSelectorChipsHintTextSize = 9;
  static const double groupSelectorChipsHeight = 40;
  static const double groupSelectorChipTextSize = 11;

  static Color groupSelectorSelectedChipColor(BuildContext context) => Theme.of(context).colorScheme.secondaryContainer;

  static Color groupSelectorChipColor(BuildContext context) => Theme.of(context).colorScheme.surfaceContainer;

  static Color groupSelectorTextColor(BuildContext context) => Theme.of(context).colorScheme.onSecondaryContainer;
  static const double groupSelectorTextFieldLabelTextSize = 12;
  static const double groupSelectorTextFieldTextSize = 14;

  /// EH Tag
  static Color ehWatchedTagDefaultBackGroundColor = const Color(0xFF3377FF);

  static Color ehTagBackGroundColor(BuildContext context) => Theme.of(context).colorScheme.secondary.withValues(alpha:0.15);

  static Color ehTagTextColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;

  static Color ehTagUnderLineColor(BuildContext context) => Theme.of(context).colorScheme.secondary;

  static Color ehTagDeleteButtonBackGroundColor(BuildContext context) => Theme.of(context).colorScheme.secondary.withValues(alpha:0.25);

  static Duration ehTagAnimationDuration = const Duration(milliseconds: 200);

  /// Gallery card favorite tag
  static const Color galleryCardFavoriteTagTextColor = Colors.white;

  /// Warning image
  static const Color warningImageBlurColor = Colors.black;

  static const Color warningImageTextColor = Colors.white;

  /// Loading state indicator
  static Color loadingStateIndicatorButtonColor(BuildContext context) => Theme.of(context).colorScheme.outline;

  /// Download dialog
  static const double downloadDialogWidth = 230;
  static const double downloadDialogBodyHeight = 140;
  static const double downloadDialogCheckBoxHeight = 20;

  static const double groupDialogCheckBoxTextSize = 14;

  static Color groupDialogCheckBoxColor(BuildContext context) => Theme.of(context).colorScheme.primary;

  /// Archive dialog
  static const double archiveDialogBodyHeight = 240;
  static const double archiveDialogCostTextSize = 10;
  static const double archiveDialogDownloadTextSize = 14;
  static const double archiveDialogDownloadIconSize = 16;

  /// Archive parse source select dialog
  static const double archiveParseSourceSelectDialogWidth = 230;
  static const double archiveParseSourceSelectDialogHeight = 140;

  static Color archiveDialogCostTextColor(BuildContext context) => Theme.of(context).colorScheme.outline;

  /// tagSet dialog
  static const double tagSetDialogBodyHeight = 230;

  /// HH download dialog
  static const double hhDialogBodyHeight = 220;
  static const double hhDialogTextSize = 9;
  static const double hhDialogTextButtonWidth = 60;

  static Color hhDialogCostTextColor(BuildContext context) => Theme.of(context).colorScheme.outline;

  /// Favorite dialog
  static const double favoriteDialogHeight = 400;
  static const double favoriteDialogLeadingTextSize = 13;
  static const double favoriteDialogTrailingTextSize = 12;

  static Color favoriteDialogCountTextColor(BuildContext context) => Theme.of(context).colorScheme.outline;

  static Color favoriteDialogTileColor(BuildContext context) => Theme.of(context).colorScheme.secondaryContainer;

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

  /// Gallery history dialog
  static Color galleryHistoryDialogTileColor(BuildContext context) => Theme.of(context).colorScheme.secondaryContainer;
  static const double galleryHistoryTitleSize = 14;
  static const double galleryHistoryDialogSubtitleIconSize = 16;
  static const double galleryHistoryDialogTrailingTextSize = 9;

  static double get statisticsDialogGraphWidth => max(300, fullScreenWidth * 2 / 3);

  /// Tag dialog
  static Color tagDialogButtonColor(BuildContext context) => Theme.of(context).colorScheme.primary;

  static Color tagDialogLikedButtonColor(BuildContext context) => Theme.of(context).colorScheme.error;
  static const double tagDialogButtonSize = 20;

  /// Tag sets page
  static Color tagSetsPageIconDefaultColor(BuildContext context) => Theme.of(context).colorScheme.primary;

  /// Add local tag page
  static const double addLocalTagPageSuggestionTitleTextSize = 14;
  static const double addLocalTagPageSuggestionSubTitleTextSize = 11;

  static Color addLocalTagPageSuggestionTitleColor(BuildContext context) => Theme.of(context).colorScheme.secondary;

  static Color addLocalTagPageSuggestionSubTitleColor(BuildContext context) => Theme.of(context).colorScheme.secondary.withValues(alpha:0.5);

  static const Color addLocalTagPageSuggestionHighlightColor = Colors.red;

  /// auth dialog
  static const double authDialogPinWidth = 300;
  static const double authDialogPinHeight = 120;
  static const double authDialogPinCodeRegionWidth = 60;
  static const double authDialogCursorHeight = 2;

  /// search config dialog
  static Color searchConfigDialogSuggestionShadowColor(BuildContext context) => Theme.of(context).colorScheme.onSurface.withValues(alpha:0.6);

  static Color searchConfigDialogFieldHintTextColor(BuildContext context) => Theme.of(context).colorScheme.outline.withValues(alpha:0.5);

  static Color searchConfigDialogHintTextColor = Colors.grey.shade600;

  /// gallery detail dialog
  static BorderRadius galleryDetailDialogItemBorderRadius = BorderRadius.circular(32);

  static const TextStyle galleryDetailDialogItemNameTextStyle = TextStyle(fontSize: 14);
  static const TextStyle galleryDetailDialogItemValueTextStyle = TextStyle(fontSize: 11);

  static const double galleryDetailDialogItemValueMaxWidth = 200;

  /// lock page
  static const double lockPagePinCodeRegionWidth = 60;
  static const double lockPageCursorHeight = 2;

  static Color lockPageFilledDashColor(BuildContext context) => Theme.of(context).colorScheme.secondaryContainer;

  static Color lockPageUnfilledDashColor(BuildContext context) => Theme.of(context).colorScheme.onSecondaryContainer;

  /// blocking rule page
  static Color blockingRulePageHelpTextColor(BuildContext context) => Colors.grey.shade600;
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
            radius: styleSetting.isInMobileLayout ? CupertinoScrollbar.defaultRadius : const Radius.circular(8),
            thickness: WidgetStateProperty.all(styleSetting.isInMobileLayout ? CupertinoScrollbar.defaultThickness : 8),
          ),
          child: Scrollbar(controller: details.controller, child: child),
        );
    }
  }
}
