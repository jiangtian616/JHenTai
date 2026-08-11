# Wave 6 lanCompute runtime

日期：2026-08-11
基线：`8370503c`
分支：`codex/p6-lan-compute-runtime`

本切片把已经冻结的 lanCompute v1 schema、`ocrCompute`/`translationCompute` 权限和现有加密 LAN v2 session 接成一个可测试的 runtime lifecycle。它只提供 runtime contract、EngineTask adapter 和 fake host 验证，不宣称真实设备、ONNX/llama 模型或 fallback 已经可用。

## Confirmed

- 新增 `lan_compute_runtime.dart`，提供 session envelope、host/client runtime、可注入的 `LanComputeExecutor`/`LanComputeEngineTaskAdapter`、timer/clock 注入和脱敏 audit sink。
- v2 authenticated session 以附加的 `lanComputeV1` capability 协商，并在既有 AEAD channel 内映射 `capabilityDescriptor`、`taskRequest`、`progress`、`cancel`、`terminalResult`、`terminalError`、`unsupported`。旧 request operation、login/history、人物 11 统一状态字段和既有 v2 envelope 没有改协议语义。
- host 每次收到 request 都重新检查 capability permission。OCR 只映射到 `ocrCompute`，translation 只映射到 `translationCompute`；descriptor ready、schemaHash、executor identity、model/config/prompt/input hash、deadline 和 commit gate 也在 request-time 校验。
- client 只在当前 task/generation/commit gate 仍匹配时提交结果；重复、迟到或过期 generation 的终态不会触发 commit。没有匹配 executor 或旧 peer 时返回明确的 `unsupported`，不影响旧操作。
- timeout/cancel 的 runtime contract 会发送显式 `cancel`；disconnect 只进入 disconnected 边界，不把 fallback 或 scheduler/admission 标记为 ready。生产 LAN timer 通过 adapter 接入，未改变现有调度策略。
- audit 只保留 task/device/capability/hash prefix、status 和 error code；不会写 Cookie、API key、完整原图或输入文本。

## State machine

```text
request
  -> validating
       -> unsupported / notAuthorized / hashMismatch / deadlineExceeded
       -> running -> progress*
                    -> terminalResult | terminalError
                    -> cancel -> terminalError(cancelled/deadline)
disconnect -> disconnected
```

`disconnected` 不自动 fallback，也不伪造终态；fallback、scheduler admission、队列重试和实际数据传输由后续切片决定。

## Test evidence

最小定向命令：

```text
flutter test --no-pub test/lan_compute_runtime_test.dart
```

结果：4 个 fake-host/runtime 测试通过，覆盖 authenticated v2 双端 session、descriptor/终态、request-time permission/hash rejection、stale generation/duplicate commit suppression 和 audit redaction。

尝试加入 progress/cancel/timeout 组合测试时，现有 `EngineTask` cancellation token 在同步 controller event re-entrancy 场景抛出 `Bad state: Cannot fire new event. Controller is already firing an event`，且 fake executor 的同步取消订阅使 progress 断言不稳定。按本波收敛要求，该未完成测试已移除并记录为 BLOCKED，没有把它包装成已验证行为；runtime 的 cancel/timeout 映射仍保留，待下一切片用独立、非重入的 EngineTask fake 修复后再验证。

## Official semantics recorded

- Dart `Future.timeout` 只让返回的 future 停止等待，原 source future 仍可能继续完成，因此 runtime 另发显式 task cancel，而不是只依赖 `Future.timeout`。见 [Dart Future.timeout](https://api.dart.dev/dart-async/Future/timeout.html)。
- WebSocket `close` 关闭 transport，不等价于应用层 compute task cancellation；本切片将断线状态和 task cancel 保持分离。见 [Dart WebSocket.close](https://api.dart.dev/dart-io/WebSocket/close.html) 与 [RFC 6455](https://www.rfc-editor.org/rfc/rfc6455.html)。

## BLOCKED / next slice

- BLOCKED：取消/超时/断线的端到端 EngineTask 测试，原因是既有 EngineTask cancellation event 的同步重入问题；下一波先修复或隔离该 fake/test contract，再补 progress、显式 cancel、deadline cancel、disconnect 断言。
- BLOCKED：真实 ONNX/llama executor、模型/config/prompt 目录、设备间真实数据 resolver、3-device LAN、性能/功耗和实际模型输出；当前只有 `DataRef` contract 与 fake executor。
- BLOCKED：fallback、scheduler admission、图片队列、UI、模型目录和自动重试；本切片没有把这些能力标记为 ready，也没有扩展到 scheduler 或 UI。
- 本次按停止指令只执行了定向测试和格式化，未重跑全量 `flutter test`、全量 analyze 或构建；这些属于后续审阅/集成门禁。
