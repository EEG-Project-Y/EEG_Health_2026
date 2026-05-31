import { BottomNav } from '../components/BottomNav';
import { InputLike } from '../components/InputLike';
import { MenuRow } from '../components/MenuRow';
import { SummaryCard } from '../components/SummaryCard';
import { TopBar } from '../components/TopBar';
import { DataService, ToAppJson } from '../data/DataService';
import { AppColor } from '../theme/AppColor';

/**
 * ============================================================================
 * Index.ets - HealthSync AI 健康监测应用主页面
 * ============================================================================
 *
 * 功能概述：
 *   基于 HarmonyOS ArkUI 框架构建的 AI 健康监测应用主界面，
 *   提供脑电(EEG)数据分析、专注计时和个人设置等核心功能。
 *
 * 页面架构（3 个 Tab 页签）：
 *   1. 仪表盘 (Dashboard)  - 健康状态总览、实时专注/疲劳指标、脑电频谱、AI 建议
 *   2. 专注    (Focus)       - 番茄钟计时器、实时专注数据、休息建议
 *   3. 个人    (Profile)     - 用户信息、设备管理、系统设置、背景样式切换
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
 *   → RestAdviceCard → Tag → ProfilePage
 *   → SummaryCard → MenuRow → SettingsPanel → LanguageSelector → InputLike
 *   → Toggle/Switch/Slider 组件 → BackgroundPicker → BackgroundOption → BottomNav
 *   → TabItem 辅助类
 */

/** 番茄钟默认时长（25 分钟），与 Progress 环 total 默认值一致 */
const DEFAULT_FOCUS_SEC: number = 1500;
/** 自定义专注时长上限（24 小时） */
const MAX_FOCUS_SEC: number = 86400;

// ============================================================================
// Index - 应用主组件（@Entry 入口 + @Component 自定义组件）
// ============================================================================
@Entry
@Component
struct Index {
  // ──────────────────────────────────────────────────────────────────────────
  // 状态变量（@State 响应式数据，变化时自动触发 UI 更新）
  // ──────────────────────────────────────────────────────────────────────────

  /** 当前选中的标签页索引：0=仪表盘, 1=专注, 2=个人 */
  @State private currentTab: number = 0;
  /** 专注指数 (0-100)，从脑电数据实时计算 */
  @State private focus: number = 0;
  /** 疲劳指数 (0-100)，数值越高越疲劳 */
  @State private fatigue: number = 0;
  @State private relax: number = 0;
  @State private load: number = 0;
  @State private quality: number = 0;
  @State private confidence: number = 0;
  @State private focusTrend: number = 0;
  @State private fatigueTrend: number = 0;
  @State private relaxTrend: number = 0;
  @State private loadTrend: number = 0;
  @State private state: string = 'normal';
  @State private eegDirection: string = '';
  @State private advice: string = '';
  @State private local: boolean = true;
  @State private model: string = '';
  @State private summary: string[] = [];
  /** 脑电频谱柱高度数组，由实时数据派生 */
  @State private barValues: number[] = [];
  /** 番茄钟剩余秒数（默认 25 分钟） */
  @State private timerSeconds: number = DEFAULT_FOCUS_SEC;
  /** 番茄钟设定的总时长（秒），可由自定义弹窗修改 */
  @State private focusDurationSec: number = DEFAULT_FOCUS_SEC;
  /** 计时器是否正在运行 */
  @State private timerRunning: boolean = false;
  /** 是否显示自定义专注时长弹窗 */
  @State private showDurationDialog: boolean = false;
  /** 弹窗内滚轮选中的时长（时/分/秒映射为 Date） */
  @State private draftDurationDate: Date = new Date(1970, 0, 1, 0, 25, 0);
  /** 是否启用设备自动重连 */
  @State private autoReconnect: boolean = true;
  /** 是否启用云端数据同步 */
  @State private cloudSync: boolean = true;
  /** 是否保持屏幕常亮 */
  @State private keepScreenOn: boolean = false;
  /** 专注警告阈值（百分比，低于此值触发提醒） */
  @State private focusThreshold: number = 40;
  /** 疲劳警告阈值（百分比，高于此值触发提醒） */
  @State private fatigueThreshold: number = 80;
  /** 背景样式索引：0=白色, 1=蓝色, 2=暖色 */
  @State private bgStyle: number = 0;

