# Wave 5 人物 15 独立全端验收报告

日期：2026-08-11（Asia/Shanghai）
验收 worktree：`/Users/zhangxuanning/My Projects/JHenTai-p5-full-acceptance`
验收分支：`codex/p5-full-acceptance`
基线：`codex/p4-integration@0e617c66cc07f6f5e00e3ce8339a0e96193f55e5`

## 总结

结论为 **PARTIAL，不能作为全端发布验收通过**。

- **PASS（本地确定性证据）**：`flutter test` 全部 `162` 项通过，退出码 `0`；推理安全默认、provider policy、canary 状态、像素预算、任务串行化、上下文批次 `1/2/4/8`、失败重试/取消、CTD/inpainting fallback、LAN 加密状态机和缓存/阅读队列测试均通过。
- **PASS（静态配置证据）**：Dart 依赖使用本地 `third_party/flutter_onnxruntime` `1.8.3`；Android 和 CocoaPods ORT pin 为 `1.23.0`；Apple Swift Package resolved 为 masicai fork `1.23.1`；Windows CMake 下载 fallback 为 `1.23.0`。这是源码/配置事实，不是设备运行时版本证明。
- **BLOCKED/UNVERIFIED（真实端到端）**：没有成功安装并运行本应用的真实 iPhone、Android、Windows 或 Linux 推理；没有真实模型加载、RSS/耗时、CoreML/NNAPI fault recovery、50 页/300 页长批次、三设备 LAN、抓包或 Apple 五端截图证据。
- **当前代码无产品改动**：本分支只新增本报告。计划文件被复制到验收 worktree 作为只读输入，保持未跟踪，不提交；主 worktree 和旧 p0 worktree 未修改。

因此 Wave 5 的集成门槛第 6、7、8、9 项（原生运行证据、目标平台截图、性能测量、计划可见行为）仍未满足，不能标记为全端 PASS。

## 环境与原始测量

本机命令探针记录如下，日志未包含 Cookie、token、API key 或其他秘密。

| 项目 | 原始结果 |
| --- | --- |
| 时间 | `2026-08-11T05:08:34Z` 环境探针；`2026-08-11T05:12:37Z` 收尾探针 |
| 主机 | Apple Silicon `darwin-arm64`，8 CPU，内存 `8589934592` bytes（8 GiB），磁盘约 460 GiB 总量、约 128 GiB 可用 |
| Flutter/Dart | Flutter `3.44.6` stable，framework `ee80f08bbf`；Dart `3.12.2` |
| Apple 工具链 | Xcode `27.0` (`27A5218g`)，macOS `27.0` (`26A5406e`) |
| 其他工具 | Java `26.0.0`，CMake `4.3.2` |
| Flutter devices | macOS desktop、Chrome `151.0.7922.76`、无线 `iPhone Air`（`00008150-00013C283482401C`，iOS `27.0`） |
| Android | `adb` 不存在；没有 Android 设备证据 |
| iOS 模拟器 | `xcrun simctl list devices available` 只有 `== Devices ==`，无可用 simulator |
| 内存/性能 | 未取得推理 RSS、峰值内存、每页耗时、吞吐或 native crash 计数；不能推断 |

## 执行命令与结果

