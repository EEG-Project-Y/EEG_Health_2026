import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'
import { ToPadFrame } from '../model/ToPadModel'

export interface SSVEPGameInput {
  ssvepTarget?: number
  ssvepFrequencyHz?: number
  ssvepConfidence?: number
  gameCommand?: string
}

@Component
export struct VisualAttentionTrainingPage {
  @Prop eegData: ToPadFrame = {
    sequence: 0,
    focus: 0,
    fatigue: 0,
    relax: 0,
    load: 0,
    quality: 0,
    confidence: 0,
    state: '',
    direction: '',
    advice: '',
    alert: false
  }
  @Prop ssvepInput: SSVEPGameInput = {}
  @Prop showBackButton: boolean = true
  onBack: () => void = () => {}

  @State sw: number = 360
  @State sh: number = 800
  @State gameAreaWidth: number = 300
  @State gameStatus: string = 'idle'
  @State targetValue: number = 1
  @State targetOrder: number[] = [1, 2, 3, 4, 5, 6]
  @State score: number = 0
  @State errors: number = 0
  @State streak: number = 0
  @State round: number = 0
  @State timeLeft: number = 60
  private timerId: number = -1

  aboutToDisappear(): void {
    this.clearTimer()
  }

  private isWide(): boolean {
    return this.sw >= 900
  }

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
  }

  private isCompactHeight(): boolean {
    return this.isNarrow() && this.sh < 760
  }

  private pageSidePadding(): number {
    if (this.sw < Dimensions.BREAKPOINT_TABLET) return 12
    if (this.sw < 900) return Dimensions.SCREEN_MARGIN_SM
    return Dimensions.SCREEN_MARGIN
  }

  private bottomNavigationInset(): number {
    if (!this.isNarrow()) return 8
    return this.sw < Dimensions.BREAKPOINT_PHONE ? 68 : 84
  }

  private clearTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  private shuffledTargets(): number[] {
    const values: number[] = [1, 2, 3, 4, 5, 6]
    for (let i: number = values.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1))
      const current: number = values[i]
      values[i] = values[j]
      values[j] = current
    }
    return values
  }

  private nextTarget(): void {
    this.targetOrder = this.shuffledTargets()
    this.targetValue = 1 + Math.floor(Math.random() * 6)
  }

  private startTimer(): void {
    this.clearTimer()
    this.timerId = setInterval(() => {
      if (this.gameStatus !== 'playing') return
      if (this.timeLeft <= 1) {
        this.timeLeft = 0
        this.gameStatus = 'done'
        this.clearTimer()
      } else {
        this.timeLeft--
      }
    }, 1000)
  }

  private startGame(): void {
    if (this.gameStatus === 'paused') {
      this.gameStatus = 'playing'
      this.startTimer()
      return
    }
    this.score = 0
    this.errors = 0
    this.streak = 0
    this.round = 1
    this.timeLeft = 60
    this.gameStatus = 'playing'
    this.nextTarget()
    this.startTimer()
  }

  private pauseGame(): void {
    if (this.gameStatus !== 'playing') return
    this.gameStatus = 'paused'
    this.clearTimer()
  }

  private resetGame(): void {
    this.clearTimer()
    this.gameStatus = 'idle'
    this.score = 0
    this.errors = 0
    this.streak = 0
    this.round = 0
    this.timeLeft = 60
    this.targetValue = 1
    this.targetOrder = [1, 2, 3, 4, 5, 6]
  }

  private selectTarget(value: number): void {
    if (this.gameStatus !== 'playing') return
    if (value === this.targetValue) {
      this.score += 10 + Math.min(this.streak, 5) * 2
      this.streak++
      this.round++
      this.nextTarget()
    } else {
      this.errors++
      this.streak = 0
      this.score = Math.max(0, this.score - 2)
    }
  }

  private tileColor(value: number): string {
    if (value === 1) return Colors.PRIMARY
    if (value === 2) return Colors.TEAL
    if (value === 3) return Colors.INDIGO
    if (value === 4) return Colors.AMBER
    if (value === 5) return Colors.MINT
    return Colors.ORANGE
  }

  private tileSize(): number {
    const columns: number = this.isNarrow() ? 2 : 3
    const gapTotal: number = (columns - 1) * 10
    return Math.floor((this.gameAreaWidth - gapTotal) / columns)
  }

  private tileHeight(): number {
    if (this.isNarrow()) return this.isCompactHeight() ? 44 : 60
    return this.isCompactHeight() ? 72 : 112
  }

  private gameStatusText(): string {
    if (this.gameStatus === 'playing') return '训练中'
    if (this.gameStatus === 'paused') return '已暂停'
    if (this.gameStatus === 'done') return '已完成'
    return '等待开始'
  }

  private feedbackText(): string {
    if (this.eegData.quality < 60) return '当前信号质量偏低，建议检查佩戴或连接状态后再继续，数据仅供参考。'
    if (this.eegData.fatigue >= 70) return '当前疲劳指标偏高，建议先短暂休息，再决定是否继续训练。'
    if (this.eegData.focus < 40) return '当前专注度偏低，可以降低节奏，先完成几轮短时目标选择。'
    if (this.eegData.advice.length > 0) return this.eegData.advice
    return '保持稳定节奏，优先准确选择目标。'
  }

  private ssvepStatus(): string {
    const hasTarget: boolean = typeof this.ssvepInput.ssvepTarget === 'number'
    const hasConfidence: boolean = typeof this.ssvepInput.ssvepConfidence === 'number'
    const hasCommand: boolean = typeof this.ssvepInput.gameCommand === 'string' && this.ssvepInput.gameCommand!.length > 0
    return hasTarget || hasConfidence || hasCommand ? '已收到预留字段' : '未接入'
  }

  private ssvepTargetText(): string {
    return typeof this.ssvepInput.ssvepTarget === 'number' ? `${this.ssvepInput.ssvepTarget}` : '--'
  }

  private ssvepConfidenceText(): string {
    return typeof this.ssvepInput.ssvepConfidence === 'number' ? `${this.ssvepInput.ssvepConfidence}%` : '--'
  }

  private ssvepFrequencyText(): string {
    return typeof this.ssvepInput.ssvepFrequencyHz === 'number' ? `${this.ssvepInput.ssvepFrequencyHz} Hz` : '-- Hz'
  }

  private ssvepCommandText(): string {
    return typeof this.ssvepInput.gameCommand === 'string' && this.ssvepInput.gameCommand.length > 0
      ? this.ssvepInput.gameCommand
      : '--'
  }

  @Builder
  HeaderBar() {
    Row({ space: 12 }) {
      if (this.showBackButton) {
        Row() {
          Text('<')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
        }
        .width(42)
        .height(42)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(Colors.GLASS_ACTIVE)
        .backgroundBlurStyle(BlurStyle.Thin)
        .border({ width: 1, color: Colors.GLASS_BORDER })
        .borderRadius(Dimensions.PILL_RADIUS)
        .onClick(() => {
          this.clearTimer()
          this.onBack()
        })
      }

      Column({ space: 3 }) {
        Text('视觉注意训练')
          .fontSize(this.isNarrow() ? 20 : 24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Text('点击目标训练，实时查看脑电反馈')
          .fontSize(this.isNarrow() ? 11 : 12)
          .fontColor(Colors.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.gameStatusText())
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.gameStatus === 'playing' ? Colors.SUCCESS : Colors.TEXT_SECONDARY)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor(Colors.GLASS_ACTIVE)
        .border({ width: 1, color: Colors.GLASS_BORDER })
        .borderRadius(Dimensions.PILL_RADIUS)
    }
    .width('100%')
  }

  @Builder
  StatItem(label: string, value: string, color: string) {
    Column({ space: 3 }) {
      Text(label)
        .fontSize(10)
        .fontColor(Colors.TEXT_TERTIARY)
      Text(value)
        .fontSize(this.isCompactHeight() ? 14 : (this.isNarrow() ? 17 : 20))
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  GamePanel() {
    Column({ space: this.isCompactHeight() ? 8 : 14 }) {
      Column() {
        if (this.isNarrow()) {
          Row({ space: 4 }) {
            this.StatItem('目标', this.gameStatus === 'idle' ? '--' : `${this.targetValue}`, Colors.PRIMARY)
            this.StatItem('得分', `${this.score}`, Colors.INDIGO)
            this.StatItem('剩余', `${this.timeLeft}s`, Colors.AMBER)
            this.StatItem('错误', `${this.errors}`, this.errors > 0 ? Colors.ERROR : Colors.TEXT_PRIMARY)
          }
          .width('100%')
        } else {
          Row({ space: 10 }) {
            this.StatItem('目标', this.gameStatus === 'idle' ? '--' : `${this.targetValue}`, Colors.PRIMARY)
            this.StatItem('得分', `${this.score}`, Colors.INDIGO)
            this.StatItem('剩余', `${this.timeLeft}s`, Colors.AMBER)
            this.StatItem('错误', `${this.errors}`, this.errors > 0 ? Colors.ERROR : Colors.TEXT_PRIMARY)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 6, right: 6, top: 10, bottom: 10 })
      .backgroundColor(Colors.SURFACE_SOFT)
      .borderRadius(Dimensions.CARD_RADIUS_MD)

      Column({ space: 5 }) {
        Text(this.gameStatus === 'idle' ? '点击开始后，按提示选择目标卡片' : `请点击数字 ${this.targetValue}`)
          .fontSize(this.isNarrow() ? 15 : 18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')
          .textAlign(TextAlign.Center)
        Text(this.gameStatus === 'paused' ? '训练已暂停' : `连续正确 ${this.streak} 次 · 第 ${this.round} 轮`)
          .fontSize(11)
          .fontColor(Colors.TEXT_TERTIARY)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(this.targetOrder, (value: number) => {
          Column() {
            Text(`${value}`)
              .fontSize(this.isCompactHeight() ? 24 : (this.isNarrow() ? 28 : 34))
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.ON_PRIMARY)
          }
          .width(this.tileSize())
          .height(this.tileHeight())
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(this.tileColor(value))
          .border({ width: 1, color: '#80FFFFFF' })
          .borderRadius(Dimensions.CARD_RADIUS_MD)
          .shadow({ radius: 12, color: '#24000000', offsetX: 0, offsetY: 4 })
          .margin({ bottom: this.isCompactHeight() ? 6 : 10 })
          .opacity(this.gameStatus === 'paused' ? 0.55 : 1)
          .onClick(() => this.selectTarget(value))
        }, (value: number) => `${value}`)
      }
      .width('100%')
      .onAreaChange((_old: Area, area: Area) => {
        const width: number = typeof area.width === 'string' ? parseFloat(area.width as string) : (area.width as number)
        if (width > 0) this.gameAreaWidth = width
      })

      Row({ space: 10 }) {
        if (this.gameStatus === 'playing') {
          Button('暂停')
            .layoutWeight(1)
            .height(this.isCompactHeight() ? 40 : 44)
            .fontColor(Colors.ON_PRIMARY)
            .backgroundColor(Colors.AMBER)
            .borderRadius(Dimensions.PILL_RADIUS)
            .onClick(() => this.pauseGame())
        } else {
          Button(this.gameStatus === 'paused' ? '继续训练' : (this.gameStatus === 'done' ? '再来一轮' : '开始训练'))
            .layoutWeight(1)
            .height(this.isCompactHeight() ? 40 : 44)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.ON_PRIMARY)
            .backgroundColor(Colors.PRIMARY)
            .borderRadius(Dimensions.PILL_RADIUS)
            .onClick(() => this.startGame())
        }
        Button('重置')
          .width(92)
          .height(this.isCompactHeight() ? 40 : 44)
          .fontColor(Colors.TEXT_SECONDARY)
          .backgroundColor(Colors.SURFACE_SOFT)
          .border({ width: 1, color: Colors.OUTLINE })
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => this.resetGame())
      }
      .width('100%')
    }
    .width('100%')
    .padding(this.isCompactHeight() ? 10 : (this.isNarrow() ? Dimensions.CARD_PADDING_XS : Dimensions.CARD_PADDING_SM))
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .shadow({ radius: 20, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 7 })
  }

  @Builder
  MetricRow(label: string, value: number, color: string) {
    Column({ space: 5 }) {
      Row() {
        Text(label)
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
        Blank()
        Text(`${value}%`)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
      }
      .width('100%')
      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width('100%')
          .height(6)
          .backgroundColor(Colors.DIVIDER)
          .borderRadius(3)
        Column()
          .width(`${Math.max(0, Math.min(100, value))}%`)
          .height(6)
          .backgroundColor(color)
          .borderRadius(3)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  FeedbackPanel() {
    Column({ space: 14 }) {
      Text('实时数据反馈')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT_PRIMARY)
        .width('100%')

      this.MetricRow('专注度', this.eegData.focus, Colors.PRIMARY)
      this.MetricRow('疲劳度', this.eegData.fatigue, Colors.ORANGE)
      this.MetricRow('信号质量', this.eegData.quality, Colors.TEAL)
      this.MetricRow('置信度', this.eegData.confidence, Colors.AMBER)

      Divider().strokeWidth(0.5).color(Colors.DIVIDER)

      Row() {
        Text('当前状态')
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
        Blank()
        Text(this.eegData.state.length > 0 ? this.eegData.state : '--')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.PRIMARY_DARK)
      }
      .width('100%')

      Text('训练建议')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT_PRIMARY)
        .width('100%')
      Text(this.feedbackText())
        .fontSize(12)
        .fontColor(Colors.TEXT_SECONDARY)
        .lineHeight(19)
        .width('100%')
    }
    .width('100%')
    .padding(Dimensions.CARD_PADDING_SM)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .shadow({ radius: 16, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 5 })
  }

  @Builder
  SsvepPanel() {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text('视觉诱发数据')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Text('SSVEP 相关识别功能待接入')
          .fontSize(11)
          .fontColor(Colors.TEXT_TERTIARY)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      Divider().strokeWidth(0.5).color(Colors.DIVIDER)
      this.SsvepRow('接入状态', '功能待接入 / 开发中')
      this.SsvepRow('目标识别', this.ssvepTargetText())
      this.SsvepRow('识别频率', this.ssvepFrequencyText())
      this.SsvepRow('置信度', this.ssvepConfidenceText())
      this.SsvepRow('指令输出', this.ssvepCommandText())
    }
    .width('100%')
    .padding(Dimensions.CARD_PADDING_SM)
    .backgroundColor(Colors.GLASS)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .shadow({ radius: 16, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 5 })
  }

  @Builder
  SsvepRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(11)
        .fontColor(Colors.TEXT_SECONDARY)
        .layoutWeight(1)
      Text(value)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_PRIMARY)
    }
    .width('100%')
    .padding({ top: 5, bottom: 5 })
  }

  @Builder
  DataSectionDivider() {
    Row({ space: 10 }) {
      Divider().layoutWeight(1).strokeWidth(1).color(Colors.DIVIDER)
      Text('实时数据与参数')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_TERTIARY)
      Divider().layoutWeight(1).strokeWidth(1).color(Colors.DIVIDER)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column({ space: 14 }) {
      this.HeaderBar()
      if (this.isWide()) {
        Row({ space: Dimensions.GUTTER }) {
          Column() {
            this.GamePanel()
          }
          .layoutWeight(1)
          .height('100%')

          Scroll() {
            Column({ space: 16 }) {
              this.FeedbackPanel()
              this.SsvepPanel()
            }
            .width('100%')
            .padding({ bottom: 8 })
          }
          .width(330)
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
        }
        .layoutWeight(1)
        .width('100%')
        .alignItems(VerticalAlign.Top)
      } else {
        Column({ space: 16 }) {
          this.GamePanel()
          if (this.isNarrow()) {
            this.DataSectionDivider()
          }
          Scroll() {
            Column({ space: 16 }) {
              this.FeedbackPanel()
              this.SsvepPanel()
            }
            .width('100%')
            .padding({ bottom: this.bottomNavigationInset() })
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
        }
        .layoutWeight(1)
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: this.pageSidePadding(),
      right: this.pageSidePadding(),
      top: this.isNarrow() ? 12 : Dimensions.SCREEN_MARGIN_SM,
      bottom: this.isNarrow() ? 0 : 120
    })
    .backgroundColor(Colors.BACKGROUND)
    .onAreaChange((_old: Area, area: Area) => {
      const width: number = typeof area.width === 'string' ? parseFloat(area.width as string) : (area.width as number)
      const height: number = typeof area.height === 'string' ? parseFloat(area.height as string) : (area.height as number)
      if (width > 0) this.sw = width
      if (height > 0) this.sh = height
    })
  }
}
