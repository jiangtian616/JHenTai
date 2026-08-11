# Wave 6B：macOS native build 与 ONNX Runtime 发布链核查

日期：2026-08-11（Asia/Shanghai）  
基线：`97c21f1d`（Wave 5 集成提交）  
工作区：独立 detached worktree `/Users/zhangxuanning/.codex/worktrees/592f/JHenTai`；主线未修改

## 结论

结论：**macOS 正确入口的 debug build 已确认可复现通过；Wave 5 的 `build.db locked` 是本次环境中的暂态 Xcode 状态，当前没有证据支持把它判定为项目配置错误。没有发现需要修改产品代码或发布配置的最小安全修复。**

默认 `flutter build macos --debug --no-pub` 仍然失败，因为 Flutter 默认寻找不存在的 `lib/main.dart`。仓库根目录脚本已经显式使用正确入口 `-t lib/src/main.dart`，因此本轮不把默认 CLI 失败改成产品代码修复；后续 CI/发布入口应继续统一使用该 target。

本轮没有把 build 成功升级为 ONNX Runtime session、模型加载、CoreML provider 或推理成功。最终 binary 确实包含由 Swift Package Manager 拉取并静态链接的 ORT 归档及 CoreML/XNNPACK 相关符号，但没有真实模型和 app-level MethodChannel/session/run 证据，`ORTVersion()` 返回值和实际 provider 使用仍为 **BLOCKED/UNVERIFIED**。

## Evidence ledger

| Claim | Evidence | Confidence | Next check |
| --- | --- | --- | --- |
| 正确 Flutter target 可构建 | `flutter build macos --debug -t lib/src/main.dart --no-pub` 退出码 0，输出 `Built .../jhentai.app` | Confirmed | 在独占 CI/发布机重跑 release、签名和归档 |
| 默认入口错误仍存在 | `flutter build macos --debug --no-pub` 退出码 1：`Target file "lib/main.dart" not found.` | Confirmed | 所有脚本/CI 显式传 `-t lib/src/main.dart` |
| Wave 5 build.db lock 非稳定配置错误 | 同一独立 worktree 后续正确 target build 成功；未清理 build 数据库 | Likely/strong local evidence | 若 CI 仍复现，记录并发进程、`build.db` 所属路径和完整 xcodebuild 日志 |
| macOS 选中的 ORT 来源是 SPM | 生成的 `FlutterGeneratedPluginSwiftPackage` 依赖 `flutter-onnxruntime`；`workspace-state.json` 有 masicai SPM checkout、artifact 路径和 checksum | Confirmed for this build | 运行 app 并从 `getRuntimeInfo` 记录 `ORTVersion`/providers |
| ORT artifact 具有 CoreML/XNNPACK 代码 | `libonnxruntime-macos.a` 为 arm64/x86_64 archive，`nm` 可见 `_OrtSessionOptionsAppendExecutionProvider_CoreML` 与 XNNPACK 符号 | Confirmed static | 真实 session 创建后核对 provider list 和运行日志 |
| SPM 版本号与 ORT payload 版本的关系 | resolved package version `1.23.1`；workspace artifact URL 为 `.../releases/download/1.23.1/onnxruntime-libs-1.23.0.zip`；plugin README 也声明 supported ORT `1.23.0` | Confirmed source/build metadata; runtime return unverified | 在 binary/runtime API 中记录 `ORTVersion()`，避免只依赖包版本号 |

## 原始命令与结果

### 环境

- Flutter `3.44.6` stable，framework `ee80f08bbf`，Dart `3.12.2`
- Xcode `27.0`，build `27A5218g`
- CocoaPods `1.17.0`（不是 `1.23.0`；Wave 5 所说的 `1.23.0` 是 podspec 声明的 ORT 依赖版本）
- macOS SDK `27.0`
- Apple Silicon，构建产物为 arm64 debug app

### 依赖与构建

```text
flutter pub get
Got dependencies!

flutter build macos --debug --no-pub
Target file "lib/main.dart" not found.
exit 1

flutter build macos --debug -t lib/src/main.dart --no-pub
Xcode is fetching Swift Package Manager dependencies...
Running pod install...
Building macOS application...
✓ Built build/macos/Build/Products/Debug/jhentai.app
exit 0
```

构建过程只有已有 Swift/deprecation 及 Flutter `Run Script` output 声明警告，没有 `build.db is locked`。本轮没有执行清理、删除 build 状态或 reset/checkout。

针对性测试：

```text
flutter test --no-pub test/inference_setting_test.dart test/onnx_model_manifest_test.dart
00:02 +11: All tests passed!
exit 0
```

产物校验：

```text
codesign --verify --deep --strict --verbose=2 build/macos/Build/Products/Debug/jhentai.app
valid on disk
satisfies its Designated Requirement
exit 0
```

## 依赖与连接核查

### Flutter 入口和生成的 SPM 连接

- `dmg.sh`、`pkg.sh` 等 macOS 发布脚本调用 `flutter build macos ... -t lib/src/main.dart`。
- `macos/Flutter/GeneratedPluginRegistrant.swift` 注册 `FlutterOnnxruntimePlugin`。
- 构建生成的 `macos/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift` 以本地 package 依赖 `flutter_onnxruntime`，并链接其 `flutter-onnxruntime` product。
- `pubspec.yaml` 通过 `dependency_overrides` 指向 `third_party/flutter_onnxruntime`，包版本为 `1.8.3`；`pubspec.lock` 记录同一 path package。

