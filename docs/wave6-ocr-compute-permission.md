# Wave 6 OCR compute 权限基础与迁移报告

日期：2026-08-11（Asia/Shanghai）
分支：`codex/p6-ocr-compute-permission`
基线：`b26eee79`（`codex/p4-integration`，本 worktree 初始为 detached HEAD）

## 结论

本切片完成独立的 `LanSharePermission.ocrCompute` 基础、既有信任记录的兼容读取、权限展示和定向测试。`ocrCompute` 与已有 `translationCompute` 是两个不同的 enum 值、JSON 名称和 UI 开关。

本切片没有接入远端 executor，也没有修改 `lan_protocol_v2.dart`、`lan_sharing_runtime.dart` 的 operation dispatch、统一状态字段或 engine adapter。当前权限仍是可信设备记录层的基础；实际 compute request-time authorization 必须由后续人物 5/14 在冻结的 LAN v2 消息和 handler 边界内接入。

## SCOPE 与冻结边界

研究链路为 `SCOPE → SEARCH → READ EXACT → VALIDATE → DECIDE/PATCH → VERIFY`。精读了当前基线的 Wave 6 分诊报告、主 checkout 中的 `JHENTAI_MULTI_AGENT_IMPLEMENTATION_PLAN.md` 人物 5/11/14 边界、权限模型、信任服务、repository、LAN 设置页、l10n 和可信设备测试。

当前实现 worktree 不包含 `JHENTAI_MULTI_AGENT_IMPLEMENTATION_PLAN.md`；该文件在同一仓库主 checkout `/Users/zhangxuanning/My Projects/JHenTai/` 和 Wave 6 报告中可定位。本分支没有复制或修改它。计划中与本切片直接相关的边界是：人物 5 冻结 LAN v2 envelope/capability schema，人物 11 的登录状态和应用历史保持独立 capability/权限，人物 14 后续负责 LAN 共享算力；实现切片只能增加后续消息/handler，不改变冻结结构。

## 改动文件

- `lib/src/model/lan_device_trust.dart`：新增 `LanSharePermission.ocrCompute`。
- `lib/src/pages/setting/network/lan/setting_lan_sharing_page.dart`：已信任设备的权限开关增加独立的 translation compute 和 OCR compute 两项；pairing dialog 原本遍历 enum，因此会自动显示 OCR 项。
- `lib/src/l18n/en_US.dart`、`lib/src/l18n/zh_CN.dart`、`lib/src/l18n/zh_TW.dart`：增加 `lanPermission_ocrCompute`。这三个 locale 是当前已有 LAN permission 文案的 locale；ko/pt/ru 在基线中本来就没有这一组 LAN permission key，本切片没有扩大到不相关的 locale 补全。
- `test/lan_device_trust_test.dart`：增加旧 JSON、未知权限、独立授权、稳定 round-trip、离线撤销重载和显示文案测试。
- `docs/wave6-ocr-compute-permission.md`：本报告。

没有修改 `lib/src/service/lan_device_trust_service.dart`、`lib/src/service/lan_trust_repository.dart` 的接口或 LAN runtime。现有 `setPermissions` 已提供本切片所需的本地撤销生命周期，因此只验证并复用它，没有新造数据库迁移接口。

## 权限生命周期与旧数据迁移证据

### 新记录与 JSON

1. pairing 的权限集合由用户选择直接写入 `TrustedLanDevice.permissions`；没有把 OCR 默认并入 translation，也没有默认授予新权限。
2. `TrustedLanDevice.toJson()` 使用现有 `permission.name` 写入 `permissions` 数组，并排序后输出。因此新增键是字符串 `ocrCompute`，不是 enum index。
3. `TrustedLanDevice.fromJson()` 继续只接受 `LanSharePermission.values` 中名称完全匹配的字符串，未知名称被丢弃；非字符串列表项也被忽略。
4. `TrustedLanDevice.fromJson()` 对缺失 `permissions` 字段继续使用空列表，保持旧行为。包含旧的 `translationCompute` 但没有 `ocrCompute` 的记录仍只有翻译算力权限。
5. repository 的 `schemaVersion` 仍为 `1`。本次没有改变外层 metadata 结构，因而没有凭空增加数据库版本或迁移步骤；新字段是既有权限数组中的可选新成员，旧记录不需要写入它。

### 撤销、离线旧记录与重连

`LanDeviceTrustService.setPermissions` 的现有顺序是：构造新权限集合 → `repository.updateDevice(updated)` 持久化 → 替换内存设备 → `disconnect(deviceId)` 关闭当前 session → 通知设置页。测试先保存 OCR+translation 权限、保持离线，再只保留 translation，最后用同一 repository 重新初始化 service，确认重载记录没有 OCR 权限。这样离线旧记录不会在重连时重新授予 OCR；重连读取的是持久化后的设备记录，而不是旧内存快照。

