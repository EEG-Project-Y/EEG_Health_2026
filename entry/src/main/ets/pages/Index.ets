/**
 * ============================================================================
 * Index.ets - HealthSync AI 健康监测应用主页面
 * ============================================================================
 *
 * 功能概述：
 *   基于 HarmonyOS ArkUI 框架构建的 AI 健康监测应用主界面，
 *   提供脑电(EEG)数据分析、专注计时、运动追踪等核心功能。
 *
 * 页面架构（4 个 Tab 页签）：
 *   1. 仪表盘 (Dashboard)  - 健康状态总览、实时专注/疲劳指标、脑电频谱、AI 建议
 *   2. 专注    (Focus)       - 番茄钟计时器、实时专注数据、休息建议
 *   3. 运动    (Sports)      - 心率/步频/卡路里监测、专注状态、路线预览
 *   4. 个人    (Profile)     - 用户信息、设备管理、系统设置、背景样式切换
 *
 * 技术栈：
 *   - ArkTS 声明式 UI + @Component/@Builder 组件化架构
 *   - @State 组件内响应式状态（未使用 @StorageLink）
 *   - 中英双语国际化支持（默认中文）
 *   - 自定义 AppColor 设计系统
 *
 * 文件结构（按 @Builder 顺序）：
 *   AppColor → Index struct → TopBar → DashboardPage → MetricCard
 *   → SpectrumCard → WaveRow → SuggestionCard → FocusPage → FocusDataCard
 *   → RestAdviceCard → Tag → SportsPage → SportMetric → ProfilePage
 *   → SummaryCard → MenuRow → SettingsPanel → LanguageSelector → InputLike
 *   → Toggle/Switch/Slider 组件 → BackgroundPicker → BackgroundOption → BottomNav
 *   → TabItem 辅助类
 */

import { DataService, ToAppJson } from '../data/DataService';
import { DemoDataService } from '../data/DemoDataService';
import { ManagerBridgeService, ManagerBridgeStatus } from '../data/ManagerBridgeService';
import { SIMULATOR_DEMO_MODE } from '../config/config';

// ============================================================================
// AppColor - 应用全局颜色设计系统
// ============================================================================
// 定义统一的色板常量，确保全应用视觉风格一致
class AppColor {
  /** 主题色 - 深蓝，用于按钮、链接、选中状态等 */
  static readonly Primary: string = '#0054CB';
  /** 主题色浅色版 - 淡蓝，用于背景高亮、图标底色 */
  static readonly PrimarySoft: string = '#DAE2FF';
  /** 表面色 - 浅灰蓝，用于卡片背景、区域底色 */
  static readonly Surface: string = '#F9F9FF';
  /** 卡片色 - 浅灰，用于内容区卡片 */
  static readonly Card: string = '#F8F9FC';
  /** 纯白色 */
  static readonly White: string = '#FFFFFF';
  /** 主文字色 - 深灰黑 */
  static readonly Text: string = '#0F1C2F';
  /** 次要文字色 - 中灰，用于副标题、说明文字 */
  static readonly Muted: string = '#556477';
  /** 边框色 - 浅灰 */
  static readonly Border: string = '#EBEDEF';
  /** 正向色 - 绿色，用于正常/良好状态指标 */
  static readonly Good: string = '#2DC973';
  /** 警告色 - 橙色 */
  static readonly Warning: string = '#FF8A4C';
  /** 危险色 - 红色，用于警告/异常状态 */
  static readonly Danger: string = '#FF4D4F';
  /** 玻璃卡片底色 - 高透明白色 */
  static readonly Glass: string = '#EFFFFFFF';
  /** 强玻璃卡片底色 - 更高可读性 */
  static readonly GlassStrong: string = '#F8FFFFFF';
  /** 健康科技青色 */
  static readonly Cyan: string = '#00A6A6';
  /** 柔和紫色，用于 AI 模块 */
  static readonly Violet: string = '#6B5CFF';
}

/** 番茄钟默认时长（25 分钟），与 Progress 环 total 默认值一致 */
const DEFAULT_FOCUS_SEC: number = 1500;
/** 自定义专注时长上限（24 小时） */
const MAX_FOCUS_SEC: number = 86400;
/** 同一类安全提醒的冷却时间，避免轮询数据反复打断用户 */
const ALERT_COOLDOWN_MS: number = 60000;

// ============================================================================
// Index - 应用主组件（@Entry 入口 + @Component 自定义组件）
// ============================================================================
@Entry
@Component
struct Index {
  // ──────────────────────────────────────────────────────────────────────────
  // 状态变量（@State 响应式数据，变化时自动触发 UI 更新）
  // ──────────────────────────────────────────────────────────────────────────

  /** 当前选中的标签页索引：0=仪表盘, 1=专注 */
  @State private currentTab: number = 0;
  /** 专注指数 (0-100)，从脑电数据实时计算 */
  @State private focusScore: number = 0;
  /** 疲劳指数 (0-100)，数值越高越疲劳 */
  @State private fatigueScore: number = 0;
  /** 放松指数 (0-100)，来自 ToApp.json */
  @State private relaxScore: number = 0;
  /** 脑负荷指数 (0-100)，来自 ToApp.json */
  @State private loadScore: number = 0;
  /** 信号质量 (0-100)，来自 ToApp.json */
  @State private qualityScore: number = 0;
  /** 模型置信度 (0-1)，来自 ToApp.json */
  @State private confidence: number = 0;
  /** AI 智能建议，来自 ToApp.json 的 advice 字段 */
  @State private advice: string = 'Waiting for EEG data. No data source connected.';
  /** 后端连接状态 */
  @State private connectionStatus: string = 'waiting';
  /** 最近一次同步序号 */
  @State private lastUpdateSequence: number = 0;
  /** 当前是否已经读到真实链路或测试脚本写入的数据 */
  @State private hasEegData: boolean = false;
  /** 当前数据来源：uart / ch340 / real_adc / none 等 */
  @State private dataSource: string = 'none';
  /** 当前数据源细分标记 */
  @State private source: string = 'no_data';
  /** 当前 ToApp/currentData 状态字段 */
  @State private dataState: string = 'waiting';
  @State private channelMode: string = 'unknown';
  /** CH1 是否有效 */
  @State private ch1Valid: boolean = false;
  /** CH2 是否有效 */
  @State private ch2Valid: boolean = false;
  /** 通道状态 */
  @State private channelStatus: string = 'not_connected';
  /** 当前趋势方向，来自 ToApp.json 的 direction 字段 */
  @State private directionText: string = 'no_data';
  /** 本地模型名称，来自 ToApp.json 的 model 字段 */
  @State private modelName: string = 'none';
  /** 是否为本地推理，来自 ToApp.json 的 local 字段 */
  @State private localInference: boolean = false;
  /** 指标趋势，来自 ToApp.json 的 trend 字段 */
  @State private focusTrend: number = 0;
  @State private fatigueTrend: number = 0;
  @State private relaxTrend: number = 0;
  @State private loadTrend: number = 0;
  /** 番茄钟剩余秒数（默认 25 分钟） */
  @State private timerSeconds: number = DEFAULT_FOCUS_SEC;
  /** 番茄钟设定的总时长（秒），可由自定义弹窗修改 */
  @State private focusDurationSec: number = DEFAULT_FOCUS_SEC;
  /** 计时器是否正在运行 */
  @State private timerRunning: boolean = false;
  /** 是否显示自定义专注时长弹窗 */
  @State private showDurationDialog: boolean = false;
  /** 是否显示设置面板 */
  @State private showSettingsPanel: boolean = false;
  /** 刷新模式：manual=手动，auto=自动 */
  @State private refreshMode: string = 'auto';
  /** 弹窗内滚轮选中的时长（时/分映射为 Date；兼容 API 10） */
  @State private draftDurationDate: Date = new Date(1970, 0, 1, 0, 25, 0);
  /** 是否启用设备自动重连 */
  @StorageLink('autoReconnect') private autoReconnect: boolean = true;
  /** 是否启用云端数据同步 */
  @StorageLink('cloudSync') private cloudSync: boolean = true;
  /** 是否保持屏幕常亮（运动模式下默认关闭） */
  @StorageLink('keepScreenOn') private keepScreenOn: boolean = false;
  /** 是否启用脑电安全警告 */
  @StorageLink('warningEnabled') private warningEnabled: boolean = true;
  /** 专注警告阈值（百分比，低于此值触发提醒） */
  @StorageLink('focusThreshold') private focusThreshold: number = 40;
  /** 疲劳警告阈值（百分比，高于此值触发提醒） */
  @StorageLink('fatigueThreshold') private fatigueThreshold: number = 80;
  /** 信号质量警告阈值（低于此值触发提醒） */
  @StorageLink('qualityThreshold') private qualityThreshold: number = 40;
  /** 数据置信度警告阈值（低于此值触发提醒） */
  @StorageLink('confidenceThreshold') private confidenceThreshold: number = 40;
  /** 背景样式索引：0=白色, 1=蓝色, 2=暖色 */
  @StorageLink('bgStyle') private bgStyle: number = 0;
  /** 香橙派管理连接窗口状态 */
  @State private bridgeState: string = 'CLOSED';
  @State private bridgeSessionId: string = '';
  @State private bridgeDeviceId: string = '';
  @State private bridgeRemainingSec: number = 0;
  @State private bridgeManagerId: string = '';
  @State private bridgeLastError: string = '';
  @State private bridgeRequestBusy: boolean = false;
  /** 是否显示全屏安全警告 */
  @State private showSafetyAlert: boolean = false;
  @State private alertTitle: string = '';
  @State private alertMessage: string = '';
  @State private alertDetail: string = '';
  @State private alertFocus: number = 0;
  @State private alertFatigue: number = 0;
  @State private alertQuality: number = 0;

  // ──────────────────────────────────────────────────────────────────────────
  // 语言设置（0=中文, 1=English，默认中文）
  // ──────────────────────────────────────────────────────────────────────────

  /** 当前语言：0=中文, 1=English */
  @StorageLink('language') private language: number = 0;

  // ──────────────────────────────────────────────────────────────────────────
  // 私有成员变量
  // ──────────────────────────────────────────────────────────────────────────

