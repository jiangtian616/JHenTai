# 第 6 波任务 A：LAN 共享算力协议分诊报告

日期：2026-08-11
分支：`codex/p6-lan-compute-triage`
基线：`97c21f1dda52d25d39cf076f9c307ebce3934470`

## TL;DR

结论为 **blocked，当前只提交审计报告，不提交运行时代码或测试切片**。

当前代码已经有可复用的安全 session、可信设备认证、权限枚举、引擎任务生命周期和本机缓存键，但没有把这些抽象连接成可执行的 LAN compute contract。特别是以下条件同时缺失

- v2 envelope 内没有 compute capability descriptor、compute task、progress、cancel 和终态错误/结果 schema。
- `translationCompute` 只有权限枚举和本地化文案，没有 `ocrCompute`，也没有对应的 v2 handler 或客户端调用。
- 本机 `EngineTask` 的取消、进度和错误没有跨 WebSocket 映射，现有 LAN timeout 只清除本地 pending state，不发送远端取消。
- `LanTaskQueue(maxConcurrent: 2)` 只包住图片读取/下载，没有队列上限、内存 admission 或 compute task ownership。
- 现有 `EngineCacheKey` 只在本机翻译/图像结果层生效，LAN 没有带 capability、model/config hash、prompt/schema version 的 task cache contract。
- 没有远端 executor、掉线后单次本机 fallback、迟到结果 commit gate 或任务级审计事件。

因此不能安全新增一个“看起来像 contract”的孤立类，也不能通过 loopback 伪造远端算力能力。人物 5 冻结的 LAN v2 envelope/capability schema 和人物 11 的统一状态字段均保持不变。

## SCOPE 与证据等级

语料范围是当前 worktree 的 LAN 协议、共享运行时、可信设备权限、统一状态服务、engine contract/adapter、相关测试和两份实施文档。研究链路为 `SCOPE → SEARCH → READ EXACT → VALIDATE → DECIDE`。

本次启用的证据面

1. **结构**：`lib/src/service`、`test`、`docs` 目录清单，确认实现文件、adapter、测试和报告存在。
2. **调用连接**：`lan_sharing_runtime.dart` 的 v2 session、secure channel、operation dispatch、handler 和 `_WebSocketLanPeerSession`；同时交叉检查权限、统一状态和 engine contract 的调用点。
3. **精确文本**：协议、运行时、权限模型、统一状态、engine contract 和定向测试的行级读取。
4. **重复测试证据**：已有 host loopback 测试、协议加密测试、engine lifecycle/cache 测试；本波没有新增真实远端 executor、三设备 LAN 或真实模型能力假通过。
5. **LSP**：尝试对 `LanProtocolV2`、`LanTaskQueue`、`LanSharePermission`、`EngineCacheKey` 做 references/documentSymbols 查询，但当前环境没有 Dart plaintext language server。该面标记为 unavailable，不把 lexical search 当作 semantic proof。

证据等级约定：`E4` 为精确代码/测试或官方规范，`E3` 为结构与多处调用交叉验证，`E2` 为单处代码或既有报告，`E1` 为待补真实运行证据。

## 已核对的结构与调用连接

### 协议和 session

- `lib/src/service/lan_protocol_v2.dart:10-26` 定义 v2、64 KiB plaintext 上限、32 KiB 图片 chunk 和当前 capability 列表。列表只有安全 session、图库 manifest/pagination、image chunk、cover cache、server status、login state、application history，没有 compute capability。
- `lib/src/service/lan_protocol_v2.dart:34-52` 只做能力交集和版本选择；`LanProtocolNegotiation.negotiate` 在 `:93-105` 只接受 v2，并返回空 capability set。
- `lib/src/service/lan_protocol_v2.dart:108-297` 提供 X25519、HKDF、XChaCha20-Poly1305、严格递增 sequence、重放/乱序拒绝和关闭时销毁 key。这是可复用的传输边界，不等于 compute task contract。
- `lib/src/service/lan_sharing_runtime.dart:891-991` 先校验 trusted device、fingerprint、签名、版本和 access token，再建立 secure channel 并发送 capability intersection。
- `lib/src/service/lan_sharing_runtime.dart:992-1023` 只分派 `list_galleries`、`gallery_manifest`、`cache_image`、`login_state` 和 `application_history`。未知 operation 被跳过，没有 compute handler，也没有显式 unsupported error。
- `lib/src/service/lan_sharing_runtime.dart:1733-1750` 的 channel 只负责加密发送/接收和 JSON object 检查；没有任务代际、结果提交门或取消协议。