完整 `revokeTrust` 仍会先断开 session，再移除设备 metadata 和 inbound/remote credential。该路径和本切片的单权限撤销都没有把 token、cookie 或其他秘密写入普通 metadata。

### Claim → evidence → confidence → next check

| Claim | Evidence | Confidence | Next check |
| --- | --- | --- | --- |
| OCR 和 translation 是独立授权 | enum 有两个不同成员；测试分别构造 only-OCR/only-translation 集合；设置页有两个独立开关 | confirmed | 后续人物 14 在每个 compute request handler 做服务端逐请求权限检查 |
| 旧 JSON 缺失新权限仍保持旧行为 | `fromJson` 缺失 `permissions` 仍为空；只含 `translationCompute` 的 JSON 不会得到 OCR；定向测试通过 | confirmed | 集成时用真实历史 `trusted_devices.json` 做一次只读回归 |
| 未知权限安全忽略 | 现有解析通过名称匹配并 `whereType`；测试加入 `futureCompute` 和非字符串项 | confirmed | 若未来改变权限 schema，补版本化迁移测试 |
| round-trip 稳定 | `toJson` 对名称排序；测试验证 OCR/translation 的稳定数组和重载对象 | confirmed | 不要改用 enum index；若迁移到新 wire schema，单独定义版本 |
| 撤销后离线旧记录不能恢复授权 | `setPermissions` 持久化后断开；service 重载测试确认 OCR 不存在 | confirmed（本地记录层） | 远端 handler 接入后验证新任务拒绝、旧 session/迟到任务失效 |
| 真实 LAN executor 已可用 | 本切片没有远端 executor、协议 dispatch 或真机证据 | blocked / out of scope | 人物 5/14 完成 schema、handler、cancel、错误和真实 LAN 验收 |

## 权威依据

- [Dart enum 文档](https://dart.dev/language/enums)：enum 是固定值集合，`values` 提供所有值，`.name` 返回 enum 值名称。
- [Dart `EnumName.name` API](https://api.dart.dev/dart-core/EnumName/name.html)：`.name` 是声明 enum value 时使用的 source identifier；因此本项目继续用 `ocrCompute` 作为 JSON 字符串键。
- [Dart `jsonDecode` API](https://api.dart.dev/dart-convert/jsonDecode.html)：`jsonDecode` 解析并返回 JSON 对象；本项目继续在 `fromJson` 边界做类型过滤和未知名称忽略。
- [人物 5/11/14 实施计划](https://github.com/jiangtian616/JHenTai/blob/master/JHENTAI_MULTI_AGENT_IMPLEMENTATION_PLAN.md)：冻结 LAN v2 envelope/capability、统一状态独立权限和后续 LAN 共享算力验收边界。当前本地基线中的计划文件未随 worktree 提供，链接用于记录权威来源；本报告没有据链接宣称远端实现已完成。

## 测试与验证

已运行：

```text
dart format lib/src/model/lan_device_trust.dart lib/src/pages/setting/network/lan/setting_lan_sharing_page.dart lib/src/l18n/en_US.dart lib/src/l18n/zh_CN.dart lib/src/l18n/zh_TW.dart test/lan_device_trust_test.dart
flutter test test/lan_device_trust_test.dart
git diff --check
```

结果：

- 定向 trust 测试通过，`18` 项通过。
- 全量 `flutter test` 通过，`167` 项通过。
- `git diff --check` 通过。
- `flutter analyze --no-pub` 完成但以非零状态退出，报告 `443 issues found`；这些是仓库既有 info/warning 诊断。对本切片改动行做定向筛选时没有发现新增 error；locale 文件命中的命名和重复 key 诊断位于既有代码行。
- formatter 对基线设置页会产生整页无关重排；已恢复该噪声，仅保留两处权限开关插入。formatter 的依赖解析警告来自初次依赖未安装，随后 `flutter test` 完成 package resolution。

待运行或待确认：

- 未运行真实 LAN、三设备 mDNS、抓包、真实远端 executor、模型推理、性能或五端 UI 截图；本切片不伪造这些证据。

## 后续接入点与阻塞项

后续人物 14 需要在既有加密 LAN v2 channel 内增加独立 OCR/translation compute 消息和 request-time authorization，至少覆盖 task ID、model/config/schema hash、progress、cancel、timeout、终态 error/result、队列/admission 和 stale-result gate。人物 5 负责冻结消息 schema 与能力协商，人物 11 的统一状态字段保持不变。运行时接入必须读取当前 trusted device 的权限集合，撤销或 session generation 变化后拒绝新任务并丢弃迟到结果。

本切片的阻塞项是远端 executor、协议消息和真实设备验收尚未实现，这些是明确的后续范围，不是本地权限模型失败。没有声称 OCR/translation 已能通过 LAN 执行。
