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
}

// ============================================================================
// Index - 应用主组件（@Entry 入口 + @Component 自定义组件）
// ============================================================================
@Entry
@Component
struct Index {
  // ──────────────────────────────────────────────────────────────────────────
  // 状态变量（@State 响应式数据，变化时自动触发 UI 更新）
  // ──────────────────────────────────────────────────────────────────────────

  /** 当前选中的标签页索引：0=仪表盘, 1=专注, 2=运动, 3=个人 */
  @State private currentTab: number = 0;
  /** 专注指数 (0-100)，从脑电数据实时计算 */
  @State private focusScore: number = 88;
  /** 疲劳指数 (0-100)，数值越高越疲劳 */
  @State private fatigueScore: number = 78;
  /** 番茄钟剩余秒数（默认 25 分钟 = 1500 秒） */
  @State private timerSeconds: number = 1500;
  /** 计时器是否正在运行 */
  @State private timerRunning: boolean = false;
  /** 是否启用设备自动重连 */
  @State private autoReconnect: boolean = true;
  /** 是否启用云端数据同步 */
  @State private cloudSync: boolean = true;
  /** 是否保持屏幕常亮（运动模式下默认关闭） */
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

  /** 定时器 ID，用于 clearInterval */
  private timerId: number = 0;
  /** 脑电频谱模拟数据（实时波柱高度数组） */
  private barValues: number[] = [32, 46, 24, 60, 36, 72, 28, 52, 42, 66, 34, 48];

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
      const zhNames: string[] = ['仪表盘', '专注', '运动', '个人'];
      return zhNames[index];
    }
    const enNames: string[] = ['Dashboard', 'Focus', 'Sports', 'Profile'];
    return enNames[index];
  }

  // ==========================================================================
  // 生命周期方法
  // ==========================================================================

  /**
   * 组件即将销毁时调用
   * 清理定时器，防止内存泄漏
   */
  aboutToDisappear(): void {
    this.stopTimer();
  }

  // ==========================================================================
  // 计时器逻辑
  // ==========================================================================

  /**
   * 启动番茄钟计时器
   * 每秒递减，模拟脑电专注指数波动（每 3 秒 +1）
   */
  private startTimer(): void {
    if (this.timerRunning) {
      return; // 防止重复启动
    }
    this.timerRunning = true;
    this.timerId = setInterval(() => {
      if (this.timerSeconds <= 0) {
        this.stopTimer();
        return;
      }
      this.timerSeconds -= 1;
      // 模拟专注指数波动（每 3 秒递增 1，到 94 后重置为 86）
      if (this.timerSeconds % 3 === 0) {
        this.focusScore = this.focusScore >= 94 ? 86 : this.focusScore + 1;
      }
    }, 1000);
  }

  /** 停止番茄钟计时器 */
  private stopTimer(): void {
    if (this.timerId !== 0) {
      clearInterval(this.timerId);
      this.timerId = 0;
    }
    this.timerRunning = false;
  }

  /** 重置计时器到 25 分钟并恢复默认专注指数 */
  private resetTimer(): void {
    this.stopTimer();
    this.timerSeconds = 1500;
    this.focusScore = 88;
  }

  /**
   * 格式化计时器显示文本
   * @returns "MM:SS" 格式的时间字符串
   */
  private timerText(): string {
    const minutes: number = Math.floor(this.timerSeconds / 60);
    const seconds: number = this.timerSeconds % 60;
    const secondsText: string = seconds < 10 ? '0' + seconds.toString() : seconds.toString();
    return minutes.toString() + ':' + secondsText;
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
            } else if (this.currentTab === 2) {
              this.SportsPage()
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
      this.BottomNav()
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
      Text(this.currentTab === 3 ? 'HS' : 'AI')
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
        Text(this.currentTab === 0 ? this.t('早上好', 'Good morning') : this.t('健康同步', 'HealthSync'))
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

      // 右侧：操作按钮（运动页=开始，其他页=提醒）
      Button(this.currentTab === 2 ? this.t('开始', 'Start') : this.t('提醒', 'Alert'))
        .height(36)
        .fontSize(13)
        .fontColor(this.currentTab === 2 ? Color.White : AppColor.Text)
        .backgroundColor(this.currentTab === 2 ? AppColor.Danger : AppColor.Surface)
        .borderRadius(18)
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#F9F9FFCC')  // 半透明白色毛玻璃效果
    .shadow({ radius: 8, color: '#10000000', offsetY: 2 })
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

        // 环形进度条：综合健康评分 85/100
        Stack() {
          Progress({ value: 85, total: 100, type: ProgressType.Ring })
            .width(68)
            .height(68)
            .color(AppColor.Primary)
          Text('85')
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
          this.t('实时专注', 'Live Focus'), '48', this.t('级', 'lvl'),
          AppColor.Good, this.t('1分钟前测量', 'Measured 1 min ago'), 48
        )
        // 疲劳指数卡片
        this.MetricCard(
          this.t('疲劳指数', 'Fatigue Index'), this.fatigueScore.toString(), '/100',
          AppColor.Danger, this.t('休息5分钟', 'Rest for 5 minutes'), this.fatigueScore
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
  MetricCard(title: string, value: string, unit: string, color: string, note: string, progress: number) {
    Column() {
      // 标题行：名称 + 趋势标记
      Row() {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.Text)
        Blank()
        // 危险指标显示 '!'，正常指标显示 '+5%'
        Text(color === AppColor.Danger ? '!' : '+5%')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
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
      Progress({ value: progress, total: 100, type: ProgressType.Linear })
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
      this.WaveRow('Alpha', 65, AppColor.Primary)
      // Theta 波：冥想/浅睡，绿色
      this.WaveRow('Theta', 40, AppColor.Good)
      // Beta 波：活跃思考，橙色警告
      this.WaveRow('Beta', 82, AppColor.Warning)
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
      Text(this.t(
        '高Beta波活动和疲劳指数表明大脑处于活跃状态。建议进行25分钟专注冲刺，然后休息5分钟。',
        'High beta activity and fatigue indicate an active brain state. Try a 25-minute focus sprint followed by a 5-minute deliberate rest.'
      ))
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
        Progress({ value: this.timerSeconds, total: 1500, type: ProgressType.Ring })
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

      // ── 控制按钮行 ──
      Row({ space: 12 }) {
        // 重置按钮：恢复 25 分钟倒计时
        Button(this.t('重置', 'Reset'))
          .layoutWeight(1)
          .height(54)
          .borderRadius(18)
          .fontColor(AppColor.Muted)
          .backgroundColor(AppColor.Surface)
          .onClick(() => {
            this.resetTimer();
          })

        // 开始/暂停按钮（两态切换）
        Button(this.timerRunning ? this.t('暂停', 'Pause') : this.t('开始', 'Start'))
          .layoutWeight(2)
          .height(54)
          .borderRadius(18)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(this.timerRunning ? AppColor.Warning : AppColor.Good)
          .onClick(() => {
            if (this.timerRunning) {
              this.stopTimer();
            } else {
              this.startTimer();
            }
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
        Text(this.focusScore.toString() + '%')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Primary)
      }
      .width('100%')

      // 进度条
      Progress({ value: this.focusScore, total: 100, type: ProgressType.Linear })
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
          Progress({ value: 88, total: 100, type: ProgressType.Ring })
            .width(250)
            .height(250)
            .color(AppColor.Primary)
          Column({ space: 4 }) {
            Text('88')
              .fontSize(52)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.Text)
            Text(this.t('+5 专注指数', '+5 Focus Index'))
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.Good)
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
        this.InputLike(this.t('IP地址', 'IP Address'), '192.168.1.100')
        this.InputLike(this.t('端口', 'Port'), '5000')
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
        .backgroundColor(AppColor.White)
        .border({ width: 1, color: AppColor.Border })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

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
   * 底部导航栏（4 个 Tab）
   * 带毛玻璃效果背景，选中态为主题色高亮
   * Tab 图标：D=仪表盘, F=专注, S=运动, P=个人
   */
  @Builder
  BottomNav() {
    Row() {
      ForEach(this.getTabItems(), (item: TabItem, index: number) => {
        Column({ space: 4 }) {
          // Tab 图标（首字母）
          Text(item.icon)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(index === this.currentTab ? AppColor.Primary : AppColor.Muted)
          // Tab 名称
          Text(item.name)
            .fontSize(12)
            .fontWeight(index === this.currentTab ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(index === this.currentTab ? AppColor.Primary : AppColor.Muted)
        }
        .layoutWeight(1)        // 均分宽度
        .height(54)
        .justifyContent(FlexAlign.Center)
        .borderRadius(16)
        .backgroundColor(index === this.currentTab ? '#1A0054CB' : '#00FFFFFF')
        .onClick(() => {
          this.currentTab = index;
        })
      })
    }
    .height(82)
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    .backgroundColor('#F9F9FFEE')  // 毛玻璃：半透明白色
    .border({ width: { top: 1 }, color: AppColor.Border })
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
        new TabItem('S', '运动'),
        new TabItem('P', '个人')
      ];
    }
    return [
      new TabItem('D', 'Dashboard'),
      new TabItem('F', 'Focus'),
      new TabItem('S', 'Sports'),
      new TabItem('P', 'Profile')
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
