# AGENTS.md

## 项目概览

本项目是一个基于 HarmonyOS Stage 模型的 ArkUI/ArkTS 应用，应用名为 HealthSync，定位为 AI 健康监测演示应用。主功能包括仪表盘、专注番茄钟、运动追踪和个人设置四个 Tab。

仓库根目录是 `D:\BigProject\APP`。项目可用 DevEco Studio 直接打开、同步 Hvigor/OHPM 后构建运行。

## 技术栈与构建

- 语言与 UI：ArkTS + ArkUI 声明式组件。
- 应用模型：HarmonyOS Stage Model，主入口为 `UIAbility`。
- 构建工具：Hvigor。
- 工程依赖：当前 `oh-package.json5` 和 `entry/oh-package.json5` 中没有第三方 OHPM 依赖。
- 设备支持：phone、tablet。
- 兼容 SDK：以根目录 `build-profile.json5` 为准，目前为 `compatibleSdkVersion: 5.0.0(12)`。
- 构建产物：成功构建后通常位于 `entry/build/default/outputs/default/`，该类生成目录不应提交。

## 关键目录

- `AppScope/app.json5`：应用级配置，包含包名 `com.stitch.healthmonitor`、版本号、图标和应用名引用。
- `entry/`：主 HAP 模块。
- `entry/src/main/module.json5`：模块清单，声明 `EntryAbility`、设备类型、权限、页面路由等。
- `entry/src/main/ets/entryability/EntryAbility.ets`：应用 Ability 入口，通过 `windowStage.loadContent('pages/Index')` 加载主页。
- `entry/src/main/ets/pages/Index.ets`：主页面和大部分业务 UI，采用单页四 Tab 架构。
- `entry/src/main/ets/components/`：可复用 UI 组件，例如 `BottomNav`、`TopBar`、`InputLike`、`MenuRow`、`SummaryCard`。
- `entry/src/main/ets/theme/AppColor.ets`：应用颜色系统。
- `entry/src/main/ets/data/DataService.ts`：ToApp 数据轮询服务，负责读取/解析 `ToAppJson` 并回调页面状态更新。
- `entry/src/main/ets/data/ToApp.json`：当前默认数据源。完整后端尚未接入时，前端以该文件内容作为默认实时数据。
- `entry/src/main/ets/config/config.ts`：后端地址配置。
- `entry/src/main/resources/base/profile/main_pages.json`：页面路由注册，新增页面时需要同步注册。

## 应用结构与状态

- 主界面由 `Index.ets` 中的 `@Entry @Component struct Index` 承载。
- 页面切换由 `@State private currentTab` 控制，Tab 顺序为：仪表盘、专注、运动、个人。
- UI 主要通过 `@Builder` 方法组织，尽量沿用现有布局方式和命名风格。
- 组件内状态主要使用 `@State`，当前未使用 `AppStorage` 或 `@StorageLink`。
- 专注计时器使用 `setTimeout` 链式调度，并在离开专注页或组件销毁时暂停。
- `aboutToAppear()` 中启动数据接收，`aboutToDisappear()` 中停止数据接收并暂停计时器。

## 数据与网络

- 当前前端数据流为：后端更新 `ToApp.json`/接口数据 → `DataService` 每 1 秒读取并解析 → 回调 `Index.ets` 更新 `@State` → 页面自动重渲染。
- 后端完整接入前，`DataService` 中的接口端点预留为空字符串，默认使用 `entry/src/main/ets/data/ToApp.json`。
- 后续接入后端时，将 `DataService` 中的接口端点改为真实地址或配置变量；旧的 `AppConfig.backendUrl` 可作为后端地址来源。
- `DataService` 轮询间隔为 1000ms。
- `DataService` 使用 `@kit.NetworkKit` 的 `http.createHttp()`，请求完成后要调用 `request.destroy()`。
- `ToAppJson` 当前支持字段包括：`focus`、`fatigue`、`relax`、`load`、`quality`、`confidence`、趋势字段、`state`、`direction`、`advice`、`local`、`model`、`summary`。
- `Index.ets` 中仪表盘、建议卡片、脑电频谱、个人页统计应优先绑定 `ToAppJson` 数据；后端失连或字段缺失时保持 0/空值或已有状态，不再使用写死演示指标。
- `entry/src/main/module.json5` 已声明 `ohos.permission.INTERNET`，网络相关改动应保持权限配置一致。

## UI 与设计约定

- 颜色优先使用 `AppColor` 中的静态值，避免在业务代码中随意新增硬编码颜色。
- 现有视觉风格偏清爽健康科技感：白色/浅灰卡片、蓝色主色、绿色成功、橙色警告、红色危险。
- 底部导航和顶部栏已拆到 `components`，扩展时优先复用或延续该拆分方式。
- 中英双语通过组件内 `t(zh, en)` 方法和 `language` 状态处理，新增可见文案时应同时提供中文和英文。
- 当前底部导航图标使用字母占位（D/F/S/P），如要替换成图标，需要确认 ArkUI 可用图标方案并保持布局稳定。

## 开发注意事项

- 文档和源码中包含中文注释，读取文件时请使用 UTF-8 编码，避免 PowerShell 默认编码导致乱码。
- 现有工作区可能存在用户未提交改动，修改前先查看 `git status --short`，不要回退或覆盖他人的改动。
- 修改数据展示逻辑时，避免在计时器或 UI 交互中模拟覆盖 `focus`、`fatigue` 等后端实时字段，防止覆盖 `DataService` 回调结果。
- 新增页面必须更新 `entry/src/main/resources/base/profile/main_pages.json`。
- 修改包名、版本号、SDK、设备类型或权限时，要同步检查 `AppScope/app.json5`、根目录 `build-profile.json5` 和 `entry/src/main/module.json5`。
- 生成目录如 `.hvigor/`、`build/`、`entry/build/`、`.idea/` 通常不应纳入提交。
- 如果需要真机构建或运行，通常要在 DevEco Studio 中配置 Signing Configs。

## 验证建议

- 小范围 ArkTS/UI 改动：至少在 DevEco Studio 中同步并构建 `entry` 模块。
- 涉及页面路由：确认 `main_pages.json` 已注册，并验证 `EntryAbility` 能加载对应页面。
- 涉及网络数据：后端未接入时确认 `ToApp.json` 能驱动页面默认数据；后端接入后确认接口返回 JSON，并观察 `DataService` 错误日志。
- 涉及计时器或轮询：重点检查离开页面、组件销毁、重复进入时是否正确清理定时器。

