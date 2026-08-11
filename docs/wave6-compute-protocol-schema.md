# Wave 6A：LAN compute additive protocol schema

日期：2026-08-11
基线：b26eee79
分支：codex/p6-compute-protocol-schema

## 范围与结论

本切片只冻结协议拥有者需要的可序列化 contract，没有接入
lan_sharing_runtime.dart、权限模型、统一状态、engine adapter、远端
executor、scheduler、UI 或真实模型。旧 LanProtocolV2 的 envelope、AEAD、
版本协商和 capability 列表没有修改。

新增 lib/src/service/lan_compute_protocol.dart，定义独立的
lanCompute schema v1。它只携带输入/输出的 kind、SHA-256 和大小，不携带
原图、原文、Cookie、API key、代理密码、完整日志或任意自由文本错误。

## Wire contract

每条消息都包含以下 envelope 字段，并且 fromJson 拒绝未知字段：

| 字段 | 约束 |
| --- | --- |
| schema | 固定 lanCompute |
| version | 固定 1 |
| type | capabilityDescriptor、taskRequest、progress、cancel、terminalResult、terminalError 或 unsupported |
| schemaHash | 对稳定 schema descriptor 做 canonical JSON + SHA-256，必须与本地值相等 |

OCR 与 Translation 使用独立的 ocrComputeV1 和
translationComputeV1 capability 名称。LanComputeCapabilityDescriptor 必须
显式传递 ready 和 reason。ready: true 还必须有 reason: ready、
modelHash 和 configHash；不可用能力必须使用非 ready reason，不能因为
存在一个目录或 capability descriptor 就被当成 ready。

taskRequest 的核心字段为：

- taskId
- capability
- modelHash、configHash，以及适用时的 promptHash
- input: {kind, hash, sizeBytes}
- deadlineEpochMs
- executor: {deviceId, executorId, platform}
- commitGate: {targetId, generation, gateId}

progress 重复 task、capability、executor 和 commit gate，并携带有限枚举
stage、0..1 的 progress 和观测时间。cancel 携带明确的取消原因和时间。
terminalResult 只返回输出引用；terminalError 只返回脱敏枚举 code 和
retryable，没有远端自由文本。终态和进度重复 generation/commit gate，供
后续 runtime 丢弃迟到或旧代结果；本切片只提供纯字段比较
LanComputeProtocol.acceptsCommit，不执行提交。

## 严格校验与安全边界

- 所有 message constructor 和 fromJson 都校验 envelope、类型、必填字段、
  枚举、identifier 长度/字符、64 位十六进制小写 SHA-256、时间/代际安全整数、
  progress 范围和 artifact size（1..64 MiB）。
- 消息 canonical JSON 上限为 64 KiB。输入/输出只允许 bounded data
  reference，不允许把 bytes 或日志塞进 JSON。
- 未知字段一律拒绝；敏感字段名（Cookie、API key、authorization、password、
  proxy、secret、credential、token、原图/字节字段）走专门的脱敏拒绝路径。
- LanComputeProtocol.canonicalJson 复用现有
  LanProtocolV2.canonicalJson 的递归 key 排序，数组顺序保持不变；
  hashCanonical 对该确定性字符串做 SHA-256。
- generation、targetId 和 gateId 是 stale-result gate 所需的最小信息；
  任何实际 fallback、cache/UI 写入和取消执行都留给后续 runtime slice。

## 旧 peer 与未支持能力

LanComputeProtocol.negotiateSupport 使用独立 compute schema version 和
精确 capability 名称：

| 情况 | 行为 |
| --- | --- |
| peer version 不是 1 | unsupportedSchema，不接受 task |
| version 为 1 但没有目标 capability | unsupportedCapability，不接受 task |
| capability descriptor ready: false | 只能报告不可用 reason，不得启动 task |
| 已协商且 descriptor ready | 仅表示 contract 层可描述；不表示真实 executor 或模型通过 |

旧 v2 peer 不会因为本文件而自动获得新 capability。能够理解
lanCompute 的 peer 可以发送 unsupported 控制消息；完全不理解新 schema
的旧 peer 必须在协商阶段保持原有行为，调用方把缺少 schema/capability 当成
unsupported，而不是把未知消息当成成功。

## 官方语义依据

本切片沿用 triage 中已核对的官方语义，不把传输超时或连接关闭当作推理取消：

- Dart Future.timeout：https://api.dart.dev/dart-async/Future/timeout.html
  timeout 只停止等待替代结果，源 Future 仍可能稍后完成，因此需要显式
  cancel 和 generation gate。
- Dart WebSocket.close：https://api.dart.dev/dart-io/WebSocket/close.html
  关闭的是 WebSocket 连接，不是应用层 compute task。
- RFC 6455：https://www.rfc-editor.org/rfc/rfc6455.html
  Close 控制帧改变连接上的后续 data frame 发送规则，不能被当成可靠的
  application-level cancel message。
- NIST FIPS 180-4：https://csrc.nist.gov/pubs/fips/180-4/upd1/final
  SHA-256 作为内容引用的摘要算法；本协议仍要求调用方提供已核验的 hash，
  不把 hash 存在当成模型或输入真实可执行的证明。

## 验证

已执行：

    dart format lib/src/service/lan_compute_protocol.dart \
      test/lan_compute_protocol_test.dart
    flutter test --no-pub test/lan_compute_protocol_test.dart

定向结果：6 项通过。测试覆盖 canonical ordering/hash、ready/unavailable
descriptor、task/progress/cancel/result/error round-trip、旧 peer/未支持
capability、stale generation gate，以及 unknown/missing/oversized/bad hash/
secret field 拒绝。

本报告不把 host test 当作真实 LAN 或模型验收。以下仍未覆盖：两台或三台真实
设备、mDNS/重连/抓包、远端 executor、权限撤销、队列和内存 admission、真实
OCR/Translation 模型、取消/掉线 fallback、五端 UI 和性能数据。接入 runtime
前还必须由后续所有权切片补齐权限、scheduler、fake executor 双端测试和真实
设备证据。
