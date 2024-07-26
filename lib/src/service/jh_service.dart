abstract interface class JHLifeCircleBean {
  Future<void> onInit();

  Future<void> onReady();

  Future<void> onClose();
}
