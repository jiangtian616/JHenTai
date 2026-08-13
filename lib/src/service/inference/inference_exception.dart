/// 推理引擎尚未就绪时抛出（模型未接入 / 未下载 / 后端缺失）。
///
/// 框架阶段所有引擎都是 [InferenceNotReadyException] 的占位；接入真实模型
/// 后，引擎实现会改为抛出更具体的错误。
class InferenceNotReadyException implements Exception {
  const InferenceNotReadyException(this.engineName);

  /// 引擎标识，用于日志与 UI 定位。
  final String engineName;

  @override
  String toString() => 'InferenceNotReadyException: $engineName not ready';
}