1. `git -C /Users/zhangxuanning/My Projects/JHenTai status --short --branch`、`git rev-parse HEAD`：主 worktree 确认为 `codex/p4-integration`、`0e617c66...`，只有未跟踪的计划文件。
2. `git worktree move .../JHenTai .../JHenTai-p5-full-acceptance`：将原有干净的 `codex/p5-full-acceptance` worktree 安全移动到要求路径；未 reset、未 checkout、未丢弃改动。
3. `cp .../JHENTAI_MULTI_AGENT_IMPLEMENTATION_PLAN.md .../JHenTai-p5-full-acceptance/`：作为只读验收输入复制；未加入 Git。
4. `flutter pub get`：**PASS，退出码 0**；解析到本地 path override `flutter_onnxruntime 1.8.3`。依赖工具同时报告有 182 个可升级但不兼容的包，未升级。
5. `flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos`：**PASS（无 analyzer error，退出码 0）**；仍报告 443 条既有 info/warning，不能称为零问题或证明原生运行。主侧独立复跑默认 `flutter analyze --no-pub` 时退出码为 `1`，原因同样是这 443 条既有 info/warning 诊断，并未发现 analyzer error；因此本报告把“无 error”与“默认命令零诊断”明确区分。
6. `flutter test > /tmp/jhentai-wave5-flutter-test.log 2>&1`：**PASS，退出码 0**；Flutter 测试报告 `00:13 +162: All tests passed!`。日志中的 `Auto-connect trusted LAN device failed: peer_device_123456` 是测试注入的失败路径，测试随后通过，不是秘密或真实 peer。
7. `flutter build macos --debug --no-pub`：**BLOCKED**，默认入口不存在：`Target file "lib/main.dart" not found.`；仓库脚本和实际入口为 `lib/src/main.dart`。
8. `flutter build macos --debug -t lib/src/main.dart --no-pub`：**BLOCKED**，Xcode 报 `unable to attach DB .../build/macos/Build/Intermediates.noindex/XCBuildData/build.db: database is locked`，`** BUILD FAILED **`。未重试或清理用户 build 状态，故无 macOS app binary 证据。
9. 本轮没有等待真实设备、真实网络或真实模型资源；未执行 Android/Windows/Linux 构建、iPhone 部署、LAN 抓包或截图操作，避免把缺少环境伪装为通过。

## 原生推理链静态核对

这部分是源码/配置核对，结论均不等同于真实端运行。

| 平台 | 当前可确认的静态链路 | 运行时结论 |
| --- | --- | --- |
| Dart/plugin | `pubspec.yaml` 使用 `third_party/flutter_onnxruntime` path override，包版本 `1.8.3`；Dart API 暴露 `OrtProvider`、`OrtSessionOptions.providers/providerOptions`、`useArena` 等字段 | **CONFIRMED static / UNVERIFIED runtime** |
| Android | `third_party/flutter_onnxruntime/android/build.gradle` 依赖 `com.microsoft.onnxruntime:onnxruntime-android:1.23.0`；Kotlin 处理 CPU/CoreML/NNAPI/XNNPACK、`setCPUArenaAllocator(useArena)` 和 provider options，并返回 `ortVersion` | **CONFIRMED static / BLOCKED device**；未证明 APK 实际链接或 NNAPI driver 行为 |
| iOS | CocoaPods podspec 依赖 `onnxruntime-objc 1.23.0`；Swift 通过 `ORTSessionOptions` 注册 CPU/CoreML/XNNPACK、读取 `ORTVersion()` 和 CoreML availability | **CONFIRMED static / BLOCKED device** |
| macOS | CocoaPods podspec 同样声明 `onnxruntime-objc 1.23.0`；SPM package/resolved 使用 `https://github.com/masicai/onnxruntime-swift-package-manager` exact `1.23.1`，resolved revision `57f28b1fdd6fe33585370b146a46c597d6750953` | **CONFIRMED source pins / UNCERTAIN selected build path**；1.23.0 CocoaPods 与 1.23.1 SPM fork 的实际构建选择未完成验证 |
| Windows | CMake 在找不到系统 ORT 时下载 `onnxruntime-win-...-1.23.0.zip`；若找到系统 ORT 则版本取决于外部安装 | **CONFIRMED fallback / UNCERTAIN actual linked version** |
| Linux | C/C++ plugin 使用 `Ort::GetVersionString()` 和 provider mapping；本验收未获得发行包/系统 ORT 版本 | **UNCERTAIN actual linked version/provider set** |

源码可确认 provider 名称映射包括 `CPU`、`CORE_ML`、`NNAPI`、`XNNPACK`；实际可用 provider 必须由目标二进制运行时返回，不能用 enum 或字符串代替。Apple/Android 原生代码和 Dart 之间的参数传递链存在，但本轮没有完成 session create/run 的设备级 smoke。