### 权限、状态和人物 5/11 边界

- `lib/src/model/lan_device_trust.dart:7-14` 的 `LanSharePermission` 有 `translationCompute`，没有 `ocrCompute`。`rg` 结果显示 `translationCompute` 只在枚举、本地化文案和既有审计文本出现，没有 runtime 校验调用。
- `lib/src/service/lan_sharing_runtime.dart:1054-1209` 的权限检查按 `downloads`、`imageCache`、`loginState`、`applicationHistory` 执行；不存在 OCR/Translation compute 的逐请求检查。
- `lib/src/service/lan_device_trust_service.dart:19-65` 的 session contract 只暴露图片、登录状态和应用历史；没有 compute request API。
- `lib/src/model/lan_unified_state.dart` 与 `lib/src/service/lan_unified_state_service.dart` 继续保留人物 11 的 login/history 独立 capability、敏感字段 guard、合并和 tombstone 边界。本波不修改这些字段或序列化。
- `JHENTAI_MULTI_AGENT_IMPLEMENTATION_PLAN.md:491-528` 冻结人物 5 的 LAN v2 envelope/capability schema；`:556-580` 冻结人物 11 的统一状态同步规则；`:747-775` 的最终完成定义要求真实 LAN、加密、可撤销权限和可追踪错误。本报告只给后续接口请求，不越权改冻字段。

### engine contract、ONNX 和 llama

- `lib/src/service/engine/engine_contract.dart:21-232` 的 `EngineTask` 已统一 task ID、queued/running/succeeded/cancelled/failed、stage progress、cancellation token 和错误码。它是本机 adapter contract，不会自动成为 LAN wire contract。
- `lib/src/service/engine/engine_contract.dart:349-438` 的 OCR、Translation、Inpaint、Super Resolution 接口以 `isReady` 和 `EngineTask` 为入口，OCR 与 Translation 在本机是独立 adapter。
- `lib/src/service/engine/engine_contract.dart:441-489` 的 `EngineCacheKey` 包含 `sourceHash`、OCR model/config、translation model/config、`promptVersion` 和 `pipelineVersion`，并做 canonical JSON + SHA-256。它没有独立 `schemaHash` 字段，也没有 capability 或远端 executor identity。
- `lib/src/service/engine/manga_ocr_engine_adapter.dart:26-43` 明确 `isReady => false`，未验证模型 hash、词表和五平台 runtime 时返回 blocked artifact；不能把它发布为 LAN ready capability。
- `lib/src/service/engine/llama_cpp_ffi_engine.dart:123-140` 以实际 bridge availability、ABI/version 和模型 store 状态决定 ready；仅有模型目录不够。
- `lib/src/service/engine/llama_server_translation_engine.dart:41-60, 80-115, 170-231` 只启动本机 `llama-server` 子进程，等待 loopback `/health`，再调用 `/v1/chat/completions`。没有 LAN node executor、远端 model/config hash 协商或任务取消消息。

## 证据账本

