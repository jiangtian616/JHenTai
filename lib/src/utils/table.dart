import 'package:get/get.dart';

class Table<K1, K2, V> {
  Map<K1, Map<K2, V>> data = {};

  V? get(K1 key1, K2 key2) {
    return data[key1]?[key2];
  }

  V? put(K1 key1, K2 key2, V value) {
    V? oldValue = data[key1]?[key2];
    data[key1] ??= {};
    data[key1]![key2] = value;
    return oldValue;
  }

  V? remove(K1 key1, K2 key2) {
    return data[key1]?.remove(key2);
  }

  bool containsKey(K1 key1, K2 key2) {
    return data[key1]?[key2] != null;
  }

  Map<K2, V>? operator [](K1 key1) {
    return data[key1];
  }

  Iterable<TableEntry<K1, K2, V>> entries() {
    return data.entries.mapMany((entry){
      return entry.value.entries.map((e) => TableEntry(entry.key, e.key, e.value));
    });
  }
}

class TableEntry<K1, K2, V> {
  final K1 key1;
  final K2 key2;
  final V value;

  /// Creates an entry with [key] and [value].
  const factory TableEntry(K1 key1, K2 key2, V value) = TableEntry<K1, K2, V>._;

  const TableEntry._(this.key1, this.key2, this.value);

  @override
  String toString() => "TableEntry($key1: $key2: $value)";
}