  /** 番茄钟 setTimeout 链 ID（-1 表示无待执行 tick） */
  private focusTimerId: number = -1;
  /** 管理连接采用单链 setTimeout 轮询，防止重复定时器。 */
  private bridgePollTimerId: number = -1;
  private bridgePollingEnabled: boolean = false;
  /** 最近一次已处理警告的时间与数据序号 */
  private lastAlertTime: number = 0;
  private lastAlertSequence: number = -1;
  /** 脑电指标波柱高度数组；无数据时保持低位，避免伪装实时波形 */
  private barValues: number[] = [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4];

  // ==========================================================================
  // 国际化辅助方法
  // ==========================================================================

  /**
   * 双语文本选择器
   * 根据当前语言状态返回中文或英文字符串
   * @param zh - 中文字符串
   * @param en - 英文字符串
   * @returns 对应语言的字符串
   */
  private t(zh: string, en: string): string {
    return this.language === 0 ? zh : en;
  }

  /**
   * 获取指定 Tab 页签的翻译名称
   * @param index - Tab 索引 (0-3)
   * @returns 对应语言的标签名
   */
  private getTabName(index: number): string {
    if (this.language === 0) {
      const zhNames: string[] = ['仪表盘', '专注', '连接'];
      return zhNames[index];
    }
    const enNames: string[] = ['Dashboard', 'Focus', 'Connection'];
    return enNames[index];
  }

  // ==========================================================================
  // 生命周期方法
  // ==========================================================================

  aboutToAppear(): void {
    this.bridgePollingEnabled = true;
    this.refreshBridgeStatus();
    if (this.refreshMode === 'auto') {
      this.startAutoRefresh();
    } else {
      this.stopAutoRefresh();
      this.refreshEegDataOnce();
    }
  }

  private applyToAppJson(data: ToAppJson): void {
    this.dataSource = this.readLabel(data.dataSource, 'none');
    this.source = typeof data.source === 'string' ? this.readLabel(data.source, 'no_data') : 'no_data';
    this.dataState = this.readLabel(data.state, this.dataSource === 'none' ? 'waiting' : 'active');
    this.channelMode = this.readLabel(data.channelMode, this.dataSource === 'none' ? 'unknown' : 'single_channel');
    this.ch1Valid = data.ch1Valid === true;
    this.ch2Valid = data.ch2Valid === true;
    this.channelStatus = this.readLabel(typeof data.channelStatus === 'string' ? data.channelStatus : undefined,
      this.dataSource === 'none' ? 'not_connected' : 'active');
    this.directionText = this.readLabel(data.direction, this.dataSource === 'none' ? 'no_data' : 'stable');
    this.modelName = this.readLabel(data.model, this.dataSource === 'none' ? 'none' : 'local_model');
    this.localInference = data.local === true;
    this.focusTrend = this.readTrend(data.focusTrend, 0);
    this.fatigueTrend = this.readTrend(data.fatigueTrend, 0);
    this.relaxTrend = this.readTrend(data.relaxTrend, 0);
    this.loadTrend = this.readTrend(data.loadTrend, 0);

    const noDataPayload = this.dataSource === 'none' || this.source === 'no_data';
    this.hasEegData = !noDataPayload && this.hasDisplayableEegData(data);

    if (!this.hasEegData) {
      this.focusScore = 0;
      this.fatigueScore = 0;
      this.relaxScore = 0;
      this.loadScore = 0;
      this.qualityScore = 0;
      this.confidence = 0;
      this.lastUpdateSequence = 0;
      this.focusTrend = 0;
      this.fatigueTrend = 0;
      this.relaxTrend = 0;
      this.loadTrend = 0;
      this.advice = this.readLabel(data.advice, 'Waiting for EEG data. No data source connected.');
      this.connectionStatus = 'no_data';
      this.resetBarValues();
      return;
    }

    this.focusScore = this.readPercent(data.focus, 0);
    this.fatigueScore = this.readPercent(data.fatigue, 0);
    this.relaxScore = this.readPercent(data.relax, 0);
    this.loadScore = this.readPercent(data.load, 0);
    this.qualityScore = this.readPercent(data.quality, 0);
    this.confidence = this.readConfidence(data.confidence, 0);
    this.lastUpdateSequence = this.readSequence(data.sequence, 0);
    this.advice = this.readLabel(data.advice, 'EEG data loaded successfully.');
    this.connectionStatus = 'connected';
    this.updateBarValues();
    this.checkSafetyAlert();
  }

  /** 根据用户设置的阈值检查实时脑电数据，沿用 ToPAD 的优先级与冷却策略 */
  private checkSafetyAlert(): void {
    if (!this.warningEnabled || !this.hasEegData || this.showSafetyAlert) {
      return;
    }
    if (this.lastUpdateSequence === this.lastAlertSequence) {
      return;
    }
    const now: number = Date.now();
    if (now - this.lastAlertTime < ALERT_COOLDOWN_MS) {
      return;
    }
    if (this.fatigueScore >= this.fatigueThreshold) {
      this.presentSafetyAlert(
        this.t('高疲劳警告', 'High Fatigue Warning'),
        this.t('检测到疲劳风险过高', 'High fatigue risk detected'),
        this.t('疲劳度已超过设定阈值，建议立即暂停训练并休息。',
          'Fatigue exceeded your threshold. Pause training and take a break.')
      );
      return;
    }
    if (this.focusScore <= this.focusThreshold) {
      this.presentSafetyAlert(
        this.t('专注提醒', 'Focus Alert'),
        this.t('当前专注度过低', 'Focus is below target'),
        this.t('专注度低于设定阈值，建议调整状态后再继续。',
          'Focus is below your threshold. Reset before continuing.')
      );
      return;
    }
    if (this.qualityScore <= this.qualityThreshold) {
      this.presentSafetyAlert(
        this.t('信号质量提醒', 'Signal Quality Alert'),
        this.t('当前信号质量较差', 'Signal quality is low'),
        this.t('数据可能不准确，请检查电极接触和设备佩戴。',
          'Readings may be inaccurate. Check electrode contact and device fit.')
      );
      return;
    }
    if (Math.round(this.confidence * 100) <= this.confidenceThreshold) {
      this.presentSafetyAlert(
        this.t('数据可信度提醒', 'Confidence Alert'),
        this.t('当前数据可信度较低', 'Data confidence is low'),
        this.t('请检查设备连接和佩戴状态，再继续本次监测。',
          'Check the device connection and fit before continuing.')
      );
    }
  }

  private presentSafetyAlert(title: string, message: string, detail: string): void {
    this.alertTitle = title;
    this.alertMessage = message;
    this.alertDetail = detail;
    this.alertFocus = this.focusScore;
    this.alertFatigue = this.fatigueScore;
    this.alertQuality = this.qualityScore;
    this.showSafetyAlert = true;
  }

  private dismissSafetyAlert(): void {
    this.lastAlertTime = Date.now();
    this.lastAlertSequence = this.lastUpdateSequence;
    this.showSafetyAlert = false;
  }

  /** 设置页测试入口：只预览警告，不覆盖实时 EEG 状态 */
  private previewSafetyAlert(): void {
    this.alertTitle = this.t('高疲劳警告', 'High Fatigue Warning');
    this.alertMessage = this.t('检测到疲劳风险过高', 'High fatigue risk detected');
    this.alertDetail = this.t('这是安全警告预览。实际监测中超过阈值时会自动显示。',
      'This is a safety alert preview. It appears automatically when a threshold is crossed.');
    this.alertFocus = this.hasEegData ? this.focusScore : 28;
    this.alertFatigue = this.hasEegData ? this.fatigueScore : 86;
    this.alertQuality = this.hasEegData ? this.qualityScore : 62;
    this.showSettingsPanel = false;
    this.showSafetyAlert = true;
  }

  private appBackgroundColor(): string {
    if (this.bgStyle === 1) {
      return '#E8F2FF';
    }
    if (this.bgStyle === 2) {
      return '#FFF4E8';
    }
    return '#EEF7F7';
  }

  private hasDisplayableEegData(data: ToAppJson): boolean {
    return typeof data.focus === 'number'
      || typeof data.fatigue === 'number'
      || typeof data.relax === 'number'
      || typeof data.load === 'number'
      || typeof data.quality === 'number'
      || (data.state !== undefined && data.state.length > 0);
  }

  private readLabel(value: string | undefined, fallback: string): string {
    if (value === undefined || value.length === 0) {
      return fallback;
    }
    return value;
  }

  private readPercent(value: number | undefined, fallback: number): number {
    if (typeof value !== 'number' || value !== value) {
      return fallback;
    }
    return Math.max(0, Math.min(100, Math.round(value)));
  }

  private readConfidence(value: number | undefined, fallback: number): number {
    if (typeof value !== 'number' || value !== value) {
      return fallback;
    }
    return Math.max(0, Math.min(1, value));
  }

  private readSequence(value: number | undefined, fallback: number): number {
    if (typeof value !== 'number' || value !== value) {
      return fallback;
    }
    return Math.max(0, Math.round(value));
  }

  private readTrend(value: number | undefined, fallback: number): number {
    if (typeof value !== 'number' || value !== value) {
      return fallback;
    }
    return Math.round(value);
  }

  private refreshEegDataOnce(): void {
    if (SIMULATOR_DEMO_MODE) {
      DemoDataService.getInstance().setLanguage(this.language);
      DemoDataService.getInstance().refreshOnce((data: ToAppJson) => {
        this.applyToAppJson(data);
      });
    } else {
      DataService.getInstance().refreshOnce((data: ToAppJson) => {
        this.applyToAppJson(data);
      }, (_msg: string) => {
        this.connectionStatus = 'no_data';
      });
    }
  }

  private startAutoRefresh(): void {
    if (SIMULATOR_DEMO_MODE) {
      DemoDataService.getInstance().setLanguage(this.language);
      DemoDataService.getInstance().startReceiving((data: ToAppJson) => {
        this.applyToAppJson(data);
      }, undefined, 1000);
    } else {
      DataService.getInstance().startReceiving((data: ToAppJson) => {
        this.applyToAppJson(data);
      }, (_msg: string) => {
        this.connectionStatus = 'no_data';
      }, 5000);
    }
  }

