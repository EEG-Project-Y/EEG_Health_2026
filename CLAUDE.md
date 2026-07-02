# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build debug HAP
hvigor assembleHap --mode module -p product=default -p buildMode=debug

# Clean build
hvigor clean
```

Build errors are logged in `.hvigor/report/report-*.json` (sorted by timestamp, latest has the most recent errors).

## Tech Stack

- **Platform**: HarmonyOS (OpenHarmony) Stage Model — SDK 4.0.0(10), API level 10
- **Language**: ArkTS (.ets), a superset of TypeScript for HarmonyOS
- **Build**: Hvigor 6.1.0 (not npm/webpack/gradle) — `hvigorfile.ts` at root and module level
- **Module**: Single HAP (`entry/`), no HAR libraries, no third-party dependencies
- **Bundle**: `com.topad.eeg`

## Architecture

### Navigation

**Tab-based** with `Index.ets` as the sole `@Entry` page. It owns `@State currentIndex` (0–4) and conditionally renders one child page at a time. Bottom pill nav tabs: 首页 → 专注 → 训练 → AI → 我的.

Only three pages are registered in `src/main/resources/base/profile/main_pages.json`:
- `pages/Index` — the tab host
- `pages/ReportPage` — pushed via `router.pushUrl()` from device cards
- `pages/SettingsPage` — pushed via `router.pushUrl()` from device cards

All other pages (HomePage, FocusPage, TrainPage, AiChatPage, ProfilePage) are **nested child components** of Index, not standalone routes.

### Data Flow

The app is entirely mock-data driven. `ToPadMock` (in `model/ToPadMock.ets`) is the singleton data source, simulating 3 managed EEG devices. Data flows:

```
ToPadModel.ets (interface definitions)
  └── ToPadMock.ets (singleton — getDevices(), getCurrent(), getRuntimeState(), etc.)
        │
        ▼
  Index.ets (@State eegData, polls every 2s for alerts)
        ├── HomePage (fleet overview + selected-device detail)
        ├── FocusPage (Pomodoro timer + EEG panel)
        ├── TrainPage (cognitive games + EEG panel)
        ├── AiChatPage (keyword-based mock reply generation)
        └── ProfilePage (static mock profile)
```

Key interfaces in `model/ToPadModel.ets`:
- **`ToPadFrame`** — per-device EEG frame: focus, fatigue, relax, load, quality, confidence, state, direction, advice, alert
- **`ManagedDevice`** — device metadata + its current `ToPadFrame`
- **`RuntimeManagementState`** — edge computing runtime state
- **`ToPadProfile`** — user/app profile info

### Component Pattern

```ets
@Component
export struct MyComponent {
  // @Prop for parent → child, @State for local state
  build() {
    // UI
  }
}
```

## Responsive Design

### Width Detection (CRITICAL)

**Always use `.onAreaChange()`** on the root build element to detect rendered width. The `aboutToAppear` + `getContext` approach is deprecated and breaks after tab switches.

```ets
@State sw: number = 360

build() {
  Column() {
    // content
  }
  .onAreaChange((_old: Area, newArea: Area) => {
    const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
    if (w > 0) this.sw = w
  })
}
```

### Breakpoints and Helpers

- `Dimensions.BREAKPOINT_TABLET` = 600dp, `Dimensions.BREAKPOINT_PHONE` = 400dp
- `isNarrow()`: `sw < 600` — compact layout, smaller fonts/spacing, use `CARD_PADDING_SM` (18) instead of `CARD_PADDING` (26)
- `isCompact()`: `sw < 500` — even tighter spacing
- `isWide()`: `sw >= 820` — side-by-side layouts (e.g., AiChatPage conversation history + chat)

### Safe Area

- `expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])` — for backgrounds that extend into system bars
- `.safeAreaPadding([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])` — on every Scroll container to prevent content from touching the status bar

## Design System

All visual tokens are centralized:
- **`constants/Colors.ets`** — primary blues (`#1677FF`, `#075AB8`), semantic (success/warning/error), glass/blur surfaces, text hierarchy
- **`constants/Dimensions.ets`** — breakpoints, spacing, card radii, typography scale, content max-width (1180dp)

Visual style: blue-white glass morphism, blur backgrounds, rounded cards (up to 28dp), pill-shaped navigation, soft shadows.

## Build Error Troubleshooting

- **arkts-no-comma-outside-loops (10605071)**: Inline object literal to `console.info(JSON.stringify({...}))` triggers the comma-operator rule. Extract the object to a `const` variable first.
- **Unterminated string constant**: Usually garbled multi-byte characters breaking string delimiters. Check for corrupted UTF-8 sequences in string literals.
- **Rollup Error (00305015)**: Often cascades from an unterminated string; fix the root cause first.

## Important Constraints

- All UI text is in Chinese (Chinese-market app).
- Window is full-screen immersive mode (set in `EntryAbility.ets`).
- No third-party dependencies — pure ArkTS with HarmonyOS system APIs only.
- Game grid cell sizes must be calculated from actual container width via `.onAreaChange()`, not from screen width.
- FocusPage landscape layout needs Scroll on both columns for overflow handling.
