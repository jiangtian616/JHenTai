# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

JHenTai is a Flutter app for browsing E-Hentai / EXHentai, targeting Android, iOS, Windows, macOS, and Linux. Version `8.0.14+328` (from pubspec.yaml).

## Build & dev commands

```bash
# Get dependencies
flutter pub get

# Run code generation (Drift DB, etc.) — required after editing any @DriftDatabase tables/queries
dart run build_runner build --delete-conflicting-outputs

# Run code generation in watch mode during active DB work
dart run build_runner watch --delete-conflicting-outputs

# Run app on a connected device
flutter run

# Lint
flutter analyze

# Run tests (single file, or a single test by name)
flutter test test/download_setting_test.dart
flutter test --plain-name 'recent gallery groups can be disabled'
```

`test/` currently contains one real test (`test/download_setting_test.dart`, covering `DownloadSetting`); add new tests there. Release artifacts are built by the platform scripts at the repo root (`apk.sh`, `ipa.sh`, `dmg.sh`, `pkg.sh`, `windows.sh`, `linux.sh`, `thin-payload.sh`) — each reads the version from `pubspec.yaml` and builds with `-t lib/src/main.dart`.

## Architecture

### Dependency framework: GetX

State management, routing, dependency injection, and i18n all use GetX. Page state is driven by `GetBuilder<T>` with manual `update([ids])` — controllers commonly call the `updateSafely([...])` extension from `lib/src/extension/get_logic_extension.dart`. Reactive `.obs` fields (122 of them) live on the setting singletons in `lib/src/setting/`, never on page controllers; pages consume them via `Obx` for cross-view rebuilds, and logic layers react to them with `ever`/`everAll` Workers. The auto-listening `GetX<T>` widget is never used.

### Lifecycle: `JHLifeCircleBean` pattern

Every singleton service, setting, and the network singletons (`ehRequest`, `jhRequest`, `archiveBotRequest`) implement `JHLifeCircleBean` from `lib/src/service/jh_service.dart`:

- `initBean()` — async init (called before `runApp`)
- `afterBeanReady()` — post-runApp setup (called from `GetMaterialApp.onReady`, not awaited)
- `initDependencies` — list of other beans this one needs initialized first

All beans are registered in the `lifeCircleBeans` list in `lib/src/main.dart`. `main()` runs `topologicalSort()` at runtime, which reorders the list purely from each bean's `initDependencies`, so **the literal order of the list does not matter** — only the dependency graph does. A circular dependency throws an uncaught `Exception` and aborts startup; a single bean's init failure is caught and logged by the mixins and is not fatal. To add a bean: add it to the list and declare correct `initDependencies` (avoiding cycles). Two mixins simplify common patterns:

- `JHLifeCircleBeanErrorCatch` — wraps init/ready in try/catch with logging; subclasses override `doInitBean()` / `doAfterBeanReady()`; defaults `initDependencies` to `[pathService, log]`
- `JHLifeCircleBeanWithConfigStorage` — adds config persistence to the `local_config` DB table via `LocalConfigService`; beans override `applyBeanConfig(String)` and `toConfigString()` (JSON in practice) and save with `saveBeanConfig()`; defaults `initDependencies` to `[pathService, log, localConfigService]`

Service beans live in `lib/src/service/`; settings singletons live in `lib/src/setting/`.

### Logging

Uses the `logger` package via the global `log` singleton (`lib/src/service/log.dart`). A console logger receives every tier. File loggers write into a single `logs/` directory under `pathService.getVisibleDir()`, one timestamped file set per session: a trace-level verbose file (`{timestamp}.log`) always, plus — only when the `enableVerboseLogging` Advanced setting is on (default in debug builds) — a warning file (`{timestamp}_error.log`) and a download file (`{timestamp}_download.log`). Call `log.trace/debug/info(msg, [withStack])`, `log.warning(msg, [error, withStack])`, `log.error(msg, [error, stackTrace])`, `log.download(msg)`. Errors in the `JHLifeCircleBeanErrorCatch` mixin and the global `FlutterError` / `PlatformDispatcher` handlers are logged automatically. Logs are not auto-rotated; `log.clear()` (from the Advanced settings page) wipes the directory.

### Supporting directories

