# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**HealthSync** (`com.stitch.healthmonitor`) — a HarmonyOS **Stage-model** ArkUI/ArkTS app that visualizes real-time EEG (脑电) health metrics: focus, fatigue, relaxation, cognitive load, signal quality, plus AI advice. The real data source is an **Orange Pi (香橙派)** board running OpenHarmony that writes EEG readings the app polls and renders.

Comments, UI strings, and docs are bilingual (Chinese-primary). **Read/write files as UTF-8** — Chinese comments are everywhere and the wrong encoding corrupts them.

## Build, run, verify

There is **no test suite, linter, or CLI build script** in the repo, and no third-party OHPM dependencies. Development is DevEco Studio-driven:

- **Open in DevEco Studio** → wait for Hvigor/OHPM sync → Build/Run the `entry` module. Signing is already configured in `build-profile.json5` (`signingConfigs`).
- CLI build (only after DevEco has generated the `hvigorw` wrapper): `hvigorw assembleHap`.
- Build output (gitignored): `entry/build/default/outputs/default/*.hap`.
- "Verifying a change" here means building the `entry` module in DevEco and running on device/emulator — there is nothing to `npm test`.

### ⚠️ API 10 is a hard runtime ceiling

`build-profile.json5` sets `compatibleSdkVersion: "4.0.0(10)"` (API 10) / `targetSdkVersion: "5.0.0(12)"`. The deploy target (Orange Pi / OpenHarmony) is **API 10**. **Do not use ArkUI/ArkTS APIs introduced in API 11+** — they compile fine but crash or freeze on the device. This already bit the project: `TimePicker` with `HOUR_MINUTE_SECOND` had to be ripped out of the Pomodoro custom-duration dialog and rebuilt from basic components. When in doubt, prefer basic ArkUI primitives.

## Architecture

### Two tabs, not four (docs are stale)

`AGENTS.md` and `PROJECT_DOCUMENTATION.md` describe a **4-tab** app (Dashboard/Focus/Sports/Profile) at SDK `5.0.0(12)`/`6.1.0(23)`. **That is out of date** — trust the code. The app is now **2 tabs** (`BottomNav.ets`): Dashboard (仪表盘) and Focus (专注). Sports was removed; Profile became a separate routed **Settings** page. Those docs remain useful for the design system (colors, spacing, i18n conventions) but not for structure/SDK.

### Single-page shell + one routed page

- `entryability/EntryAbility.ets` → `onCreate` calls `initSettingsStorage()`, then `onWindowStageCreate` loads `pages/Index`.
- `pages/Index.ets` (~2400 lines) is the whole tabbed UI. Both tabs and nearly all cards are `@Builder` methods on the single `@Entry struct Index`; tab switching is `@State currentTab`.
- `pages/Settings.ets` is the only other route, reached via `@ohos.router` (e.g. `router.pushUrl({ url: 'pages/Settings' })`). The Settings page also calls `initSettingsStorage()` in `aboutToAppear()` — redundant with EntryAbility.onCreate but harmless since `SetOrCreate` is idempotent.
- **New pages must be registered** in `entry/src/main/resources/base/profile/main_pages.json`, or they can't be navigated to.

### Data pipeline (the core of the app)

`data/DataService.ts` is a singleton that drives all live metrics:

1. `startReceiving(cb, errCb, intervalMs)` polls on a `setInterval`. Index uses **5000ms** on real device, DemoDataService uses 1000ms.
2. Each tick, `fetchData()` tries HTTP endpoints then local files **in order**, using the first that yields displayable data:
   - HTTP: `AppConfig.eegHttpEndpoints` (`http://127.0.0.1:18080/ToApp.json`)
   - Files: `AppConfig.eegLocalFiles` (`/data/local/tmp/eeg_health/runtime/ToApp.json`, `/data/eeg_health/runtime/ToApp.json`, `.../currentData.json`)
   - If all fail → `getNoDataState()` and the error callback fires.
3. Payloads are parsed into the **`ToAppJson`** interface. `parseAndNormalize` flattens nested `metrics`/`trend`/`summary`/`channelStatus`/`source` shapes into flat top-level fields, so the UI only reads flat fields. Extend normalization there, not in the UI.
4. Index's `applyToAppJson(data)` maps `ToAppJson` → `@State`. When there's no real data it **forces metrics to 0** rather than showing stale/fake numbers.