一个需要后续责任人处理的风险是 Apple CocoaPods `1.23.0` 与 SPM resolved `1.23.1` 并存。它们可能属于兼容的 fork/包装选择，但没有构建产物和 `ORTVersion()` 运行日志前只能标记 **LIKELY risk / UNCERTAIN runtime**，本验收不擅自修改 vendored plugin。

## 矩阵逐项状态

状态含义：`PASS (local)` 只代表确定性 Dart/Flutter host 证据；`PARTIAL` 代表有局部静态/host 证据但缺少真实端；`BLOCKED` 代表环境、构建或资源使该项不能执行；`UNVERIFIED` 代表没有足够证据作正面判断。

### iOS / Android 推理安全

| 项目 | 状态 | 证据、缺口和所需环境 |
| --- | --- | --- |
| iOS 4 GiB/新 iPhone CPU OCR | **BLOCKED** | 发现无线 iPhone，但未完成 app build/deploy/run；4 GiB RSS、CPU session 和输入结果未测。需要签名可用的 iPhone、真实模型、运行日志和 Instruments/系统内存记录。 |
| iOS CoreML/ANE/CPU fallback | **BLOCKED** | 静态 Swift CoreML registration 可确认；没有 CoreML session/run、provider list、canary failure 或 fallback 证据。需要目标 iPhone/iPad、模型和可重复 fault/canary harness。 |
| iOS canary running/succeeded/failed | **PASS (local) / BLOCKED (native)** | `test/inference_setting_test.dart` 覆盖安全默认、canary `running` 持久化及同 key block、success 解锁；没有真实 session 创建/中断后的下一次启动证据。 |
| iOS 50 页/后台/内存压力 | **BLOCKED** | 未取得页面素材、真实 app run、后台切换或 RSS。 |
| Android CPU | **BLOCKED** | `adb` 不存在，无设备或 APK 安装证据。 |
| Android NNAPI | **BLOCKED** | 静态 Kotlin `addNnapi()` 和 ORT 1.23.0 依赖可见；没有 Android API/driver/provider list/session run。需要 Android 8.1+ 真机和 adb。 |
| Android NNAPI driver fault 持久回落 | **BLOCKED** | 无 driver fault 注入、重启后 canary blocked、CPU run 证据。 |
| Android 后台/内存压力 | **BLOCKED** | 无设备、生命周期脚本、RSS 或 native fault 记录。 |

### 桌面 OCR、翻译、模型

| 项目 | 状态 | 证据、缺口和所需环境 |
| --- | --- | --- |
| macOS OCR | **BLOCKED** | 正确 target 的 debug build 被 Xcode `build.db` lock 阻塞；未运行 app/session/model。需要独占、可复现的 Xcode build 状态后重新构建并执行真实 OCR。 |
| Windows OCR | **BLOCKED** | 当前主机为 macOS，未有 Windows runner/VM/安装包；无 ORT runtime/provider/模型证据。 |
| Linux OCR | **BLOCKED** | 当前主机无 Linux runner；CMake/system ORT 版本未形成 Linux binary。 |
| llama-server / 本地 FFI | **PARTIAL / BLOCKED runtime** | `docs/lan-compute-protocol-audit.md` 明确当前仅有本机子进程生命周期，缺少 LAN executor、模型/config hash 协商；`docs/context-translation-wave4-blockers.md` 明确没有真实 provider/model API smoke。需要真实 binary、GGUF、server 进程、协议和长批次日志。 |
| 模型下载/校验/加载/翻译/取消/删除 | **PARTIAL / BLOCKED runtime** | `test/onnx_model_manifest_test.dart` 只证明 manifest/host/hash 约束，未下载六个模型或运行六个模型生命周期。需要网络可用的干净缓存、逐模型 hash、session/run/取消/删除记录。 |
| 六个内置模型逐个生命周期 | **BLOCKED** | 没有模型资源和真实端，未宣称通过。 |

### 上下文翻译、CTD、inpainting、超分

