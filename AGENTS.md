# AGENTS.md

## Project Overview

HarmonyOS tablet/phone app for EEG brain monitoring (ToPAD). Receives processed EEG data from edge device via SLE (星闪) protocol.

## Tech Stack

- **Framework**: HarmonyOS (OpenHarmony) Stage Model
- **Language**: ArkTS (.ets files)
- **Build**: hvigor (not npm/webpack)
- **Target**: Tablet only (SDK 4.0.0(10)), `deviceTypes: ["tablet"]` in module.json5
- **Bundle**: `com.topad.eeg`

## Project Structure

```
eegonpad/
├── AppScope/                    # App-level config (app.json5)
├── entry/                       # Single HAP module
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/    # EntryAbility.ets (app entry)
│       │   ├── pages/           # Index (tab host), HomePage, FocusPage, TrainPage, AiChatPage, ProfilePage, ReportPage, SettingsPage
│       │   ├── components/      # UI components (MetricsPanel, AlertCard, MetricGauge, FullAlertDialog, etc.)
│       │   ├── model/           # ToPadModel.ets, ToPadMock.ets, ChatModel.ets (interfaces + mock data)
│       │   ├── utils/           # DeviceManager.ets, CommandDispatcher.ets
│       │   └── constants/       # Colors.ets, Dimensions.ets
│       ├── module.json5         # Module config
│       └── resources/           # Strings, colors, media
```

## Key Conventions

- **Components**: Use `@Component export struct` pattern
- **State**: Use `@State` decorators for reactive state
- **Navigation**: Tab-based (Index.ets manages currentIndex state)
- **Data**: Currently uses mock data via `ToPadMock` class
- **Styling**: Centralized in `constants/Colors.ets` and `constants/Dimensions.ets`

## Responsive Design

- **Breakpoints**: `Dimensions.BREAKPOINT_TABLET` (600dp) and `Dimensions.BREAKPOINT_PHONE` (400dp)
- **Width Detection**: 使用 `.onAreaChange()` 在 build 根元素上监听实际渲染宽度
- **DO NOT USE** `aboutToAppear` + `getContext` 获取屏幕宽度（已废弃，切换Tab后失效）
- **Safe Area**: 所有 Scroll 容器添加 `.safeAreaPadding([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])` 防止内容贴顶

### Width Detection Pattern

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

### Responsive Sizing

- **isNarrow()**: `sw < Dimensions.BREAKPOINT_TABLET` — 触发紧凑布局
- **isCompact()**: `sw < 500` — 触发更紧凑间距
- **Narrow mode**: 缩小字号、间距、padding，使用 `CARD_PADDING_SM` (18) 而非 `CARD_PADDING` (26)
- **MetricsPanel narrow**: 2列 x 3行 MetricGauge 布局（非3列）
- **TrainPage narrow**: 游戏格子用 `onAreaChange` 测量实际容器宽度计算尺寸

### Safe Area

- `expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])` — 背景延伸到安全区域
- `safeAreaPadding([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])` — 内容顶部留出状态栏间距

## Product Direction

- The app is a tablet-first EEG device management client, not a single-user status viewer.
- Preserve the blue-white glass visual system, rounded cards, bottom pill navigation, and responsive spacing.
- The home dashboard must support multiple managed devices, simultaneous parameter comparison, and a selected-device detail view.
- The primary tab order is 首页 / 专注 / 训练 / AI / 我的.
- AI uses a management-assistant workspace: conversation history on tablets, compact history on narrow screens, device context, stop/regenerate/copy actions, and a persistent composer.

## Pages

- **Index.ets**: Main entry with tab navigation (首页/专注/训练/AI/我的), handles alerts and vibration
- **HomePage.ets**: Multi-device management dashboard with fleet overview, selected-device metrics, and alerts
- **FocusPage.ets**: Pomodoro timer with EEG data panel, landscape/portrait adaptive
- **TrainPage.ets**: Schulte grid & memory games with dynamic cell sizing
- **AiChatPage.ets**: AI management assistant workspace with conversation history
- **ProfilePage.ets**: User info, device info, privacy settings
- **ReportPage.ets**: Navigable standalone report page (registered in main_pages.json)
- **SettingsPage.ets**: Navigable standalone settings page (registered in main_pages.json)

Note: Only `pages/Index`, `pages/ReportPage`, and `pages/SettingsPage` are registered in `main_pages.json` — other pages are nested components within Index.

## Build Commands

```bash
# Build debug HAP
hvigor assembleHap --mode module -p product=default -p buildMode=debug

# Clean build
hvigor clean
```

## Important Notes

- All UI text is in Chinese (Chinese market app)
- Window is set to full-screen immersive mode in EntryAbility
- Only `pages/Index` is registered in `main_pages.json` (other pages are nested components)
- No dependencies in oh-package.json5 (pure ArkTS, no third-party libs)
- Vibration: `@ohos.vibrator` for alerts and timer completion
- Connect card opens system Bluetooth settings via intent

## Build Error Troubleshooting

Build errors appear in `.hvigor/report/report-*.json` (latest by timestamp). Common ArkTS compiler errors:

- **arkts-no-comma-outside-loops (10605071)**: Object literal passed inline to `console.info(JSON.stringify({...}))` triggers comma-operator rule. Fix: extract the object to a `const` variable first, then stringify.
- **Unterminated string constant**: Usually caused by garbled multi-byte characters breaking string delimiters. Check for corrupted UTF-8 sequences in string literals.
- **Rollup Error (00305015)**: Often follows unterminated string; the parser cascades into downstream syntax errors.

## Known Issues

- `getContext` is deprecated — use `onAreaChange` instead for screen width detection
- Game grid cell size must be calculated from actual container width, not screen width
- `safeAreaPadding` on Scroll containers is required to prevent content from touching status bar
- FocusPage landscape layout needs Scroll on both columns for overflow handling
