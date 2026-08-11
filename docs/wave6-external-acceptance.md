# Wave 6 外部平台验收记录

日期：2026-08-11（Asia/Shanghai）

## 本轮实际证据

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| macOS debug build | PASS | `flutter build macos --debug -t lib/src/main.dart --no-pub` 成功，生成 `build/macos/Build/Products/Debug/jhentai.app` |
| iOS device compile | PASS（无签名） | `flutter build ios --debug -t lib/src/main.dart --no-pub --no-codesign` 成功，生成 `build/ios/iphoneos/Runner.app` |
| iOS wireless device discovery | PASS | Flutter 发现 `轩宁的iPhone Air`，iOS `27.0`，设备 ID 已由 Flutter 输出；本记录不重复写入个人敏感标识 |
| iOS install/run | BLOCKED | `flutter run -d ...` 在 Xcode 签名阶段失败：`No Accounts: Add a new account in Accounts settings`、`No profiles for 'top.jtmonster.jhentai' were found` |
| Android | BLOCKED | 当前环境没有 `adb` 或 Android device |
| iOS simulator | BLOCKED | 当前环境没有可用 simulator |
| Windows/Linux | BLOCKED | 当前工作主机为 macOS，没有对应 runner/VM |

## 解释边界

无签名 iOS 编译只能证明 Flutter/Xcode 工程和 native 编译链可生成 device app，不能证明真机安装、CoreML provider、ORT session、模型推理、内存或后台恢复。macOS build 成功也不能替代真实模型和 provider 运行。

本轮未下载大型模型、未写入用户模型目录、未进行真实三设备 LAN 会话或抓包。原因是当前本机没有可验证的完整模型/远端设备/Android runner；模型目录或 fake host 测试不能冒充真实运行证据。

## 解除 BLOCKED 的最小条件

1. 在 Xcode Accounts 中配置可用开发账号，并为 `top.jtmonster.jhentai` 提供匹配 provisioning profile；重新运行无线 iPhone，记录 provider、模型 hash、50 页/后台/内存数据。
2. 提供 Android 8.1+ 真机和 `adb`，分别执行 CPU、NNAPI、driver fault fallback 和后台压力测试。
3. 提供 Windows/Linux runner，执行 ORT/llama 生命周期与长批次测量。
4. 提供六个带 SHA-256 的真实模型、300 页 fixture、至少三台可信 LAN 设备和可保存的脱敏抓包。