  // ──────────────────────────────────────────────────────────────────────────
  // 语言设置（0=中文, 1=English，默认中文）
  // ──────────────────────────────────────────────────────────────────────────

  /** 当前语言：0=中文, 1=English */
  @State private language: number = 0;

  // ──────────────────────────────────────────────────────────────────────────
  // 私有成员变量
  // ──────────────────────────────────────────────────────────────────────────

  /** 番茄钟 setTimeout 链 ID（-1 表示无待执行 tick） */
  private focusTimerId: number = -1;
  private dataService: DataService = new DataService();

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
   * @param index - Tab 索引 (0-2)
   * @returns 对应语言的标签名
   */
  // ==========================================================================
  // 生命周期方法
  // ==========================================================================

  /**
   * 组件即将销毁时调用
   * 暂停番茄钟，防止页面销毁后仍计时
   */
  aboutToAppear(): void {
    this.dataService.startReceiving((data: ToAppJson) => {
      this.applyToAppJson(data);
    });
  }

  private applyToAppJson(data: ToAppJson): void {
    this.focus = data.focus ?? this.focus;
    this.fatigue = data.fatigue ?? this.fatigue;
    this.relax = data.relax ?? this.relax;
    this.load = data.load ?? this.load;
    this.quality = data.quality ?? this.quality;
    this.confidence = data.confidence ?? this.confidence;
    this.focusTrend = data.focusTrend ?? this.focusTrend;
    this.fatigueTrend = data.fatigueTrend ?? this.fatigueTrend;
    this.relaxTrend = data.relaxTrend ?? this.relaxTrend;
    this.loadTrend = data.loadTrend ?? this.loadTrend;
    this.state = data.state ?? this.state;
    this.eegDirection = data.direction ?? this.eegDirection;
    this.advice = data.advice ?? this.advice;
    this.local = data.local ?? this.local;
    this.model = data.model ?? this.model;
    this.summary = data.summary ?? this.summary;
    this.barValues = this.createBarValues();
  }

  private clampPercent(value: number): number {
    return Math.max(0, Math.min(100, Math.round(value)));
  }

  private trendText(value: number): string {
    if (value > 0) {
      return '+' + value.toString();
    }
    return value.toString();
  }

  private healthScore(): number {
    const signalPart: number = (this.quality + Math.round(this.confidence * 100)) / 2;
    const balancePart: number = (this.focus + this.relax + Math.max(0, 100 - this.fatigue) + Math.max(0, 100 - this.load)) / 4;
    return this.clampPercent((signalPart + balancePart) / 2);
  }

  private suggestionText(): string {
    return this.advice.length > 0 ? this.advice : '';
  }

  private summaryValue(index: number, fallback: string): string {
    if (this.summary.length > index && this.summary[index].length > 0) {
      return this.summary[index];
    }
    return fallback;
  }

  private createBarValues(): number[] {
    const baseValues: number[] = [
      this.focus,
      this.fatigue,
      this.relax,
      this.load,
      this.quality,
      Math.round(this.confidence * 100)
    ];
    const modelSeed: number = this.model.length % 17;
    const bars: number[] = [];
    for (let index = 0; index < 12; index++) {
      const source: number = baseValues[index % baseValues.length];
      bars.push(this.clampPercent(source + modelSeed + (index % 3) * 4));
    }
    return bars;
  }

