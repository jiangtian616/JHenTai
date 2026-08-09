import 'dart:core';

class en_US {
  static Map<String, String> keys() {
    return {
      /// common
      'yes': 'Yes',
      'no': 'No',
      'cancel': "Cancel",
      'OK': "OK",
      'reset': "Reset",
      'success': "Success",
      'error': "Error",
      'failed': "Failed",
      'reload': 'Reload',
      'noMoreData': 'No More',
      'noData': 'No Data',
      'operationFailed': 'Operation Failed',
      'needLoginToOperate': 'Need Log In To Operate',
      'hasCopiedToClipboard': "Has Copied To Clipboard",
      'platformNotSupported': "Current platform not supported",
      'networkError': "Network Error, Tap to Reload",
      'systemError': "System Error",
      'invalid': "Invalid",
      'internalError': "Internal Error",
      'you': 'You',
      'retryHint': 'Please retry after refresh',
      'stop': 'Stop',
      'attention': 'Attention',
      'jump': 'Jump',
      'resetReadProgress': 'Reset Read Progress',
      'deleteAll': 'Delete All',
      'connectionTimeoutHint': 'Network connect timeout',
      'receiveDataTimeoutHint': 'Network receive data timeout',
      'archiveError': 'Download Archive Error',
      'edit': 'Edit',
      'confirmDestructiveActions': 'Confirm destructive actions',
      'confirmDestructiveActionsHint':
          'Show a confirmation dialog before destructive actions such as deleting tasks or re-downloading in the download page',

      'home': "Home",
      'gallery': "Gallery",
      'setting': 'Setting',

      /// schedule
      'dawnOfaNewDay': 'It is the dawn of a new day!',
      'encounterMonster': 'You have encountered a monster!',
      'encounterMonsterHint': 'Click to fight in the HentaiVerse.',

      /// unlock page
      'localizedReason': 'Please authenticate to continue',
      'tap2Auth': 'Tap to Authenticate',
      'passwordErrorHint': 'Password error, please try again',

      /// start page
      'TapAgainToExit': 'Tap again to exit',

      /// update dialog
      'availableUpdate': 'Available Update!',
      'LatestVersion': 'Latest Ver',
      'CurrentVersion': 'Current Ver',
      'check': 'Check',
      'dismiss': 'Dismiss',

      /// login page
      'login': 'Login',
      'notLoggedIn': 'Login',
      'logout': 'Logout',
      'passwordLogin': 'Password Login',
      'cookieLogin': 'Cookie Login',
      'useWebview': 'Use Webview',
      'skipCookieVerification': 'Skip Verification',
      'youHaveLoggedInAs': 'Hello:   ',
      'cookieIsBlack': 'Cookie is Black',
      'cookieFormatError': 'Cookie Format Error',
      'invalidCookie': 'Login failed or invalid cookie',
      'loginFail': 'Login Failed',
      'userName': 'Username',
      'EHUser': 'EH User',
      'password': 'Password',
      'needCaptcha': 'Need captcha, please login via cookie or web again.',
      'userNameOrPasswordMismatch': 'Username or password mismatch',
      'copyCookies': 'Copy Cookies',
      'tap2Copy': 'Tap to copy',
      'webLoginIsDisabled': 'Web login is disabled on desktop',
      'loginSuccess': 'Login Success',
      'userNameFormHint': 'Try with cookie in case of Sad Panda',
      'tap2Login': 'Log In',
      'parse': 'parse',
      'igneousHint': 'igneous(EX required)',
      'refreshIgneousFailed': 'Refresh Igneous Failed',

      /// request
      'sadPanda':
          'Sad Panda(no data). Refer: https://github.com/jiangtian616/JHenTai/wiki/Common-Questions',
      'sadPandaReferLink':
          'https://github.com/jiangtian616/JHenTai/wiki/Common-Questions',

      /// gallery card
      'filtered': 'Filtered',

      /// gallery page
      'getGallerysFailed': "Get Gallerys Failed",
      'refreshGalleryFailed': 'Refresh Gallery Failed',
      'tabBarSetting': 'TabBar Setting',
      'jumpPageTo': 'Jump Page To',
      'range': 'Range',
      'current': 'Current',
      'galleryUrlDetected': 'Found Gallery Url in Clipboard',
      'galleryUrlDetectedHint': 'Tap to enter detail page',

      /// details page
      'read': 'Read',
      'download': 'Download',
      'favorite': 'Favorite',
      'rating': 'Rating',
      'torrent': 'Torrent',
      'archive': 'Archive',
      'statistic': 'Statistic',
      'similar': 'Similar',
      'downloading': "Downloading",
      'resume': "Resume",
      'pause': 'Pause',
      'finished': 'Finished',
      'update': 'Update',
      'submit': 'Submit',
      'chooseFavorite': 'Choose Favorite',
      'asYourDefault': 'As Default',
      'Note': 'Note',
      'addNoteHint': 'Choose a slot before adding note',
      'uploader': 'Uploader',
      'allComments': 'All Comments',
      'noComments': 'No Comments',
      'lastEditedOn': 'Last edited on',
      'getGalleryDetailFailed': 'Get Gallery Detail Failed',
      'cloudflare403':
          'You have been restricted by Cloudflare from making network requests. Please try switching networks or using another login method.',
      'invisible2User': 'This Gallery is invisible to You',
      'invisibleHints': 'This gallery is removed or unavailable.',
      'copyRightHints':
          'This gallery is unavailable due to a copyright claim by: ',
      'refreshGalleryDetailsFailed': 'Refresh Gallery Details Failed',
      'failToGetThumbnails': "Fail To Get Thumbnails",
      'favoriteGallerySuccess': "Favorite Gallery Success",
      'favoriteGalleryFailed': "Favorite Gallery Failed",
      'removeFavoriteSuccess': "Remove Favorite Success",
      'removeFavoriteFailed': "Remove Favorite Failed",
      'getGalleryFavoriteInfoFailed': 'Get gallery favorite info failed',
      'favoriteNoteSlotFullHint':
          'Favorite note slot is full, please delete some notes first',
      'ratingSuccess': 'Rating Success',
      'ratingFailed': 'Rating Failed',
      'voteTagFailed': 'Vote Tag Failed',
      'beginToDownload': 'Begin To Download',
      'resumeDownload': 'Resume Download',
      'pauseDownload': 'Pause Download',
      'addNewTagSetSuccess': 'Add New Tag Set Success',
      'addNewWatchedTagSetSuccess': 'Add New Watched Tag Set Success',
      'addNewHiddenTagSetSuccess': 'Add New Hidden Tag Set Success',
      'addNewTagSetSuccessHint':
          'You can check your tags at Setting->EH->My Tags',
      'addNewTagSetFailed': 'Add New Tag Set Failed',
      'VisitorStatistics': 'Visitor Statistics',
      'invisible2UserWithoutDonation':
          'This gallery\'s stats is invisible to user without donation',
      'getGalleryStatisticsFailed': 'Get Gallery Statistics Failed',
      'totalVisits': 'Total Visits',
      'visits': 'Visits',
      'imageAccesses': 'Image Accesses',
      'period': 'Period',
      'ranking': 'Ranking',
      'score': 'Score',
      'NotOnTheList': 'Not on the list',
      'getGalleryArchiveFailed': 'Get Gallery Archive Failed',
      'parseGalleryArchiveFailed':
          'Parse failed, make sure your [Archiver Settings] in e-hentai is [Manual Select, Manual Start (Default)]',
      'original': 'Original',
      'resample': 'Resample',
      'beginToDownloadArchive': 'Begin to Download Archive',
      'beginToDownloadArchiveHint':
          'You can check progress at Download -> Archive',
      'updateGalleryError': 'Update Gallery Error',
      'thisGalleryHasANewVersion': 'This gallery has a new version',
      'hasUpdated': 'Has updated',
      'unpackingArchiveError': 'Unpacking archive error',
      'failedToDealWith': 'Failed to deal with',
      'hasDownloaded': 'Has downloaded',
      '410Hints':
          'You have clocked too many downloaded bytes on this archive, and need to re-unlock of this archive to resume.',
      '429Hints':
          'Too many download requests! You\'d better decrease your archive download concurrency.',
      'getUnpackedImagesFailedMsg':
          'JHenTai can\'t load images of this archive, please check your local file.',
      'getGalleryTorrentsFailed': 'Get torrents failed',
      'chooseArchive': 'Choose Archive',
      'tagSetExceedLimit':
          'No more tags can be added because you have reach the limit',
      'useTranslation': 'Use Translation',
      'addTagSuccess': 'Add Tag Success',
      'addTagFailed': 'Add Tag Failed',
      'parentGallery': 'Parent',
      'blockUploaderLocally': 'Block user locally',
      'block': 'Block',

      /// detail dialog
      'galleryUrl': 'Gallery Url',
      'title': 'Title',
      'japaneseTitle': 'Japanese Title',
      'category': 'Category',
      'publishTime': 'Publish Time',
      'pageCount': 'Page Count',
      'favoriteCount': 'Favorite Count',
      'ratingCount': 'Rating Count',

      /// comment page
      'newComment': 'New Comment',
      'updateComment': 'Update Comment',
      'commentTooShort': 'Comment is Too Short',
      'sendCommentFailed': 'Send Comment Failed',
      'voteCommentFailed': 'Vote Comment Failed',
      'voteCommentFailedHint': 'Try to pull-down to refresh details page first',
      'unknownUser': 'Unknown User',
      'atLeast3Characters': 'At least 3 characters',
      'noJHenTaiHints': 'Please don\'t mention JHenTai, thanks',
      'blockUser': 'Block user',

      /// EHImage
      'reloadImage': "Reload Image",

      /// read page
      'parsingPage': "Parsing Page",
      'parsingURL': "Parsing URL",
      'parsePageFailed': "Parse Page Failed, Tap to Retry",
      'parseURLFailed': "Parse URL Failed, Tap to Retry",
      'loading': "Loading",
      'paused': 'Paused',
      'exceedImageLimits': "Exceed Image Limits",
      'ehServerError':
          'An error occurred due to EH\'s server, please try again later',
      'unsupportedImagePageStyle':
          "JHenTai doesn't support Multi-Page Viewer(MPV), please change to default style in e-hentai.org",
      'toNext': 'To next',
      'toPrev': 'To prev',
      'back': 'Back',
      'toggleMenu': 'Toggle menu',
      'share': 'Share',
      'copyImage': 'Copy Image',
      'save': 'Save to Pictures',
      'copyEHPageUrl': 'Copy E-Hentai Page URL',

      /// setting page
      'account': 'Account',
      'EH': 'EH',
      'style': 'Style',
      'preference': 'Preference',
      'network': 'Network',
      'performance': 'Performance',
      'mouseWheel': 'Mouse Wheel',
      'advanced': 'Advanced',
      'cloud': 'Cloud',
      'security': 'Security',
      'about': 'About',
      'accountSetting': 'Account Setting',
      'styleSetting': 'Style Setting',
      'advancedSetting': 'Advanced Setting',
      'securitySetting': 'Security Setting',
      'ehSetting': 'EH Site Setting',
      'readSetting': 'Read Setting',
      'preferenceSetting': 'Preference Setting',
      'downloadSetting': 'Download Setting',
      'networkSetting': 'Network Setting',
      'performanceSetting': 'Performance Setting',
      'mouseWheelSetting': 'Mouse Wheel Setting',

      /// eh setting page
      'site': 'Site',
      'redirect2Eh': 'Redirect to EH if available',
      'redirect2EhHint':
          'Try to load gallery detail page from EH site first to get better network performance',
      'redirectAllGallery': 'Redirect all gallery to EH',
      'imDonorHint':
          'If you are a donor, you can turn this on to help you access gallerys in EX site',
      'profileSetting': 'Profile Setting',
      'chooseProfileHint': 'Choose profile used in JHenTai',
      'siteSetting': 'Site Setting',
      'siteSettingHint': 'Edit site setting in e-hentai',
      'showCookie': 'Cookie',
      'redirect2EH': 'Redirect to EH site if Available',
      'redirect2Hints': 'Will try to parse EH site first',
      'pleaseLogInToOperate': 'Please Log In To Operate',
      'imageLimits': 'Image Quota',
      'resetCost': 'Long press to reset, cost',
      'assets': 'Assets',
      'isNotDonator': 'Non-donators can\'t view the quota',
      'fetchImageQuotaFailed': 'Fetch image quota failed',

      /// tag setting page
      'myTags': 'My Tags',
      'myTagsHint': 'Manage watched and hidden tags online',
      'localTags': 'Local Tags',
      'localTagsHint': 'Extra filter tags',
      'localTagsHint2': 'Gallerys with these tags will be hidden',
      'addLocalTags': 'Add Tags',
      'hidden': 'Hidden',
      'nope': 'Nope',
      'getTagSetFailed': 'Get Tag Set Failed',
      'updateTagSetFailed': 'Update Tag Set Failed',
      'updateTagFailed': 'Update Tag Failed',
      'deleteTagSuccess': 'Delete Tag Success',
      'deleteTagFailed': 'Delete Tag Failed',
      'addLocalTagHint': 'Search to add new tag',

      /// Profile Setting page
      'selectedProfile': 'Selected Profile',
      'resetIfSwitchSite': 'Will be reset if switch site',

      /// add host mapping dialog
      'addHostMapping': 'Add Host Mapping',

      /// Layout
      'layoutMode': 'Layout Mode',
      'mobileLayoutV2Name': 'Mobile',
      'mobileLayoutV2Desc': 'Single column',
      'mobileLayoutName': 'Mobile(old)',
      'mobileLayoutDesc': 'Maintenance stopped',
      'tabletLayoutV2Name': 'Tablet',
      'tabletLayoutV2Desc': 'Double column',
      'tabletLayoutName': 'Tablet(old)',
      'tabletLayoutDesc': 'Maintenance stopped',
      'desktopLayoutName': 'Desktop',
      'desktopLayoutDesc': 'Double column with left tab bar, supports keyboard',

      /// style setting page
      'enableTagZHTranslation': 'Translate Tag Name into Chinese',
      'version': 'Version',
      'downloadTagTranslationHint': 'Downloading data..., downloaded: ',
      'zhTagSearchOrderOptimization':
          'Chinese Tag Auto-Completion Ordering Rule',
      'zhTagSearchOrderOptimizationHint':
          'Intelligent sorting by default and sort by frequency if enabled',
      'themeMode': 'Theme Mode',
      'dark': 'Dark',
      'light': 'Light',
      'followSystem': 'Follow System',
      'themeColor': 'Theme Color',
      'themeColorFixedOnApple': 'Fixed accent on macOS / iOS',
      'appleVisualStyle': 'Apple visual style',
      'appleVisualStyleHint': 'Enable the redesigned Apple-style interface',
      'listStyle': 'Gallery List Style (Global)',
      'flat': 'Flat',
      'flatWithoutTags': 'Flat(Without Tags)',
      'listWithoutTags': 'Card(Without Tags)',
      'listWithTags': 'Card',
      'waterfallFlowSmall': 'Waterfall Flow (Small)',
      'waterfallFlowMedium': 'Waterfall Flow (Medium)',
      'waterfallFlowBig': 'Waterfall Flow (Big)',
      'crossAxisCountInWaterFallFlow': 'Waterfall Flow Column Count',
      'pageListStyle': 'Gallery List Style (Page)',
      'crossAxisCountInGridDownloadPageForGroup':
          'Download Page Grid Column Count(Group)',
      'crossAxisCountInGridDownloadPageForGallery':
          'Download Page Grid Column Count(Gallery)',
      'crossAxisCountInDetailPage': 'Detail Page Thumbnail Column Count',
      'global': 'Global',
      'auto': 'Auto',
      'moveCover2RightSide': 'Move Cover to Right Side',
      'coverStyle': 'Cover Style',
      'cover': 'Cover',
      'adaptive': 'Adaptive',
      'simpleDashboardMode': 'Simple Home Page',
      'simpleDashboardModeHint': 'Hide Ranklist and Popular',
      'hideBottomBar': 'Hide Bottom Bar',
      'hideScroll2TopButton': 'Hide Scroll to Top Button',
      'whenScrollUp': 'When Scroll Up',
      'whenScrollDown': 'When Scroll Down',
      'preloadGalleryCover': 'Preload gallery cover',
      'preloadGalleryCoverHint':
          'Preload the covers of galleries that are not yet displayed on the page',
      'enableSwipeBackGesture': 'Enable Swipe Back Gesture',
      'enableLeftMenuDrawerGesture': 'Enable Left Menu Drawer Gesture',
      'enableQuickSearchDrawerGesture': 'Enable QuickSearch Drawer Gesture',
      'drawerGestureEdgeWidth': 'Drawer Gesture Edge Width',
      'alwaysShowScroll2TopButton': 'Always Show Scroll to Top Button',
      'enableDefaultFavorite': 'Enable Default Favorite',
      'enableDefaultFavoriteHint': 'Long press to re-select',
      'enableDefaultTagSet': 'Enable Default Tag Set',
      'enableDefaultTagSetHint': 'Long press to re-select',
      'disableDefaultTagSetHint': 'Select manually',
      'launchInFullScreen': 'Launch In Full Screen',
      'launchInFullScreenHint': 'Switch manually by F11',
      'disableDefaultFavoriteHint': 'Select manually',
      'searchBehaviour': 'Search Behaviour',
      'inheritAll': 'Inherit All',
      'inheritAllHint': 'Use last search options for next search',
      'inheritPartially': 'Inherit Partially',
      'inheritPartiallyHint':
          'Use last search options for next search(except language and category)',
      'none': 'None',
      'noneHint': 'Use default search options for next search',
      'showAllGalleryTitles': 'Show All Gallery Titles',
      'showAllGalleryTitlesHint':
          'Show both original and japanese titles if available',
      'showGalleryTagVoteStatus': 'Show Gallery Tag Vote Status',
      'showGalleryTagVoteStatusHint':
          'Include confidence, skepticism and incorrect',
      'showComments': 'Show Comments',
      'showAllComments': 'Show All Comments',
      'showAllCommentsHint':
          'By default only the 45 highest scoring and 5 most recent comments will be shown',
      'addTag': 'Add Tag',
      'addTagHint': 'Enter new tags, separated with comma',

      /// theme color setting page
      'themeColorSettingHint':
          'Assign different color for light and dark theme',
      'preview': 'Preview',
      'preset': 'Preset',
      'custom': 'Custom',

      /// performance setting page
      'maxGalleryNum4Animation':
          'Max Gallery Num For List Animation in Download page',
      'maxGalleryNum4AnimationHint':
          'Disable animation for groups which have more gallerys than this value(for list style)',
      'enableCoverDecodeOptimization': 'Cover Decode Optimization',
      'enableCoverDecodeOptimizationHint':
          'Decode gallery covers at a size closer to their displayed size instead of the full native resolution. Reduces decode time and memory usage when browsing grids, with a small quality tradeoff.',

      /// mouse wheel setting page
      'wheelScrollSpeed': 'Wheel scroll speed',
      'ineffectiveInGalleryPage': 'Ineffective in gallery page now.',

      /// advanced setting page
      'enableDomainFronting': 'Enable Domain Fronting',
      'bypassSNIBlocking': 'Bypass SNI blocking',
      'hostMapping': 'Host Mapping',
      'hostMappingHint': 'Used for domain fronting',
      'proxyAddress': 'Proxy Address',
      'proxyAddressHint':
          'If you use proxy server, make sure to set it up correctly',
      'saveSuccess': 'Save success',
      'saveFailed': 'Save failed',
      'updateSuccess': 'Update success',
      'connectTimeout': 'Connect Timeout',
      'receiveTimeout': 'Receive Data Timeout',
      'enableSmartCache': "Smart Cache",
      'enableSmartCacheHint':
          "Keep viewed pages and images for the retention period; turn off to keep only a short-lived cache",
      'smartCacheRetention': "Cache Retention",
      'smartCacheRetentionHint':
          "Cache older than this is cleared automatically",
      'smartCacheMaxSize': "Max Cache Size",
      'smartCacheMaxSizeHint':
          "Cache is automatically trimmed when it exceeds this limit",
      'smartCacheEvictPolicy': "Eviction Policy",
      'smartCacheEvictPolicyHint':
          "Which cache entries are removed first when the limit is reached",
      'smartCacheEvictByAddedDate': "By added date",
      'smartCacheEvictByUsageFrequency': "By usage frequency",
      'unlimited': "Unlimited",
      'cacheSize': "Current Cache Size",
      'oneMinute': '1 Minute',
      'tenMinute': '10 Minute',
      'oneHour': '1 Hour',
      'oneDay': '1 Day',
      'threeDay': '3 Day',
      'enableLogging': 'Enable Logging',
      'enableVerboseLogging': 'Enable Verbose Logging',
      'openLog': 'Open Log',
      'clearLogs': 'Clear Logs',
      'longPress2Clear': 'Long press to clear',
      'checkUpdateAfterLaunchingApp': 'Check update after launching app',
      'checkClipboard': 'Check Gallery URL in Clipboard',
      'clearSuccess': 'Clear Success',
      'superResolution': 'Image Super Resolution',
      'stopSuperResolution': 'Stop Super Resolution',
      'deleteSuperResolvedImage': 'Delete Super Resolved Image',
      'superResolveOriginalImageHint':
          'Process original image cost more time, space and performance, are you sure to continue?',
      'verityAppLinks4Android12': 'Verity App Links(Android 12+)',
      'verityAppLinks4Android12Hint':
          'For Android 12+, you need to manually add link to verified links in order to open JHenTai in 3-rd apps',
      'noImageMode': 'No Image Mode',
      'exportData': 'Export Data',
      'exportDataHint': 'Export configs, block rules and history',
      'selectExportItems': 'Select Export Items',
      'importData': 'Import Data',
      'importDataHint':
          'App will shutdown automatically after importing to apply the latest configuration',

      /// host mapping page
      'hostDataSource':
          'No need to change by default.\nData source: https://dns.google/',

      /// proxy page
      'proxySetting': 'Proxy Setting',
      'proxyType': 'Proxy Type',
      'systemProxy': 'System',
      'httpProxy': 'HTTP',
      'socks5Proxy': 'SOCKS5',
      'socks4Proxy': 'SOCKS4',
      'directProxy': 'DIRECT',
      'address': 'Address',

      /// security setting page
      'enablePasswordAuth': 'Enable Password Auth',
      'enableBiometricAuth': 'Enable Biometric Auth',
      'enableAuthOnResume': 'Enable Auth on Resume',
      'enableAuthOnResumeHints': '3 seconds delay',
      'enableBlurBackgroundApp': 'Enable Blur Page When Switch to Background',
      'hideImagesInAlbum': 'Hide Images in Album',
      'hideImagesInAlbumHints':
          'If you changed default download path, you need to create .nomedia manually',

      /// read setting page
      'enableImmersiveMode': 'Enable Immersive Mode',
      'keepScreenAwakeWhenReading': 'Keep Screen Awake When Reading',
      'enableCustomReadBrightness': 'Enable Custom Brightness When Reading',
      'spaceBetweenImages': 'Space Between Images',
      'enableImmersiveHint': 'Hide System Bar',
      'enableImmersiveHint4Windows': 'Hide Title Bar',
      'deviceOrientation': 'Device Orientation',
      'landscape': 'Landscape',
      'portrait': 'Portrait',
      'readDirection': 'Read Direction',
      'enableOrientationSpecificReadDirection':
          'Orientation-Specific Read Direction',
      'enableOrientationSpecificReadDirectionHint':
          'Set different read directions for portrait and landscape orientations',
      'portraitReadDirection': 'Portrait Read Direction',
      'landscapeReadDirection': 'Landscape Read Direction',
      'autoSwitchedReadDirection': 'Auto-switched read direction',
      'notchOptimization': 'Notch Optimization',
      'notchOptimizationHint':
          'Add padding before the first image to avoid the notch and status bar',
      'imageRegionWidthRatio': 'Image Region Width Ratio',
      'portraitImageRegionWidthRatio': 'Portrait Image Width Ratio',
      'landscapeImageRegionWidthRatio': 'Landscape Image Width Ratio',
      'gestureRegionWidthRatio': 'Gesture Region Width Ratio',
      'useThirdPartyViewer': 'Use Custom Viewer',
      'thirdPartyViewerPath': 'Custom Viewer Path(Executable file)',
      'showThumbnails': 'Show Thumbnails',
      'showScrollBar': 'Show Scroll Bar',
      'showStatusInfo': 'Show Status at Bottom',
      'autoModeInterval': 'Turn Page Interval',
      'autoModeStyle': 'Auto mode style',
      'scroll': 'Scroll',
      'turnPage': 'Turn page',
      'top2bottomList': 'Top to Bottom (Continuous)',
      'left2rightSinglePage': 'Left to Right (Single Page)',
      'left2rightSinglePageFitWidth': 'Left to Right (Fit Width)',
      'right2leftSinglePage': 'Right to Left (Single Page)',
      'right2leftSinglePageFitWidth': 'Right to Left (Fit Width)',
      'left2rightDoubleColumn': 'Left to Right (Double Column)',
      'right2leftDoubleColumn': 'Right to Left (Double Column)',
      'left2rightList': 'Left to Right (Continuous)',
      'right2leftList': 'Right to Left (Continuous)',
      'enablePageTurnByVolumeKeys': 'Use volume key to turn page',
      'enablePageTurnByVolumeKeysHint':
          'On iOS, if the volume is at 0 or 100%, it will be adjusted automatically when entering the reader to support page turning, and restored on exit',
      'enablePageTurnAnime': 'Enable Turn Page Animation',
      'enableDoubleTapToScaleUp': 'Enable Double Tap to Scale up',
      'enableTapDragToScaleUp': 'Enable Tap Drag to Scale up',
      'enableBottomMenu': 'Enable Bottom Menu',
      'reverseTurnPageDirection': 'Reverse Page Turning Direction',
      'disableGestureWhenScrolling': 'Disable Gesture When Scrolling',
      'disablePageTurningOnTap': 'Disable Page Turning On Tap',
      'turnPageMode': 'Turn Page Mode',
      'turnPageModeHint': 'To next screen or next image',
      'enableImageMaxKilobytes': 'Enable Image Compression',
      'imageMaxKilobytes': 'Image Max Size',
      'imageMaxKilobytesHint':
          'Images larger than this size will be compressed',
      'image': 'Image',
      'screen': 'Screen',
      'preloadDistanceInOnlineMode': 'Preload Distance(Online)',
      'preloadDistanceInLocalMode': 'Preload Distance(Local)',
      'ScreenHeight': 'Screen',
      'preloadPageCount': 'Preload Page Count(Online)',
      'preloadPageCountInLocalMode': 'Preload Page Count(Local)',
      'failedImageRetryScope': "Retry Failed Images",
      'failedImageRetryScopeHint':
          "Scope when tapping a failed online image to reload it",
      'retrySingleImage': "Only the tapped image",
      'retryCurrentPageAndAfter': "Current image and after",
      'retryAllFailedImages': "All failed images",
      'continuousScroll': 'Continuous Scroll',
      'continuousScrollHint': 'Splice multiple images',
      'doubleColumn': 'Double Column',
      'displayFirstPageAlone': 'Display First Page Alone',
      'displayFirstPageAloneGlobally': 'Display First Page Alone(Globally)',
      'portraitDisplayFirstPageAlone': 'Portrait Display First Page Alone',
      'landscapeDisplayFirstPageAlone': 'Landscape Display First Page Alone',
      'toggleFullScreen': 'Toggle Full Screen',
      'keyboardShortcuts': 'Keyboard Shortcuts',
      'keyboardShortcutsHint': 'Customize read page keyboard shortcuts',
      'pressAnyKey': 'Press any key...',
      'unboundKey': 'Unbound',
      'clearKey': 'Clear',
      'resetAll': 'Reset All',
      'resetSuccess': 'Reset to default',
      'keyConflict': 'Key conflict',
      'fixedKeyHint': 'Fixed key, cannot be customized',
      'pressAnyKeyOrMouseSideButton': 'Press any key or side button...',
      'mouseButton4Name': 'Mouse Forward',
      'mouseButton5Name': 'Mouse Back',
      'toLeft': 'Turn Left',
      'toRight': 'Turn Right',
      'enableAutoScaleUp': 'Enable Auto Scale up Long Image',
      'enableAutoScaleUpHints': 'Make image width same as screen width',

      /// preference setting page
      'showR18GImageDirectly': 'Show R18G Image Directly',
      'defaultTab': 'Default Tab',
      'defaultDownloadTab': 'Default Download Tab',
      'showUtcTime': 'Show UTC Time for Gallery',
      'showDawnInfo': 'Show new dawn event',
      'showEncounterMonster': 'Show hentaiVerse monster encounter event',

      /// log page
      'logList': 'Log List',

      /// super resolution setting page
      'downloadSuperResolutionModelHint': 'Download Model From Github',
      'modelDirectoryPath': 'Model Directory Path',
      'upSamplingScale': 'Up Sampling Scale',
      'modelType': 'Choose Model',
      'x4plusHint': 'Take up more space but faster at most time',
      'x4plusAnimeHint': 'Take up less space but slower at most time',
      'enable4OnlineReading': 'Process Automatically While Reading Online',

      /// download page
      'local': 'Local',
      'reDownload': 'Re-Download',
      'delete': 'Delete',
      'deleteTask': 'Delete Task Only',
      'deleteTaskAndImages': 'Delete Task And Images',
      'unlocking': 'Unlocking',
      'unlocked': 'Unlocked',
      'parsingDownloadPageUrl': 'Parsing Ⅰ',
      'parsedDownloadPageUrl': 'Parsing Ⅰ',
      'parsingDownloadUrl': 'Parsing Ⅱ',
      'parsedDownloadUrl': 'Parsing Ⅱ',
      'waitingIsolate': 'Waiting',
      'downloaded': 'Downloaded',
      'downloadFailed': 'Download Failed',
      'unpacking': 'Unpacking',
      'completed': 'Completed',
      'needReUnlock': 'Need Re-Unlock',
      'reUnlock': 'Re-Unlock',
      'reUnlockHint': 'Attention! Re-unlock need to buy this archive again.',
      'downloadHelpInfo':
          'If you can\'t download and find errors like table doesn\'t exist in logs, please uninstall current app and re-install.',
      'localGalleryHelpInfo':
          'Load gallerys which is not downloaded by JHenTai. Add config in Download Setting -> Extra Gallery Scan Path and then refresh.',
      'localGalleryHelpInfo4iOSAndMacOS':
          'Load gallerys which is not downloaded by JHenTai. Put your gallerys in default download path and then refresh',
      'deleteLocalGalleryHint': 'Delete your local files',
      'priority': 'Priority',
      'highest': 'Highest',
      'default': 'Default',
      'newGalleryCount': 'New gallery count',
      'changePriority': 'Change Priority',
      'changeGroup': 'Change Group',
      'chooseGroup': 'Choose Group',
      'renameGroup': 'Rename Group',
      'deleteGroup': 'Delete Group',
      'existingGroup': 'Existing Group',
      'groupName': 'Group Name',
      'drag2sort': 'Drag to Sort',
      'switch2GridMode': 'Switch to Grid Mode',
      'switch2ListMode': 'Switch to List Mode',
      'multiSelect': 'Multi-Select',
      'multiSelectHint': 'Tap to select',
      'resumeAllTasks': 'Resume All Tasks',
      'pauseAllTasks': 'Pause All Tasks',
      'requireDownloadComplete': 'Require download complete',
      'operationHasCompleted': 'The operation has completed',
      'operationInProgress': 'The operation is in progress',
      'startProcess': 'Start Process',
      'multiReDownloadHint': 'You will re-download all selected gallerys.',
      'multiChangeGroupHint': 'You will change group of all selected gallerys.',
      'multiDeleteHint': 'You will delete all selected gallerys.',
      'blankImageHint':
          'Downloading the image returned an empty result, trying to re-parse.',
      'peakHoursHint':
          'Downloading original files during peak hours requires GP, and you do not have enough, downloading is paused.',
      'oldGalleryHint':
          'Downloading original files of this gallery requires GP, and you do not have enough.',
      'exceedLimitHint':
          'You have reached the image limit, and do not have sufficient GP to buy a download quota.',
      'deleteUpdatingDependentHint':
          'Another gallery\'s update relies on current gallery, you\'d better delete after update has completed.',
      'migrateToDownload': 'Migrate To 「Download」',
      'refresh': 'Refresh',

      /// download search page
      'simpleSearch': 'Simple',
      'regexSearch': 'Regex',

      /// search dialog
      'searchConfig': 'Search Config',
      'addTabBar': 'Add Tab Bar',
      'updateTabBar': 'Update Tab Bar',
      'addQuickSearch': 'Add',
      'updateQuickSearch': 'Update',
      'filter': 'Filter',
      'tabBarName': 'TabBar Name',
      'quickSearchName': 'Name',
      'pleaseInputValidName': 'Please input valid name',
      'sameNameExists': 'Same name exists',
      'sameConfigExists': 'Same config exists',
      'searchType': 'Search Type',
      'popular': 'Popular',
      'ranklist': 'Ranklist',
      'ranklistBoard': 'Ranklist',
      'watched': 'Watched',
      'history': 'History',
      'keyword': 'Keyword',
      'orderBy': 'Order by',
      'favoritedTime': 'Favorited Time',
      'publishedTime': 'Published Time',
      'backspace2DeleteTag': 'Backspace to Delete Tag',
      'searchGalleryName': 'Search Gallery Name',
      'searchGalleryTags': 'Search Gallery Tags',
      'searchGalleryDescription': 'Search Gallery Description',
      'onlySearchExpungedGalleries': "Only Search Expunged Galleries",
      'onlyShowGalleriesWithTorrents': 'Only Show Galleries With Torrents',
      'searchLowPowerTags': 'Search LowPower Tags',
      'searchDownVotedTags': 'Search DownVoted Tags',
      'pageAtLeast': 'Page At Least',
      'pageAtMost': 'Page At Most',
      'pagesBetween': 'Pages Between',
      'pageRangeSelectHint':
          'min <= 1000, max >= 10\nmin/max <= 0.8, max-min >= 20',
      'to': 'to',
      'minimumRating': 'Minimum Rating',
      'disableFilterForLanguage': 'Disable Filter For Language',
      'disableFilterForUploader': 'Disable Filter For Uploader',
      'disableFilterForTags': 'Disable Filter For Tags',
      'searchName': 'Search Name',
      'searchTags': 'Search Tags',
      'searchNote': 'Search Note',
      'allTime': 'All',
      'year': 'Year',
      'month': 'Mon',
      'day': 'Day',
      'favoriteHint': 'Qualifiers: tag/title/comment/favnote',

      /// popular page
      'getPopularListFailed': 'Get Popular List Failed',

      /// ranklist page
      'getRanklistFailed': 'Get Ranklist Failed',
      'getSomeOfGallerysFailed': 'Get Some of Gallerys Failed',

      /// history page
      'getHistoryGallerysFailed': 'Get Some of History Gallerys Failed',

      /// search page
      'search': 'Search',
      'searchFailed': 'Search Failed',
      'fileSearchFailed': 'File Search Failed',
      'tab': 'Tab',
      'openGallery': 'Open Gallery',
      'tapChip2Delete': 'Tap chip to delete\nLong press button to delete all',
      'accurateCountTemplate': '%s results',
      'hundredsOfCountTemplate': 'Hundreds of results',
      'thousandsOfCountTemplate': 'Thousands of results',

      /// about page
      'author': 'Author',
      'Q&A': 'Q&A',
      'telegramHint': 'You can ask your questions in github first',

      /// download setting page
      'downloadPath': 'Download Path',
      'changeDownloadPathHint':
          'Long press to change(do not use SD-Card or any system path). Will copy downloaded gallerys automatically and keep old files. If you meet any error, try to reset.',
      'resetDownloadPath': 'Reset Download Path',
      'extraGalleryScanPath': 'Extra Gallery Scan Path',
      'extraGalleryScanPathHint': 'To scan and load local gallerys',
      'singleImageSavePath': 'Single Image Save Path',
      'downloadOriginalImage': 'Original Image',
      'downloadOriginalImageByDefault': 'Choose Original Image By Default',
      'originalImage': 'Original',
      'resampleImage': 'Resample',
      'defaultGalleryGroup': 'Default Gallery Group',
      'prioritizeRecentGalleryGroups':
          'Prioritize Recently Used Gallery Groups',
      'defaultArchiveGroup': 'Default Archive Group',
      'never': 'Never',
      'manual': 'Manual',
      'always': 'Always',
      'longPress2Reset': 'Long Press to Reset',
      'needPermissionToChangeDownloadPath':
          'Need permission to change download path',
      'invalidPath':
          'Invalid Path. Avoid using SD-Card, system path or root path.',
      'downloadTaskConcurrency': 'Download Concurrency',
      'needRestart': 'Need restart',
      'speedLimit': 'Speed Limit',
      'speedLimitHint': 'Don\'t download too fast',
      'per': 'per',
      'images': 'images',
      'downloadTimeout': 'Download Timeout',
      'downloadAllGallerysOfSamePriority':
          'Download All Gallerys of Same Priority',
      'downloadAllGallerysOfSamePriorityHint':
          'Download only 1 gallery simultaneously in 1 group with highest priority by default',
      'alwaysUseDefaultGroup': 'Always Use Default Group',
      'enableStoreMetadataForRestore': 'Enable Store Metadata for Restore',
      'enableStoreMetadataForRestoreHint':
          'If disable this, you can\'t restore download tasks',
      'archiveDownloadIsolateCount': 'Archive Download Thread Count',
      'archiveDownloadIsolateCountHint':
          'Sum of threads for all tasks needs to be less than 10, otherwise the download will fail',
      'manageArchiveDownloadConcurrency': 'Manage Archive Download Concurrency',
      'manageArchiveDownloadConcurrencyHint':
          'Archive will wait until there are enough threads to download',
      'deleteArchiveFileAfterDownload':
          'Delete Archive .zip File After Download',
      'restoreDownloadTasks': 'Restore Download Tasks',
      'restoreDownloadTasksHint': 'Restore download tasks by metadata',
      'restoreDownloadTasksSuccess': 'Restore Download Tasks Success',
      'restoredCount': 'Restored task count',
      'restoredGalleryCount': 'Restored gallery count',
      'restoredArchiveCount': 'Restored archive count',
      'restoreTasksAutomatically': 'Restore Tasks Automatically',
      'restoreTasksAutomaticallyHint':
          'Restore tasks automatically when app launched',
      'brokenDownloadPathHint':
          'Seems your download path is broken, download function may be ineffective',
      'brokenExtraScanPathHint':
          'Seems your default local gallery path is broken, local gallery may be not recognized',
      'useJH2UpdateGallery': 'Use JH server to accelerate gallery updates',

      /// archive bot settings
      'archiveBotSettings': 'Archive Bot Settings',
      'archiveBotSettingsHint': 'Use archive bot to get archive links for free',
      'apiSetting': 'API Setting',
      'archiveBotProtocol': 'Protocol',
      'apiAddress': 'Address',
      'apiKey': 'Key',
      'apiKeyHint': 'Enter the key you got from Telegram bot',
      'dailyCheckin': 'Daily Check-in',
      'currentBalance': 'Current GP Balance',
      'checkBalanceFailed': 'Failed to get GP balance',
      'checkInFailed': 'Check-in failed',
      'checkInSuccess': 'Check-in success',
      'checkInSuccessHint': 'Got GP: %s, current total GP: %s.',
      'pauseDownloadByInvalidArchiveBotKey':
          'Archive bot settings is invalid, download paused',
      'chooseArchiveParseSource': 'Change Parse Source',
      'official': 'Official',
      'archiveBot': 'Archive Bot',
      'changeParseSource2Official': 'Change parse source to official',
      'changeParseSource2Bot': 'Change parse source to archive bot',
      'invalidParam': 'Invalid parameter',
      'invalidApiKey': 'Invalid API key',
      'banned': 'You have been banned',
      'fetchGalleryInfoFailed': 'Failed to get gallery info',
      'insufficientGP': 'Insufficient GP',
      'parseFailed': 'Parse failed',
      'checkedIn': 'Already checked in today',
      'serverError': 'Archive bot internal error',
      'useProxyServer': 'Use JHenTai Proxy Server',
      'useProxyServerHint': 'Route requests through JHenTai server',

      /// password setting dialog
      'setPasswordHint': 'Please input your password',
      'confirmPasswordHint': 'Please input your password again',
      'passwordNotMatchHint': 'Password not match, try again',

      /// cloud setting page
      'serverCondition': 'Server Condition',
      'configSync': 'Config Sync',
      'configSyncHint': 'Store your config data in cloud(up to 50 entries)',
      'upload2cloud': 'Upload to Cloud',
      'upload2cloudHint': 'Upload your current local configuration',
      'tap2upload': 'Tap to upload',
      'copyIdentificationCodeSuccess':
          'Upload successfully. Identification code has been copied',
      'copyShareCode': 'Copy Share Code',
      'import': 'Import',
      'save2Local': 'Save to Local',
      'readIndexRecord': 'Read Progress',
      'quickSearch': 'Quick Search Config',
      'blockRules': 'Block Rules',
      'searchHistory': 'Search History',
      'galleryHistory': 'Gallery History',

      /// block rule page
      'configureBlockRuleFailed': 'Configure block rule failed',
      'removeBlockRuleFailed': 'Remove block rule failed',
      'inputNumberHint': 'Please input a correct number',
      'inputRegexHint': 'Please input a correct regex',
      'useBuiltInBlockedUsers': 'Enable Built-in User Blocklist',
      'useBuiltInBlockedUsersHint':
          'Filter out gallery comments from users on the blocklist',
      'blockingRules': 'Block Rules',
      'blockingRulesHint':
          'Additional blocking rules for gallerys and comments',
      'blockingTarget': 'Blocking Target',
      'blockingAttribute': 'Blocking Attribute',
      'blockingPattern': 'Blocking Pattern',
      'blockingExpression': 'Blocking Expression',
      'contain': 'Contain',
      'notContain': 'Not Contain',
      'regex': 'Regex',
      'comment': 'Comment',
      'tag': 'Tag',
      'userId': 'UserId',
      'content': 'Content',
      'incompleteInformation': 'Incomplete information',
      'noBlockingRuleHint': 'Add at least 1 rule',
      'notSameBlockingRuleTargetHint':
          'All sub-rules should have the same blocking target',
      'blockingRuleHelp': '''
Blocking Target: Filter galleries on the list page or filter comments on the details page. All sub-rules under the same rule must have the same blocking target.
Blocking Attribute: Specify the attribute of the target based on which the rule is written to block.
Blocking Pattern: Use regular expressions for complex scenarios.
Blocking Expression: Simple strings or regular expressions.

Note1: Different rules have an OR (||) relationship, while all sub-rules under the same rule have an AND (&&) relationship.
Note2: When blocking tag, the rule will check each tag in the gallery, the expression should be written for a single tag.
Note3: When blocking tag, you need specify full tag with namespace if you use '=' rule.
Note4: You need to use a gallery layout that can display all tags in E-Hentai, such as "Extended," otherwise some galleries may not be filtered correctly.

Example 1: Block galleries that have the "yaoi" tag and do not have the "tomgirl" tag————Gallery Tag Contain male:yaoi && Gallery Tag NotContain male:tomgirl
Example 2: Block comments with a score not exceeding 10————Comment Score <= 10
    ''',

      /// quick search page
      'quickSearch': 'Quick Search',

      /// dashboard page
      'seeAll': 'All',
      'newest': 'Latest',

      /// torrent dialog
      'outdated': 'Outdated',

      /// tag dialog
      'warningImageHint': 'R18G image, Tap to view',

      /// tagSet dialog
      'chooseTagSet': 'Choose Tag Set',

      /// tag namespace
      'language': 'Language',
      'artist': 'Artist',
      'character': 'Character',
      'female': 'Female',
      'male': 'Male',
      'parody': 'Parody',
      'group': 'Group',
      'mixed': 'Mixed',
      'Coser': 'Coser',
      'cosplayer': 'Cosplayer',
      'reclass': 'Reclass',
      'temp': 'Temp',
      'other': 'Other',

      /// image text translation
      'imageTextTranslation': 'Image Text Translation',
      'translateImageText': 'Recognize and Translate This Page',
      'recognizingImageText': 'Recognizing image text…',
      'translatingImageText': 'Translating image text…',
      'showTranslation': 'Show Translation',
      'showOriginal': 'Show Original',
      'copy': 'Copy',
      'retry': 'Retry',
      'configure': 'Configure',
      'saveSetting': 'Save',
      'imageTranslationNoResult': 'No result to display',
      'imageTranslationConfigureHint':
          'Original text was recognized. Configure a translation provider in Advanced settings first.',
      'imageTranslationUnsupportedPlatform':
          'Image OCR is not available on this platform yet.',
      'imageTranslationOcrUnavailable':
          'OCR executable was not found. Install or configure Tesseract on desktop.',
      'imageTranslationOcrFailed':
          'Text recognition failed. Check the OCR language packs and image format.',
      'imageTranslationNoText': 'No text was recognized in this image.',
      'imageTranslationRequestFailed':
          'Translation request failed. Check the endpoint, key, and network.',
      'imageTranslationInvalidResponse':
          'The translation provider returned an invalid result.',
      'imageTranslationFailed': 'Image text translation failed.',
      'imageTranslationPaddleNotReady':
          'PaddleOCR runtime is not installed. Install it in Advanced settings first.',
      'imageTranslationDeletePaddleRuntime': 'Delete PaddleOCR Runtime',
      'imageTranslationDeletePaddleHint':
          'Remove the virtual environment and downloaded models.',
      'imageTranslationDeletePaddleConfirm': 'Delete the PaddleOCR runtime?',
      'imageTranslationEnableThinking': 'Enable Thinking',
      'imageTranslationEnableThinkingHint':
          'Off for faster translation; on for deeper reasoning.',
      'imageTranslationTranslateScope': 'Translate Scope',
      'imageTranslationScopeCurrent': 'Current page only',
      'imageTranslationScopeSubsequent': 'Current and following pages',
      'imageTranslationCachedRetranslate': 'Cached · Retranslate',
      'translationProgress': 'Translating @current/@total · @stage',
      'translationStageIdle': 'Preparing',
      'translationStageRecognizing': 'Recognizing',
      'translationStageTranslating': 'Translating',
      'translationStageMasking': 'Masking',
      'translationStageEmbedding': 'Embedding text',
      'translationStageDone': 'Done',
      'imageTranslationSourceUnavailable': 'The current image is unavailable.',
      'imageTranslationSettingHint': 'Configure OCR and translation provider',
      'imageTranslationOcrSection': 'Text recognition',
      'imageTranslationOcrHint':
          'Desktop uses local Tesseract by default. Install the required language packs.',
      'imageTranslationOcrExecutable': 'OCR executable',
      'imageTranslationOcrLanguage': 'OCR languages',
      'imageTranslationTranslatorSection': 'Translation provider',
      'imageTranslationTranslatorHint':
          'Uses an OpenAI-compatible Chat Completions endpoint. The key stays on this device.',
      'imageTranslationEndpoint': 'Endpoint',
      'imageTranslationModel': 'Model',
      'imageTranslationTargetLanguage': 'Target language',
      'imageTranslationApiTestHint':
          'Enter an API base URL and key, then test it to load its available models. The key stays on this device.',
      'imageTranslationProvider': 'API format',
      'imageTranslationOpenAICompatible': 'OpenAI-compatible',
      'imageTranslationApiBaseUrl': 'API base URL',
      'imageTranslationTestAndFetchModels': 'Test and fetch models',
      'imageTranslationFetchModelsFirst': 'Test the API and fetch models first',
      'imageTranslationApiTestSuccess':
          'Connection succeeded; @count models found',
      'imageTranslationApiTestFailed': 'API test failed: @error',
      'imageTranslationOcrDownloadHint':
          'Download tessdata_fast language models into the local Tesseract data directory. Choose a China mirror or the official source.',
      'imageTranslationOcrDataDirectory': 'OCR data directory',
      'imageTranslationChooseDirectory': 'Choose data directory',
      'imageTranslationDetectOcr': 'Detect local OCR',
      'imageTranslationOcrModelSource': 'OCR model source',
      'imageTranslationGiteeMirror': 'Gitee community mirror (China)',
      'imageTranslationGithubOfficial': 'Official GitHub source',
      'imageTranslationOcrInstalled': 'Installed',
      'imageTranslationOcrNotInstalled': 'Not installed',
      'imageTranslationOcrDetectFailed':
          'OCR detection failed. Check the executable path.',
      'imageTranslationOcrDirectoryRequired':
          'Choose or detect the OCR data directory first.',
      'imageTranslationOcrDownloadSuccess': 'OCR model downloaded.',
      'imageTranslationOcrDownloadFailed':
          'OCR model download failed. Try another source.',
      'imageTranslationOcrEngine': 'OCR engine',
      'imageTranslationPaddleHint':
          'The app creates an isolated Python environment in its data directory. PaddleOCR-VL-1.6 is downloaded from Hugging Face and may take some time.',
      'imageTranslationPaddleLanguage': 'PaddleOCR language',
      'imageTranslationOcrEngineAppleLiveText': 'Apple Live Text',
      'imageTranslationAppleLiveTextLanguage':
          'Apple Live Text recognition language',
      'imageTranslationAppleLiveTextHint':
          'On-device OCR via Apple Vision. Works on iOS and macOS, no model download needed.',
      'imageTranslationAppleLiveTextUnavailable':
          'Apple Live Text is only available on iOS and macOS.',
      'imageTranslationMethodSection': 'Translation method',
      'imageTranslationMethodAppleLiveText': 'Apple Live Text',
      'imageTranslationMethodCustom': 'Custom',
      'imageTranslationAppleLiveTextUseApi': 'Use third-party API for translation',
      'imageTranslationAppleLiveTextUseApiHint':
          'Reuse the same OpenAI-compatible / Anthropic API as the custom mode instead of Apple on-device translation.',
      'imageTranslationAppleLiveTextOnDeviceHint':
          'Recognition and translation both run on-device via Apple. On-device translation needs iOS 26 / macOS 26 or newer.',
      'autoTranslateGalleryText': 'Auto-translate titles & comments',
      'autoTranslateGalleryTextHint': 'Translate the gallery titles and comments you see on-device (requires Apple Live Text + Apple on-device translation).',
      'imageTranslationTranslationUnavailable':
          'Apple on-device translation needs iOS 26 / macOS 26 or newer. Turn on "Use third-party API" to translate on this system.',
      'imageTranslationTranslationFailed': 'Apple on-device translation failed.',
      'imageTranslationShow': 'Show translation',
      'imageTranslationHide': 'Hide translation',
      'imageTranslationRetranslate': 'Re-translate',
      'imageTranslationStart': 'Start translation',
      'imageTranslationSettings': 'Translation settings',
      'imageTranslationTranslationNotInstalled':
          'Apple on-device translation languages are not installed. Install them in System Settings → General → Language & Region → Translation Languages, or turn on "Use third-party API".',
      'imageTranslationTranslationNotInstalledIos':
          'Apple on-device translation languages are not installed. Install them in Settings → Translate → Downloaded Languages, or turn on "Use third-party API".',
      'imageTranslationPaddleRuntimePath': 'Paddle runtime',
      'imageTranslationPreparePaddle': 'Install runtime and download model',
      'imageTranslationPaddleReady': 'PaddleOCR runtime is ready.',
      'imageTranslationPaddlePrepareFailed': 'PaddleOCR setup failed: @error',
      'imageTranslationExportOverlay': 'Create translated overlay',
      'imageTranslationExporting': 'Creating…',
      'imageTranslationOverlaySaved': 'Translated overlay saved: @path',
      'imageTranslationOverlayUnavailable':
          'The translated lines do not match the text regions, so an overlay cannot be generated safely.',
      'imageTranslationOverlayFailed': 'Failed to create translated overlay.',
    };
  }
}
