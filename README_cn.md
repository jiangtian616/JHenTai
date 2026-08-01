![platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20MacOS%20%7C%20Linux-brightgreen)
![last-commit](https://img.shields.io/github/last-commit/bingxizhe/JHenTai)
![star](https://img.shields.io/github/stars/bingxizhe/JHenTai)
[![issue](https://img.shields.io/badge/chat-issue-brightgreen)](https://github.com/bingxizhe/JHenTai/issues/new)

# JHenTai (Fork)

[English](README.md) | 简体中文 | [한국어](README_kr.md)

本项目是 [JHenTai](https://github.com/jiangtian616/JHenTai) 的 Fork，一个支持 Android、iOS、Windows、MacOS 和 Linux 的 E-Hentai 多端漫画阅读器。

此 Fork 在原版基础上添加了若干功能和优化，所有改动均设计为非侵入式，与上游代码库兼容。

## Fork 功能与优化

### 1. 启动性能优化

- **延迟画廊扫描**：本地画廊扫描不再阻塞应用启动。扫描逻辑在 UI 渲染完成后通过 `doAfterBeanReady()` 运行，而非 `doInitBean()`。
- **懒加载数据库查询**：大数据集查询（如图片记录）延迟到 UI 初始化完成后执行，初始数据库查询时间从约 3.9s 降至 82ms。
- **恢复竞态修复**：`restoreTasks()` 使用 `isRestoring` 守卫 + `try-finally`，防止从下载页进入触发恢复和从设置页手动触发恢复同时执行导致的竞态。

### 2. 历史版本批量删除

- **Union-Find 版本分组**：通过 `oldVersionGalleryUrl` 字段（而非名称）进行版本链分组，避免同名画廊误判。
- **双站点深度扫描**：扫描画廊版本时，先尝试原站点（e-hentai.org/exhentai.org）最多重试 5 次，失败后切换到对站点再重试最多 5 次，提高被移至里站的画廊扫描成功率。
- **扫描结果持久化**：深度扫描结果（含重试结果）作为整体保存，自动合并重试数据到已有扫描历史，超过 24 小时的结果自动丢弃。
- **全局状态更新**：删除后调用 `updateGlobalGalleryStatus()` 同步所有页面的画廊状态。
- **默认预选旧版本**：所有旧版本默认预选，用户无需手动展开分组即可直接确认删除。

### 3. 收藏批量下载

- **一键批量下载**：一键下载指定分组的所有收藏，支持断点续传。
- **增量持久化**：收藏列表每 5 页保存一次而非每页保存，降低大规模收藏的 O(n²) 序列化开销。
- **网络层限流**：入队操作间无人工延迟。限流由下载引擎（`EHExecutor`）在实际网络请求派发层通过 `Rate(maximum, period)` 处理。
- **重试机制**：失败的下载任务最多重试 5 次，重试间隔可配置。

### 4. WebP/GIF 动画播放优化

- **基于可见性的动画控制**：动画 WebP/GIF 图片仅在可见于视口时播放。离屏图片仅显示首帧，降低解码开销和内存压力。
- **简化动画字段**：从 3 个动画控制字段（`disableGifAnimation`、`playAnimation`、`forcePlay`）简化为 2 个（`disableGifAnimation`、`playAnimation`），完全依赖 `VisibilityDetector` 进行可见性追踪。
- **离屏图片单帧解码**：离屏本地图片使用 `_SingleFrameExtendedFileImageProvider`，离屏在线图片使用 `_SingleFrameExtendedNetworkImageProvider`，限制仅解码首帧。

### 5. 稳定性修复

- **setState() after dispose() 修复**：在 `VisibilityDetector` 回调中添加 `if (!mounted) return;` 守卫，防止 widget 销毁后调用 `setState()`。
- **调试代码清理**：将 `debugPrint` 调用替换为项目统一的 `log.trace` 系统。

## 下载与安装

稳定版请参考 [原项目 Releases](https://github.com/jiangtian616/JHenTai/releases)。

从源码构建：

1. 你需要自己管理安卓签名文件，见 https://docs.flutter.dev/deployment/android#signing-the-app
2. 使用 IDEA 或 VSCode 直接运行即可。

## 主要 Dart 依赖

- [get](https://pub.flutter-io.cn/packages/get): 依赖管理、状态管理、国际化、NoSQL
- [dio](https://pub.flutter-io.cn/packages?q=dio): 网络
- [extendedImage](https://pub.flutter-io.cn/packages/extended_image): 图片
- [drift](https://pub.flutter-io.cn/packages/drift): 数据库

## 借鉴与感谢

- [JHenTai](https://github.com/jiangtian616/JHenTai) - 原项目
- [FEhviewer](https://github.com/honjow/FEhViewer) - 布局样式参考
- [EHPanda](https://github.com/tatsuz0u/EhPanda) - 布局样式参考
- [EhTagTranslation](https://github.com/EhTagTranslation/Database) - 标签翻译