  aboutToDisappear(): void {
    this.dataService.stopReceiving();
    this.pauseFocusTimer();
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

  /** 将秒数转为 TimePicker 用的 Date（1970-01-01 HH:mm:ss） */
  private dateFromSeconds(total: number): Date {
    const safeTotal: number = Math.max(0, Math.min(total, MAX_FOCUS_SEC));
    const hours: number = Math.floor(safeTotal / 3600);
    const minutes: number = Math.floor((safeTotal % 3600) / 60);
    const seconds: number = safeTotal % 60;
    return new Date(1970, 0, 1, hours, minutes, seconds);
  }

  /** 从 TimePicker Date 读取总秒数 */
  private secondsFromDate(date: Date): number {
    return date.getHours() * 3600 + date.getMinutes() * 60 + date.getSeconds();
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
    if (this.currentTab === 1 && index !== 1 && this.timerRunning) {
      this.pauseFocusTimer();
    }
    this.currentTab = index;
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
        TopBar({ currentTab: this.currentTab, language: this.language })

        Scroll() {                              // 可滚动内容区域
          Column({ space: 16 }) {
            // 根据 currentTab 切换显示不同页面
            if (this.currentTab === 0) {
              this.DashboardPage()
            } else if (this.currentTab === 1) {
              this.FocusPage()
            } else {
              this.ProfilePage()
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 104 })  // 底部留出导航栏高度
        }
        .layoutWeight(1)      // 填充剩余空间
        .scrollBar(BarState.Off) // 隐藏滚动条
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColor.White)

      // ── 固定在底部的导航栏 ──
      BottomNav({
        currentTab: this.currentTab,
        language: this.language,
        onTabChange: (index: number) => {
          this.switchTab(index);
        }
      })

      if (this.showDurationDialog) {
        Stack() {
          this.FocusDurationDialog()
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .zIndex(1000)
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
  // ==========================================================================
  // @Builder 方法 - 仪表盘页面（Dashboard）
  // ==========================================================================

  /**
   * 仪表盘页面 - 健康数据总览
   * 包含：健康状态卡片 → 实时指标卡片 → 脑电频谱 → AI 智能建议
   */
  @Builder
  DashboardPage() {
    Column({ space: 12 }) {
      // ── 健康状态总览卡片 ──
      Row() {
        Column({ space: 4 }) {
          Text(this.t('每日健康状态', 'Daily Health Status'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.Text)
          Text(this.t('生物信号稳定。保持节奏，需要时适当休息。', 'Bio signals are stable. Keep your rhythm and rest when needed.'))
            .fontSize(14)
            .fontColor(AppColor.Muted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 环形进度条：综合健康评分，随 ToAppJson 实时刷新
        Stack() {
          Progress({ value: this.healthScore(), total: 100, type: ProgressType.Ring })
            .width(68)
            .height(68)
            .color(AppColor.Primary)
          Text(this.healthScore().toString())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.Primary)
        }
      }
      .padding(14)
      .backgroundColor(AppColor.Card)
      .borderRadius(16)
      .border({ width: 1, color: AppColor.Border })

      // ── 实时指标卡片（横向排列）──
      Row({ space: 12 }) {
        // 实时专注指数卡片
        this.MetricCard(
          this.t('实时专注', 'Live Focus'), this.focus.toString(), '/100',
          AppColor.Good, this.t('实时数据', 'Live data'), this.focus, this.focusTrend
        )
        // 疲劳指数卡片
        this.MetricCard(
          this.t('疲劳指数', 'Fatigue Index'), this.fatigue.toString(), '/100',
          AppColor.Danger, this.t('实时数据', 'Live data'), this.fatigue, this.fatigueTrend
        )
      }

      Row({ space: 12 }) {
        this.MetricCard(
          this.t('放松指数', 'Relax Index'), this.relax.toString(), '/100',
          AppColor.Primary, this.t('实时数据', 'Live data'), this.relax, this.relaxTrend
        )
        this.MetricCard(
          this.t('脑负荷', 'Brain Load'), this.load.toString(), '/100',
          AppColor.Warning, this.t('实时数据', 'Live data'), this.load, this.loadTrend
        )
      }

      Row({ space: 12 }) {
        this.MetricCard(
          this.t('信号质量', 'Signal Quality'), this.quality.toString(), '/100',
          AppColor.Good, this.t('实时数据', 'Live data'), this.quality, 0
        )
        this.MetricCard(
          this.t('置信度', 'Confidence'), Math.round(this.confidence * 100).toString(), '%',
          AppColor.Primary, this.t('实时数据', 'Live data'), Math.round(this.confidence * 100), 0
        )
      }

      // ── 脑电频谱图 ──
      this.SpectrumCard()

      // ── AI 智能建议 ──
      this.SuggestionCard()
    }
    .width('100%')
  }

  /**
   * 指标卡片 - 单个健康指标展示
   *
   * @param title    - 指标名称
   * @param value    - 指标数值
   * @param unit     - 单位
   * @param color    - 主题色（Good=绿色, Danger=红色）
   * @param note     - 底部提示文字
   * @param progress - 进度值 (0-100)
   */
  @Builder
  MetricCard(title: string, value: string, unit: string, color: string, note: string, progress: number, trend: number) {
    Column() {
      // 标题行：名称 + 趋势标记
      Row() {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.Text)
        Blank()
        Text(this.trendText(trend))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(trend < 0 ? AppColor.Danger : color)
      }
      .width('100%')

      // 数值行：大号数字 + 小号单位
      Row({ space: 4 }) {
        Text(value)
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor(color === AppColor.Danger ? AppColor.Danger : AppColor.Text)
        Text(unit)
          .fontSize(12)
          .fontColor(AppColor.Muted)
      }
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 20 })

      // 线性进度条（0-100%）
      Progress({ value: this.clampPercent(progress), total: 100, type: ProgressType.Linear })
        .height(8)
        .color(color)
        .margin({ top: 16 })

      // 底部提示
      Text(note)
        .fontSize(11)
        .fontColor(color)
        .margin({ top: 8 })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .height(176)
    .padding(14)
    .backgroundColor(AppColor.Card)
    .borderRadius(16)
    .border({ width: 1, color: color === AppColor.Danger ? '#33FF4D4F' : AppColor.Border })
  }

  /**
   * 脑电频谱卡片
   * 展示 Alpha、Theta、Beta 三种脑电波的强度分布
   */
  @Builder
  SpectrumCard() {
    Column({ space: 14 }) {
      Text(this.t('脑电频谱', 'EEG Spectrum'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.Text)
      // Alpha 波：放松状态，主题色
      this.WaveRow('Alpha', this.relax, AppColor.Primary)
      // Theta 波：认知负荷/内省状态
      this.WaveRow('Theta', this.load, AppColor.Good)
      // Beta 波：活跃思考/疲劳压力
      this.WaveRow('Beta', this.fatigue, AppColor.Warning)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor(AppColor.Card)
    .borderRadius(16)
    .border({ width: 1, color: AppColor.Border })
  }

  /**
   * 单条脑电波段行
   * @param label - 波段名称（Alpha/Theta/Beta）
   * @param value - 强度百分比 (0-100)
   * @param color - 显示颜色
   */
  @Builder
  WaveRow(label: string, value: number, color: string) {
    Row({ space: 12 }) {
      Text(label)
        .width(58)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.Text)
      Progress({ value: value, total: 100, type: ProgressType.Linear })
        .layoutWeight(1)
        .height(6)
        .color(color)
      Text(value.toString() + '%')
        .width(42)
        .fontSize(12)
        .fontColor(color)
    }
    .width('100%')
  }

  /**
   * AI 智能建议卡片
   * 根据当前健康数据生成个性化建议
   * 包含：AI 图标 → 标题 → 建议详情 → 快捷操作按钮
   */
  @Builder
  SuggestionCard() {
    Column({ space: 12 }) {
      // AI 标识 + 标题
      Row({ space: 8 }) {
        Text('AI')
          .width(28)
          .height(28)
          .borderRadius(14)
          .textAlign(TextAlign.Center)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(AppColor.Primary)
        Text(this.t('智能建议', 'Smart Suggestion'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Primary)
      }

      // 建议文本内容
      Text(this.suggestionText())
        .fontSize(14)
        .lineHeight(22)
        .fontColor(AppColor.Muted)

      // 快捷跳转按钮：点击后切换到专注页面
      Button(this.t('打开专注计时器', 'Open Focus Timer'))
        .height(48)
        .width('100%')
        .borderRadius(12)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(AppColor.Primary)
        .onClick(() => {
          this.currentTab = 1;
        })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor(AppColor.Card)
    .borderRadius(16)
    .border({ width: 1, color: AppColor.Border })
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
   * 时/分/秒滚轮 + 取消 / 确定（蓝色高亮）
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
          selected: this.draftDurationDate,
          format: TimePickerFormat.HOUR_MINUTE_SECOND
        })
          .useMilitaryTime(true)
          .onChange((value: TimePickerResult) => {
            if (value.hour >= 0) {
              this.draftDurationDate = new Date(1970, 0, 1, value.hour, value.minute, value.second);
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
      .backgroundColor(AppColor.White)
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
        Text(this.focus.toString() + '%')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Primary)
      }
      .width('100%')

      // 进度条
      Progress({ value: this.focus, total: 100, type: ProgressType.Linear })
        .height(8)
        .color(AppColor.Primary)

      Text(this.t('实时脑电', 'Realtime EEG'))
        .fontSize(12)
        .fontColor(AppColor.Muted)

      // 模拟脑电波柱状图（12 根动态高度柱）
      Row({ space: 3 }) {
        ForEach(this.barValues, (height: number) => {
          Column() {
          }
            .width(5)
            .height(Math.max(8, height))
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
      Text(this.t(
        '每次专注训练后休息5分钟，有助于认知恢复。',
        'After one focus session, rest for 5 minutes to help cognitive recovery.'
      ))
        .fontSize(14)
        .lineHeight(22)
        .fontColor(AppColor.Muted)
      // 标签行：有效性 + 科学依据标记
      Row({ space: 8 }) {
        this.Tag(this.t('有效', 'Effective'))
        this.Tag(this.t('有依据', 'Evidence'))
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
        SummaryCard({ title: this.t('今日专注', 'Today Focus'), value: this.summaryValue(0, '0'), color: AppColor.Primary })
        SummaryCard({ title: this.t('平均疲劳', 'Avg Fatigue'), value: this.summaryValue(1, this.fatigue.toString() + ' /100'), color: AppColor.Warning })
      }

      // ── 功能菜单列表 ──
      Column() {
        MenuRow({ title: this.t('设备管理', 'Device Management'), subtitle: this.t('Orange Pi 已连接', 'Orange Pi connected'), color: AppColor.Primary })
        MenuRow({ title: this.t('提醒阈值', 'Alert Thresholds'), subtitle: this.t('自定义疲劳提醒', 'Customize fatigue warning'), color: AppColor.Danger })
        MenuRow({ title: this.t('背景样式', 'Background Style'), subtitle: this.t('纯色、渐变和预览', 'Solid, gradient and preview'), color: AppColor.Good })
      }
      .backgroundColor(AppColor.White)
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
  /**
   * 菜单行（含标题 + 副标题 + 右箭头）
   * @param title    - 主标题
   * @param subtitle - 副标题/当前状态
   * @param color    - 右箭头颜色
   */
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
        InputLike({ label: this.t('IP地址', 'IP Address'), value: '192.168.1.100' })
        InputLike({ label: this.t('端口', 'Port'), value: '5000' })
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
  // ── 开关行组件 ──

  /** 自动重连开关 */
  @Builder
  ToggleAutoReconnect() {
    this.SwitchRow(this.t('自动重连', 'Auto reconnect'), this.autoReconnect)
  }

  /** 云同步开关 */
  @Builder
  ToggleCloudSync() {
    this.SwitchRow(this.t('云同步', 'Cloud sync'), this.cloudSync)
  }

  /** 屏幕常亮开关 */
  @Builder
  ToggleKeepScreenOn() {
    this.SwitchRow(this.t('保持屏幕常亮', 'Keep screen on'), this.keepScreenOn)
  }

  /**
   * 通用开关行（标签 + Switch 组件）
   * @param label   - 开关标签
   * @param checked - 当前开关状态
   */
  @Builder
  SwitchRow(label: string, checked: boolean) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(AppColor.Text)
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: checked })
        .selectedColor(AppColor.Primary)
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
  // @Builder 方法 - 底部导航栏
  // ==========================================================================

  /**
   * 底部导航栏（3 个 Tab）
   * 带毛玻璃效果背景，选中态为主题色高亮
   * Tab 图标：D=仪表盘, F=专注, P=个人
   */
  /**
   * 获取导航栏 Tab 项列表（支持中英双语）
   * @returns 根据当前语言返回对应的 TabItem 数组
   */
}