| Claim | Evidence | Confidence | Next check |
|---|---|---|---|
| task ID 必须贯穿 wire、engine、progress、终态和 stale-write gate | 本机 `EngineTask.id`/progress 有统一 ID；v2 request 只有普通 request `id`，没有 compute task schema或generation | E4 | 冻结双端 compute schema，并测试重复、迟到和代际淘汰 |
| model/config/prompt/schema hash 必须进入 capability/task/cache | `EngineCacheKey` 有 source/model/config/prompt/pipeline；LAN payload 没有这些字段，`schemaHash` 不存在 | E3 | 明确 hash 来源、canonicalization、schema version/hash 与远端回报字段 |
| capability 不能只依赖 UI 或目录 | v2 capability 列表无 compute；server 只回交集；engine registry 另有 `isReady` 判断 | E4 | capability descriptor 必须带 capability、engine/model fingerprint、ready reason和权限要求 |
| OCR 和 Translation 必须独立授权 | engine kind 独立；权限只有 `translationCompute`，无 `ocrCompute`；runtime 无 compute auth check | E4 | 由协议/权限负责人增加独立权限、迁移、撤销和服务端逐请求拒绝测试 |
| timeout 不能代替取消 | `LanPendingRequestRegistry` timeout 只移除本地 pending；client timeout callback只清本地图片 assembly | E4 | timeout 后发送加密 cancel，验证远端终止、单次 fallback和迟到结果丢弃 |
| WebSocket close 不能代替应用任务取消 | 当前 runtime用 `socket.close` 清理 session；协议未定义 compute cancel | E4（官方规范） | 保持连接存活时传递 cancel；连接关闭只作为失联信号 |
| progress/error 必须有 wire contract | `EngineTaskProgress`/`EngineException` 仅在本机；v2只有 request/response和图片 chunk | E4 | 定义 progress、terminal result/error、cancelled/timeout/disconnected code并双端测试 |
| queue/concurrency/memory admission 未达标 | `LanTaskQueue(maxConcurrent: 2)` 只用于 `_imageTasks`；无 pending cap、byte budget、model memory estimate或 admission result | E4 | 为 compute 建独立 scheduler，固定并发、队列、输入 bytes 和内存预算，拒绝前置执行 |
| cache isolation 未达标 | 本机 `EngineCacheKey` 可隔离模型/config/prompt/pipeline；LAN 没有 task cache layer或 capability字段 | E3 | 由远端任务 key 绑定输入、OCR/translation capability、model/config/prompt/schema和pipeline hash |
| disconnect fallback 未达标 | session drain 只 completeAll 本地 pending；无 remote cancel、generation gate和本机 fallback orchestration | E4 | 测试掉线、超时、cancel race、一次 fallback及迟到成功不可写 cache/UI |
| audit logging 未达标 | runtime 只有请求异常/发现异常等通用日志，没有 task id、capability、device、admission、terminal outcome 的脱敏审计事件 | E3 | 定义不含密钥/原图的结构化 audit event，并测试 secret redaction |
| 人物 5/11 冻结边界可保持 | 本波只读协议、runtime、权限、统一状态和 engine contract，没有改冻结字段 | E4 | 后续由拥有者提交接口请求，经集成/独立验收后再接入 |

## 可实现 / 部分 / blocked 矩阵

| 能力 | 当前结论 | 原因 |
|---|---|---|
| 加密 v2 transport、序号、重放保护 | **可实现基础** | 已有 `LanSecureSession`，但不能推导 compute 完整性 |
| trusted device/session identity | **可实现基础** | 已有 fingerprint、签名、access token 和 permission set |
| OCR capability advertisement | **blocked** | 无 compute capability schema，且 manga-OCR 明确 not ready；ONNX readiness不能由目录代替 |
| Translation capability advertisement | **blocked** | `translationCompute`没有 wire/handler，llama 只有本机 adapter |
| OCR/Translation 独立权限 | **blocked** | 缺 `ocrCompute`，修改权限/序列化/撤销属于冻结边界请求 |
| task ID、hash、input schema | **部分** | 本机 engine/cache 有字段，LAN 没有可互通 schema |
| progress、cancel、timeout、error | **部分** | 本机 engine 有 lifecycle；LAN 只有普通 request timeout，没有显式 cancel或终态 contract |
| queue/concurrency/memory admission | **blocked** | 现有 image queue不具备 compute admission语义 |
| cache isolation | **部分** | 本机 key 足够作为输入，但远端缺 capability/executor/schema维度 |
| disconnect fallback/stale write | **blocked** | 没有远端 compute client、generation gate和单次 fallback |
| audit log | **blocked** | 没有任务级、脱敏、可关联的审计事件 |
| 最小独立 contract/test slice | **blocked for this wave** | 抽象、权限、runtime、adapter、scheduler 和 test fixture 仍未闭合；孤立切片会伪造完成度 |

## 安全边界和禁止绕过项

本波严格保留以下边界