### CocoaPods 与 SPM

`third_party/flutter_onnxruntime/macos/flutter_onnxruntime.podspec` 声明 `onnxruntime-objc` `1.23.0`，但本次 macOS 构建的 `macos/Podfile.lock` 只包含 Flutter/其他 CocoaPods plugin，没有 `onnxruntime-objc` 条目；它的 CocoaPods tool version 是 `1.17.0`。因此本次 macOS 构建实际走的是 Flutter 生成的 SPM 路径，而不能把 podspec 声明误写成“CocoaPods 1.23.0”。

SPM 证据：

- `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`：masicai fork，revision `57f28b1fdd6fe33585370b146a46c597d6750953`，package version `1.23.1`。
- `build/macos/SourcePackages/workspace-state.json`：同一 package checkout；artifact checksum 为 `4bd86356e2d5aab1b8ece609bb9caa63161a6d79d21244da007f9fda6830ff3b`，下载 URL 的文件名明确为 `onnxruntime-libs-1.23.0.zip`。
- `build/macos/SourcePackages/artifacts/.../onnxruntime.xcframework/macos-arm64_x86_64/libonnxruntime-macos.a`：Mach-O universal archive，包含 arm64/x86_64；`nm` 可见 `_OrtSessionOptionsAppendExecutionProvider_CoreML` 和 XNNPACK 相关符号。
- app 的 `jhentai.debug.dylib` 中可见 `FlutterOnnxruntimePlugin`、CoreML 与 XNNPACK API 符号；没有单独的 `onnxruntime.framework`，符合静态归档被链接进 app/plugin product 的结果。

这组证据足以确认“构建时下载并链接了 SPM ORT artifact”，但不足以确认 app 运行时 `ORTVersion()` 返回值、session 是否创建成功或 provider 是否实际执行模型。

## Confirmed / Likely / Uncertain

### Confirmed

- 正确入口 `lib/src/main.dart` 的 macOS debug build 在当前 macOS/Xcode/Flutter 环境成功。
- 默认入口 `lib/main.dart` 不存在；仓库已有发布脚本使用正确 target。
- Wave 5 报告中的 `build.db locked` 未在本轮重跑中复现，且没有通过删除数据库来“修复”。
- 本次构建生成签名有效的 arm64 debug app，并实际拉取 SPM ORT xcframework artifact。
- 静态代码中存在 CoreML/XNNPACK registration 和 `ORTVersion()` 返回路径。

### Likely

- 本次 macOS 运行时使用的是 SPM package `1.23.1` 所引用的 ORT `1.23.0` artifact；这是由 resolved/workspace artifact URL 支持的构建元数据结论，不是 `ORTVersion()` runtime 读回值。
- build.db lock 更可能是共享 build 目录或并行 xcodebuild 的暂态锁；如果再次发生，应先保留完整日志并确认进程/路径，而不是修改工程配置。

### Uncertain / BLOCKED

- `ORTVersion()` 在最终 app runtime 中的实际返回值。
- `getAvailableProviders` 的真实输出，以及 CoreML provider 是否成功注册。
- 任意真实 ONNX model 的 `createSession`、`runInference`、CoreML fallback、内存峰值和耗时。
- 发布版、签名/公证、冷启动和模型下载后的 ORT 生命周期。
- CocoaPods fallback path（尤其 iOS）与 macOS SPM path 的版本锁步是否在未来依赖升级时仍保持一致。

## 官方/权威来源

- [Flutter macOS deployment](https://docs.flutter.dev/deployment/macos)：Flutter 官方 macOS 构建/部署边界；本仓库的发布脚本仍应使用正确 target。
- [Apple Xcode build system](https://developer.apple.com/documentation/xcode/build-system)：Xcode build system 管理从源码/资源到 app 的构建过程；build database lock 属于构建状态/并发诊断，不足以单独推断源码配置错误。
- [ONNX Runtime Execution Providers](https://onnxruntime.ai/docs/execution-providers/)：EP 根据最终运行环境和模型图分配子图，静态符号/enum 不能证明实际硬件执行。
- [ONNX Runtime CoreML Execution Provider](https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html)：CoreML EP 需要在创建 inference session 时显式注册；因此 build/link 不能替代 session/run 证据。
- [Swift Package Manager package dependencies](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html)：Swift package 的依赖和产品连接语义；本次通过生成的 Flutter SPM package 和 Xcode `Package.resolved` 进行实际核对。

## 最小后续动作

1. 在可运行本应用的 macOS 环境启动该 debug/release app，调用现有 runtime-info/provider channel，保存 `ORTVersion`、provider list 和 OS/架构。
2. 使用一个受控、带 hash 的 ONNX fixture，记录 session create/run、CoreML 注册失败后的 CPU fallback、耗时和 RSS；仍需明确模型/运行时证据。
3. 若 CI 再现 `build.db` lock，保存并发进程、数据库绝对路径和 xcodebuild 日志，使用独占 `--build-dir` 或串行 job 复现后再决定是否需要 CI 配置修复。
4. 独立核对 iOS CocoaPods `onnxruntime-objc 1.23.0` 与 SPM artifact 的版本锁步；不要仅因 package semantic version `1.23.1` 就声称 runtime 为 1.23.1。

本轮没有修改 LAN、翻译、阅读页、模型清单或产品功能代码。
