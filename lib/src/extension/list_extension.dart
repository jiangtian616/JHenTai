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
}