- `lib/src/config/` — app-level configuration (theme, UI constants, API secrets)
- `lib/src/consts/` — constants per backend (`eh_consts`, `jh_consts`, `archive_bot_consts`, `locale_consts`)
- `lib/src/enum/` — enums shared across the app (`EHNamespace`, `ConfigEnum`, `CloudConfigTypeEnum`)
- `lib/src/extension/` — extension methods on framework types (DioException, String, List, Directory, Widget, GetLogic)
- `lib/src/mixin/` — reusable page mixins: scroll-to-top, double-tap-refresh, login-required guard, animation, window-widget, global-gallery-status
- `lib/src/model/` — data classes: `Gallery`, `GalleryTag`, `GalleryImage`, `GalleryComment`, `SearchConfig`, `SearchHistory`, and per-endpoint response models in `model/jh_response/` and `model/archive_bot_response/`
- `lib/src/utils/` — ~30 utility files for parsing (`eh_spider_parser`, `jh_spider_parser`), IO, date, crypto, proxy, version, etc.
- `lib/src/exception/` — custom exception classes (`EHSiteException`, `NotUploadException`, and several others)

### Routing

All routes are defined in `lib/src/routes/routes.dart` as static const strings on `class Routes`, together with the `static List<EHPage> pages` map and `defaultTransition`. The `EHPage` class extends `GetPage` and adds:
- `side` — `left`/`right`/`fullScreen` (which navigator the route pushes to, in the tablet and desktop split layouts)
- `offAllBefore` — whether previous right-side routes are popped

Actual navigation goes through `toRoute()` in `lib/src/utils/route_util.dart`, which adapts the push to the current layout. Nested settings routes use a `settingPrefix` convention (`/setting_*`). `GetXRouterObserver` (`lib/src/routes/getx_router_observer.dart`) keeps GetX controllers recycled when the native Navigator API is used.

### Page pattern

Pages follow a consistent GetX structure in `lib/src/pages/`:
- `*_page.dart` — Widget
- `*_page_logic.dart` — `GetxController` subclass (business logic)
- `*_page_state.dart` — Mutable state object

Gallery-list pages inherit the base trio in `pages/base/`: `BasePage` (widget), `BasePageLogic` (`GetxController`), `BasePageState` (state). `BasePageLogic` handles pull-to-refresh, pagination (prev/next gid), search config persistence, and tag blocking/filtering. Subclasses configure it through getters like `useSearchConfig` / `autoLoadNeedLogin`; `getGalleryPage()` is an override hook whose default implementation already performs the API call. `OldBasePageLogic`/`OldBasePageState` implement page-index-based pagination for EH's old search rule. The details/read pages are **not** `BasePageLogic` subclasses — they use the same file convention but extend `GetxController` directly.

### Network layer (`lib/src/network/`)

Uses a custom Dio fork (`dio` from `jiangtian616/dio` at `append-mode` ref). Main request classes:
- `EHRequest` — the workhorse for all E-Hentai and app-managed HTTP: E-Hentai API calls with cookie management (`eh_cookie_manager`), custom SQLite caching (`eh_cache_manager` over the `dio_cache` table), and domain fronting for EX (`eh_ip_provider`); also fetches tag translations (EhTagTranslation via jsdelivr), GitHub release/update data, and the built-in block list
- `JHRequest` — JHenTai backend API calls (cloud config sync, signed image-hash endpoint)
- `ArchiveBotRequest` — archive.org resolution (EhArBot / Archive-at-Home protocols)

`EHRequest` / `JHRequest` / `ArchiveBotRequest` are themselves `JHLifeCircleBean`s. Parsers for HTML responses live in `lib/src/utils/eh_spider_parser.dart`.

### Database (`lib/src/database/`)

Drift (SQLite) at schema version 24 with a heavy migration chain. Tables in `database/table/`, hand-written DAOs (static methods over `appDb`) in `database/dao/`. Current physical tables are `_v2`-suffixed (`gallery_downloaded_v2`, `archive_downloaded_v2`, `super_resolution_info_v2`, `gallery_history_v2`); the unsuffixed tables are legacy/migration variants. The global `appDb` singleton is declared at the bottom of `database.dart`. Generated code is in `database.g.dart` — re-run `dart run build_runner build` after any schema change and add a migration step in `MigrationStrategy.onUpgrade` (the chain also runs one-off data backfills, and migration errors rethrow `NotUploadException`).

