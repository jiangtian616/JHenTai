class GalleryNote {
  final String note;

  final int usedSlot;

  bool get isFull => usedSlot >= 1000;

  const GalleryNote({required this.note, required this.usedSlot});
}
