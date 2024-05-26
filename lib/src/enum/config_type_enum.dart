enum CloudConfigTypeEnum {
  settings(1, 'settings'),
  blockRules(2, 'blockRules'),
  history(3, 'histories'),
  ;

  final int code;
  
  final String name;

  const CloudConfigTypeEnum(this.code, this.name);

  static CloudConfigTypeEnum fromCode(int code) {
    switch (code) {
      case 1:
        return CloudConfigTypeEnum.settings;
      case 2:
        return CloudConfigTypeEnum.blockRules;
      case 3:
        return CloudConfigTypeEnum.history;
      default:
        throw ArgumentError('Invalid code: $code');
    }
  }
}