| 项目 | 状态 | 证据、缺口和所需环境 |
| --- | --- | --- |
| 300 页持久化 | **PARTIAL / BLOCKED scale** | host 测试覆盖缓存 key、独立页面发布/持久化语义，但未执行 300 页长批次、磁盘容量、重启 hydrate 或 RSS。需要 300 页 fixture、真实引擎、可控磁盘/内存和重启脚本。 |
| 取消、失败、重试 | **PASS (local)** | `test/context_translation_service_test.dart` 覆盖失败页可重试、其他页不丢失、四种 batch size 取消；仅 deterministic fake engine。 |
| 上下文 `1/2/4/8` | **PASS (local) / UNVERIFIED runtime** | host 测试证明只暴露固定批次并正确分区；没有真实 provider/model structured request/response。 |
| CTD mask/inpainting | **PASS (local) / BLOCKED model** | `test/ctd_inpainting_test.dart` 覆盖 polygon mask、不可用状态、独立缓存、失败回 overlay、manifest pin；真实 CTD/inpainting session 未执行。 |
| 单页超分 | **PASS (local manifest/pixel) / BLOCKED runtime** | manifest、像素预算和队列测试通过；没有真实 Real-ESRGAN session、耗时、峰值内存或视觉结果。 |

### LAN、同步和 UI

| 项目 | 状态 | 证据、缺口和所需环境 |
| --- | --- | --- |
| 三台真实设备、mDNS churn | **BLOCKED** | host `lan_device_trust_test.dart` 使用 deterministic connector/discovery，不是三台设备或真实 mDNS。需要三台真实设备、同 LAN、可抓包的网络。 |
| 断线重连 | **PARTIAL local / BLOCKED real** | 本地状态机/可信设备测试覆盖关闭、重连、失效 session；未在真实网络断开/恢复下验证。 |
| 桌面服务器 | **BLOCKED** | 未启动真实桌面 server；当前审计文档明确未提交远端 compute executor。 |
| 登录/历史同步 | **PARTIAL local / BLOCKED real** | `lan_unified_state_test.dart`、可信设备测试提供 host 证据；无三设备真实同步、冲突和重连录像。 |
| 远端 OCR/翻译 | **BLOCKED** | `docs/lan-compute-protocol-audit.md` 明确没有 compute task/progress/cancel wire contract、remote executor 和 admission scheduler；不能把 capability 宣称 ready。 |
| 抓包检查 | **BLOCKED** | 未建立三设备会话或抓包文件；没有声称 payload/取消/权限在真实线上满足要求。 |
| Apple 风格五端截图 | **BLOCKED** | 没有 iOS/iPadOS/macOS/tvOS/visionOS 五端运行截图；当前 host 也没有完成 app build。 |
| 深浅色弹窗、底栏限制、缩略图、悬浮球、书签 | **PARTIAL local / BLOCKED visual gate** | 相关 host/widget/route/persistence 测试在 162 项中通过；无目标尺寸深浅色截图、交互录像或五端视觉比对，因此不能通过 UI 集成门槛。 |

## Confirmed / Likely / Uncertain

### Confirmed

- 主 worktree 是 `codex/p4-integration@0e617c66...`；验收在独立 `codex/p5-full-acceptance` worktree 完成，旧 p0 worktree 未触碰。
- `flutter pub get`、`flutter analyze --no-fatal-warnings --no-fatal-infos`（无 error）和完整 `flutter test` 成功；测试总计 `162` 项。默认 analyzer 命令仍会因既有 443 条 info/warning 返回非零，不能宣称零诊断。
- `InferenceSetting` 的安全默认是 `enableNnapi == false`、`enableCpuFallback == true`；确定性测试覆盖 provider policy、canary persistence/block、像素预算和 session/task serialization。
- `flutter_onnxruntime` 的 Dart package 版本和各 native 源码中的 ORT pins 如上表；源码存在 provider/options/version 查询链。
- 上下文翻译和 LAN 审计文档明确写出真实 provider/model smoke、真实 LAN compute executor 和五端 runtime 仍是阻塞项；本验收没有把 unavailable 当 ready。