`config.ts` exposes `SIMULATOR_DEMO_MODE`. When `true`, Index swaps `DataService` for `data/DemoDataService.ts` (a scripted focused→fatigue→high-risk loop for previews). **Must be `false` for real-device builds** — `AppConfig` endpoints/paths, permissions (`INTERNET`), and HTTP `request.destroy()` cleanup are all built around the real path.

The bundled `data/ToApp.json` is a sample payload. On the device, `deploy_scripts/*.sh` (run on the Orange Pi, not on your dev machine) generate/write live or mock EEG data into `/data/eeg_health/runtime/ToApp.json` — that's how you feed the app without the full backend. Scripts: `eeg_live_data_loop.sh` (real device loop), `eeg_mock_focus_relax.sh` (mock focus/relax cycle), `toapp_relax_focus_loop.sh` (ToApp.json writer loop).

### Settings persist via AppStorage / @StorageLink

Unlike what the old docs say ("no AppStorage"), settings **are** global and persistent:

- `store/SettingsStore.ts` defines `SettingsDefaults` and `initSettingsStorage()`, which seeds `AppStorage` keys (`language`, `autoReconnect`, `cloudSync`, `keepScreenOn`, `warningEnabled`, `focusThreshold`, `fatigueThreshold`, `qualityThreshold`, `confidenceThreshold`, `bgStyle`).
- `Index.ets` and `Settings.ets` bind these with `@StorageLink('key')`, so a change on either screen is reflected on the other.
- **To add a setting**: add it to `SettingsDefaults` + `initSettingsStorage()`, then `@StorageLink` it where used. A `@StorageLink` key with no matching `SetOrCreate` won't be seeded. **Bug**: `Settings.ets` binds `@StorageLink('healthThreshold')` but `SettingsStore` seeds `focusThreshold` — these are different keys. The Settings page reads/writes a key that no one initializes. Fix by renaming to `focusThreshold` in Settings.ets or adding `healthThreshold` to the store.

### Permissions

`entry/src/main/module.json5` declares `ohos.permission.INTERNET` (required for HTTP polling) and `ohos.permission.READ_MEDIA` (for media access). The INTERNET permission is essential for the data pipeline — without it, HTTP requests to the EEG endpoint silently fail.

### Health safety alerts

Index raises a full-screen alert when metrics cross the threshold settings, throttled by `ALERT_COOLDOWN_MS` (60s) and de-duplicated by data sequence so polling can't spam the user.

## Conventions & gotchas

- **Two `AppColor` classes exist.** `theme/AppColor.ets` is the canonical palette used by extracted components (`BottomNav`, `TopBar`, `MenuRow`, `SummaryCard`, `Settings`). `Index.ets` also declares its **own** inline `AppColor` (with extra tokens like `Glass`, `Cyan`, `Violet`). Keep them in sync, or migrate toward the `theme/` one. Don't hardcode hex colors in business code.
- **Reusable UI lives in `components/`** (`BottomNav`, `TopBar`, `InputLike`, `MenuRow`, `SummaryCard`); models in `models/`. Prefer extracting large `@Builder`s from `Index.ets` into `@Component`s over growing the file further.
- **Bilingual text**: use the `t(zh, en)` helper (present in Index and Settings, keyed off the `language` StorageLink). Always supply both languages for user-visible strings.
- **Don't overwrite live EEG state with simulated values** in timers or UI handlers — `focus`/`fatigue`/etc. are owned by the DataService callback. Faking them in the Pomodoro tick or elsewhere fights the real data flow.
- **Timers**: the Pomodoro uses a `setTimeout` chain (`focusTimerId`); stop it on tab-leave / `aboutToDisappear`. When touching polling or timers, verify cleanup on leave, destroy, and re-enter.
- **Keep manifests in sync** when changing package/version/SDK/device/permissions: `AppScope/app.json5`, root `build-profile.json5`, `entry/src/main/module.json5`.
- **Untracked, non-source artifacts** in the tree (`agent.docx`, `agent_final.docx`, `agent_source_summary.md`) are notes, not part of the app.
- There may be uncommitted work in the tree — check `git status --short` before large changes and don't revert others' edits.
