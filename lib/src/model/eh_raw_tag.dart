class EHRawTag {
  String? namespace;
  String key;

  bool get isFullTag => namespace != null;

  EHRawTag({this.namespace, required this.key});
}