  private stopAutoRefresh(): void {
    if (SIMULATOR_DEMO_MODE) {
      DemoDataService.getInstance().stopReceiving();
    } else {
      DataService.getInstance().stopReceiving();
    }
  }

  private switchToManualRefresh(): void {
    if (this.refreshMode === 'manual') {
      return;
    }
    this.refreshMode = 'manual';
    this.stopAutoRefresh();
  }

  private switchToAutoRefresh(): void {
    this.refreshMode = 'auto';
    this.startAutoRefresh();
  }
  private connectionNote(): string {
    if (this.connectionStatus === 'connected') {
      return this.t('ToApp已同步 #' + this.lastUpdateSequence.toString() + ' | 来源 ' + this.dataSource,
        'ToApp synced #' + this.lastUpdateSequence.toString() + ' | source ' + this.dataSource);
    }
    if (this.connectionStatus === 'no_data') {
      return this.t('等待脑电数据 | 数据来源 none', 'Waiting for EEG data | source none');
    }
    return this.t('正在连接ToApp服务', 'Connecting ToApp service');
  }

  private applyBridgeStatus(status: ManagerBridgeStatus): void {
    this.bridgeState = status.state;
    this.bridgeSessionId = status.sessionId;
    this.bridgeDeviceId = status.deviceId;
    this.bridgeRemainingSec = status.remainingSec;
    this.bridgeManagerId = status.connectedManagerId;
    this.bridgeLastError = status.lastError;
  }

  private async refreshBridgeStatus(): Promise<void> {
    if (!this.bridgePollingEnabled) {
      return;
    }
    try {
      const status = await ManagerBridgeService.status();
      this.applyBridgeStatus(status);
    } catch (error) {
      this.bridgeState = 'ERROR';
      this.bridgeLastError = 'BACKEND_UNREACHABLE: ' + JSON.stringify(error);
    }
    this.scheduleBridgePoll();
  }

  private scheduleBridgePoll(): void {
    this.stopBridgePollTimer();
    if (!this.bridgePollingEnabled) {
      return;
    }
    let intervalMs: number = 0;
    if (this.bridgeState === 'OPENING' || this.bridgeState === 'ADVERTISING') {
      intervalMs = 1000;
    } else if (this.bridgeState === 'CONNECTED') {
      intervalMs = 4000;
    }
    if (intervalMs > 0) {
      this.bridgePollTimerId = setTimeout(() => {
        this.bridgePollTimerId = -1;
        this.refreshBridgeStatus();
      }, intervalMs);
    }
  }

  private stopBridgePollTimer(): void {
    if (this.bridgePollTimerId !== -1) {
      clearTimeout(this.bridgePollTimerId);
      this.bridgePollTimerId = -1;
    }
  }

  private async openManagerBridge(): Promise<void> {
    if (this.bridgeRequestBusy) {
      return;
    }
    this.bridgeRequestBusy = true;
    this.stopBridgePollTimer();
    try {
      this.applyBridgeStatus(await ManagerBridgeService.open(300));
    } catch (error) {
      this.bridgeState = 'ERROR';
      this.bridgeLastError = 'OPEN_FAILED: ' + JSON.stringify(error);
    } finally {
      this.bridgeRequestBusy = false;
      this.scheduleBridgePoll();
    }
  }

  private async closeManagerBridge(): Promise<void> {
    if (this.bridgeRequestBusy) {
      return;
    }
    this.bridgeRequestBusy = true;
    this.stopBridgePollTimer();
    try {
      this.applyBridgeStatus(await ManagerBridgeService.close());
    } catch (error) {
      this.bridgeState = 'ERROR';
      this.bridgeLastError = 'CLOSE_FAILED: ' + JSON.stringify(error);
    } finally {
      this.bridgeRequestBusy = false;
      this.scheduleBridgePoll();
    }
  }

  private bridgeStateText(): string {
    if (this.bridgeState === 'CLOSED') return this.t('已关闭', 'Closed');
    if (this.bridgeState === 'OPENING') return this.t('正在打开', 'Opening');
    if (this.bridgeState === 'ADVERTISING') return this.t('等待管理端连接', 'Advertising');
    if (this.bridgeState === 'CONNECTED') return this.t('管理端已连接', 'Connected');
    if (this.bridgeState === 'TIMEOUT') return this.t('连接窗口已超时', 'Timed out');
    return this.t('连接异常', 'Error');
  }

  private bridgeStateColor(): string {
    if (this.bridgeState === 'CONNECTED') return AppColor.Good;
    if (this.bridgeState === 'OPENING' || this.bridgeState === 'ADVERTISING') return AppColor.Primary;
    if (this.bridgeState === 'ERROR') return AppColor.Danger;
    if (this.bridgeState === 'TIMEOUT') return AppColor.Warning;
    return AppColor.Muted;
  }

  private bridgeCountdownText(): string {
    const minutes: number = Math.floor(this.bridgeRemainingSec / 60);
    const seconds: number = this.bridgeRemainingSec % 60;
    const secondText: string = seconds < 10 ? '0' + seconds.toString() : seconds.toString();
    return minutes.toString() + ':' + secondText;
  }

  private metricText(value: number): string {
    return this.hasEegData ? value.toString() : '--';
  }

  private metricProgress(value: number): number {
    return this.hasEegData ? value : 0;
  }

  private sourceColor(): string {
    if (!this.hasEegData) {
      return AppColor.Warning;
    }
    return AppColor.Good;
  }

  private dataSourceNote(): string {
    return this.t('数据来源：' + this.dataSource + ' / ' + this.source,
      'Data source: ' + this.dataSource + ' / ' + this.source);
  }
  private adviceText(): string {
    if (this.advice.length === 0) {
      return this.t('暂未读取到脑电数据，请检查香橙派链路或 ToApp.json。', 'Waiting for EEG data. No data source connected.');
    }
    if (SIMULATOR_DEMO_MODE && this.language === 1) {
      return DemoDataService.getInstance().getAdviceEn(this.advice);
    }
    if (SIMULATOR_DEMO_MODE && this.language === 0) {
      return DemoDataService.getInstance().getAdviceZh(this.advice);
    }
    return this.advice;
  }

  private coreHealthScore(): number {
    if (!this.hasEegData) {
      return 0;
    }
    const score = this.focusScore * 0.35
      + (100 - this.fatigueScore) * 0.25
      + this.relaxScore * 0.15
      + (100 - this.loadScore) * 0.10
      + this.qualityScore * 0.15;
    return Math.max(0, Math.min(100, Math.round(score)));
  }

  private displayStateText(): string {
    if (!this.hasEegData) {
      return this.t('等待脑电数据', 'Waiting for EEG data');
    }
    if (this.dataState === 'focused') {
      return this.t('专注', 'Focused');
    }
    if (this.dataState === 'fatigue_rising') {
      return this.t('疲劳上升', 'Fatigue Rising');
    }
    if (this.dataState === 'fatigue' || this.dataState === 'fatigue_high') {
      return this.t('疲劳', 'Fatigue');
    }
    if (this.dataState === 'relaxed') {
      return this.t('放松', 'Relaxed');
    }
    return this.dataState;
  }

  private trendSymbol(value: number): string {
    if (value > 0) {
      return '↑';
    }
    if (value < 0) {
      return '↓';
    }
    return '→';
  }

  private trendText(value: number): string {
    if (value > 0) {
      return '+' + value.toString();
    }
    return value.toString();
  }

  /**
   * 卡片底部趋势说明文案（替代原“数据来源 / http_toapp”文案）
   * 无数据时保留“等待脑电数据”提示，有数据时展示该卡片对应指标的上升/下降/平稳趋势
   */
  private trendNote(value: number): string {
    if (!this.hasEegData) {
      return this.t('等待脑电数据', 'Waiting for EEG data');
    }
    if (value > 0) {
      return this.t('趋势：上升 ↑', 'Trend: up ↑');
    }
    if (value < 0) {
      return this.t('趋势：下降 ↓', 'Trend: down ↓');
    }
    return this.t('趋势：平稳 →', 'Trend: stable →');
  }

  private confidencePercentText(): string {
    return this.hasEegData ? Math.round(this.confidence * 100).toString() : '--';
  }

  private confidenceProgress(): number {
    return this.hasEegData ? Math.round(this.confidence * 100) : 0;
  }

  private resetBarValues(): void {
    this.barValues = [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4];
  }

  private updateBarValues(): void {
    this.barValues = [
      Math.max(6, this.focusScore),
      Math.max(6, this.relaxScore),
      Math.max(6, this.loadScore),
      Math.max(6, this.qualityScore),
      Math.max(6, 100 - this.fatigueScore),
      Math.max(6, Math.round(this.confidence * 100)),
      Math.max(6, this.focusScore),
      Math.max(6, this.relaxScore),
      Math.max(6, this.loadScore),
      Math.max(6, this.qualityScore),
      Math.max(6, 100 - this.fatigueScore),
      Math.max(6, Math.round(this.confidence * 100))
    ];
  }

  /**
   * 组件即将销毁时调用
   * 停止数据轮询和番茄钟，防止页面销毁后仍计时
   */
  aboutToDisappear(): void {
    this.stopAutoRefresh();
    this.pauseFocusTimer();
    this.bridgePollingEnabled = false;
    this.stopBridgePollTimer();
  }

  // ==========================================================================
  // 番茄钟逻辑（setTimeout 链式调度，避免 setInterval/clearInterval 与隐藏 TextTimer 问题）
  // ==========================================================================

  /** 调度下一秒 tick；仅当 timerRunning 为 true 时继续链式调用 */
  private scheduleFocusTick(): void {
    if (!this.timerRunning) {
      return;
    }
    this.focusTimerId = setTimeout(() => {
      if (!this.timerRunning) {
        return;
      }
      if (this.timerSeconds <= 0) {
        this.pauseFocusTimer();
        return;
      }
      this.timerSeconds -= 1;
      if (this.timerRunning) {
        this.scheduleFocusTick();
      }
    }, 1000);
  }

