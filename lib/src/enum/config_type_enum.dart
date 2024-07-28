enum CloudConfigTypeEnum {
  readIndexRecord(1, 'readIndexRecord'),
  quickSearch(2, 'quickSearch'),
  blockRules(3, 'blockRules'),
  searchHistory(4, 'searchHistory'),
  history(5, 'galleryHistory'),
  ;

  final int code;

  final String name;

  const CloudConfigTypeEnum(this.code, this.name);

  static CloudConfigTypeEnum fromCode(int code) {
    switch (code) {
      case 1:
        return CloudConfigTypeEnum.readIndexRecord;
      case 2:
        return CloudConfigTypeEnum.quickSearch;
      case 3:
        return CloudConfigTypeEnum.blockRules;
      case 4:
        return CloudConfigTypeEnum.searchHistory;
      case 5:
        return CloudConfigTypeEnum.history;
      default:
        throw Exception('Unknown CloudConfigTypeEnum code: $code');
    }
  }
}
