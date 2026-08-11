# LAN 共享算力协议审计与阻塞报告

日期：2026-08-11

分支：`codex/p4-lan-compute`

基线：`codex/p3-integration@d65c9108`

## 结论

本分支不提交 LAN 共享算力的 wire handler、调度器或远端 executor。当前代码可以安全确认协议的加密传输边界和可信设备边界，但不能在没有新增并验收整条生命周期的情况下，把远端 OCR 或 Translation 宣称为可用。

为了避免伪造能力，本报告不改变 `LanProtocolV2` 的 capability 列表、不改变现有 AEAD/session、不改变配对和 unified state，也不新增会被旧客户端误解的消息类型。

## 已核对的本地事实

1. `lib/src/service/lan_protocol_v2.dart` 的 v2 record 只提供加密、序号、重放保护和 64 KiB plaintext 上限。现有 `request` 分派只覆盖图库、图片缓存、登录状态和应用历史；没有 compute task、progress、cancel 或 capability descriptor schema。
2. `lib/src/service/lan_sharing_runtime.dart` 的服务端 session 已经绑定可信设备、access token、身份签名和 capability intersection。新增计算请求必须继续走该加密 `request` envelope，不能旁路 HTTP 或新增明文 socket。
3. `LanSharePermission` 已有 `translationCompute`，但没有独立的 `ocrCompute`。因此无法仅凭现有权限实现“分别授权 OCR 和 Translation”而不改变配对设置、序列化、权限撤销和服务端校验。
4. `MangaOcrEngineAdapter.isReady` 明确为 `false`，因为官方模型哈希、词表和五平台 runtime 尚未全部验证。
5. `LlamaCppFfiTranslationEngine.isReady` 依赖实际加载的维护版 FFI bridge、ABI 符号、版本和已校验 GGUF。当前代码把 bridge 缺失定义为 unavailable；不能把远端节点仅凭模型目录显示为 ready。
6. 桌面 `llama-server` adapter 是当前设备上的本地子进程生命周期。代码没有 LAN 节点上的 executor contract、模型/配置 hash 协商或远端临时输入文件生命周期。
7. 现有翻译持久缓存已经把模型、配置和 prompt version 纳入 `EngineCacheKey`。共享算力若不复用同一组 hash 字段，会产生跨模型或跨配置的错误命中。

## 官方语义对实现的硬约束

- Dart `Future.timeout` 只停止等待包装 future；原始 future 仍可能在稍后完成。因此远端超时后必须发送显式、加密的 cancel task 消息，并用 task generation/commit gate 丢弃迟到结果。见 [Dart Future.timeout](https://api.dart.dev/dart-async/Future/timeout.html)。
- Dart `WebSocket.close` 发起的是连接关闭握手，不是应用任务取消。RFC 6455 规定关闭握手开始后不会再可靠承载后续业务数据，因此不能用断开 socket 代替任务取消。见 [Dart WebSocket.close](https://api.dart.dev/dart-io/WebSocket/close.html) 和 [RFC 6455](https://www.rfc-editor.org/rfc/rfc6455.html)。
- Dart WebSocket 的 ping/pong 可用于判断连接失效，但不能证明推理任务已经停止。现有 `pingInterval` 只覆盖连接存活检查。见 [Dart WebSocket.pingInterval](https://api.dart.dev/dart-io/WebSocket/pingInterval.html)。

## 未满足的阻塞条件

以下任一条件缺失，都不能把远端 capability 标成 ready：

1. **双端 wire contract**：需要在现有 v2 envelope 内定义并测试 `compute_capabilities`、`compute_task`、`compute_progress`、`cancel_compute` 和终态结果/错误消息；字段至少包括 task ID、capability、模型 SHA-256、配置 SHA-256、输入类型、进度、超时、取消状态和可展示的错误原因。
2. **独立权限**：需要新增 `ocrCompute`，并让服务端按发起方的 trusted device permission 逐请求检查。未授权设备必须在执行前拒绝，不能仅由客户端隐藏按钮。
3. **真实 executor**：需要一个可注入且可验证的远端 executor。OCR 只能在实际收到裁切图后调用已 ready 的 adapter；Translation 优先接收 OCR blocks/text；API key、Cookie、代理密码和完整原图不能进入 payload 或日志。
4. **资源调度**：服务端需要固定的最大并发、队列长度和内存预算，并对每个 task 做 admission check。当前 runtime 的图片队列不能直接证明推理队列满足这些约束。
5. **取消和回落**：客户端必须在掉线/超时后显式取消远端，再只执行一次本机 fallback；迟到的远端成功不得再次写入翻译缓存或 UI 状态。
6. **缓存隔离**：任务缓存键必须同时包含输入 hash、模型 hash、配置 hash、prompt/schema version 和 capability。当前 LAN runtime 没有这一层 task cache contract。
7. **真实验收**：至少需要两台可信设备的 v2 session、权限撤销、远端掉线、取消传递、不同模型/配置隔离和抓包验证。静态测试或 loopback 单进程不能替代这些证据。

## 可安全回滚边界

本分支只新增本审计文件；它不改变运行时代码、设置、权限、协议版本、数据库或模型目录。删除本文件即可完全回滚，不影响 `codex/p3-integration`。

## 下一步最小实现顺序

1. 先由协议负责人冻结 compute message schema 和错误码，并为旧 peer 定义 capability intersection 行为。
2. 再由 LAN runtime 负责人新增独立 `ocrCompute` 权限、加密 task/progress/cancel handler 和服务端 admission scheduler。
3. 由 OCR/Translation 负责人分别提供带真实 model hash 的 executor；不可用 adapter 必须返回 unavailable，不得伪造 ready。
4. 最后用双设备测试验证取消、超时回落、stale-write 和缓存隔离，再接入阅读页翻译流程。
