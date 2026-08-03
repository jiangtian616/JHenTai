# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

JHenTai is a Flutter app for browsing E-Hentai / EXHentai, targeting Android, iOS, Windows, macOS, and Linux. Version `8.0.14+328` (from pubspec.yaml).

## Build & dev commands

```bash
# Get dependencies
flutter pub get

# Run code generation (Drift DB, etc.) — required after editing any @DriftDatabase tables/queries
dart run build_runner build

# Run code generation in watch mode during active DB work
dart run build_runner watch --delete-conflicting-outputs

# Run app on a connected device
flutter run

# Lint
flutter analyze

# Run tests
flutter test
```

No test directory files are present, so `flutter test` is purely for when new tests are added.

## Architecture

### Dependency framework: GetX
State management, routing, dependency injection, and i18n all use GetX. Widgets use `GetBuilder<T>` (manual `update()`), not reactive `.obs` streams. Pages use `.obs` for settings that must broadcast changes across views.

### Lifecycle: `JHLifeCircleBean` pattern

Every singleton service and setting implements `JHLifeCircleBean` from `lib/src/service/jh_service.dart`:

- `initBean()` — async init (called before `runApp`)
- `afterBeanReady()` — post-runApp setup
- `initDependencies` — list of other beans this one needs initialized first

All beans are registered in a topological-sorted list in `lib/src/main.dart` and initialized in order. **Adding a new service/setting requires inserting it into this list with the correct `initDependencies` ordering** — out-of-order registration will cause init failures. Three mixins simplify common patterns:
- `JHLifeCircleBeanErrorCatch` — wraps init/ready in try/catch with logging; subclasses override `doInitBean()` / `doAfterBeanReady()` instead
- `JHLifeCircleBeanWithConfigStorage` — adds JSON serialize/deserialize to the `local_config` DB table via `applyBeanConfig()` / `getBeanConfig()`
- Service beans live in `lib/src/service/`; settings singletons live in `lib/src/setting/`

### Logging

Uses the `logger` package via the global `log` singleton (`lib/src/service/log.dart`). Four tiered outputs:
- Console logger (dev: colored + method info; prod: plain with timestamp)
- Verbose file logger (trace-level, `verbose/`)
- Warning file logger (warn+, `warning/`)
- Download-specific file logger (`download/`)

Call `log.trace/debug/info/warn/error(msg, e, stack)`. Errors in `JHLifeCircleBeanErrorCatch` mixin are automatically logged.

### Supporting directories

- `lib/src/config/` — app-level configuration (theme, UI constants, Sentry, API secrets)
- `lib/src/enum/` — enums shared across the app (`EHNamespace`, `ConfigEnum`, `ConfigTypeEnum`)
- `lib/src/extension/` — extension methods on framework types (DioException, String, List, Directory, Widget, GetLogic)
- `lib/src/mixin/` — reusable page mixins: scroll-to-top, double-tap-refresh, login-required guard, animation, window-widget
- `lib/src/model/` — data classes: `Gallery`, `GalleryTag`, `GalleryImage`, `GalleryComment`, `SearchConfig`, `SearchHistory`, and per-endpoint response models in `model/jh_response/` and `model/archive_bot_response/`
- `lib/src/utils/` — 30+ utility files for parsing (eh_spider_parser, jh_spider_parser), IO, date, crypto, proxy, version, etc.
- `lib/src/exception/` — custom exception classes (`EHSiteException`, `NotUploadException`)

### Routing

All routes are defined in `lib/src/routes/routes.dart` as static const strings on `class Routes`. The `EHPage` class extends `GetPage` and adds:
- `side` — `left`/`right`/`fullScreen` (tablet layout uses left/right split)
- `offAllBefore` — whether previous right-side routes are popped

Nested settings routes use a `settingPrefix` convention (`/setting_*`).

### Page pattern

Pages follow a consistent GetX structure in `lib/src/pages/`:

- `*_page.dart` — Widget
- `*_logic.dart` — `GetxController` subclass (business logic)
- `*_state.dart` — Mutable state object

The base class is `BasePageLogic` (`pages/base/base_page_logic.dart`) which handles gallery-list pages: pull-to-refresh, pagination (prev/next gid), search config persistence, and tag blocking/filtering. Subclasses override `getGalleryPage()` to provide page-specific API calls.

### Network layer (`lib/src/network/`)

Uses a custom Dio fork (`dio` from `jiangtian616/dio` at `append-mode` ref). Main request classes:
- `EHRequest` — all E-Hentai API calls, with cookie management, caching, domain fronting for EX
- `JHRequest` — backend API calls (tag translations, app update checks, built-in block lists)
- `ArchiveBotRequest` — archive.org resolution

Parsers for HTML responses live in `lib/src/utils/eh_spider_parser.dart`.

### Database (`lib/src/database/`)

Drift (SQLite) at schema version 24 with heavy migration chain. Tables in `database/table/`, DAOs in `database/dao/`. The global `appDb` singleton is declared at the bottom of `database.dart`. Generated code is in `database.g.dart` — re-run `dart run build_runner build` after any schema change and add a migration step in `MigrationStrategy.onUpgrade`.

### Services (`lib/src/service/`)

Independent singletons that manage core features:
- `gallery_download_service.dart` / `archive_download_service.dart` — download engine with parallel queue, resume, priority
- `tag_translation_service.dart` — fetches and caches tag translations from EhTagTranslation
- `local_block_rule_service.dart` — user-configured gallery blocking rules
- `cloud_service.dart` — config sync
- `storage_service.dart` — JSON/GetStorage NoSQL persistence
- `super_resolution_service.dart` — image upscaling metadata tracking
- `path_service.dart` — platform-aware directory resolution

### Settings (`lib/src/setting/`)

Each setting module is a standalone singleton (e.g., `ehSetting`, `styleSetting`, `preferenceSetting`) using `JHLifeCircleBeanWithConfigStorage`. Settings are serialized as JSON and stored in the `local_config` DB table. Reactive `.obs` values are used when settings need to trigger UI rebuilds across the app.

### Layout system (`lib/src/pages/layout/`)

Three layout modes:
- `mobile_v2` — bottom navigation bar with tab-style pages
- `tablet_v2` — master-detail split (left/right route sides)
- `desktop` — sidebar navigation with persistent detail panel

The home page (`home_page.dart`) selects the layout based on screen width.

### i18n (`lib/src/l18n/`)

Custom translation system via `LocaleText` (GetX `Translations`). One `.dart` file per language with key-value pairs. Adding a new language requires: the locale file, an entry in `locale_text.dart`, and an entry in `locale_consts.dart`.

### Widget library (`lib/src/widget/`)

Reusable widgets prefixed `eh_` — dialogs, cards, image components, tag displays, etc. The `app_manager.dart` widget wraps the entire app for global concerns. The `loading_state_indicator.dart` provides a standard loading/error/empty/idle state widget.

### Key dependencies (beyond Flutter standard)

- `get` 4.6.6 — state management, routing, i18n, NoSQL storage
- `dio` (custom fork) — HTTP client
- `drift` 2.21.0 — SQLite ORM
- `extended_image` — image loading with cache
- `photo_view` / `zoom_view` (custom forks) — reading page image viewer
- `desktop_webview_window` — desktop webview for cookie login