### Likely

- 目标 build 若选择 CocoaPods，很可能使用 ORT `1.23.0`；若选择 Apple SPM，则很可能使用 resolved 的 masicai fork `1.23.1`。二者是否在应用实际构建中完全等价，需读取产物中的 `ORTVersion()` 并执行 session。
- provider 名称能从 plugin enum/mapping 传到原生，但“可用 provider”仍取决于最终 binary、OS、驱动和模型支持；静态 provider list 不能证明实际可执行。
- 本地 inference/context/LAN 测试是确定性 host 测试，主要证明状态/协议边界，不证明 native fatal fault、ANE/NNAPI driver、RSS 或真实网络行为。

### Uncertain

- 五端实际加载的 ORT 版本、provider 列表、CoreML/NNAPI/ANE/GPU 是否真正参与计算。
- canary 对真实 session create/run 中断、Android NNAPI driver fault、后台恢复和 CPU 回落的行为。
- 4 GiB 新 iPhone、50 页、300 页、六模型、真实 llama-server/FFI、CTD/inpainting/SR 的性能和稳定性。
- 三设备 mDNS、权限撤销、重连、远端 OCR/translation、取消与抓包结果。
- Apple 五平台实际 UI 行为、浅色/深色对比度和目标尺寸截图。

## 权威来源与结论

本轮只对与 provider/API 语义直接相关的官方或权威页面做了有限核对，未以旧版 ORT 行为推断当前运行时：

- [ONNX Runtime Execution Providers](https://onnxruntime.ai/docs/execution-providers/)：EP 会按目标环境提供并分配子图；应用必须以最终 runtime 的 provider 能力为准，静态 enum 不等于可用硬件。
- [ONNX Runtime CoreML Execution Provider](https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html)：CoreML EP 需要显式注册；页面列出的系统要求和注册方式不能替代目标设备 session/run 证据。
- [ONNX Runtime NNAPI Execution Provider](https://onnxruntime.ai/docs/execution-providers/NNAPI-ExecutionProvider.html)：NNAPI EP 需要显式注册，要求 Android 8.1+；driver、支持算子和 CPU fallback 仍需目标设备验证。
- [flutter_onnxruntime 1.8.3 Dart API](https://pub.dev/documentation/flutter_onnxruntime/latest/flutter_onnxruntime/) 与 [package version 1.8.3](https://pub.dev/packages/flutter_onnxruntime/versions)：确认 Dart 类/enum/API 文档版本；本仓库又以本地 path override 覆盖了 pub.dev 包，故仍需以本地 native 源和最终产物为准。
- [Flutter integration testing](https://docs.flutter.dev/testing/integration-tests)：真实设备/模拟器需要实际 app 和设备执行；本机没有 Android `adb`，没有可用 iOS simulator，故 host test 不升级为真实端 PASS。

## 回滚、迁移与限制

- 本次没有修改数据库、设置 schema、模型目录、协议版本或产品代码；新增文件只有本报告。
- 计划文件仅作为只读验收输入保留在 worktree，刻意不提交；删除本报告即可回滚本次验收产物。
- 未执行 `git reset`、`git checkout`、merge 或 push；没有接触人物 2/3 领域。
- 后续若要完成 BLOCKED 项，最小前置是：清理/隔离 Xcode build database 后重新构建；提供签名 iOS 与 Android 真机/adb；提供 Windows/Linux runner；提供六个带 hash 的模型和 300 页 fixture；提供三台同 LAN 设备、server、mDNS 与抓包；提供五端截图执行环境。每项都应保存原始命令、设备/OS/ORT/provider、RSS/耗时、模型 hash 和失败回落日志。

## 收尾状态

收尾前应执行并保持以下状态：

```text
git diff --check                 PASS
git status --short --branch      codex/p5-full-acceptance
                                 ?? JHENTAI_MULTI_AGENT_IMPLEMENTATION_PLAN.md
```

计划文件未纳入本次提交；最终提交 hash 由交付回复给出。
