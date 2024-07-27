enum ConfigEnum {
  /// app update
  firstOpenInited('firstOpenInited'),
  renameDownloadMetadata('renameDownloadMetadata'),
  migrateGalleryHistory('migrateGalleryHistory'),
  migrateStorageConfig('migrateStorageConfig'),
  
  /// settings
  favoriteSetting('favoriteSetting'),
  advancedSetting('advancedSetting'),
  downloadSetting('downloadSetting'),
  EHSetting('EHSetting'),
  mouseSetting('mouseSetting'),
  networkSetting('networkSetting'),
  performanceSetting('performanceSetting'),
  preferenceSetting('preferenceSetting'),
  readSetting('readSetting'),
  securitySetting('securitySetting'),
  siteSetting('siteSetting'),
  styleSetting('styleSetting'),
  superResolutionSetting('SuperResolutionSetting'),
  userSetting('userSetting'),
  downloadSearchPageType('downloadSearchPageType'),
  windowFullScreen('windowFullScreen'),
  windowMaximize('windowMaximize'),
  windowWidth('windowWidth'),
  windowHeight('windowHeight'),
  leftColumnWidthRatio('leftColumnWidthRatio'),

  /// config
  ehCookie('eh_cookies'),
  searchConfig('searchConfig'),
  dismissVersion('dismissVersion'),
  readIndexRecord('readIndexRecord'),
  quickSearch('quickSearch'),
  oldGalleryHistory('history'),
  searchHistory('searchHistory'),
  myTagsSetting('MyTagsSetting'),

  /// page config
  downloadPageBodyType('downloadPageGalleryType'),
  displayArchiveGroups('displayArchiveGroups'),
  displayGalleryGroups('displayGalleryGroups'),
  enableSearchHistoryTranslation('enableSearchHistoryTranslation'),
  tagTranslationServiceLoadingState('TagTranslationServiceLoadingState'),
  tagTranslationServiceTimestamp('TagTranslationServiceTimestamp'),
  tagSearchOrderOptimizationServiceVersion('TagTranslationServiceVersion'),
  tagSearchOrderOptimizationServiceLoadingState('TagSearchOrderOptimizationServiceLoadingState'),
  displayBlockingRulesGroup('displayBlockingRulesGroup'),

  /// cache
  isSpreadPage('isSpreadPage'),
  ;

  final String key;

  const ConfigEnum(this.key);
}