- 不修改人物 5 冻结的 v2 envelope、既有 capability 字段、协议版本和 AEAD/session实现。
- 不修改人物 11 的 login/history capability、统一状态字段、敏感字段 guard、合并和 tombstone语义。
- 不把 `translationCompute` 复用为 OCR 权限，不以隐藏 UI 按钮代替服务端授权。
- 不把 WebSocket close、ping/pong、Dart `Future.timeout` 当作推理任务取消。
- 不把模型名、模型目录、进程存在或 `/health` 通过当作 `isReady`、模型 hash 或可执行能力证明。
- 不把 `LanTaskQueue(maxConcurrent: 2)` 直接当作 compute scheduler，不省略队列长度、内存 admission和拒绝错误。
- 不把本机 `EngineCacheKey` 自动宣称为 LAN cache contract，不省略 capability/model/config/prompt/schema维度。
- 不新增真实远端 executor、三设备 LAN、真实模型调用、抓包“假证据”或 loopback-only 的 production-ready 宣称。
- 不记录 API key、Cookie、代理密码、完整原图、模型下载凭据或其他秘密。审计日志只允许脱敏的 device/task/capability/hash prefix、状态和错误 code。

## 后续最小切片边界

本波不实现。下一次实现必须按所有权拆成可独立验收的 slices

1. **Protocol-owned schema**：冻结 capability descriptor、task request、progress、cancel、terminal result/error、错误码和 schema hash；规定旧 peer 的 intersection/unsupported行为。
2. **Permission-owned migration**：增加独立 `ocrCompute`，完成设置、序列化、默认值、撤销、服务端 request-time check；translation permission保持独立。
3. **Runtime-owned adapter**：在已有 encrypted v2 channel 上映射 `EngineTask`，明确 task ID、generation、hash、input type、progress、deadline、cancel state和executor identity；不得旁路 HTTP或明文 socket。
4. **Admission-owned scheduler**：独立于图片队列，固定 max concurrent、max queued、输入/输出 bytes、模型 memory budget，并在执行前返回可展示的 admission error。
5. **Client lifecycle**：timeout/disconnect先发 cancel（若连接仍可用），然后只执行一次本机 fallback；用 generation/commit gate拒绝迟到的远端结果和 cache/UI写入。
6. **Host test fixture**：使用注入的 fake OCR/Translation executor和两个 in-process authenticated host，验证权限拒绝、hash mismatch、progress、cancel、timeout、disconnect、fallback、cache isolation、admission和脱敏 audit。该 fixture不得声称真实模型或三设备通过。
7. **真实验收**：拥有真实设备、模型 hash、平台运行记录、抓包和内存测量后，才能进入人物 15 的 LAN 矩阵。

## 实施顺序

`协议 schema 冻结 → 独立权限与迁移 → runtime handler/client → scheduler/admission → fake host contract tests → 本机 adapter 接入 → 双设备真实验证 → 三设备/抓包/性能验收`

在第一个真实 executor 接入前，必须同时有 schema hash、model/config hash、权限撤销和 terminal error 的可重复测试；否则 capability 必须返回 unavailable/unsupported，不能返回 ready。

## 官方语义核验

以下结论来自官方 API/规范或上游项目文档，不是猜测