  /** 暂停番茄钟 */
  private pauseFocusTimer(): void {
    this.timerRunning = false;
    if (this.focusTimerId !== -1) {
      clearTimeout(this.focusTimerId);
      this.focusTimerId = -1;
    }
  }

  /** 开始或继续番茄钟 */
  private startFocusTimer(): void {
    if (this.timerRunning) {
      return;
    }
    if (this.timerSeconds <= 0) {
      this.timerSeconds = this.focusDurationSec;
    }
    this.timerRunning = true;
    this.scheduleFocusTick();
  }

  /** 重置番茄钟到设定总时长并停止 */
  private resetFocusTimer(): void {
    this.pauseFocusTimer();
    this.timerSeconds = this.focusDurationSec;
  }

  /** 将秒数转为 TimePicker 用的 Date（API 10 仅支持小时和分钟） */
  private dateFromSeconds(total: number): Date {
    const safeTotal: number = Math.max(0, Math.min(total, MAX_FOCUS_SEC));
    const hours: number = Math.floor(safeTotal / 3600);
    const minutes: number = Math.floor((safeTotal % 3600) / 60);
    return new Date(1970, 0, 1, hours, minutes, 0);
  }

  /** 从 TimePicker Date 读取总秒数 */
  private secondsFromDate(date: Date): number {
    return date.getHours() * 3600 + date.getMinutes() * 60;
  }

  /** 打开自定义专注时长弹窗 */
  private openDurationDialog(): void {
    if (this.timerRunning) {
      return;
    }
    this.draftDurationDate = this.dateFromSeconds(this.timerSeconds);
    this.showDurationDialog = true;
  }

  /** 取消自定义时长 */
  private cancelDurationDialog(): void {
    this.showDurationDialog = false;
  }

  /** 确认自定义时长并应用到番茄钟 */
  private confirmDurationDialog(): void {
    const total: number = this.secondsFromDate(this.draftDurationDate);
    if (total <= 0) {
      return;
    }
    this.pauseFocusTimer();
    this.focusDurationSec = Math.min(total, MAX_FOCUS_SEC);
    this.timerSeconds = this.focusDurationSec;
    this.showDurationDialog = false;
  }

  /** 切换 Tab；离开专注页时自动暂停计时 */
  private switchTab(index: number): void {
    const nextIndex: number = index > 2 ? 2 : Math.max(0, index);
    if (this.currentTab === 1 && nextIndex !== 1 && this.timerRunning) {
      this.pauseFocusTimer();
    }
    this.currentTab = nextIndex;
  }

  /**
   * 格式化计时器显示文本
   * @returns "MM:SS" 格式的时间字符串
   */
  private timerText(): string {
    const hours: number = Math.floor(this.timerSeconds / 3600);
    const minutes: number = Math.floor((this.timerSeconds % 3600) / 60);
    const seconds: number = this.timerSeconds % 60;
    const pad = (value: number): string => value < 10 ? '0' + value.toString() : value.toString();
    if (hours > 0) {
      return hours.toString() + ':' + pad(minutes) + ':' + pad(seconds);
    }
    return minutes.toString() + ':' + pad(seconds);
  }

  // ==========================================================================
  // build() - 组件构建入口
  // ==========================================================================

  /**
   * 根布局：Stack 叠加容器
   * - 底层：Column 垂直布局（顶栏 + 可滚动内容区）
   * - 顶层：BottomNav 底部导航栏（固定在 Stack 底部）
   */
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // ── 主内容区 ──
      Column() {
        this.TopBar()                          // 顶部栏（用户信息 + 操作按钮）

        Scroll() {                              // 可滚动内容区域
          Column({ space: 16 }) {
            // 根据 currentTab 切换显示不同页面
            if (this.currentTab === 0) {
              this.DashboardPage()
            } else if (this.currentTab === 1) {
              this.FocusPage()
            } else {
              this.ConnectionPage()
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 126 })  // 底部留出悬浮导航栏高度
        }
        .layoutWeight(1)      // 填充剩余空间
        .scrollBar(BarState.Off) // 隐藏滚动条
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.appBackgroundColor())

      // ── 固定在底部的导航栏 ──
      this.BottomNav()

      if (this.showSettingsPanel) {
        Stack() {
          this.SettingsDialog()
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .zIndex(1000)
      }

      if (this.showDurationDialog) {
        Stack() {
          this.FocusDurationDialog()
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .zIndex(1000)
      }

      if (this.showSafetyAlert) {
        Stack() {
          this.SafetyAlertDialog()
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .zIndex(3000)
      }
    }
    .width('100%')
    .height('100%')
  }

  // ==========================================================================
  // @Builder 方法 - 顶部栏
  // ==========================================================================

  /**
   * 顶部栏组件
   * 包含：AI 图标 → 问候语/App名称 → Tab名称 → 操作按钮
   * 背景带毛玻璃效果（半透明 + 阴影）
   */
  @Builder
  TopBar() {
    Row() {
      // 左侧：AI/HS 圆形图标
      Text('AI')
        .width(42)
        .height(42)
        .borderRadius(21)
        .textAlign(TextAlign.Center)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.Primary)
        .backgroundColor(AppColor.PrimarySoft)

      // 中间：上行为问候语，下行为当前页面标题
      Column() {
        Text(this.currentTab === 0 ? this.t('早上好', 'Good morning') : this.currentTab === 2 ? this.t('设备连接', 'Device') : this.t('健康同步', 'HealthSync'))
          .fontSize(12)
          .fontColor(AppColor.Muted)
        Text(this.getTabName(this.currentTab))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Primary)
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      Blank()  // 弹性空白，将按钮推到右侧

      if (SIMULATOR_DEMO_MODE) {
        Text(this.displayStateText())
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.sourceColor())
          .borderRadius(10)
          .margin({ right: 6 })
      }

      // 右侧：设置入口
      Button(this.t('设置', 'Settings'))
        .width(92)
        .height(40)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(AppColor.Primary)
        .borderRadius(20)
        .shadow({ radius: 10, color: '#220054CB', offsetY: 4 })
        .onClick(() => {
          this.showSettingsPanel = true;
        })
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#ECFFFFFF')  // 半透明白色毛玻璃效果
    .shadow({ radius: 14, color: '#142A5670', offsetY: 4 })
  }

  // ==========================================================================
  // @Builder 方法 - 仪表盘页面（Dashboard）
  // ==========================================================================

  /**
   * 仪表盘页面 - 健康数据总览
   * 包含：健康状态卡片 → 实时指标卡片 → 脑电频谱 → AI 智能建议
   */
  @Builder
  DashboardPage() {
    Column({ space: 14 }) {
      this.DashboardHeader()
      this.RefreshModePanel()
      this.AdviceCard()
      this.MetricGrid()
    }
    .width('100%')
  }

