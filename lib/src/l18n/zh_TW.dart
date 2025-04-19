import 'dart:core';

class zh_TW {
  static Map<String, String> keys() {
    return {
      /// common
      'yes': '是',
      'no': '否',
      'cancel': "取消",
      'OK': "確定",
      'reset': "重設",
      'success': "成功",
      'error': "錯誤",
      'failed': "失敗",
      'reload': '重新載入',
      'noMoreData': '到底囉~',
      'noData': '查無資料',
      'operationFailed': '操作失敗',
      'needLoginToOperate': '需要登入後才能操作',
      'hasCopiedToClipboard': "已複製到剪貼簿",
      'networkError': "網路錯誤，點擊重試",
      'systemError': "系統錯誤",
      'invalid': "無效",
      'internalError': "內部錯誤",
      'you': '你',
      'retryHint': '請重新整理後再試一次',
      'stop': '停止',
      'attention': '注意',
      'jump': '跳轉',
      'deleteAll': '刪除全部',
      'connectionTimeoutHint': '建立網路連線超時',
      'receiveDataTimeoutHint': '接收網路資料超時',
      'archiveError': '下載歸檔錯誤',
      'edit': '編輯',

      'home': "首頁",
      'gallery': "畫廊",
      'setting': '設定',

      /// unlock page
      'localizedReason': '請驗證以繼續',
      'tap2Auth': '點擊以驗證',
      'passwordErrorHint': '密碼錯誤，請重試',

      /// schedule
      'dawnOfaNewDay': '黎明之時',
      'encounterMonster': '你遭遇了一隻怪獸！',
      'encounterMonsterHint': '點擊跳轉至HentaiVerse戰鬥。',

      /// start page
      'TapAgainToExit': '再按一次退出',

      /// update dialog
      'availableUpdate': '有可用的更新!',
      'LatestVersion': '最新版本',
      'CurrentVersion': '目前版本',
      'check': '查看',
      'dismiss': '忽略',

      /// login page
      'login': '登入',
      'notLoggedIn': '未登入',
      'logout': '登出',
      'passwordLogin': '密碼登入',
      'cookieLogin': 'cookie登入',
      'youHaveLoggedInAs': '您已登入:   ',
      'cookieIsBlack': 'cookie為空',
      'cookieFormatError': 'cookie格式錯誤',
      'invalidCookie': '登入失敗或Cookie無效',
      'loginFail': '登入失敗',
      'userName': '使用者名稱',
      'EHUser': 'E站使用者',
      'password': '密碼',
      'needCaptcha': '觸發人機驗證。請另外選擇cookie登入或網頁登入。',
      'userNameOrPasswordMismatch': '使用者名稱或密碼錯誤',
      'copyCookies': '複製Cookies',
      'tap2Copy': '點擊複製',
      'webLoginIsDisabled': '桌面端無法使用Web登入',
      'loginSuccess': '登入成功',
      'userNameFormHint': '如果無法進入裡站，請嘗試Cookie登入',
      'tap2Login': '點擊登入',
      'parse': '解析',
      'igneousHint': 'igneous（裡站必帶）',
      'refreshIgneousFailed': '重新整理Igneous失敗',

      /// request
      'sadPanda': 'Sad Panda(無響應資料). 解決參考Github Wiki: https://github.com/jiangtian616/JHenTai/wiki/%E5%B8%B8%E8%A7%81%E9%97%AE%E9%A2%98',
      'sadPandaReferLink': 'https://github.com/jiangtian616/JHenTai/wiki/%E5%B8%B8%E8%A7%81%E9%97%AE%E9%A2%98',

      /// gallery card
      'filtered': '已過濾',

      /// gallery page
      'getGallerysFailed': "獲取畫廊資料失敗",
      'tabBarSetting': '標籤欄設定',
      'refreshGalleryFailed': '重新整理畫廊失敗',
      'jumpPageTo': '跳轉頁面至',
      'range': '範圍',
      'current': '目前',
      'galleryUrlDetected': '剪貼簿裡發現畫廊連結',
      'galleryUrlDetectedHint': '點擊進入詳情頁面',

      /// details page
      'read': '閱讀',
      'download': '下載',
      'favorite': '收藏',
      'rating': '評分',
      'torrent': '種子',
      'archive': '歸檔',
      'statistic': '統計',
      'similar': '相似',
      'downloading': "下載中",
      'resume': "繼續下載",
      'pause': '暫停',
      'finished': '已完成',
      'update': '更新',
      'submit': '送出',
      'chooseFavorite': '選擇收藏夾',
      'asYourDefault': '作為預設選擇',
      'Note': '備註',
      'addNoteHint': '新增備註前請先選擇收藏夾',
      'uploader': '上傳者',
      'allComments': '所有評論',
      'noComments': '暫無評論',
      'lastEditedOn': '最後修改於',
      'getGalleryDetailFailed': '獲取畫廊詳情失敗',
      'invisible2User': '此畫廊對您不可見',
      'invisibleHints': '畫廊已被刪除或對您進行了限制',
      'copyRightHints': '該畫廊因為版權已被刪除，版權作者：',
      'refreshGalleryDetailsFailed': '重新整理畫廊詳情失敗',
      'failToGetThumbnails': "獲取畫廊縮圖資料失敗",
      'favoriteGallerySuccess': "收藏畫廊成功",
      'favoriteGalleryFailed': "收藏畫廊失敗",
      'removeFavoriteSuccess': "取消收藏成功",
      'removeFavoriteFailed': "取消收藏失敗",
      'getGalleryFavoriteInfoFailed': '獲取畫廊收藏資訊失敗',
      'favoriteNoteSlotFullHint': '收藏備註已滿，無法新增備註',
      'ratingSuccess': '評分成功',
      'ratingFailed': '評分失敗',
      'voteTagFailed': '投票標籤失敗',
      'beginToDownload': '開始下載',
      'resumeDownload': '繼續下載',
      'pauseDownload': '暫停下載',
      'addNewTagSetSuccess': '新增標籤資料成功',
      'addNewWatchedTagSetSuccess': '新增關注標籤成功',
      'addNewHiddenTagSetSuccess': '新增隱藏標籤成功',
      'addNewTagSetSuccessHint': '你可以在 設定->EH->我的標籤 查看你的所有標籤',
      'addNewTagSetFailed': '新增標籤資料失敗',
      'VisitorStatistics': '閱覽資料',
      'invisible2UserWithoutDonation': '該畫廊統計資料對未贊助使用者不可見',
      'getGalleryStatisticsFailed': '獲取畫廊統計資料失敗',
      'totalVisits': '總閱覽量',
      'visits': '閱覽數',
      'imageAccesses': '圖片閱覽數',
      'period': '時間段',
      'ranking': '排行',
      'score': '分數',
      'NotOnTheList': '未上榜',
      'getGalleryArchiveFailed': '獲取歸檔資料失敗',
      'parseGalleryArchiveFailed': '解析錯誤，確保你e站的[Archiver Settings]設定的是[Manual Select, Manual Start (Default)]',
      'original': '原圖',
      'resample': '壓縮',
      'beginToDownloadArchive': '開始下載歸檔',
      'beginToDownloadArchiveHint': '可在 下載 -> 歸檔 確認進度',
      'updateGalleryError': '更新畫廊失敗',
      'thisGalleryHasANewVersion': '該畫廊有新版本',
      'hasUpdated': '已更新',
      'unpackingArchiveError': '解壓歸檔失敗',
      'failedToDealWith': '處理失敗',
      'hasDownloaded': '已下載',
      '410Hints': '下載此歸檔次數過多，你需要重新購買、解鎖後才能繼續下載',
      '429Hints': '下載請求過多！請減小歸檔下載並發度或稍後再試。',
      'getUnpackedImagesFailedMsg': 'JHenTai無法讀取此歸檔圖片，請檢查本機文件是否正常',
      'getGalleryTorrentsFailed': '獲取種子失敗',
      'chooseArchive': '選擇歸檔',
      'tagSetExceedLimit': '標籤數量已達到上限',
      'useTranslation': '使用翻譯標籤',
      'addTagSuccess': '新增標籤成功',
      'addTagFailed': '新增標籤失敗',
      'parentGallery': '父畫廊',
      'blockUploaderLocally': '於本機端隱藏的上傳者',

      /// detail dialog
      'galleryUrl': '畫廊連結',
      'title': '標題',
      'japaneseTitle': '日文標題',
      'category': '類別',
      'publishTime': '發表時間',
      'pageCount': '頁數',
      'favoriteCount': '收藏次數',
      'ratingCount': '評分次數',

      /// comment page
      'newComment': '新評論',
      'updateComment': '更新評論',
      'commentTooShort': '評論過短',
      'sendCommentFailed': '發送評論失敗',
      'voteCommentFailed': '投票評論失敗',
      'unknownUser': '未知使用者',
      'atLeast3Characters': '至少3個字元',
      'noJHenTaiHints': '請不要提及JHenTai，感謝理解',
      'blockUser': '隱藏使用者',

      /// EHImage
      'reloadImage': "重新載入圖片",

      /// read page
      'parsingPage': "解析頁面中",
      'parsingURL': "解析URL中",
      'parsePageFailed': "解析頁面錯誤，點擊重試",
      'parseURLFailed': "解析URL錯誤，點擊重試",
      'loading': "載入中",
      'paused': '已暫停',
      'exceedImageLimits': "超出圖片配額限制",
      'ehServerError': 'E站伺服器發生錯誤，請稍後重試',
      'unsupportedImagePageStyle': "JHenTai目前不支援Multi-Page Viewer(MPV)多頁查看，請在e-hentai.org更換為預設風格",
      'toNext': '下一頁',
      'toPrev': '上一頁',
      'back': '返回',
      'toggleMenu': '顯示/隱藏選單',
      'share': '分享',
      'save': '儲存至相簿',

      /// setting page
      'account': '帳戶',
      'EH': 'EH',
      'style': '樣式',
      'preference': '偏好',
      'network': '網路',
      'performance': '性能',
      'mouseWheel': '滑鼠滾輪',
      'advanced': '進階',
      'cloud': '雲端',
      'about': '關於',
      'security': '安全',
      'accountSetting': '帳戶設定',
      'styleSetting': '樣式設定',
      'advancedSetting': '進階設定',
      'ehSetting': 'EH 網站設定',
      'securitySetting': '安全設定',
      'readSetting': '閱讀設定',
      'preferenceSetting': '偏好設定',
      'downloadSetting': '下載設定',
      'networkSetting': '網路設定',
      'performanceSetting': '性能設定',
      'mouseWheelSetting': '滑鼠滾輪設定',

      /// eh setting page
      'site': '站點',
      'redirect2Eh': '優先重新導向至表站',
      'redirect2EhHint': '優先嘗試從表站載入畫廊詳情頁，以獲得更好的網路體驗，非必要不用關閉',
      'redirectAllGallery': '重新導向所有畫廊至表站',
      'imDonorHint': '如果你是贊助者，你可以打開此項來更容易進入裡站中的畫廊',
      'profileSetting': 'Profile設定',
      'chooseProfileHint': '選擇在JHenTai中使用的Profile',
      'siteSetting': '站點設定',
      'siteSettingHint': '更改E站個人設定',
      'showCookie': '查看 Cookie',
      'redirect2EH': '畫廊連結重新導向至表站(如果可用)',
      'redirect2Hints': '會先嘗試解析表站',
      'pleaseLogInToOperate': '請登入後操作',
      'imageLimits': '圖片配額',
      'resetCost': '長按重設，花費',
      'assets': '資產',
      'isNotDonator': '非捐贈者無法查看配額',
      'fetchImageQuotaFailed': '獲取圖片配額失敗',

      /// tag setting page
      'myTags': '我的標籤',
      'myTagsHint': '管理關注和隱藏的標籤',
      'localTags': '本機標籤隱藏',
      'localTagsHint': '額外的隱藏標籤',
      'localTagsHint2': '含有隱藏標籤的畫廊會被隱藏',
      'addLocalTags': '新增標籤',
      'hidden': '隱藏',
      'nope': '無',
      'getTagSetFailed': '獲取標籤資料失敗',
      'updateTagSetFailed': '更新標籤資料失敗',
      'updateTagFailed': '更新標籤資料失敗',
      'deleteTagSuccess': '刪除標籤資料成功',
      'deleteTagFailed': '刪除標籤資料失敗',
      'addLocalTagHint': '搜尋新增標籤',

      /// Profile Setting page
      'selectedProfile': '目前使用的Profile',
      'resetIfSwitchSite': '切換站點後將會自動重設',

      /// add host mapping dialog
      'addHostMapping': '新增自訂Host',

      /// Layout
      'mobileLayoutV2Name': '手機模式',
      'mobileLayoutV2Desc': '單列',
      'mobileLayoutName': '手機模式(舊)',
      'mobileLayoutDesc': '已停止維護',
      'tabletLayoutV2Name': '平板模式',
      'tabletLayoutV2Desc': '雙列',
      'tabletLayoutName': '平板模式(舊)',
      'tabletLayoutDesc': '已停止維護',
      'desktopLayoutName': '桌面模式',
      'desktopLayoutDesc': '雙列帶側欄，支援鍵盤操作',

      /// style setting page
      'layoutMode': '佈局模式',
      'enableTagZHTranslation': '開啟標籤中文翻譯',
      'version': '版本',
      'downloadTagTranslationHint': '下載資料中... 已下載: ',
      'zhTagSearchOrderOptimization': '標籤補全排序規則',
      'zhTagSearchOrderOptimizationHint': '預設智慧排序，啟用後按畫廊使用頻率排序',
      'themeMode': '主題模式',
      'dark': '黑暗',
      'light': '明亮',
      'followSystem': '跟隨系統',
      'themeColor': '主題顏色',
      'listStyle': '畫廊列表樣式(全域)',
      'flat': '平坦',
      'flatWithoutTags': '平坦 - 無標籤',
      'listWithoutTags': '卡片 - 無標籤',
      'listWithTags': '卡片',
      'waterfallFlowSmall': '瀑布流(小)',
      'waterfallFlowMedium': '瀑布流(中)',
      'waterfallFlowBig': '瀑布流(大)',
      'crossAxisCountInWaterFallFlow': '瀑布流列數',
      'pageListStyle': '畫廊列表樣式(頁面)',
      'crossAxisCountInGridDownloadPage': '下載頁網格顯示列數',
      'crossAxisCountInGridDownloadPageForGroup': '下載頁網格顯示列數(分組)',
      'crossAxisCountInGridDownloadPageForGallery': '下載頁網格顯示列數(畫廊)',
      'crossAxisCountInDetailPage': '詳情頁縮圖列數',
      'global': '全域',
      'auto': '自動',
      'moveCover2RightSide': '移動封面圖至右側',
      'coverStyle': '封面圖片樣式',
      'cover': '覆蓋',
      'adaptive': '自適應',
      'simpleDashboardMode': '精簡主頁面',
      'simpleDashboardModeHint': '隱藏排行榜和熱門模組',
      'hideBottomBar': '隱藏底部導航欄',
      'hideScroll2TopButton': '隱藏快速回頂按鈕',
      'whenScrollUp': '向上滾動時',
      'whenScrollDown': '向下滾動時',
      'preloadGalleryCover': '預先載入畫廊封面',
      'preloadGalleryCoverHint': '預先載入還未顯示在頁面上的畫廊的封面',
      'enableSwipeBackGesture': '允許透過左滑手勢返回',
      'enableLeftMenuDrawerGesture': '允許透過手勢喚起左側選單',
      'enableQuickSearchDrawerGesture': '允許透過手勢喚起快速搜尋',
      'drawerGestureEdgeWidth': '抽屜選單手勢區域寬度',
      'alwaysShowScroll2TopButton': '總是顯示快速回頂按鈕',
      'enableDefaultFavorite': '使用預設收藏夾',
      'enableDefaultFavoriteHint': '預設直接收藏，長按重新選擇',
      'enableDefaultTagSet': '關注標籤時使用預設標籤集',
      'enableDefaultTagSetHint': '預設直接關注，長按重新選擇',
      'disableDefaultTagSetHint': '手動選擇',
      'launchInFullScreen': '以全螢幕模式啟動',
      'launchInFullScreenHint': 'F11手動切換全螢幕',
      'disableDefaultFavoriteHint': '手動選擇',
      'searchBehaviour': '搜尋選項繼承',
      'inheritAll': '繼承全部',
      'inheritAllHint': '搜尋時使用上一次搜尋選項',
      'inheritPartially': '繼承部分',
      'inheritPartiallyHint': '搜尋時使用上一次搜尋選項（除開種類和語言）',
      'none': '無',
      'noneHint': '搜尋時使用新的初始搜尋選項',
      'showAllGalleryTitles': '顯示所有畫廊標題',
      'showAllGalleryTitlesHint': '同時顯示原標題和日文標題（如果可用）',
      'showGalleryTagVoteStatus': '顯示畫廊標籤投票狀態',
      'showGalleryTagVoteStatusHint': '包括可信、存疑與錯誤三種狀態',
      'showComments': '顯示畫廊評論',
      'showAllComments': '顯示畫廊所有評論',
      'showAllCommentsHint': '預設只會顯示45個最高分評論和5個最新評論，低分評論也會被自動隱藏',
      'addTag': '新增標籤',
      'addTagHint': '輸入新標籤，以逗號分隔',

      /// theme color setting page
      'themeColorSettingHint': '你可以為明亮和黑暗主題分配不同的主題色',
      'preview': '預覽',
      'preset': '預設',
      'custom': '自訂',

      /// performance setting page
      'maxGalleryNum4Animation': '下載頁支援列表動畫的最大畫廊個數',
      'maxGalleryNum4AnimationHint': '列表模式下，擁有超過此設定個數畫廊的分組在展開/收起時取消動畫效果',

      /// mouse wheel setting page
      'wheelScrollSpeed': '滑鼠滾輪速度',
      'ineffectiveInGalleryPage': '在畫廊頁面暫時無效',

      /// advanced setting page
      'enableDomainFronting': '開啟域名前置',
      'bypassSNIBlocking': '繞過SNI封鎖',
      'hostMapping': 'Host映射',
      'hostMappingHint': '用於域名前置',
      'proxyAddress': '代理伺服器地址',
      'proxyAddressHint': '如果你使用了代理伺服器，務必正確設定',
      'saveSuccess': '儲存成功',
      'saveFailed': '儲存失敗',
      'updateSuccess': '更新成功',
      'connectTimeout': '建立連線超時時間',
      'receiveTimeout': '接收資料超時時間',
      'pageCacheMaxAge': '頁面快取時間',
      'pageCacheMaxAgeHint': '你可以透過重新整理頁面來更新快取',
      'cacheImageExpireDuration': '圖片快取時間',
      'cacheImageExpireDurationHint': 'App啟動時會自動清除過期的圖片快取',
      'oneMinute': '1 分鐘',
      'tenMinute': '10 分鐘',
      'oneHour': '1 小時',
      'oneDay': '1 天',
      'threeDay': '3 天',
      'enableLogging': '開啟日誌',
      'enableVerboseLogging': '記錄全部日誌',
      'openLog': '查看日誌',
      'clearLogs': '清除日誌',
      'clearImagesCache': '清除圖片快取',
      'longPress2Clear': '長按清除',
      'checkUpdateAfterLaunchingApp': '啟動程式時檢查更新',
      'checkClipboard': '讀取剪貼簿中的畫廊連結',
      'clearPageCache': '清除頁面快取',
      'clearSuccess': '清除成功',
      'superResolution': '圖片超解析度',
      'stopSuperResolution': '停止圖片超解析度',
      'deleteSuperResolvedImage': '刪除圖片超解析度後的圖片',
      'superResolveOriginalImageHint': '處理原圖會耗費更多的時間、空間和性能，確定繼續？',
      'verityAppLinks4Android12': '驗證應用程式連結（安卓12+）',
      'verityAppLinks4Android12Hint': '對於Android 12+，您需要手動新增連結到已驗證連結才能在其他程式中喚起JHenTai',
      'noImageMode': '無圖模式',
      'exportData': '匯出資料',
      'exportDataHint': '匯出設定、隱藏規則與歷史記錄',
      'selectExportItems': '選擇匯出項',
      'importData': '匯入資料',
      'importDataHint': '在匯入成功後程式會自動關閉以套用最新設定',

      /// host mapping page
      'hostDataSource': '預設情況下不用改動。\n資料來源: https://dns.google/',

      /// proxy page
      'proxySetting': '代理設定',
      'proxyType': '代理類型',
      'systemProxy': '系統代理',
      'httpProxy': 'HTTP',
      'socks5Proxy': 'SOCKS5',
      'socks4Proxy': 'SOCKS4',
      'directProxy': 'DIRECT',
      'address': '地址',

      /// security setting page
      'enablePasswordAuth': '開啟密碼認證',
      'enableBiometricAuth': '開啟生物認證',
      'enableAuthOnResume': '切換至後台後重新認證',
      'enableAuthOnResumeHints': '需要切換至後台超過3s',
      'enableBlurBackgroundApp': '在工具列中模糊程式頁面',
      'hideImagesInAlbum': '在相簿中隱藏圖片',
      'hideImagesInAlbumHints': '如果你更改過預設下載路徑，你需要手動建立.nomedia文件',

      /// read setting page
      'enableImmersiveMode': '開啟沉浸模式',
      'keepScreenAwakeWhenReading': '閱讀時螢幕不自動鎖定',
      'enableCustomReadBrightness': '閱讀頁自訂亮度',
      'spaceBetweenImages': '圖片間隔',
      'enableImmersiveHint': '隱藏系統狀態欄和底部導航欄',
      'enableImmersiveHint4Windows': '隱藏頂部標題欄',
      'deviceOrientation': '螢幕方向',
      'landscape': '橫向',
      'portrait': '直向',
      'readDirection': '閱讀方向',
      'notchOptimization': '瀏海屏最佳化',
      'notchOptimizationHint': '在第一張圖片之前加入空白區域，以應對瀏海屏與狀態欄',
      'imageRegionWidthRatio': '圖片區域寬度比例',
      'gestureRegionWidthRatio': '選單手勢區域寬度比例',
      'useThirdPartyViewer': '使用第三方閱讀器',
      'thirdPartyViewerPath': '第三方閱讀器路徑（可執行文件）',
      'showThumbnails': '顯示縮圖',
      'showScrollBar': '顯示滾動條',
      'showStatusInfo': '底部顯示狀態資訊',
      'autoModeInterval': '自動模式翻頁時間',
      'autoModeStyle': '自動模式風格',
      'scroll': '連續滾動',
      'turnPage': '依次翻頁',
      'top2bottomList': '從上至下(連續)',
      'left2rightSinglePage': '從左至右(單頁)',
      'left2rightSinglePageFitWidth': '從左至右(自適應寬度)',
      'right2leftSinglePage': '從右至左(單頁)',
      'right2leftSinglePageFitWidth': '從右至左(自適應寬度)',
      'left2rightDoubleColumn': '從左至右(雙列)',
      'right2leftDoubleColumn': '從右至左(雙列)',
      'left2rightList': '從左至右(連續)',
      'right2leftList': '從右至左(連續)',
      'enablePageTurnByVolumeKeys': '使用音量鍵翻頁',
      'enablePageTurnAnime': '開啟翻頁動畫',
      'enableDoubleTapToScaleUp': '允許雙擊放大圖片',
      'enableTapDragToScaleUp': '允許單擊後拖曳放大圖片',
      'enableBottomMenu': '開啟底部選單',
      'reverseTurnPageDirection': '反轉翻頁方向',
      'disableGestureWhenScrolling': '滾動時停用手勢',
      'disablePageTurningOnTap': '停用點擊翻頁手勢',
      'turnPageMode': '翻頁模式',
      'turnPageModeHint': '移動至下一螢幕還是下一圖片',
      'enableImageMaxKilobytes': '開啟圖片壓縮',
      'imageMaxKilobytes': '圖片大小限制',
      'imageMaxKilobytesHint': '超過此大小的圖片將會被壓縮',
      'image': '圖片',
      'screen': '螢幕',
      'preloadDistanceInOnlineMode': '預先載入距離(線上模式)',
      'preloadDistanceInLocalMode': '預先載入距離(本機模式)',
      'ScreenHeight': '螢幕',
      'preloadPageCount': '預先載入圖片數量(線上模式)',
      'preloadPageCountInLocalMode': '預先載入圖片數量(本機模式)',
      'continuousScroll': '連續滾動',
      'continuousScrollHint': '拼接多個圖片',
      'doubleColumn': '雙列模式',
      'displayFirstPageAlone': '單獨顯示首頁',
      'displayFirstPageAloneGlobally': '單獨顯示首頁(全域)',
      'toggleFullScreen': '切換全螢幕',
      'enableAutoScaleUp': '自動放大長圖片',
      'enableAutoScaleUpHints': '優先使圖片寬度占滿螢幕',

      /// preference setting page
      'showR18GImageDirectly': '標籤資料中直接顯示R18G圖片',
      'defaultTab': '啟動時預設選單',
      'showUtcTime': '畫廊時間使用UTC顯示',
      'showDawnInfo': '顯示黎明之時事件',
      'showEncounterMonster': '顯示HV遭遇戰事件',

      /// log page
      'logList': '日誌列表',

      /// super resolution setting page
      'downloadSuperResolutionModelHint': '從Github下載模型',
      'modelDirectoryPath': '模型資料夾路徑',
      'upSamplingScale': '圖片放大倍數',
      'modelType': '選擇模型',
      'x4plusHint': '占據更多空間但大多數情況下更快',
      'x4plusAnimeHint': '占據更少空間但大多數情況下更慢',
      'enable4OnlineReading': '線上閱讀時自動處理圖片',

      /// download page
      'local': '本機',
      'delete': '刪除',
      'deleteTask': '僅刪除任務',
      'deleteTaskAndImages': '刪除任務和圖片',
      'reDownload': '重新下載',
      'unlocking': '解鎖歸檔中',
      'unlocked': '已解鎖',
      'parsingDownloadPageUrl': '解析Ⅰ',
      'parsedDownloadPageUrl': '解析Ⅰ',
      'parsingDownloadUrl': '解析Ⅱ',
      'parsedDownloadUrl': '解析Ⅱ',
      'waitingIsolate': '等待中',
      'downloaded': '下載完成',
      'downloadFailed': '下載失敗',
      'unpacking': '解壓中',
      'completed': '已完成',
      'needReUnlock': '需要重新解鎖',
      'reUnlock': '重新解鎖',
      'reUnlockHint': '注意！重新解鎖需要重新購買此歸檔！',
      'downloadHelpInfo': '如果發現無法下載，在日誌中發現了資料庫表不存在等問題，移除目前app重裝即可。',
      'localGalleryHelpInfo': '載入那些不是由JHenTai下載的畫廊(當做本機閱覽器)。在下載設定-額外的畫廊掃描路徑中設定，之後重新整理即可',
      'localGalleryHelpInfo4iOSAndMacOS': '載入那些不是由JHenTai下載的畫廊(當做本機閱覽器)。將你的畫廊放在預設下載路徑下，之後重新整理即可',
      'deleteLocalGalleryHint': '刪除您的本機文件',
      'priority': '優先度',
      'highest': '最高',
      'default': '預設',
      'newGalleryCount': '新掃描到畫廊數目',
      'changePriority': '改變優先度',
      'changeGroup': '改變分組',
      'chooseGroup': '選擇分組',
      'renameGroup': '重新命名分組',
      'deleteGroup': '刪除分組',
      'existingGroup': '現有分組',
      'groupName': '分組名稱',
      'drag2sort': '拖曳以排序',
      'switch2GridMode': '切換至網格模式',
      'switch2ListMode': '切換至列表模式',
      'multiSelect': '多選模式',
      'multiSelectHint': '點擊以選中',
      'resumeAllTasks': '復原所有任務',
      'pauseAllTasks': '暫停所有任務',
      'requireDownloadComplete': '需要等待下載完成',
      'operationHasCompleted': '操作已經結束',
      'operationInProgress': '操作正在進行中',
      'startProcess': '開始處理',
      'multiReDownloadHint': '你將會重新下載所有選中的畫廊。',
      'multiChangeGroupHint': '你將會改變所有選中畫廊的分組。',
      'multiDeleteHint': '你將會刪除所有選中的畫廊。',
      'peakHoursHint': '尖峰時段下載原圖需要耗費GP，由於你的GP不足，下載已自動停止。',
      'oldGalleryHint': '部分畫廊下載原圖需要耗費GP，由於你的GP不足，下載已自動停止。',
      'exceedLimitHint': '圖片配額已耗盡，由於你的GP不足，下載已自動停止。',
      'deleteUpdatingDependentHint': '有其他畫廊的更新依賴目前畫廊，此時刪除會影響其他畫廊的更新速度，推薦在更新完畢後再執行刪除操作。',
      'migrateToDownload': '遷移至「下載」',
      'refresh': '重新整理',

      /// download search page
      'simpleSearch': '簡單',
      'regexSearch': '正則',

      /// search dialog
      'searchConfig': '搜尋條件',
      'addTabBar': '新增標籤欄',
      'updateTabBar': '更新條件',
      'addQuickSearch': '新增',
      'updateQuickSearch': '修改',
      'filter': '篩選',
      'tabBarName': '標籤欄名稱',
      'quickSearchName': '名稱',
      'pleaseInputValidName': '請輸入有效的名稱',
      'sameNameExists': '存在相同的條件名稱',
      'sameConfigExists': '存在相同的搜尋條件',
      'searchType': '搜尋方式',
      'popular': '熱門',
      'ranklist': '排行',
      'ranklistBoard': '排行榜',
      'watched': '關注',
      'history': '歷史紀錄',
      'keyword': '關鍵字',
      'orderBy': '排序',
      'favoritedTime': '收藏時間',
      'publishedTime': '發表時間',
      'backspace2DeleteTag': '雙擊退格來刪除標籤',
      'searchGalleryName': '搜尋畫廊名字',
      'searchGalleryTags': '搜尋畫廊標籤',
      'searchGalleryDescription': '搜尋畫廊描述',
      'onlySearchExpungedGalleries': '僅搜尋已移除的畫廊',
      'onlyShowGalleriesWithTorrents': '只顯示有種子的畫廊',
      'searchLowPowerTags': '搜尋可信度較低的標籤',
      'searchDownVotedTags': '搜尋差評標籤',
      'pageAtLeast': '頁數至少',
      'pageAtMost': '頁數最多',
      'pagesBetween': '頁數範圍',
      'pageRangeSelectHint': 'min <= 1000, max >= 10\nmin/max <= 0.8, max-min >= 20',
      'to': '到',
      'minimumRating': '最低評分',
      'disableFilterForLanguage': '停用語言過濾',
      'disableFilterForUploader': '停用上傳者過濾',
      'disableFilterForTags': '停用標籤過濾',
      'searchName': '搜尋畫廊名稱',
      'searchTags': '搜尋畫廊標籤',
      'searchNote': '搜尋畫廊註解',
      'allTime': '總',
      'year': '年',
      'month': '月',
      'day': '日',
      'favoriteHint': '''
限定詞：
tag： 配對全命名空間內的標籤
title：同時配對羅馬音和日文的標題
comment：配對評論
favnote：配對收藏備註
      ''',

      /// popular page
      'getPopularListFailed': '獲取熱門畫廊列表失敗',

      /// ranklist page
      'getRanklistFailed': '獲取排行榜資料失敗',
      'getSomeOfGallerysFailed': '獲取部分畫廊資料失敗',

      /// history page
      'getHistoryGallerysFailed': '獲取瀏覽紀錄失敗',

      /// search page
      'search': '搜尋',
      'searchFailed': '搜尋失敗',
      'fileSearchFailed': '以圖搜圖失敗',
      'tab': '分頁',
      'openGallery': '打開畫廊',
      'tapChip2Delete': '點擊標籤刪除單條\n長按按鈕刪除全部',
      'accurateCountTemplate': '%s個結果',
      'hundredsOfCountTemplate': '數百個結果',
      'thousandsOfCountTemplate': '數千個結果',

      /// about page
      'author': '原作者',
      'Q&A': '常見問題',
      'telegramHint': '帳號登入、裡站、網路等基礎問題請自行搜尋解決',

      /// download setting page
      'downloadPath': '下載路徑',
      'changeDownloadPathHint': '長按來改變下載路徑(請不要使用SD卡或系統路徑)。會自動複製已下載的畫廊到新路徑，並保留原文件。如果你遇到相關錯誤，請嘗試重設路徑',
      'resetDownloadPath': '重設下載路徑',
      'singleImageSavePath': '單張圖片儲存路徑',
      'extraGalleryScanPath': '額外的畫廊掃描路徑',
      'extraGalleryScanPathHint': '掃描並載入本機畫廊的路徑。請不要使用SD卡或系統路徑',
      'longPress2Reset': '長按以重設',
      'downloadOriginalImage': '下載原圖',
      'downloadOriginalImageByDefault': '預設選中下載原圖',
      'originalImage': '原圖',
      'resampleImage': '壓縮',
      'defaultGalleryGroup': '預設分組（下載）',
      'defaultArchiveGroup': '預設分組（歸檔）',
      'never': '從不',
      'manual': '手動',
      'always': '總是',
      'needPermissionToChangeDownloadPath': '需要權限來改變下載路徑',
      'invalidPath': '無效的路徑。避免使用系統路徑、根路徑或sd卡。',
      'downloadTaskConcurrency': '同時下載圖片數量',
      'needRestart': '需要重啟',
      'downloadTimeout': '單次下載超時時間',
      'speedLimit': '速度限制',
      'speedLimitHint': '下載太快可能會被限制',
      'per': '每',
      'images': '圖片',
      'downloadAllGallerysOfSamePriority': '同一優先度時同時下載所有畫廊',
      'downloadAllGallerysOfSamePriorityHint': '預設情況下依優先度下載畫廊，且每個優先度下只會同時下載一個畫廊',
      'alwaysUseDefaultGroup': '總是使用預設分組',
      'restoreDownloadTasks': '復原下載任務',
      'enableStoreMetadataForRestore': '允許儲存下載的中繼資料用來復原下載記錄',
      'enableStoreMetadataForRestoreHint': '關閉此項後無法再復原下載記錄',
      'archiveDownloadIsolateCount': '歸檔下載同時下載數',
      'archiveDownloadIsolateCountHint': '所有任務同時下載數總和若超過10將導致下載失敗',
      'manageArchiveDownloadConcurrency': '控制歸檔下載並發數',
      'manageArchiveDownloadConcurrencyHint': '在有足夠的同時下載數之前，歸檔任務會保持等待狀態',
      'deleteArchiveFileAfterDownload': '歸檔下載完成後刪除原壓縮檔',
      'restoreDownloadTasksHint': '透過下載中繼資料來復原下載記錄',
      'restoreDownloadTasksSuccess': '復原下載任務成功',
      'restoredCount': '復原任務數',
      'restoredGalleryCount': '復原畫廊數目',
      'restoredArchiveCount': '復原歸檔數目',
      'restoreTasksAutomatically': '自動復原下載任務',
      'restoreTasksAutomaticallyHint': '程式每次啟動時嘗試復原下載任務',
      'brokenDownloadPathHint': '你的下載路徑似乎已經損壞，下載功能可能失效',
      'brokenExtraScanPathHint': '你的預設本機畫廊路徑似乎已經損壞，本機畫廊可能無法被識別',


      /// archive bot settings
      'archiveBotSettings': '歸檔機器人設定',
      'archiveBotSettingsHint': '使用歸檔機器人免費獲取歸檔連結',
      'apiKey': 'API Key',
      'apiKeyHint': '填寫您從 Telegram 機器人獲取的金鑰',
      'dailyCheckin': '日常簽到',
      'currentBalance': '目前 GP 餘額',
      'checkBalanceFailed': '獲取 GP 餘額失敗',
      'checkInFailed': '簽到失敗',
      'checkInSuccess': '簽到成功',
      'checkInSuccessHint': '獲得 GP：%s，目前總 GP：%s。',
      'pauseDownloadByInvalidArchiveBotKey': '歸檔機器人金鑰無效，下載已暫停',
      'chooseArchiveParseSource': '修改解析來源',
      'official': '官方',
      'archiveBot': '歸檔機器人',
      'changeParseSource2Official': '修改解析來源為官方',
      'changeParseSource2Bot': '修改解析來源為歸檔機器人',
      'invalidParam': '無效參數',
      'invalidApiKey': '無效的 API 金鑰',
      'banned': '您已被封禁',
      'fetchGalleryInfoFailed': '獲取畫廊資訊失敗',
      'insufficientGP': 'GP 不足',
      'parseFailed': '解析失敗',
      'checkedIn': '今日已簽到',
      'serverError': '歸檔機器人內部錯誤',
      'useProxyServer': '使用JHenTai代理伺服器',
      'useProxyServerHint': '通過JHenTai伺服器中轉請求',
      
      /// password setting dialog
      'setPasswordHint': '請輸入您的密碼',
      'confirmPasswordHint': '請再次輸入您的密碼',
      'passwordNotMatchHint': '密碼不一致，請重試',

      /// cloud setting page
      'serverCondition': '伺服器狀態',
      'configSync': '設定同步',
      'configSyncHint': '將您的設定資料儲存至雲端(最多50條)',
      'upload2cloud': '上傳至雲端',
      'upload2cloudHint': '上傳您目前的本機設定',
      'tap2upload': '點擊上傳',
      'copyIdentificationCodeSuccess': '上傳設定成功，已自動複製您的設定識別碼',
      'copyShareCode': '複製分享碼',
      'import': '匯入',
      'save2Local': '儲存至本機',
      'readIndexRecord': '閱讀進度',
      'quickSearch': '快速搜尋設定',
      'blockRules': '本機隱藏規則',
      'searchHistory': '搜尋紀錄',
      'galleryHistory': '畫廊瀏覽紀錄',

      /// block rule page
      'configureBlockRuleFailed': '設定隱藏規則失敗',
      'removeBlockRuleFailed': '刪除隱藏規則失敗',
      'inputNumberHint': '請輸入正確的數字',
      'inputRegexHint': '請輸入合法的正規表示式',
      'useBuiltInBlockedUsers': '使用內建使用者封鎖名單',
      'useBuiltInBlockedUsersHint': '過濾掉在名單中的使用者評論',
      'blockingRules': '隱藏規則',
      'blockingRulesHint': '針對畫廊和評論設定額外的隱藏規則',
      'blockingTarget': '隱藏目標',
      'blockingAttribute': '隱藏屬性',
      'blockingPattern': '隱藏規則',
      'blockingExpression': '隱藏表達式',
      'contain': '包含',
      'notContain': '不包含',
      'regex': '正則',
      'comment': '評論',
      'tag': '標籤',
      'userId': '使用者id',
      'content': '內容',
      'incompleteInformation': '請補充完整的資訊',
      'noBlockingRuleHint': '請至少設定一條規則',
      'notSameBlockingRuleTargetHint': '所有子規則的隱藏目標需要相同',
      'blockingRuleHelp': '''
    隱藏目標：在列表頁過濾畫廊或者在詳情頁過濾評論，同一規則下所有子規則的隱藏目標必須相同。
    隱藏屬性：根據目標的哪個屬性來編寫規則進行隱藏。
    隱藏規則：複雜場景可使用正規表示式配對。
    隱藏表達式：簡單字串或者正規表示式。
    
    注意1：不同規則之間是||的關係，同一規則下所有子規則之間是&&的關係。
    注意2：隱藏屬性為標籤時，規則會對畫廊的每一個標籤均進行校驗，表達式針對單個標籤進行編寫即可。
    注意3：隱藏屬性為標籤時，如果你使用'='規則，你必須準確填寫帶命名空間的完整標籤。    
    注意3：隱藏屬性為標籤時，如果你使用'='規則，你必須準確填寫帶命名空間的完整標籤。
    注意4：在E站官方設定中，你需要使用能夠展示所有標籤的畫廊布局如Extended，否則部分畫廊可能不會被正確過濾
    
    範例1：隱藏有男同標籤且無偽娘標籤的畫廊————畫廊標籤包含male:yaoi && 畫廊標籤不包含male:tomgirl
    範例2：隱藏評分不超過10分的評論————評論評分<=10
    ''',

      /// quick search page
      'quickSearch': '快速搜尋',

      /// dashboard page
      'seeAll': '查看全部',
      'newest': '最新',

      /// torrent dialog
      'outdated': '已過期',

      /// tag dialog
      'warningImageHint': 'R18G圖片，點擊以顯示',

      /// tagSet dialog
      'chooseTagSet': '選擇收藏標籤集',

      /// tag namespace
      'language': '語言',
      'artist': '作者',
      'character': '角色',
      'female': '女性',
      'male': '男性',
      'parody': '原作',
      'group': '團體',
      'mixed': '混合',
      'Coser': 'Coser',
      'cosplayer': 'Coser',
      'reclass': '重新分類',
      'temp': '暫時',
      'other': '其它',
    };
  }
}
