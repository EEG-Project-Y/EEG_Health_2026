# HealthSync — HarmonyOS ArkUI App

基于 HarmonyOS **Stage 模型** 的 AI 健康监测演示应用，可在 DevEco Studio 中直接打开、构建与运行。详细中文说明见 [PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md)。

## Project Structure

| 路径 | 说明 |
|------|------|
| `AppScope/` | 应用级配置（`app.json5`：包名、版本等） |
| `entry/` | 主 HAP 模块 |
| `entry/src/main/ets/entryability/EntryAbility.ets` | UIAbility 入口，加载主页面 |
| `entry/src/main/ets/pages/Index.ets` | 四 Tab 主界面（仪表盘 / 专注 / 运动 / 个人） |
| `entry/src/main/module.json5` | 模块清单与 Ability 声明 |
| `build-profile.json5` | 工程级 SDK 与模块映射 |
| `hvigor/`、`hvigorfile.ts` | Hvigor 构建配置 |

预留目录（当前无源码）：`entry/src/main/ets/model/`、`entry/src/main/ets/theme/`。

本仓库 **不包含** HTML 静态原型文件夹；可运行实现均在 `entry/src/main/ets/`。

## Implemented Screens

- **Dashboard** — health score, focus/fatigue metrics, EEG spectrum, AI suggestion
- **Focus** — Pomodoro timer (start/pause/reset), live focus score, rest advice
- **Sports** — heart rate, cadence, calories, focus ring, route placeholder, hydration tip
- **Profile** — summary, device menu, settings (switches, sliders, cloud sync), language toggle, background picker

## Requirements

- DevEco Studio（推荐最新稳定版）
- SDK aligned with `build-profile.json5`: **compatibleSdkVersion `5.0.0(12)`**, **targetSdkVersion `6.1.0(23)`**
- Devices: phone, tablet

## Open in DevEco Studio

1. Open DevEco Studio → **Open Project**.
2. Select this repository root directory.
3. Wait for Hvigor / OHPM sync (no third-party OHPM dependencies currently).
4. **File → Project Structure → Signing Configs** — configure signing to run on a device.
5. Build or run the **entry** module.

## Build Output

After a successful build (paths are gitignored locally):

`entry/build/default/outputs/default/` — signed or unsigned `.hap` packages.
