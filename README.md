![platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20MacOS%20%7C%20Linux-brightgreen)
![last-commit](https://img.shields.io/github/last-commit/bingxizhe/JHenTai)
![star](https://img.shields.io/github/stars/bingxizhe/JHenTai)
[![issue](https://img.shields.io/badge/chat-issue-brightgreen)](https://github.com/bingxizhe/JHenTai/issues/new)

# JHenTai (Fork)

This is a fork of [JHenTai](https://github.com/jiangtian616/JHenTai), a manga app for E-Hentai, supporting Android & iOS & Windows & MacOS & Linux.

This fork adds several features and optimizations on top of the original project. All changes are designed to be non-invasive and compatible with the upstream codebase.

## Fork Features & Optimizations

### 1. Startup Performance Optimization

- **Deferred gallery scanning**: Local gallery scanning no longer blocks app startup. Scanning logic runs after UI rendering is complete via `doAfterBeanReady()` instead of `doInitBean()`.
- **Lazy database queries**: Large dataset queries (e.g., image records) are delayed until UI initialization completes, reducing initial database query time from ~3.9s to ~82ms.
- **Restore race condition fix**: `restoreTasks()` now uses an `isRestoring` guard with `try-finally` to prevent concurrent restore operations when entering the download page and manually triggering restore from settings simultaneously.

### 2. History Version Batch Delete

- **Version grouping via Union-Find**: Galleries are grouped by version chain using `oldVersionGalleryUrl` field (not by name), avoiding misjudgment when multiple galleries share the same name.
- **Deep scan with dual-site fallback**: When scanning gallery versions, the system first tries the original site (e-hentai.org/exhentai.org) with up to 5 retries. On failure, it falls back to the opposite site with another 5 retries, improving scan success rate for galleries moved between sites.
- **Scan result persistence**: Deep scan results (including retry results) are saved as an integral whole, with automatic merging of retry data into existing scan history. Results older than 24 hours are automatically discarded.
- **Global status update**: After deletion, `updateGlobalGalleryStatus()` is called to sync gallery status across all pages.
- **Pre-selected old versions**: All old versions are pre-selected by default, allowing users to delete them without manually expanding any group.

### 3. Favorite Batch Download

- **One-click batch download**: Download all favorites from a specific group with a single action, with support for breakpoint resume.
- **Incremental persistence**: Favorites are saved every 5 pages instead of every page, reducing O(n²) serialization overhead for large collections.
- **Rate limiting at network layer**: No artificial delay between enqueue operations. Rate limiting is handled by the download engine (`EHExecutor`) at the actual network request dispatch level via `Rate(maximum, period)`.
- **Retry mechanism**: Failed download tasks are retried up to 5 times with configurable retry intervals.

### 4. WebP/GIF Animation Playback Optimization

- **Visibility-based animation control**: Animated WebP/GIF images only play when visible in the viewport. Off-screen images render only the first frame, reducing decode cost and memory pressure.
- **Simplified animation fields**: Consolidated from 3 animation control fields (`disableGifAnimation`, `playAnimation`, `forcePlay`) to 2 (`disableGifAnimation`, `playAnimation`), relying solely on `VisibilityDetector` for visibility tracking.
- **Single-frame decoding for off-screen images**: Off-screen local images use `_SingleFrameExtendedFileImageProvider` and off-screen online images use `_SingleFrameExtendedNetworkImageProvider` to limit decoding to the first frame only.

### 5. Stability Fixes

- **setState() after dispose() fix**: Added `if (!mounted) return;` guard in `VisibilityDetector` callback to prevent state updates on disposed widgets.
- **Debug code cleanup**: Replaced `debugPrint` calls with the project's unified `log.trace` system.

## Download & Install

Refer to the [original project's releases](https://github.com/jiangtian616/JHenTai/releases) for stable builds.

To build from source:

1. You need to manage your Android signing by yourself, check https://docs.flutter.dev/deployment/android#signing-the-app
2. Run this project via IDEA or VSCode.

## Main Dart Dependencies

- [get](https://pub.flutter-io.cn/packages/get): dependency management, state management, l18n, NoSQL
- [dio](https://pub.flutter-io.cn/packages?q=dio): network
- [extendedImage](https://pub.flutter-io.cn/packages/extended_image): image
- [drift](https://pub.flutter-io.cn/packages/drift): database

## References & Thanks

- [JHenTai](https://github.com/jiangtian616/JHenTai) - The original project
- [FEhviewer](https://github.com/honjow/FEhViewer) - Layout and style reference
- [EHPanda](https://github.com/tatsuz0u/EhPanda) - Layout and style reference
- [EhTagTranslation](https://github.com/EhTagTranslation/Database) - Tag translation