  @Builder
  DashboardHeader() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.t('每日健康状态', 'Daily Health Status'))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.Text)
          Text(this.hasEegData
            ? this.t('脑电数据已读取，按当前 ToApp 状态显示。', 'EEG data loaded from the current ToApp state.')
            : this.t('等待脑电数据，未连接数据源。', 'Waiting for EEG data. No data source connected.'))
            .fontSize(13)
            .fontColor(AppColor.Muted)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.StatusBadge(this.dataSource, this.sourceColor())
      }
      .width('100%')

      Row({ space: 8 }) {
        this.StatusBadge(this.source, AppColor.Violet)
        this.StatusBadge(this.channelStatus, this.sourceColor())
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 4, right: 4, top: 4 })
  }

  @Builder
  RefreshModePanel() {
    Column({ space: 8 }) {
      Text(this.t('刷新模式', 'Refresh Mode'))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.Text)

      this.RefreshModeSegment()

      if (this.refreshMode === 'manual') {
        Row() {
          Button(this.t('测试', 'Test'))
            .width(92)
            .height(34)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(AppColor.Primary)
            .borderRadius(17)
            .shadow({ radius: 6, color: '#160054CB', offsetY: 2 })
            .onClick(() => {
              this.refreshEegDataOnce();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Text(this.t('每5秒轮询', 'Polling every 5s'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.Muted)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor('#E8FFFFFF')
    .borderRadius(22)
    .border({ width: 1, color: '#C8FFFFFF' })
    .shadow({ radius: 10, color: '#102A5670', offsetY: 4 })
  }

  @Builder
  RefreshModeSegment() {
    Row() {
      this.RefreshModeOption(this.t('手动', 'Manual'), 'manual')
      this.RefreshModeOption(this.t('自动', 'Auto'), 'auto')
    }
    .width(184)
    .height(38)
    .padding(3)
    .backgroundColor('#F2FFFFFF')
    .borderRadius(19)
    .border({ width: 1, color: '#C8FFFFFF' })
  }

  @Builder
  RefreshModeOption(label: string, mode: string) {
    Text(label)
      .layoutWeight(1)
      .height(32)
      .fontSize(14)
      .fontWeight(this.refreshMode === mode ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.refreshMode === mode ? Color.White : AppColor.Muted)
      .textAlign(TextAlign.Center)
      .borderRadius(16)
      .backgroundColor(this.refreshMode === mode ? AppColor.Primary : '#00FFFFFF')
      .onClick(() => {
        if (mode === 'manual') {
          this.switchToManualRefresh();
        } else {
          this.switchToAutoRefresh();
        }
      })
  }

  @Builder
  AdviceCard() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        Text('AI')
          .width(42)
          .height(42)
          .borderRadius(21)
          .textAlign(TextAlign.Center)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(AppColor.Violet)
        Column({ space: 2 }) {
          Text(this.t('智能建议', 'Smart Suggestion'))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.Text)
          Text(this.modelName)
            .fontSize(12)
            .fontColor(AppColor.Violet)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Text(this.adviceText())
        .fontSize(24)
        .lineHeight(34)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.Text)

      Row({ space: 8 }) {
        this.ChannelPill(this.t('数据源', 'Data'), this.dataSource + ' / ' + this.source, this.sourceColor())
        this.ChannelPill(this.t('状态', 'State'), this.dataState, this.sourceColor())
      }
      .width('100%')

      Row({ space: 8 }) {
        this.ChannelPill('source', this.modelName, AppColor.Violet)
        this.ChannelPill('CH1/CH2', (this.ch1Valid ? 'CH1 OK' : 'CH1 --') + ' / ' + (this.ch2Valid ? 'CH2 OK' : 'CH2 --'), this.sourceColor())
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(22)
    .backgroundColor('#FAFFFFFF')
    .borderRadius(32)
    .border({ width: 1, color: '#DFFFFFFF' })
    .shadow({ radius: 24, color: '#202E3A50', offsetY: 10 })
  }
  @Builder
  MetricGrid() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        this.MetricCard(this.t('实时专注', 'Live Focus'), this.metricText(this.focusScore), '/100', AppColor.Good, this.trendNote(this.focusTrend), this.metricProgress(this.focusScore), this.focusTrend)
        this.MetricCard(this.t('疲劳指数', 'Fatigue Index'), this.metricText(this.fatigueScore), '/100', AppColor.Danger, this.trendNote(this.fatigueTrend), this.metricProgress(this.fatigueScore), this.fatigueTrend)
      }
      .width('100%')
      Row({ space: 10 }) {
        this.MetricCard(this.t('放松', 'Relax'), this.metricText(this.relaxScore), '/100', AppColor.Primary, this.trendNote(this.relaxTrend), this.metricProgress(this.relaxScore), this.relaxTrend)
        this.MetricCard(this.t('负荷', 'Load'), this.metricText(this.loadScore), '/100', AppColor.Warning, this.trendNote(this.loadTrend), this.metricProgress(this.loadScore), this.loadTrend)
      }
      .width('100%')
      Row({ space: 10 }) {
        this.MetricCard(this.t('信号质量', 'Signal Quality'), this.metricText(this.qualityScore), '/100', AppColor.Cyan, this.trendNote(0), this.metricProgress(this.qualityScore), 0)
        this.MetricCard(this.t('置信度', 'Confidence'), this.confidencePercentText(), '%', AppColor.Violet, this.trendNote(0), this.confidenceProgress(), 0)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  MetricCard(title: string, value: string, unit: string, color: string, note: string, progress: number, trend: number) {
    Column({ space: 9 }) {
      Row() {
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Muted)
        Blank()
        Text(this.trendText(trend))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(trend > 0 ? AppColor.Good : (trend < 0 ? AppColor.Danger : AppColor.Muted))
      }
      .width('100%')

      Row({ space: 4 }) {
        Text(value)
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Text)
          .maxLines(1)
        Text(unit)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
          .margin({ bottom: 5 })
      }
      .alignItems(VerticalAlign.Bottom)

      Progress({ value: progress, total: 100, type: ProgressType.Linear })
        .height(7)
        .color(color)

      Text(note)
        .fontSize(11)
        .fontColor(color)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .height(136)
    .padding(14)
    .backgroundColor(AppColor.Glass)
    .borderRadius(24)
    .border({ width: 1, color: '#C8FFFFFF' })
    .shadow({ radius: 12, color: '#102A5670', offsetY: 5 })
  }

  @Builder
  AuxiliaryInfoCard() {
    Column({ space: 12 }) {
      Row() {
        Text(this.hasEegData
          ? this.t('当前模式：' + this.channelMode, 'Mode: ' + this.channelMode)
          : this.t('等待脑电数据', 'Waiting for EEG data'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Text)
        Blank()
        Text('#' + this.lastUpdateSequence.toString())
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Muted)
      }
      .width('100%')

      Row({ space: 8 }) {
        this.ChannelPill(this.t('状态', 'State'), this.channelMode, this.sourceColor())
        this.ChannelPill('CH1/CH2', (this.ch1Valid ? 'CH1 OK' : 'CH1 --') + ' / ' + (this.ch2Valid ? 'CH2 OK' : 'CH2 --'), this.sourceColor())
      }
      .width('100%')
      Row({ space: 8 }) {
        this.ChannelPill(this.t('数据源', 'Data'), this.dataSource + ' / ' + this.source, this.sourceColor())
        this.ChannelPill('source', this.modelName, AppColor.Violet)
      }
      .width('100%')

      Text(this.channelStatus)
        .fontSize(12)
        .fontColor(AppColor.Muted)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor('#DFFFFFFF')
    .borderRadius(24)
    .border({ width: 1, color: '#BFFFFFFF' })
  }

  @Builder
  ChannelPill(label: string, value: string, color: string) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(value)
        .fontSize(12)
        .fontColor(AppColor.Text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor('#F4FFFFFF')
    .borderRadius(16)
    .border({ width: 1, color: '#B8FFFFFF' })
  }


  @Builder
  SettingsDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#730F1C2F')
        .onClick(() => {
          this.showSettingsPanel = false;
        })

      Column({ space: 12 }) {
        Row() {
          Column({ space: 3 }) {
            Text(this.t('设置中心', 'Settings Center'))
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.Text)
            Text(this.t('设备、提醒与显示偏好', 'Device, alerts and display preferences'))
              .fontSize(12)
              .fontColor(AppColor.Muted)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text(this.hasEegData ? this.t('设备在线', 'Device online') : this.t('等待数据', 'Waiting for data'))
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.sourceColor())
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.hasEegData ? '#E5F8EE' : '#FFF1E8')
            .borderRadius(14)
            .margin({ right: 10 })
          Button(this.t('完成', 'Done'))
            .height(36)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(AppColor.Primary)
            .borderRadius(18)
            .onClick(() => {
              this.showSettingsPanel = false;
            })
        }
        .width('100%')

        Scroll() {
          Column({ space: 12 }) {
            Row({ space: 12 }) {
              Column({ space: 12 }) {
                this.SettingsDeviceCard()
                this.SettingsGeneralCard()
              }
              .layoutWeight(1)

              Column() {
                this.SettingsAlertCard()
              }
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)

            this.SettingsAppearanceCard()
          }
          .width('100%')
          .padding({ bottom: 4 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .alignItems(HorizontalAlign.Start)
      .width('92%')
      .height('88%')
      .padding(18)
      .backgroundColor('#F8FFFFFF')
      .borderRadius(30)
      .border({ width: 1, color: '#D8FFFFFF' })
      .shadow({ radius: 24, color: '#33000000', offsetY: 10 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SettingsDeviceCard() {
    Column({ space: 10 }) {
      this.SettingsSectionHeader(this.t('设备', 'Device'), this.t('实时链路', 'Live link'), AppColor.Cyan)
      this.SettingsInfoRow(this.t('数据源', 'Data source'), this.dataSource + ' / ' + this.source, this.sourceColor())
      this.SettingsInfoRow(this.t('状态', 'Status'), this.channelStatus, this.sourceColor())
      this.SettingsInfoRow(this.t('模型', 'Model'), this.modelName, AppColor.Violet)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#F5FFFFFF')
    .borderRadius(22)
    .border({ width: 1, color: '#D8FFFFFF' })
  }

  @Builder
  SettingsGeneralCard() {
    Column({ space: 10 }) {
      this.SettingsSectionHeader(this.t('通用', 'General'), this.t('本机偏好', 'Local preferences'), AppColor.Primary)
      this.LanguageSelector()
      this.SwitchRow(this.t('自动重连', 'Auto reconnect'), this.autoReconnect, (value: boolean) => {
        this.autoReconnect = value;
      })
      this.SwitchRow(this.t('云同步', 'Cloud sync'), this.cloudSync, (value: boolean) => {
        this.cloudSync = value;
      })
      this.SwitchRow(this.t('保持屏幕常亮', 'Keep screen on'), this.keepScreenOn, (value: boolean) => {
        this.keepScreenOn = value;
      })
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#F5FFFFFF')
    .borderRadius(22)
    .border({ width: 1, color: '#D8FFFFFF' })
  }

  @Builder
  SettingsAlertCard() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 3 }) {
          Text(this.t('安全警告', 'Safety Alerts'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.Text)
          Text(this.t('超过阈值时全屏提醒，60 秒内不重复打断',
            'Full-screen alert with a 60-second cooldown'))
            .fontSize(11)
            .fontColor(AppColor.Muted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.warningEnabled })
          .selectedColor(AppColor.Danger)
          .onChange((value: boolean) => {
            this.warningEnabled = value;
            if (!value) {
              this.showSafetyAlert = false;
            }
          })
      }
      .width('100%')

      this.SliderFocusThreshold()
      this.SliderFatigueThreshold()
      this.SliderQualityThreshold()
      this.SliderConfidenceThreshold()

      Button(this.t('预览安全警告', 'Preview Safety Alert'))
        .width('100%')
        .height(40)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(AppColor.Danger)
        .borderRadius(20)
        .enabled(this.warningEnabled)
        .opacity(this.warningEnabled ? 1 : 0.45)
        .onClick(() => {
          this.previewSafetyAlert();
        })
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFF8F7')
    .borderRadius(22)
    .border({ width: 1, color: '#FFD4D0' })
  }

  @Builder
  SettingsAppearanceCard() {
    Column({ space: 10 }) {
      this.SettingsSectionHeader(this.t('界面背景', 'Interface Background'),
        this.t('选择后立即应用', 'Applied immediately'), AppColor.Good)
      Row({ space: 10 }) {
        this.BackgroundOption(this.t('清爽', 'Fresh'), '#EEF7F7', 0)
        this.BackgroundOption(this.t('蓝色', 'Blue'), '#E8F2FF', 1)
        this.BackgroundOption(this.t('暖色', 'Warm'), '#FFF4E8', 2)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#F5FFFFFF')
    .borderRadius(22)
    .border({ width: 1, color: '#D8FFFFFF' })
  }

  @Builder
  SettingsSectionHeader(title: string, subtitle: string, color: string) {
    Row() {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Text)
        Text(subtitle)
          .fontSize(11)
          .fontColor(AppColor.Muted)
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      Text(this.t('已保存', 'Saved'))
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .padding({ left: 9, right: 9, top: 5, bottom: 5 })
        .backgroundColor('#EFFFFFFF')
        .borderRadius(12)
    }
    .width('100%')
  }

  @Builder
  SettingsInfoRow(label: string, value: string, color: string) {
    Row({ space: 8 }) {
      Text(label)
        .width(72)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(value)
        .layoutWeight(1)
        .fontSize(11)
        .fontColor(AppColor.Text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor('#F2FFFFFF')
    .borderRadius(14)
    .border({ width: 1, color: '#B8FFFFFF' })
  }

  @Builder
  SliderQualityThreshold() {
    Column({ space: 5 }) {
      Row() {
        Text(this.t('信号质量下限', 'Signal quality minimum'))
          .fontSize(13)
          .fontColor(AppColor.Text)
        Blank()
        Text(Math.round(this.qualityThreshold).toString() + '%')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Warning)
      }
      Slider({ value: this.qualityThreshold, min: 0, max: 100, step: 1, style: SliderStyle.InSet })
        .width('100%')
        .blockColor(AppColor.Warning)
        .trackColor('#33FF8A4C')
        .selectedColor(AppColor.Warning)
        .onChange((value: number) => {
          this.qualityThreshold = value;
        })
    }
    .width('100%')
  }

  @Builder
  SliderConfidenceThreshold() {
    Column({ space: 5 }) {
      Row() {
        Text(this.t('可信度下限', 'Confidence minimum'))
          .fontSize(13)
          .fontColor(AppColor.Text)
        Blank()
        Text(Math.round(this.confidenceThreshold).toString() + '%')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Violet)
      }
      Slider({ value: this.confidenceThreshold, min: 0, max: 100, step: 1, style: SliderStyle.InSet })
        .width('100%')
        .blockColor(AppColor.Violet)
        .trackColor('#336B5CFF')
        .selectedColor(AppColor.Violet)
        .onChange((value: number) => {
          this.confidenceThreshold = value;
        })
    }
    .width('100%')
  }

  @Builder
  SafetyAlertDialog() {
    Column({ space: 14 }) {
      Text(this.alertTitle)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#8E1B1B')
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .backgroundColor('#FDE8E7')
        .borderRadius(16)

      Text(this.alertMessage)
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)

      Text(this.alertDetail)
        .fontSize(14)
        .fontColor('#FFF0EF')
        .textAlign(TextAlign.Center)
        .maxLines(2)

      Row({ space: 12 }) {
        this.AlertMetric(this.t('疲劳度', 'Fatigue'), this.alertFatigue)
        this.AlertMetric(this.t('专注度', 'Focus'), this.alertFocus)
        this.AlertMetric(this.t('信号质量', 'Signal'), this.alertQuality)
      }
      .width('72%')

      Button(this.t('我知道了', 'Acknowledge'))
        .width('52%')
        .height(48)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#8E1B1B')
        .backgroundColor(Color.White)
        .borderRadius(24)
        .shadow({ radius: 18, color: '#42000000', offsetY: 5 })
        .onClick(() => {
          this.dismissSafetyAlert();
        })
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ left: 28, right: 28, top: 20, bottom: 20 })
    .linearGradient({
      angle: 135,
      colors: [['#E5484D', 0.0], ['#991B1B', 1.0]]
    })
  }

  @Builder
  AlertMetric(label: string, value: number) {
    Column({ space: 3 }) {
      Text(value.toString())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
      Text(label)
        .fontSize(11)
        .fontColor('#FFD7D5')
    }
    .layoutWeight(1)
    .height(68)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#28FFFFFF')
    .borderRadius(18)
    .border({ width: 1, color: '#40FFFFFF' })
  }

  @Builder
  StatusBadge(label: string, color: string) {
    Text(label)
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor(color)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor('#EEFFFFFF')
      .borderRadius(14)
      .border({ width: 1, color: '#C8FFFFFF' })
  }
  // ==========================================================================
  // @Builder 方法 - 专注页面（Focus）
  // ==========================================================================

  /**
   * 专注页面 - 番茄钟 + 实时专注监测
   * 包含：环形计时器 → 控制按钮（重置/开始暂停） → 专注数据 → 休息建议
   */
  @Builder
  FocusPage() {
    Column({ space: 24 }) {
      // ── 环形计时器 ──
      // 进度 = 剩余时间 / 总时间，颜色在最后 1 分钟变红
      Stack() {
        Progress({ value: this.timerSeconds, total: this.focusDurationSec, type: ProgressType.Ring })
          .width(280)
          .height(280)
          .color(this.timerSeconds <= 60 ? AppColor.Danger : AppColor.Good)
        Column({ space: 4 }) {
          Text(this.timerText())         // "MM:SS"
            .fontSize(54)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.timerSeconds <= 60 ? AppColor.Danger : AppColor.Text)
          Text(this.timerRunning ? this.t('专注中', 'Focusing') : this.t('就绪', 'Ready'))
            .fontSize(12)
            .fontColor(AppColor.Muted)
        }
      }
      .margin({ top: 18 })

      // ── 控制按钮行：重置 | 开始/暂停 | 自定义 ──
      Row({ space: 12 }) {
        Button(this.t('重置', 'Reset'))
          .layoutWeight(1)
          .height(54)
          .borderRadius(18)
          .fontColor(AppColor.Muted)
          .backgroundColor(AppColor.Surface)
          .onClick(() => {
            this.resetFocusTimer();
          })

        Button(this.timerRunning ? this.t('暂停', 'Pause') : this.t('开始', 'Start'))
          .layoutWeight(1)
          .height(54)
          .borderRadius(18)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(this.timerRunning ? AppColor.Warning : AppColor.Good)
          .onClick(() => {
            if (this.timerRunning) {
              this.pauseFocusTimer();
            } else {
              this.startFocusTimer();
            }
          })

        Button(this.t('自定义', 'Custom'))
          .layoutWeight(1)
          .height(54)
          .borderRadius(18)
          .fontColor(this.timerRunning ? AppColor.Muted : AppColor.Primary)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.timerRunning ? AppColor.Surface : AppColor.PrimarySoft)
          .enabled(!this.timerRunning)
          .onClick(() => {
            this.openDurationDialog();
          })
      }
      .width('100%')

      // ── 专注数据 + 休息建议（左右并排）──
      Row({ space: 12 }) {
        this.FocusDataCard()
        this.RestAdviceCard()
      }
    }
    .width('100%')
  }

  /**
   * 自定义专注时长弹窗
   * 时/分滚轮 + 取消 / 确定（兼容 OpenHarmony API 10）
   */
  @Builder
  FocusDurationDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .onClick(() => {
          this.cancelDurationDialog();
        })

      Column({ space: 20 }) {
        Text(this.t('自定义专注时长', 'Custom Focus Duration'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Text)
          .width('100%')
          .textAlign(TextAlign.Center)

        TimePicker({
          selected: this.draftDurationDate
        })
          .useMilitaryTime(true)
          .onChange((value: TimePickerResult) => {
            if (value.hour >= 0) {
              this.draftDurationDate = new Date(1970, 0, 1, value.hour, value.minute, 0);
            }
          })

        Row({ space: 12 }) {
          Button(this.t('取消', 'Cancel'))
            .layoutWeight(1)
            .height(48)
            .borderRadius(12)
            .fontColor(AppColor.Muted)
            .backgroundColor(AppColor.Surface)
            .onClick(() => {
              this.cancelDurationDialog();
            })

          Button(this.t('确定', 'Confirm'))
            .layoutWeight(1)
            .height(48)
            .borderRadius(12)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
            .backgroundColor(AppColor.Primary)
            .onClick(() => {
              this.confirmDurationDialog();
            })
        }
        .width('100%')
      }
      .padding(20)
      .width('88%')
      .backgroundColor('#EEF7F7')
      .borderRadius(20)
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 实时专注数据卡片
   * 显示当前专注指数和脑电波实时波形图
   */
  @Builder
  FocusDataCard() {
    Column({ space: 12 }) {
      // 专注指数行
      Row() {
        Text(this.t('实时专注', 'Live Focus'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Text)
        Blank()
        Text(this.hasEegData ? this.focusScore.toString() + '%' : '--')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Primary)
      }
      .width('100%')

      // 进度条
      Progress({ value: this.metricProgress(this.focusScore), total: 100, type: ProgressType.Linear })
        .height(8)
        .color(AppColor.Primary)

      Text(this.hasEegData ? this.dataSourceNote() : this.t('等待脑电数据', 'Waiting for EEG data'))
        .fontSize(12)
        .fontColor(AppColor.Muted)

      // 无数据时保持低位占位；有数据时由 ToApp/currentData 指标派生高度
      Row({ space: 3 }) {
        ForEach(this.barValues, (height: number) => {
          Column() {
          }
            .width(5)
            .height(height)
            .borderRadius(3)
            .opacity(0.72)
            .backgroundColor(AppColor.Primary)
        })
      }
      .height(84)
      .alignItems(VerticalAlign.Center)
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(14)
    .backgroundColor(AppColor.Card)
    .borderRadius(16)
    .border({ width: 1, color: AppColor.Border })
  }

  /**
   * 休息建议卡片
   * 专注训练后的科学休息指导
   */
  @Builder
  RestAdviceCard() {
    Column({ space: 12 }) {
      Text(this.t('休息建议', 'Rest Advice'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.Text)
      Text(this.advice)
        .fontSize(14)
        .lineHeight(22)
        .fontColor(AppColor.Muted)
      // 标签行：显示数据来源与状态
      Row({ space: 8 }) {
        this.Tag(this.dataSource)
        this.Tag(this.dataState)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .padding(14)
    .backgroundColor(AppColor.Card)
    .borderRadius(16)
    .border({ width: 1, color: AppColor.Border })
  }

  /**
   * 标签组件 - 圆角药丸形标签
   * @param text - 标签文字
   */
  @Builder
  Tag(text: string) {
    Text(text)
      .fontSize(11)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(12)
      .fontColor(AppColor.Text)
      .backgroundColor(AppColor.Surface)
  }

  // ==========================================================================
  // @Builder 方法 - 运动页面（Sports）
  // ==========================================================================

  /**
   * 运动页面 - 实时运动数据追踪
   * 包含：横向滚动指标卡 → 专注状态环 → 路线预览 → 饮水提示
   */
  @Builder
  SportsPage() {
    Column({ space: 18 }) {
      // ── 横向滚动的运动指标 ──
      Scroll() {
        Row({ space: 12 }) {
          this.SportMetric(this.t('心率', 'Heart Rate'), '142', this.t('次/分', 'bpm'), AppColor.Danger)
          this.SportMetric(this.t('步频', 'Cadence'), '184', this.t('步/分', 'spm'), AppColor.Primary)
          this.SportMetric(this.t('卡路里', 'Calories'), '342', this.t('千卡', 'kcal'), AppColor.Warning)
        }
        .padding({ right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)

      // ── 专注状态环形图 ──
      Column({ space: 8 }) {
        Text(this.t('专注状态', 'Focus State'))
          .fontSize(12)
          .fontColor(AppColor.Muted)
        Stack() {
          Progress({ value: this.metricProgress(this.focusScore), total: 100, type: ProgressType.Ring })
            .width(250)
            .height(250)
            .color(AppColor.Primary)
          Column({ space: 4 }) {
            Text(this.metricText(this.focusScore))
              .fontSize(52)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.Text)
            Text(this.hasEegData ? this.dataSourceNote() : this.t('等待脑电数据', 'Waiting for EEG data'))
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.sourceColor())
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      // ── 路线预览区域 ──
      Column({ space: 8 }) {
        Text(this.t('路线预览', 'Route Preview'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.Muted)
        Stack() {
          // 模拟地图水印
          Text(this.t('地图', 'MAP'))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.Primary)
            .opacity(0.28)
          // 路线追踪状态标签
          Text(this.t('追踪运动路线', 'Tracking workout route'))
            .fontSize(13)
            .fontColor(AppColor.Primary)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .borderRadius(16)
            .backgroundColor('#1A0054CB')
            .margin({ top: 96 })
        }
        .height(196)
        .width('100%')
        .backgroundColor(AppColor.Surface)
        .borderRadius(16)
        .border({ width: 1, color: AppColor.Border })
      }
      .alignItems(HorizontalAlign.Start)

      // ── 饮水提醒 ──
      Row({ space: 12 }) {
        Text('H2O')
          .width(42)
          .height(38)
          .borderRadius(10)
          .textAlign(TextAlign.Center)
          .fontColor(AppColor.Primary)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(AppColor.PrimarySoft)
        Text(this.t('保持节奏，记得喝水。', 'Keep your pace and drink water.'))
          .fontSize(14)
          .fontColor(AppColor.Muted)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(AppColor.Surface)
      .borderRadius(16)
    }
  }

  /**
   * 运动指标卡片（支持横向滚动）
   * @param title - 指标名称
   * @param value - 当前数值
   * @param unit  - 单位
   * @param color - 主题色
   */
  @Builder
  SportMetric(title: string, value: string, unit: string, color: string) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(12)
        .fontColor(AppColor.Muted)
      Row({ space: 4 }) {
        Text(value)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Text)
        Text(unit)
          .fontSize(11)
          .fontColor(color)
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .alignItems(HorizontalAlign.Start)
    .width(152)
    .padding(14)
    .borderRadius(16)
    .backgroundColor(AppColor.Card)
    .border({ width: 1, color: AppColor.Border })
  }

  // ==========================================================================
  // @Builder 方法 - 个人页面（Profile）
  // ==========================================================================

  /**
   * 个人页面 - 用户中心 + 系统设置
   * 包含：用户信息 → 今日/疲劳统计 → 菜单列表 → 设置面板 → 背景选择器
   */
  @Builder
  ProfilePage() {
    Column({ space: 18 }) {
      // ── 用户信息区（未登录状态）──
      Column({ space: 12 }) {
        Text(this.t('用户', 'User'))
          .width(64)
          .height(64)
          .borderRadius(32)
          .textAlign(TextAlign.Center)
          .fontColor(AppColor.Muted)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(AppColor.Surface)
        Text(this.t('游客 / 未登录', 'Guest / Not signed in'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Text)
        Text(this.t('登录以同步健康数据，解锁更多功能。', 'Sign in to sync health data and unlock more features.'))
          .fontSize(14)
          .fontColor(AppColor.Muted)
        Button(this.t('华为账号登录', 'Sign in with Huawei ID'))
          .height(44)
          .borderRadius(12)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(AppColor.Primary)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 10, bottom: 10 })

      // ── 统计汇总卡片（今日专注 + 平均疲劳）──
      Row({ space: 12 }) {
        this.SummaryCard(this.t('今日专注', 'Today Focus'), '2h 30m', AppColor.Primary)
        this.SummaryCard(this.t('平均疲劳', 'Avg Fatigue'), '45 /100', AppColor.Warning)
      }

      // ── 功能菜单列表 ──
      Column() {
        this.MenuRow(
          this.t('设备管理', 'Device Management'),
          this.t('Orange Pi 已连接', 'Orange Pi connected'),
          AppColor.Primary
        )
        this.MenuRow(
          this.t('提醒阈值', 'Alert Thresholds'),
          this.t('自定义疲劳提醒', 'Customize fatigue warning'),
          AppColor.Danger
        )
        this.MenuRow(
          this.t('背景样式', 'Background Style'),
          this.t('纯色、渐变和预览', 'Solid, gradient and preview'),
          AppColor.Good
        )
      }
      .backgroundColor('#EEF7F7')
      .borderRadius(16)
      .border({ width: 1, color: AppColor.Border })

      // ── 设置面板 ──
      this.SettingsPanel()

      // ── 背景样式选择器 ──
      this.BackgroundPicker()
    }
    .width('100%')
  }

  /**
   * 统计摘要卡片（大号数值 + 标题）
   * @param title - 卡片标题
   * @param value - 核心数值
   * @param color - 数值颜色
   */
  @Builder
  SummaryCard(title: string, value: string, color: string) {
    Column() {
      Text(title)
        .fontSize(12)
        .fontColor(AppColor.Muted)
      Blank()
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .height(122)
    .padding(14)
    .backgroundColor(AppColor.Card)
    .borderRadius(16)
    .border({ width: 1, color: AppColor.Border })
  }

  /**
   * 菜单行（含标题 + 副标题 + 右箭头）
   * @param title    - 主标题
   * @param subtitle - 副标题/当前状态
   * @param color    - 右箭头颜色
   */
  @Builder
  MenuRow(title: string, subtitle: string, color: string) {
    Row() {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.Text)
        Text(subtitle)
          .fontSize(12)
          .fontColor(AppColor.Muted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('>')
        .fontSize(22)
        .fontColor(color)
    }
    .padding(16)
    .width('100%')
  }

  // ==========================================================================
  // @Builder 方法 - 设置面板
  // ==========================================================================

  /**
   * 设置面板
   * 包含：IP/端口配置 → 语言切换 → 自动重连开关 → 阈值滑块 → 云同步/常亮开关
   */
  @Builder
  SettingsPanel() {
    Column({ space: 12 }) {
      Text(this.t('设置', 'Settings'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.Text)
        .width('100%')

      // ── 服务器连接配置（IP + 端口）──
      Row({ space: 10 }) {
        this.InputLike(this.t('IP地址', 'IP Address'), '127.0.0.1')
        this.InputLike(this.t('端口', 'Port'), '18080')
      }

      // ── 语言选择器 ──
      this.LanguageSelector()

      // ── 自动重连开关 ──
      this.ToggleAutoReconnect()

      // ── 专注/疲劳阈值滑块 ──
      this.SliderFocusThreshold()
      this.SliderFatigueThreshold()

      // ── 云同步 + 屏幕常亮开关 ──
      this.ToggleCloudSync()
      this.ToggleKeepScreenOn()
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(AppColor.Card)
    .borderRadius(16)
    .border({ width: 1, color: AppColor.Border })
  }

  /**
   * 语言选择器 - 中文/英文 二选一按钮组
   * 选中状态高亮为主题色，未选中为灰色
   */
  @Builder
  LanguageSelector() {
    Row() {
      Text(this.t('语言', 'Language'))
        .fontSize(15)
        .fontColor(AppColor.Text)
      Blank()
      Row({ space: 6 }) {
        // 中文按钮
        Button(this.t('中文', 'CN'))
          .height(32)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.language === 0 ? Color.White : AppColor.Text)
          .backgroundColor(this.language === 0 ? AppColor.Primary : AppColor.Surface)
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.language = 0;
            if (SIMULATOR_DEMO_MODE) {
              DemoDataService.getInstance().setLanguage(0);
            }
          })
        // 英文按钮
        Button(this.t('EN', 'EN'))
          .height(32)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.language === 1 ? Color.White : AppColor.Text)
          .backgroundColor(this.language === 1 ? AppColor.Primary : AppColor.Surface)
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.language = 1;
            if (SIMULATOR_DEMO_MODE) {
              DemoDataService.getInstance().setLanguage(1);
            }
          })
      }
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  /**
   * 模拟输入框（只读展示，不可编辑）
   * @param label - 标签文字
   * @param value - 显示的值
   */
  @Builder
  InputLike(label: string, value: string) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(AppColor.Muted)
      Text(value)
        .fontSize(14)
        .fontColor(AppColor.Text)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .width('100%')
        .borderRadius(10)
        .backgroundColor('#EEF7F7')
        .border({ width: 1, color: AppColor.Border })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  // ── 开关行组件 ──

  /** 自动重连开关 */
  @Builder
  ToggleAutoReconnect() {
    this.SwitchRow(this.t('自动重连', 'Auto reconnect'), this.autoReconnect, (value: boolean) => {
      this.autoReconnect = value;
    })
  }

  /** 云同步开关 */
  @Builder
  ToggleCloudSync() {
    this.SwitchRow(this.t('云同步', 'Cloud sync'), this.cloudSync, (value: boolean) => {
      this.cloudSync = value;
    })
  }

  /** 屏幕常亮开关 */
  @Builder
  ToggleKeepScreenOn() {
    this.SwitchRow(this.t('保持屏幕常亮', 'Keep screen on'), this.keepScreenOn, (value: boolean) => {
      this.keepScreenOn = value;
    })
  }

  /**
   * 通用开关行（标签 + Switch 组件）
   * @param label   - 开关标签
   * @param checked - 当前开关状态
   * @param onChange - 开关状态变化回调
   */
  @Builder
  SwitchRow(label: string, checked: boolean, onChange: (value: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(AppColor.Text)
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: checked })
        .selectedColor(AppColor.Primary)
        .onChange((value: boolean) => {
          onChange(value);
        })
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  /**
   * 专注阈值滑块
   * 范围 0-100%，使用内嵌样式（InSet）滑块
   */
  @Builder
  SliderFocusThreshold() {
    Column({ space: 8 }) {
      Row() {
        Text(this.t('专注阈值', 'Focus threshold'))
          .fontSize(15)
          .fontColor(AppColor.Text)
        Blank()
        Text(Math.round(this.focusThreshold).toString() + '%')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Primary)
      }
      .width('100%')
      Slider({
        value: this.focusThreshold,
        min: 0,
        max: 100,
        step: 1,
        style: SliderStyle.InSet
      })
        .width('100%')
        .blockColor(AppColor.Primary)
        .trackColor(AppColor.PrimarySoft)
        .selectedColor(AppColor.Primary)
        .onChange((value: number) => {
          this.focusThreshold = value;
        })
    }
    .width('100%')
  }

  /**
   * 疲劳阈值滑块
   * 范围 0-100，超过阈值触发疲劳警告
   */
  @Builder
  SliderFatigueThreshold() {
    Column({ space: 8 }) {
      Row() {
        Text(this.t('疲劳阈值', 'Fatigue threshold'))
          .fontSize(15)
          .fontColor(AppColor.Text)
        Blank()
        Text(Math.round(this.fatigueThreshold).toString() + '/100')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Danger)
      }
      .width('100%')
      Slider({
        value: this.fatigueThreshold,
        min: 0,
        max: 100,
        step: 1,
        style: SliderStyle.InSet
      })
        .width('100%')
        .blockColor(AppColor.Danger)
        .trackColor('#33FF4D4F')
        .selectedColor(AppColor.Danger)
        .onChange((value: number) => {
          this.fatigueThreshold = value;
        })
    }
    .width('100%')
  }

  // ==========================================================================
  // @Builder 方法 - 背景样式选择器
  // ==========================================================================

  /**
   * 背景样式选择器
   * 提供三种预设背景主题：白色、蓝色、暖色
   */
  @Builder
  BackgroundPicker() {
    Column({ space: 14 }) {
      // 预览区：显示当前选中样式的效果
      Column({ space: 8 }) {
        Text(this.t('健康同步', 'Health Sync'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Text)
        Progress({ value: 74, total: 100, type: ProgressType.Linear })
          .height(8)
          .color(AppColor.Primary)
      }
      .width('78%')
      .padding(18)
      .borderRadius(16)
      .backgroundColor('#CCFFFFFF')
      .border({ width: 1, color: AppColor.Border })

      // 颜色选项行
      Row({ space: 10 }) {
        this.BackgroundOption(this.t('白色', 'White'), '#FFFFFF', 0)
        this.BackgroundOption(this.t('蓝色', 'Blue'), '#E0F2FF', 1)
        this.BackgroundOption(this.t('暖色', 'Warm'), '#FFF3E0', 2)
      }

      // 应用按钮
      Button(this.t('应用背景', 'Apply Background'))
        .height(48)
        .width('100%')
        .borderRadius(12)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(AppColor.Primary)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(AppColor.Card)
    .borderRadius(16)
    .border({ width: 1, color: AppColor.Border })
  }

  /**
   * 背景颜色选项
   * 选中时显示主题色边框 + 文字加粗
   * @param label - 颜色名称
   * @param color - 背景色值
   * @param index - 选项索引
   */
  @Builder
  BackgroundOption(label: string, color: string, index: number) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor(index === this.bgStyle ? AppColor.Primary : AppColor.Muted)
        .fontWeight(index === this.bgStyle ? FontWeight.Bold : FontWeight.Regular)
    }
    .layoutWeight(1)
    .height(72)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(color)
    .borderRadius(14)
    .border({ width: index === this.bgStyle ? 2 : 1, color: index === this.bgStyle ? AppColor.Primary : AppColor.Border })
    .onClick(() => {
      this.bgStyle = index;
    })
  }

  // ==========================================================================
  // @Builder 方法 - 连接页面（Connection）
  // ==========================================================================

  /** 香橙派管理连接窗口：APP 仅调用本机 HTTP，不直接控制 SLE。 */
  @Builder
  ConnectionPage() {
    Column({ space: 14 }) {
      Column({ space: 14 }) {
        Row() {
          Column({ space: 4 }) {
            Text(this.t('管理连接', 'Management Connection'))
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.Text)
            Text(this.bridgeStateText())
              .fontSize(13)
              .fontColor(this.bridgeStateColor())
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text(this.bridgeCountdownText())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.bridgeStateColor())
        }
        .width('100%')

        Divider().color(AppColor.Border)

        Row() {
          Text(this.t('边缘端 ID', 'Edge ID'))
            .fontSize(13)
            .fontColor(AppColor.Muted)
          Blank()
          Text(this.bridgeDeviceId.length > 0 ? this.bridgeDeviceId : '--')
            .fontSize(13)
            .fontColor(AppColor.Text)
        }
        .width('100%')

        Row() {
          Text(this.t('会话 ID', 'Session ID'))
            .fontSize(13)
            .fontColor(AppColor.Muted)
          Blank()
          Text(this.bridgeSessionId.length > 0 ? this.bridgeSessionId : '--')
            .fontSize(13)
            .fontColor(AppColor.Text)
        }
        .width('100%')

        Row() {
          Text(this.t('已连接管理端', 'Connected Manager'))
            .fontSize(13)
            .fontColor(AppColor.Muted)
          Blank()
          Text(this.bridgeManagerId.length > 0 ? this.bridgeManagerId : '--')
            .fontSize(13)
            .fontColor(AppColor.Text)
        }
        .width('100%')

        if (this.bridgeLastError.length > 0) {
          Text(this.bridgeLastError)
            .width('100%')
            .fontSize(12)
            .fontColor(AppColor.Danger)
            .backgroundColor('#12FF4D4F')
            .borderRadius(10)
            .padding(10)
        }

        Row({ space: 10 }) {
          Button(this.bridgeRequestBusy ? this.t('处理中', 'Working') : this.t('打开 5 分钟', 'Open for 5 min'))
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(AppColor.Primary)
            .enabled(!this.bridgeRequestBusy &&
              this.bridgeState !== 'OPENING' && this.bridgeState !== 'ADVERTISING' &&
              this.bridgeState !== 'CONNECTED')
            .onClick(() => {
              this.openManagerBridge();
            })

          Button(this.t('关闭', 'Close'))
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.Danger)
            .backgroundColor('#10FF4D4F')
            .enabled(!this.bridgeRequestBusy &&
              (this.bridgeState === 'OPENING' || this.bridgeState === 'ADVERTISING' ||
                this.bridgeState === 'CONNECTED'))
            .onClick(() => {
              this.closeManagerBridge();
            })
        }
        .width('100%')

        Text(this.t('窗口最长 300 秒；关闭页面会停止状态轮询，但不会擅自延长会话。',
          'The window is capped at 300 seconds. Leaving this page stops polling without extending it.'))
          .width('100%')
          .fontSize(12)
          .fontColor(AppColor.Muted)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(AppColor.Card)
      .borderRadius(16)
      .border({ width: 1, color: AppColor.Border })

      Column({ space: 8 }) {
        Text(this.t('连接路径', 'Connection Path'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.Text)
        Text(this.t('边缘端 APP → 香橙派后端 → UART → 小熊派 B → SLE 管理端',
          'Edge APP → Orange Pi backend → UART → BearPi B → SLE manager'))
          .fontSize(13)
          .fontColor(AppColor.Muted)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor(AppColor.Card)
      .borderRadius(16)
      .border({ width: 1, color: AppColor.Border })
    }
    .width('100%')
  }

  // ==========================================================================
  // @Builder 方法 - 底部导航栏
  // ==========================================================================

  /**
   * 底部导航栏（3 个 Tab）
   * 毛玻璃背景胶囊，选中态为纯色填充。
   */
  @Builder
  BottomNav() {
    Row() {
      ForEach(this.getTabItems(), (item: TabItem, index: number) => {
        this.NavItem(item, index)
      })
    }
    .width('82%')
    .height(52)
    .padding(4)
    .backgroundColor('#BFFFFFFF')
    .backdropBlur(20)
    .borderRadius(26)
    .border({ width: 1, color: '#E6FFFFFF' })
    .shadow({ radius: 18, color: '#262A5670', offsetY: 6 })
    .margin({ bottom: 20 })
  }

  @Builder
  NavItem(item: TabItem, index: number) {
    Row({ space: 5 }) {
      Text(item.icon)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(index === this.currentTab ? Color.White : '#88556477')
      Text(item.name)
        .fontSize(11)
        .fontWeight(index === this.currentTab ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(index === this.currentTab ? Color.White : '#99556477')
        .maxLines(1)
        .opacity(index === this.currentTab ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseOut })
    }
    .height(44)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .borderRadius(22)
    .backgroundColor(index === this.currentTab ? AppColor.Primary : Color.Transparent)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onClick(() => {
      this.switchTab(index);
    })
  }

  /**
   * 获取导航栏 Tab 项列表（支持中英双语）
   * @returns 根据当前语言返回对应的 TabItem 数组
   */
  private getTabItems(): TabItem[] {
    if (this.language === 0) {
      return [
        new TabItem('D', '仪表盘'),
        new TabItem('F', '专注'),
        new TabItem('C', '连接')
      ];
    }
    return [
      new TabItem('D', 'Dashboard'),
      new TabItem('F', 'Focus'),
      new TabItem('C', 'Connection')
    ];
  }
}

// ============================================================================
// TabItem - 导航栏 Tab 项数据模型
// ============================================================================

/**
 * 底部导航栏项数据类
 * 用于 ForEach 渲染导航栏按钮
 */
class TabItem {
  /** Tab 图标（首字母） */
  icon: string;
  /** Tab 名称 */
  name: string;

  constructor(icon: string, name: string) {
    this.icon = icon;
    this.name = name;
  }
}
