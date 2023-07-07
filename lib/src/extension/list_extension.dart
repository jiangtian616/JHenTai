extension ListExtension<E> on List<E> {
  List<E> joinNewElement(E newElement, {bool joinAtFirst = false, bool joinAtLast = false}) {
    if (length == 0) {
      return this;
    }

    List<E> newList = [];

    if (joinAtFirst) {
      newList.add(newElement);
    }

    for (int i = 0; i < length - 1; i++) {
      newList.add(this[i]);
      newList.add(newElement);
    }

    newList.add(this[length - 1]);
    if (joinAtLast) {
      newList.add(newElement);
    }

    return newList;
  }

  List<E> joinNewElementIndexed(E Function(int index) newElement, {bool joinAtFirst = false, bool joinAtLast = false}) {
    if (length == 0) {
      return this;
    }

    List<E> newList = [];

    if (joinAtFirst) {
      newList.add(newElement.call(-1));
    }

    for (int i = 0; i < length - 1; i++) {
      newList.add(this[i]);
      newList.add(newElement.call(i));
    }

    newList.add(this[length - 1]);
    if (joinAtLast) {
      newList.add(newElement.call(length - 1));
    }

    return newList;
  }

  void addIfNotExists(E element) {
    if (!contains(element)) {
      add(element);
    }
  }

  int? firstIndexWhereOrNull(bool Function(E element) test) {
    for (int i = 0; i < length; i++) {
      if (test(this[i])) {
        return i;
      }
    }
    return null;
  }
}