### Services (`lib/src/service/`)

Independent singletons that manage core features:
- `gallery_download_service.dart` / `archive_download_service.dart` — download engines with parallel queue, resume, priority
- `local_config_service.dart` — the DB-backed KV store all settings persist through (backbone of `JHLifeCircleBeanWithConfigStorage`)
- `app_update_service.dart` — versioned migration engine (runs 11 update handlers from a version stamp, migrating legacy settings into `local_config`)
- `schedule_service.dart` — post-launch scheduled tasks (update check, tag refresh, cache cleanup, EH event polling, ArchiveBot check-in)
- `tag_translation_service.dart` — fetches/caches EhTagTranslation, tag autocomplete
- `local_block_rule_service.dart` — user-configured gallery & comment blocking rules (23 rule handlers + pluggable providers)
- `built_in_blocked_user_service.dart` — downloads/contributes the built-in blocked-user list
- `super_resolution_service.dart` — full upscaling engine (model download, external process, status tracking)
- `cloud_service.dart` — cloud-config sync payload serialization (the remote transfer lives in the config-sync page)
- `storage_service.dart` — GetStorage NoSQL persistence (now largely legacy/backward-compat since v8.x)
- `isolate_service.dart` — off-main-isolate JSON/compute helpers
- `path_service.dart` — platform-aware directory resolution

### Settings (`lib/src/setting/`)

Each setting module is a standalone singleton (e.g., `ehSetting`, `styleSetting`, `preferenceSetting`) using `JHLifeCircleBeanWithConfigStorage` — the one exception is `my_tags_setting.dart`, which holds server-session data and uses `JHLifeCircleBeanErrorCatch`. Settings are serialized as JSON and stored in the `local_config` DB table. Reactive `.obs` values are used when settings need to trigger UI rebuilds across the app.

### Layout system (`lib/src/pages/layout/`)

Three layout modes, selected in `home_page.dart` primarily from the user's `styleSetting.layout` preference: `mobile_v2` (bottom navigation bar with tab-style pages), `tablet_v2` (master-detail split with left/right route sides), `desktop` (sidebar icon tab bar + persistent detail panel). Screen width only overrides to mobile when `Get.width < 600`; the initial default is auto-picked by device width in `style_setting.dart`. Tablet and desktop both use a resizable split via `flutter_resizable_container`.

### i18n (`lib/src/l18n/`)

Custom translation system via `LocaleText` (GetX `Translations`). One `.dart` file per language (`en_US`, `zh_CN`, `zh_TW`, `ko_KR`, `pt_BR`, `ru_RU`) with key-value pairs. Adding a new language requires: the locale file in `l18n/`, an entry in `locale_text.dart`, an entry in `localeCode2Description` in `lib/src/consts/locale_consts.dart` (the language-picker dropdown looks it up with a null-assert, so the two files must stay in sync), **and** an entry in `supportedLocales` in `lib/src/main.dart`. (`ru_RU` currently demonstrates what happens when the last step is skipped — it is registered but missing from `supportedLocales`.)

### Widget library (`lib/src/widget/`)

Reusable widgets prefixed `eh_` — dialogs, cards, image components, tag displays, etc. The `app_manager.dart` widget wraps the entire app for global concerns (app lifecycle, platform-brightness theme switching, privacy: background blur + Android FLAG_SECURE, lock-screen on resume). The `loading_state_indicator.dart` provides a standard loading/error/empty/idle state widget.

### Key dependencies (beyond Flutter standard)

- `get` 4.6.6 — state management, routing, i18n
- `dio` (custom `jiangtian616/dio` fork) — HTTP client
- `drift` 2.21.0 — SQLite ORM
- `extended_image` — image loading with cache
- `photo_view` / `zoom_view` (custom `jiangtian616` forks) — reading page image viewer
- `get_storage` — NoSQL persistence (used by `storage_service`)
- `desktop_webview_window` — desktop webview for cookie login

Many other dependencies are also `jiangtian616` forks (e.g. `scrollable_positioned_list`, `like_button`, `j_downloader`, proxy packages); `j_downloader` powers the archive download engine.
