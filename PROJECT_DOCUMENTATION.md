# HealthSync — AI 健康监测应用项目文档

> **版本**：1.0.0 · **包名**：`com.stitch.healthmonitor` · **平台**：HarmonyOS NEXT (Stage Model)

---

## 目录

1. [项目概览](#1-项目概览)
2. [技术架构](#2-技术架构)
3. [项目结构](#3-项目结构)
4. [核心配置文件说明](#4-核心配置文件说明)
5. [功能模块详解](#5-功能模块详解)
6. [设计系统](#6-设计系统)
7. [状态管理](#7-状态管理)
8. [构建与运行](#8-构建与运行)
9. [开发约定](#9-开发约定)
10. [后续迭代方向](#10-后续迭代方向)

---

## 1. 项目概览

**HealthSync** 是一款基于 HarmonyOS ArkUI 框架的 AI 健康监测应用。应用通过模拟脑电（EEG）数据，提供实时专注度与疲劳度分析、番茄钟专注计时、运动数据追踪等核心功能，并结合 AI 智能建议，帮助用户科学管理健康状态。

| 属性 | 值 |
|------|-----|
| 应用名称 | HealthSync |
| 包名 (Bundle Name) | `com.stitch.healthmonitor` |
| 版本号 (versionCode) | `1000000` |
| 版本名称 (versionName) | `1.0.0` |
| 供应商 | stitch |
| API 模型 | Stage Model (apiType: stageMode) |
| 开发语言 | ArkTS (TypeScript 方言) |
| 构建工具 | Hvigor 6.1.0（`hvigor/hvigor-config.json5` → `modelVersion`） |
| 支持设备 | 手机 (phone)、平板 (tablet) |
| 兼容 SDK | `5.0.0(12)`（`build-profile.json5` → `compatibleSdkVersion`） |
| 目标 SDK | `6.1.0(23)`（`build-profile.json5` → `targetSdkVersion`） |
| 运行时 | HarmonyOS（`runtimeOS`） |

---

## 2. 技术架构

### 2.1 整体架构

```
┌──────────────────────────────────────────────────┐
│                   AppScope                       │
│              (app.json5 应用全局配置)              │
├──────────────────────────────────────────────────┤
│                  Entry HAP Module                │
│  ┌────────────────────────────────────────────┐  │
│  │          EntryAbility (UIAbility)           │  │
│  │           应用生命周期 · 窗口管理             │  │
│  ├────────────────────────────────────────────┤  │
│  │        Index.ets (单页多 Tab 架构)           │  │
│  │  ┌──────┬──────┬──────┬──────┐            │  │
│  │  │仪表盘 │ 专注  │ 运动  │ 个人  │            │  │
│  │  └──────┴──────┴──────┴──────┘            │  │
│  └────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────┤
│              资源层 (resources)                   │
│       string.json · color.json · media/          │
└──────────────────────────────────────────────────┘
```

### 2.2 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| UI 框架 | ArkUI (声明式) | @Component / @Builder / @Entry |
| 编程语言 | ArkTS | TypeScript 超集，HarmonyOS 原生语言 |
| 状态管理 | `@State` | 组件内响应式状态（未使用 `@StorageLink` / AppStorage） |
| 生命周期 | Stage 模型 | UIAbility + WindowStage |
| 构建系统 | Hvigor | 官方构建工具，HAP 打包 |
| 页面路由 | main_pages.json | 声明式页面注册 |
| 设计系统 | Vitality Tech Health | 自定义 AppColor + 中英双语 |

---

## 3. 项目结构

本仓库为 **可运行的 HarmonyOS Stage 工程**，UI 由 HTML 原型迁移为 ArkUI 后集中在 `Index.ets`。不包含历史上的 HTML 静态稿目录（如 `dashboard_v2/`、`vitality_tech_health/` 等）；若需对照设计稿，请从 Stitch 完整交付包或其它分支获取。

```
stitch_harmonyos_ai_health_monitor/
│
├── AppScope/
│   └── app.json5                            # 应用全局配置（包名、版本、图标/名称引用）
│
├── entry/                                   # 主入口模块 (entry HAP)
│   ├── build-profile.json5
│   ├── hvigorfile.ts
│   ├── oh-package.json5
│   │
│   └── src/main/
│       ├── module.json5
│       │
│       ├── ets/
│       │   ├── entryability/
│       │   │   └── EntryAbility.ets
│       │   ├── pages/
│       │   │   └── Index.ets                # 4 Tab 单文件 UI + AppColor + 状态逻辑
│       │   ├── model/                       # 预留（当前无源码文件）
│       │   └── theme/                       # 预留（当前无源码文件）
│       │
│       └── resources/base/
│           ├── element/string.json, color.json
│           ├── media/app_icon.svg
│           └── profile/main_pages.json
│
├── hvigor/hvigor-config.json5
├── hvigorfile.ts                            # 工程级 Hvigor 入口
├── build-profile.json5                      # 工程级 SDK 与模块映射
├── oh-package.json5                         # 工程级 OHPM 描述
├── README.md
└── PROJECT_DOCUMENTATION.md
```

**本地生成、通常不入 Git 的目录**（见 `.gitignore`）：`entry/build/`、`entry/.preview/`、`.hvigor/`、`.idea/` 等。在 DevEco 中打开工程并构建后才会出现。

### 文件说明

| 文件 | 作用 | 必须 |
|------|------|:----:|
| `AppScope/app.json5` | 定义应用包名、版本、图标等全局属性 | ✅ |
| `build-profile.json5` | 工程级 compatible/target SDK、entry 模块引用 | ✅ |
| `oh-package.json5` | 工程级 OHPM 描述 | ✅ |
| `hvigorfile.ts` | 工程级 Hvigor 构建入口 | ✅ |
| `entry/src/main/module.json5` | 模块清单：声明 Ability、页面路由、Skills | ✅ |
| `entry/src/main/ets/entryability/EntryAbility.ets` | 应用入口：窗口创建与页面加载 | ✅ |
| `entry/src/main/ets/pages/Index.ets` | 主界面：所有 UI 组件的单文件实现 | ✅ |
| `entry/src/main/resources/base/profile/main_pages.json` | 页面路由注册 | ✅ |
| `entry/src/main/resources/base/element/string.json` | 应用名等字符串资源 | 推荐 |
| `entry/src/main/resources/base/element/color.json` | 启动页背景等颜色资源 | 推荐 |
| `entry/build-profile.json5` | 模块编译配置 | ✅ |
| `entry/hvigorfile.ts` | 模块构建任务 | ✅ |
| `entry/oh-package.json5` | 模块三方依赖（当前为空） | ✅ |
| `hvigor/hvigor-config.json5` | Hvigor `modelVersion` 等全局配置 | ✅ |

---

## 4. 核心配置文件说明

### 4.1 `AppScope/app.json5` — 应用全局配置

```json5
{
  "app": {
    "bundleName": "com.stitch.healthmonitor",  // 全局唯一包名
    "vendor": "stitch",                         // 开发者
    "versionCode": 1000000,                      // 构建版本号 (整数递增)
    "versionName": "1.0.0",                     // 用户可见版本
    "icon": "$media:app_icon",
    "label": "$string:app_name"
  }
}
```

> **注意**：`versionCode` 每次发布必须递增，用于应用商店版本判断。

### 4.2 `entry/src/main/module.json5` — 模块清单

```json5
{
  "module": {
    "name": "entry",
    "type": "entry",                            // 应用入口模块（不可缺省）
    "mainElement": "EntryAbility",               // 启动入口 Ability
    "deviceTypes": ["phone", "tablet"],          // 支持设备类型
    "deliveryWithInstall": true,                 // 随应用安装部署
    "installationFree": false,                   // 不支持免安装
    "pages": "$profile:main_pages",              // 页面路由配置引用
    "abilities": [{
      "name": "EntryAbility",
      "srcEntry": "./ets/entryability/EntryAbility.ets",
      "exported": true,
      "skills": [{
        "entities": ["entity.system.home"],
        "actions": ["action.system.home"]        // 桌面入口
      }]
    }]
  }
}
```

#### 配置要点

- `type: "entry"` — 标记该模块为应用主入口，每个应用必须有且仅有一个 entry 类型模块
- `pages` — 使用 `$profile:` 语法引用 `resources/base/profile/` 下的路由配置
- `skills` — 声明 `action.system.home` 使应用出现在桌面/主屏幕

### 4.3 `main_pages.json` — 页面路由注册

```json
{
  "src": ["pages/Index"]
}
```

> ⚠️ **新增页面时必须在此文件中注册**，否则页面无法访问。

### 4.4 `entry/oh-package.json5` — 依赖管理

```json5
{
  "name": "entry",
  "version": "1.0.0",
  "dependencies": {}     // 三方库在此声明，通过 ohpm install 安装
}
```

当前无外部依赖，所有功能均基于 HarmonyOS 原生框架实现。

---

## 5. 功能模块详解

应用采用 **单页面四 Tab 架构**，由 `Index.ets` 中的 `@State currentTab` 控制页面切换，所有 UI 通过 `@Builder` 方法构建。

### 5.1 Tab 1 — 仪表盘 (Dashboard)

**功能定位**：健康状态总览，一站式数据聚合页

| 子组件 | 说明 | 关键数据 |
|--------|------|----------|
| 健康状态卡片 | 综合健康评分环形图 | 评分：85/100 |
| `MetricCard` × 2 | 实时专注指数 / 疲劳指数 | 专注 48级 · 疲劳 78/100 |
| `SpectrumCard` | 脑电频谱 (Alpha/Theta/Beta 波) | 三波段强度可视化 |
| `SuggestionCard` | AI 智能健康建议 | 提示进行25分钟专注训练 |

**生命周期**：进入页面即显示，数据为模拟静态/动态混合。

### 5.2 Tab 2 — 专注 (Focus)

**功能定位**：番茄钟计时器 + 实时专注监测

| 组件 | 功能 |
|------|------|
| 环形计时器 | 25分钟番茄钟倒计时，最后一分钟变红警告 |
| 控制按钮组 | 重置 / 开始暂停（双态切换） |
| `FocusDataCard` | 脑电波柱状图 + 专注百分比进度条 |
| `RestAdviceCard` | 科学休息建议卡片 |

**核心逻辑**：
```
timerSeconds 每秒 -1
  ├── 倒计时 ≤ 60s → 环形进度条变红
  ├── 每 3 秒 → focusScore +1 (86~94 循环)
  └── 倒计时归零 → 自动停止
```

**生命周期**：`aboutToDisappear()` 中调用 `stopTimer()` 清理定时器。

### 5.3 Tab 3 — 运动 (Sports)

**功能定位**：运动数据实时追踪

| 组件 | 指标 |
|------|------|
| 横向滚动指标卡 | 心率 142bpm · 步频 168spm · 卡路里 312kcal |
| 专注状态环 | 运动中的脑电专注度环形图 |
| 路线预览区 | 跑步路线缩略图占位 |
| 饮水提示 | 运动补水建议 |

### 5.4 Tab 4 — 个人 (Profile)

**功能定位**：用户信息与系统设置

| 子组件 | 功能 |
|--------|------|
| 用户摘要卡片 | 头像、昵称、会员状态 |
| 菜单行 | 设备管理、数据同步、通知等入口 |
| `SettingsPanel` | 设置面板（自动重连、云同步、屏幕常亮等开关） |
| 专注/疲劳阈值滑块 | 自定义警告阈值 |
| `LanguageSelector` | 中英双语切换 |
| `BackgroundPicker` | 三种背景样式选择（白色/蓝色/暖色） |

---

## 6. 设计系统

采用 **Vitality Tech Health** 视觉规范（色板与间距约定见下文）。实现上由 `entry/src/main/ets/pages/Index.ets` 内的 `AppColor` 静态类承载主色；`resources/base/element/color.json` 仅用于模块配置中的启动页背景等资源引用。

### 6.1 色彩系统

#### 核心色板

| Token | 色值 | 用途 |
|-------|------|------|
| `Primary` | `#0054CB` | 主按钮、链接、选中态 |
| `PrimarySoft` | `#DAE2FF` | 图标底色、背景高亮 |
| `Surface` | `#F9F9FF` | 区域底色、次级按钮 |
| `Card` | `#F8F9FC` | 数据卡片背景 |
| `Text` | `#0F1C2F` | 主文字色 |
| `Muted` | `#556477` | 次要/说明文字 |
| `Border` | `#EBEDEF` | 卡片边框 |

#### 状态色

| Token | 色值 | 语义 |
|-------|------|------|
| `Good` | `#2DC973` | 健康/正常/达标 |
| `Warning` | `#FF8A4C` | 临界/待处理 |
| `Danger` | `#FF4D4F` | 警告/异常/错误 |

> 代码中以 `AppColor` 静态类承载所有颜色常量（见 `Index.ets` L35-L58）。

### 6.2 字体排版

| 样式 | 字体 | 字号 | 字重 | 用途 |
|------|------|------|------|------|
| display-lg | Inter | 32px | 700 | 大标题 |
| headline-md | Inter | 24px | 600 | 页面标题 |
| headline-sm | Inter | 20px | 600 | 卡片标题 |
| body-lg | Inter | 16px | 400 | 正文 |
| body-md | Inter | 14px | 400 | 描述文字 |
| label-md | Inter | 12px | 500 | 数据标签 |

### 6.3 形状与间距

| 属性 | 值 |
|------|-----|
| 基础间距 | 8px grid |
| 卡片圆角 | 16px (rounded-lg) |
| 按钮圆角 | 8px (rounded-md) |
| 标签圆角 | 9999px (full pill) |
| 页面边距 | 16px |
| 卡片间距 | 12px |

### 6.4 国际化

应用内置中英双语支持，通过 `@State language` 控制：
- `0` = 中文（默认）
- `1` = English

核心方法：
```typescript
private t(zh: string, en: string): string {
  return this.language === 0 ? zh : en;
}
```

---

## 7. 状态管理

### 7.1 状态变量清单

| 变量 | 类型 | 默认值 | 用途 |
|------|------|--------|------|
| `currentTab` | `number` | `0` | 当前标签页索引 |
| `focusScore` | `number` | `88` | 专注指数 (0-100) |
| `fatigueScore` | `number` | `78` | 疲劳指数 (0-100) |
| `timerSeconds` | `number` | `1500` | 番茄钟倒计时秒数 |
| `timerRunning` | `boolean` | `false` | 计时器运行状态 |
| `language` | `number` | `0` | 语言设置 |
| `autoReconnect` | `boolean` | `true` | 设备自动重连 |
| `cloudSync` | `boolean` | `true` | 云端数据同步 |
| `keepScreenOn` | `boolean` | `false` | 屏幕常亮 |
| `focusThreshold` | `number` | `40` | 专注警告阈值 |
| `fatigueThreshold` | `number` | `80` | 疲劳警告阈值 |
| `bgStyle` | `number` | `0` | 背景样式索引 |

### 7.2 非状态成员

| 变量 | 类型 | 用途 |
|------|------|------|
| `timerId` | `number` | `setInterval` 返回的定时器 ID |
| `barValues` | `number[]` | 脑电柱状图模拟数据 |

### 7.3 数据流

```
用户交互 → onClick / onChange
    ↓
@State 变量更新
    ↓
依赖该变量的 @Builder 方法自动重新渲染
    ↓
UI 刷新
```

> 当前所有状态均为组件级（`@State`），未使用全局状态管理（如 AppStorage）。未来如需跨页面共享健康数据，建议引入 `@StorageLink` 或 ViewModel 模式。

---

## 8. 构建与运行

### 8.1 构建工具链

| 工具 | 版本 | 用途 |
|------|------|------|
| Hvigor | 6.1.0 | 项目构建 |
| DevEco Studio | 最新版 | IDE |
| ohpm | — | 包管理器 |

### 8.2 构建命令

```bash
# 在 DevEco Studio 中：
# 菜单栏 → Build → Build HAP(s) / Build APP(s)

# 或使用命令行：
hvigorw assembleHap    # 编译 HAP
```

### 8.3 运行要求

- HarmonyOS NEXT 真机或模拟器
- DevEco Studio 与工程 `build-profile.json5` 中声明的 SDK 一致（当前 **compatibleSdkVersion `5.0.0(12)`**、**targetSdkVersion `6.1.0(23)`**）
- 支持设备：Phone、Tablet（见 `module.json5` → `deviceTypes`）

### 8.4 构建产物

构建成功后（目录由 Hvigor 生成，默认被 `.gitignore` 忽略）：

```
entry/build/default/outputs/default/
├── entry-default-signed.hap      # 已签名 HAP（需先配置 Signing Configs）
└── entry-default-unsigned.hap    # 未签名 HAP
```

实际文件名可能随 DevEco / Hvigor 版本略有差异，以 `entry/build/.../outputs/` 下产物为准。

---

## 9. 开发约定

### 9.1 代码风格

- **语言**：ArkTS (TypeScript)
- **UI 范式**：声明式，所有 UI 通过 `build()` / `@Builder` 方法构建
- **命名**：
  - 组件名：PascalCase（如 `DashboardPage`）
  - 方法名：camelCase（如 `startTimer`）
  - 常量：PascalCase 或 UPPER_SNAKE_CASE
- **注释**：JSDoc 风格，中文优先
- **格式化**：2 空格缩进

### 9.2 组件架构原则

- 当前为单文件多 Builder 结构，所有 UI 在 `Index.ets` 中
- 功能逐步复杂时，应将 `@Builder` 方法抽取为独立 `@Component`
- 通用 UI 单元（如 `Tag`、`MetricCard`）优先复用

### 9.3 新增页面流程

1. 在 `entry/src/main/ets/pages/` 下创建新的 `.ets` 文件
2. 在 `main_pages.json` 的 `src` 数组中注册路径
3. 如需新 Ability，在 `module.json5` 的 `abilities` 中声明

### 9.4 资源引用规范

| 资源类型 | 引用语法 | 示例 |
|----------|----------|------|
| 字符串 | `$string:key` | `$string:app_name` |
| 颜色 | `$color:key` | `$color:background_main` |
| 媒体 | `$media:filename` | `$media:app_icon` |
| 配置文件 | `$profile:filename` | `$profile:main_pages` |

---

## 10. 后续迭代方向

### 短期优化

- [ ] 抽取各 Tab 页面为独立 `@Component`，拆分 `Index.ets`；将 `AppColor` 迁入 `ets/theme/`
- [ ] 在 `ets/model/` 中建立健康数据模型，与 UI 解耦
- [ ] 引入真机脑电设备 SDK 对接，替换模拟数据
- [ ] 添加本地数据库（如 `@ohos.data.relationalStore`）持久化用户健康数据
- [ ] 完善设置页面功能（背景切换实际生效、数据导出等）

### 中期规划

- [ ] 多设备协同（手机 + 手表数据同步）
- [ ] 健康报告生成与分享
- [ ] 运动 GPS 轨迹记录
- [ ] 接入华为健康服务 (Health Kit)

### 长期规划

- [ ] AI 模型本地推理（专注度/疲劳度预测）
- [ ] 社区功能（健康挑战赛、排行榜）
- [ ] 原子化服务卡片 (FormAbility)
- [ ] 数据可视化增强（折线图、热力图）
- [ ] Wear Engine 穿戴设备深度集成

---

> **文档更新日期**：2026-05-29  
> **维护者**：stitch  
> **说明**：本仓库未附带 `LICENSE` 文件；使用前请与项目维护方确认授权范围。
