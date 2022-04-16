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
}