- [Dart `Future.timeout`](https://api.dart.dev/dart-async/Future/timeout.html)：timeout future停止等待并返回替代结果，但 source future 仍可能稍后完成。因此远端超时必须有显式取消和 stale-result gate。
- [Dart `WebSocket.close`](https://api.dart.dev/dart-io/WebSocket/close.html)：关闭 WebSocket 是关闭连接并发送 close information，不是应用层任务取消。
- [Dart `WebSocket.pingInterval`](https://api.dart.dev/dart-io/WebSocket/pingInterval.html)：ping/pong只用于判断连接是否失效；未及时 pong 会关闭连接，不能证明推理任务停止。
- [RFC 6455 §1.4、§5.5.1](https://www.rfc-editor.org/rfc/rfc6455.html)：发送 Close 后应用不得再发送 data frame，收到 Close 后还可能丢弃后续数据；不能把 close 当作可靠的 cancel message。
- [ONNX Runtime Execution Providers](https://onnxruntime.ai/docs/execution-providers/)：EP通过 capability分配模型子图，EP选项必须在 session/API层配置；模型目录存在不等于目标设备上的 EP/model ready。
- [ONNX Runtime Thread Management](https://onnxruntime.ai/docs/performance/tune-performance/threading.html)：session默认会使用线程池，intra/inter-op线程、执行模式和全局线程池都会影响并发与资源占用；LAN admission不能只用 Dart task count替代 native memory/thread budget。
- [ONNX Runtime Architecture](https://onnxruntime.ai/docs/reference/high-level-design.html)：多个线程可调用同一 session 的 `Run`，但具体 EP、模型和平台组合仍需验证；不能据此推断当前五端 adapter安全。
- [llama.cpp server README](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)：server支持 `/health`、OpenAI-compatible chat completions、`--parallel`、`/slots`状态和模型路径等显式运行参数；这些是 server API/进程能力，不是 JHenTai LAN task cancel、权限、hash协商或 fallback contract。当前代码的 loopback health + `/v1/chat/completions` 仅证明本机子进程路径。

## 需要用户/集成方提供的真实证据

以下证据不能由当前 host-only worktree 生成，也不应被静态测试替代

- 两台可信桌面设备的 v2 session 日志摘要和抓包结论，第三台设备用于最终矩阵。
- 每个可宣告 OCR/Translation capability 的真实模型、词表、projector/FFI bridge、版本和 SHA-256；不得只提供模型名称。
- 设备平台、CPU/GPU/内存、ONNX EP/session配置、llama.cpp commit/build 信息和峰值 RSS。
- 远端执行期间的 progress、cancel、timeout、disconnect、fallback、迟到结果处理原始记录。
- 权限撤销后新 task 被服务端拒绝的记录，以及历史/登录权限没有被 compute 权限旁路的记录。
- 不同 model/config/prompt/schema 组合的 cache key 与命中/未命中记录。
- 脱敏 audit log 样本，证明没有 API key、Cookie、代理密码、完整原图或模型凭据。

## 复现命令与结果

本波使用的定位/验证命令

```text
git status --short --branch
git rev-parse HEAD
git branch --show-current
rg -n 'translationCompute|ocrCompute|compute_capabilities|compute_task|compute_progress|cancel_compute|schemaHash|modelSha|configSha' lib test docs
rg -n "'op':|'type': 'request'|class _WebSocketLanPeerSession|pendingRequestTimeout" lib/src/service/lan_sharing_runtime.dart lib/src/service/lan_device_trust_service.dart
```

关键结果

- HEAD 为 `97c21f1dda52d25d39cf076f9c307ebce3934470`，分支为 `codex/p6-lan-compute-triage`。
- `translationCompute` 只在权限枚举、本地化文案和既有审计文档出现；`ocrCompute`、compute message 名称和 `schemaHash` 没有运行时代码命中。
- operation dispatch 只有五类既有 LAN operation；`_WebSocketLanPeerSession` 只有图片、图库、manifest、login/history pending registry。
- LSP 查询因当前环境没有 Dart plaintext language server 失败，已用精确读取、`rg` 调用连接和现有测试替代，未把 LSP 缺失解释为代码缺失。

本次实际执行

```text
flutter test test/lan_protocol_v2_test.dart test/lan_sharing_runtime_test.dart test/lan_device_trust_test.dart test/lan_unified_state_test.dart test/engine_contract_test.dart
git diff --check
git status --short --branch
```

实际结果

- `flutter test ...`：通过，`32` 项，终端输出 `All tests passed!`。测试覆盖 v2 capability/AEAD/replay、两端 loopback host session、权限/重连/撤销、统一状态 guard/merge，以及 engine task cancellation/cache/ONNX manifest。
- 测试输出包含两条预期的 `Auto-connect trusted LAN device failed` warning，来自故障重连测试；没有 test failure。
- `git diff --check`：通过。
- `git diff --cached --check`：暂存提交前通过。
- 最终 `git status --short --branch`：分支干净，只有预先存在的 `?? JHENTAI_MULTI_AGENT_IMPLEMENTATION_PLAN.md` 未跟踪；该文件不纳入本次提交。

## 决策

本波只新增本报告。它不改变协议、权限、统一状态、engine adapter、缓存、数据库、UI或模型目录；删除本文件即可回滚。只有在上面的 contract slices 和真实证据补齐后，才允许进入人物 14 的 LAN shared compute 实现与人物 15 的最终验收。
