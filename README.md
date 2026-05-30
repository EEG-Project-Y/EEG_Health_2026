# HealthSync HarmonyOS ArkUI App

This repository has been initialized as a HarmonyOS Stage model project that can be opened in DevEco Studio.

## Project Structure

- `AppScope/`: application-level metadata and shared resources.
- `entry/`: main HAP module.
- `entry/src/main/ets/pages/Index.ets`: ArkTS/ArkUI implementation converted from the HTML prototypes.
- `entry/src/main/module.json5`: Stage model module configuration.
- `hvigor/`, `hvigorfile.ts`, `build-profile.json5`: DevEco/Hvigor build configuration.

## Implemented Screens

- Dashboard with health score, focus, fatigue, EEG spectrum, and AI suggestion card.
- Pomodoro focus timer with start, pause, reset, live focus score, and rest advice.
- Sports mode with heart rate, cadence, calories, focus ring, route preview, and hydration tip.
- Profile center with login entry, summary cards, device and alert menu.
- Settings panel with device connection fields, switches, sliders, cloud sync, and screen options.
- Background picker with preview and selectable styles.

## Open in DevEco Studio

1. Open DevEco Studio.
2. Choose `Open Project`.
3. Select this repository root: `D:\stitch_harmonyos_ai_health_monitor`.
4. Let DevEco sync Hvigor and OHPM dependencies.
5. Configure signing in `File > Project Structure > Signing Configs` if you want to run on a device.
6. Build or run the `entry` module.

The original HTML prototype folders are kept as visual references. The runnable HarmonyOS implementation is under `entry/src/main/ets`.
