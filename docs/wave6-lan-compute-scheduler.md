# Wave 6：LAN compute scheduler / admission / fallback

日期：2026-08-11
分支：`codex/p6-lan-compute-scheduler`
基线：`7b5eff04`（已包含 `lan_compute_runtime.dart`）

## 结论

本地可验收切片已完成。scheduler、admission、task cache key、fallback
commit gate、审计和取消竞态均有 host-only deterministic tests。真实设备、真实
ONNX/llama 推理、三设备 LAN、抓包和 native 峰值内存仍然是 **BLOCKED**，没有用
fake host 或模型目录把它们标成通过。

## 已完成

### 1. 独立 compute scheduler

新增 `lib/src/service/lan_compute_scheduler.dart`，不复用图片下载/预取队列。

- `maxConcurrent` 控制运行中任务数。
- `maxQueued` 控制等待队列长度。
- 每个 executor 必须提供 `LanComputeResourceEstimate`，包含 input、output 和
  model memory bytes；估算不完整或不匹配输入引用时拒绝。
- admission 前检查输入/输出单任务预算、单模型 memory 上限和已保留的总 model
  memory。
- admission 失败返回 `LanComputeAdmissionException`，包含稳定 reason、code 和
  displayable message；冻结的 wire schema 只发送已有的
  `resourceExhausted`，精确 admission reason 保留在脱敏 audit event。
- 任务完成、失败、取消和队列取消都会释放并发槽和 memory reservation；运行中
  cancel 通过 microtask 触发底层 `EngineTask.cancel`，避免同步 cancellation
  controller 重入。
- 实际输出超过已批准的 output reservation 时，scheduler 返回
  `resourceExhausted`，不会把超额结果交给 runtime commit。

### 2. 严格 LAN task cache key

`LanComputeTaskCacheKey` 使用 canonical JSON + SHA-256，固定包含：

`capability`、`inputHash`、`modelHash`、`configHash`、可选 `promptHash`、
`schemaHash` 和完整 executor identity（device/executor/platform）。

`LanComputeTaskCache` 使用最终 key hash 做隔离，并提供 `writeIfAbsent`。key 和
audit 都不携带输入原文、图片 bytes、Cookie、API key、token 或密码。

### 3. Runtime 接入和单次 fallback

- `LanComputeHostRuntime` 现在先做 request-time authorization/hash/input 检查，
  再经过独立 scheduler，最后才调用 executor。
- host lifecycle 覆盖 admitted/queued/running/progress/cancelled/timeout/
  disconnected/terminal 等事件。
- `LanComputeClientRuntime` 在 timeout、transport disconnect、显式 cancel 和
  remote cancelled/deadline terminal 上最多启动一次本机 fallback。
- fallback 没有注册时返回明确的 `fallbackUnavailable`，不会伪造成功。
- remote result 和 local fallback 共用 task generation/commit gate；当前 gate
  失效或已有 commit claim 时，迟到结果只进入 stale audit，不写 cache/UI。
- remote/fallback commit 都可接入严格 task cache；现有 `onCommit`、
  `onFallbackCommit` 只在一次 commit claim 后调用。

### 4. cancellation re-entrancy

保留既有同步 cancellation token 语义，只做最小生命周期修复：
`EngineCancellationToken.dispose()` 现在是幂等的，并把 synchronous
`StreamController.close()` 延到下一个 microtask。这样 adapter 在 cancel listener
中完成 cooperative cancellation 时，不会在同步事件派发期间再次 close controller。
runtime/scheduler 自身的 cancel 触发也统一延后；没有重写整个 engine contract。

## 验证结果

```text
dart format \
  lib/src/service/lan_compute_scheduler.dart \
  lib/src/service/lan_compute_runtime.dart \
  lib/src/service/engine/engine_contract.dart \
  test/lan_compute_scheduler_test.dart \
  test/lan_compute_runtime_test.dart

flutter test --no-pub test/lan_compute_scheduler_test.dart
# 6 tests passed

flutter test --no-pub \
  test/lan_compute_protocol_test.dart \
  test/lan_compute_runtime_test.dart \
  test/lan_compute_scheduler_test.dart \
  test/engine_contract_test.dart
# 21 tests passed

flutter test --no-pub
# 183 tests passed

flutter analyze --no-pub \
  lib/src/service/lan_compute_scheduler.dart \
  lib/src/service/lan_compute_runtime.dart \
  lib/src/service/engine/engine_contract.dart \
  test/lan_compute_scheduler_test.dart \
  test/lan_compute_runtime_test.dart
# no analyzer errors; only info-level style findings

git diff --check
# passed
```

新增测试覆盖：双端 in-process fake host、权限拒绝、hash/input validation、
maxConcurrent、maxQueued、input/output bytes、model memory、progress、cancel、
deadline timeout、disconnect single fallback、late result suppression、stale gate、
cache isolation、cache write-once、audit redaction 和 synchronous cancellation
re-entrancy。

## 官方语义依据

- [Dart `Future.timeout`](https://api.dart.dev/dart-async/Future/timeout.html)：
  timeout future 停止等待，但 source future 之后仍可完成；因此 timeout 不能替代
  explicit cancel 和 stale-result gate。
- [Dart `WebSocket.close`](https://api.dart.dev/dart-io/WebSocket/close.html)：
  close 关闭 WebSocket 并发送 close information；它不是 compute task 的应用层
  cancel acknowledgement。
- [Dart `SynchronousStreamController`](https://api.dart.dev/dart-async/SynchronousStreamController-class.html)：
  synchronous broadcast controller 在事件派发期间不能再次 add、close 或
  addStream；这是 microtask defer 和 `dispose` 幂等化的依据。
- [ONNX Runtime thread management](https://onnxruntime.ai/docs/performance/tune-performance/threading.html)：
  native session/thread-pool 参数会影响资源使用；本切片只接受 adapter 显式
  memory estimate，不把 Dart 并发数冒充 native RSS 证据。
- [ONNX Runtime Execution Providers](https://onnxruntime.ai/docs/execution-providers/)
  说明 provider/session 能力需要在目标 runtime 验证；本切片没有宣称真实
  provider 或模型 ready。

## 仍需外部验收 / BLOCKED

- 没有真实 OCR/translation adapter，因此 production client 的默认 fallback 是
  `fallbackUnavailable`；本地 fake executor 只验证 contract，不证明模型可用。
- 没有 iOS/Android/macOS/Windows/Linux 目标机上的 provider/session/run、模型
  memory、峰值 RSS、CPU/NNAPI/CoreML fault recovery 或长批次性能数据。
- 没有两台/三台真实可信设备上的加密 LAN session、mDNS churn、reconnect、权限
  撤销、远端 OCR/translation、packet capture 和 scheduler admission 证据。
- `LanComputeScheduler.close()` 对 native adapter 发出 cancel，但不会伪造底层
  future 已经停止；adapter 必须最终 settle 才会释放其 running reservation。
- protocol v1 terminal error 当前只有稳定 error code，没有额外 display message；
  因此远端 admission 的细 reason 仍通过本机 structured audit 和
  `LanComputeAdmissionException` 取得，不能从 wire error code 推断更多细节。

本切片没有修改 LAN v2 AEAD、人物 11 统一状态 schema、图片队列、UI 或模型目录。
