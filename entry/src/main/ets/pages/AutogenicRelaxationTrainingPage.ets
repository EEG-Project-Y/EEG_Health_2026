import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'
import { ToPadFrame } from '../model/ToPadModel'

interface RelaxPhase {
  id: string
  title: string
  subtitle: string
  guidance: string
  sensation: string
  durationSec: number
  breathInhaleSec: number
  breathHoldSec: number
  breathExhaleSec: number
}

const RELAX_PHASES: RelaxPhase[] = [
  {
    id: 'heaviness',
    title: '沉重感练习',
    subtitle: '第 1 步 / 共 6 步',
    guidance: '轻轻闭上眼睛，将注意力放在你的右臂上。',
    sensation: '在心里默念："我的右臂很沉重，很放松。"感受肌肉慢慢松开，手臂像被温柔地拉向地面。',
    durationSec: 120,
    breathInhaleSec: 4,
    breathHoldSec: 2,
    breathExhaleSec: 6
  },
  {
    id: 'warmth',
    title: '温暖感练习',
    subtitle: '第 2 步 / 共 6 步',
    guidance: '继续保持放松的姿势，将注意力转向手臂的皮肤表面。',
    sensation: '在心里默念："我的右臂很温暖，血液流动很顺畅。"想象阳光轻轻照在手臂上，暖意慢慢蔓延。',
    durationSec: 120,
    breathInhaleSec: 4,
    breathHoldSec: 2,
    breathExhaleSec: 6
  },
  {
    id: 'heartbeat',
    title: '心跳感知',
    subtitle: '第 3 步 / 共 6 步',
    guidance: '将一只手轻轻放在胸口或手腕上，安静地感受自己的脉搏。',
    sensation: '在心里默念："我的心跳平稳而有节奏。"不必刻意控制，只需要觉察每次心跳的自然节律。',
    durationSec: 90,
    breathInhaleSec: 4,
    breathHoldSec: 4,
    breathExhaleSec: 6
  },
  {
    id: 'breathing',
    title: '呼吸调节',
    subtitle: '第 4 步 / 共 6 步',
    guidance: '把注意力轻轻地放在鼻腔的气息进出上。',
    sensation: '在心里默念："我的呼吸自然、均匀、不需要费力。"跟随下方的呼吸指示，让吸气和呼气都变得缓慢而平稳。',
    durationSec: 120,
    breathInhaleSec: 4,
    breathHoldSec: 4,
    breathExhaleSec: 6
  },
  {
    id: 'abdomen',
    title: '腹部温暖',
    subtitle: '第 5 步 / 共 6 步',
    guidance: '将注意力从胸口向下移动，放在腹部区域。',
    sensation: '在心里默念："我的腹部感到温暖、舒适。"想象有一股柔和的热流在腹部扩散开来。',
    durationSec: 90,
    breathInhaleSec: 4,
    breathHoldSec: 2,
    breathExhaleSec: 6
  },
  {
    id: 'forehead',
    title: '前额凉爽',
    subtitle: '第 6 步 / 共 6 步',
    guidance: '最后，将注意力移到前额和眉心位置。',
    sensation: '在心里默念："我的前额凉爽而清醒。"像有一阵轻柔的微风拂过额头，带走所有的紧绷感。',
    durationSec: 90,
    breathInhaleSec: 4,
    breathHoldSec: 2,
    breathExhaleSec: 6
  }
]

@Component
export struct AutogenicRelaxationTrainingPage {
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
  @Prop showBackButton: boolean = true
  onBack: () => void = () => {}

  @State sw: number = 360
  @State status: string = 'idle'
  @State phaseIndex: number = 0
  @State phaseTimeLeft: number = 0
  @State totalElapsed: number = 0
  @State breathPhase: string = 'inhale'
  @State breathCountdown: number = 4
  @State breathProgress: number = 0
  private timerId: number = -1
  private breathTimerId: number = -1

  aboutToDisappear(): void {
    this.clearAllTimers()
  }

  private clearAllTimers(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
    if (this.breathTimerId >= 0) {
      clearInterval(this.breathTimerId)
      this.breathTimerId = -1
    }
  }

  private isWide(): boolean {
    return this.sw >= 900
  }

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
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

  private currentPhase(): RelaxPhase {
    return RELAX_PHASES[this.phaseIndex]
  }

  private totalPhases(): number {
    return RELAX_PHASES.length
  }

  private phaseProgressPercent(): number {
    const phase = this.currentPhase()
    if (phase.durationSec <= 0) return 0
    return Math.max(0, Math.min(100, Math.round(((phase.durationSec - this.phaseTimeLeft) / phase.durationSec) * 100)))
  }

  private overallProgressPercent(): number {
    const completed = this.phaseIndex
    const current = this.phaseProgressPercent() / 100
    const total = this.totalPhases()
    return Math.round(((completed + current) / total) * 100)
  }

  private startTraining(): void {
    if (this.status === 'paused') {
      this.status = 'playing'
      this.startPhaseTimer()
      this.startBreathCycle()
      return
    }
    this.phaseIndex = 0
    this.totalElapsed = 0
    this.phaseTimeLeft = RELAX_PHASES[0].durationSec
    this.status = 'playing'
    this.startPhaseTimer()
    this.startBreathCycle()
  }

  private pauseTraining(): void {
    if (this.status !== 'playing') return
    this.status = 'paused'
    this.clearAllTimers()
  }

  private resetTraining(): void {
    this.clearAllTimers()
    this.status = 'idle'
    this.phaseIndex = 0
    this.totalElapsed = 0
    this.phaseTimeLeft = 0
    this.breathPhase = 'inhale'
    this.breathCountdown = 4
    this.breathProgress = 0
  }

  private startPhaseTimer(): void {
    if (this.timerId >= 0) clearInterval(this.timerId)
    this.timerId = setInterval(() => {
      if (this.status !== 'playing') return
      if (this.phaseTimeLeft <= 1) {
        this.phaseTimeLeft = 0
        this.totalElapsed += this.currentPhase().durationSec
        if (this.phaseIndex < RELAX_PHASES.length - 1) {
          this.phaseIndex++
          this.phaseTimeLeft = this.currentPhase().durationSec
          this.startBreathCycle()
        } else {
          this.status = 'done'
          this.clearAllTimers()
        }
      } else {
        this.phaseTimeLeft--
        this.totalElapsed++
      }
    }, 1000)
  }

  private startBreathCycle(): void {
    if (this.breathTimerId >= 0) clearInterval(this.breathTimerId)
    const phase = this.currentPhase()
    this.breathPhase = 'inhale'
    this.breathCountdown = phase.breathInhaleSec
    this.breathProgress = 0
    this.breathTimerId = setInterval(() => {
      if (this.status !== 'playing') return
      this.breathProgress++
      if (this.breathPhase === 'inhale') {
        if (this.breathCountdown <= 1) {
          this.breathPhase = 'hold'
          this.breathCountdown = phase.breathHoldSec
        } else {
          this.breathCountdown--
        }
      } else if (this.breathPhase === 'hold') {
        if (this.breathCountdown <= 1) {
          this.breathPhase = 'exhale'
          this.breathCountdown = phase.breathExhaleSec
        } else {
          this.breathCountdown--
        }
      } else {
        if (this.breathCountdown <= 1) {
          this.breathPhase = 'inhale'
          this.breathCountdown = phase.breathInhaleSec
          this.breathProgress = 0
        } else {
          this.breathCountdown--
        }
      }
    }, 1000)
  }

  private nextPhase(): void {
    if (this.phaseIndex < RELAX_PHASES.length - 1) {
      this.totalElapsed += this.currentPhase().durationSec - this.phaseTimeLeft
      this.phaseIndex++
      this.phaseTimeLeft = this.currentPhase().durationSec
      this.startBreathCycle()
    }
  }

  private prevPhase(): void {
    if (this.phaseIndex > 0) {
      this.phaseIndex--
      this.phaseTimeLeft = this.currentPhase().durationSec
      this.startBreathCycle()
    }
  }

  private formatTime(sec: number): string {
    const m = Math.floor(sec / 60)
    const s = sec % 60
    return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s
  }

  private breathLabel(): string {
    if (this.breathPhase === 'inhale') return '吸气'
    if (this.breathPhase === 'hold') return '屏息'
    return '呼气'
  }

  private breathColor(): string {
    if (this.breathPhase === 'inhale') return Colors.PRIMARY
    if (this.breathPhase === 'hold') return Colors.AMBER
    return Colors.TEAL
  }

  private statusText(): string {
    if (this.status === 'playing') return '训练中'
    if (this.status === 'paused') return '已暂停'
    if (this.status === 'done') return '已完成'
    return '等待开始'
  }

  private relaxFeedbackText(): string {
    if (this.status === 'idle') return '点击"开始训练"进入自生放松引导，跟随声音或文字指示逐步放松身体各个部位。'
    if (this.eegData.relax >= 70) return '当前放松度良好，身体已进入较深的放松状态，继续保持自然呼吸。'
    if (this.eegData.relax >= 40) return '放松度正在提升，继续跟随引导逐步释放身体的紧张感。'
    if (this.eegData.quality < 60) return '当前信号质量偏低，建议检查设备佩戴，确保脑电数据准确。'
    if (this.eegData.fatigue >= 70) return '检测到疲劳指标偏高，当前的放松训练正是缓解疲劳的好时机。'
    return '保持耐心，自生放松需要反复练习，每次训练都在帮助身体建立更快的放松反应。'
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
          this.clearAllTimers()
          this.onBack()
        })
      }

      Column({ space: 3 }) {
        Text('自生放松训练')
          .fontSize(this.isNarrow() ? 20 : 24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Text('身体感受引导 · 呼吸节奏辅助 · 脑电状态反馈')
          .fontSize(this.isNarrow() ? 11 : 12)
          .fontColor(Colors.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.statusText())
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.status === 'playing' ? Colors.SUCCESS : Colors.TEXT_SECONDARY)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor(Colors.GLASS_ACTIVE)
        .border({ width: 1, color: Colors.GLASS_BORDER })
        .borderRadius(Dimensions.PILL_RADIUS)
    }
    .width('100%')
  }

  @Builder
  GuidancePanel() {
    Column({ space: this.isNarrow() ? 12 : 16 }) {
      if (this.status === 'idle') {
        this.IdleContent()
      } else {
        this.ActiveGuidanceContent()
      }
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_XS : Dimensions.CARD_PADDING_SM)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .shadow({ radius: 20, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 7 })
  }

  @Builder
  IdleContent() {
    Column({ space: 18 }) {
      Column() {
        Image($r('app.media.training_relax'))
          .width('100%')
          .height(this.isNarrow() ? 150 : 200)
          .objectFit(ImageFit.Cover)
          .borderRadius(Dimensions.CARD_RADIUS_MD)
      }
      .width('100%')

      Column({ space: 8 }) {
        Text('自生放松训练')
          .fontSize(this.isNarrow() ? 20 : 24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEAL)
          .width('100%')
          .textAlign(TextAlign.Center)
        Text('通过身体感受引导、自然呼吸提示和放松暗示，帮助你逐步进入更平稳的放松状态。')
          .fontSize(this.isNarrow() ? 13 : 15)
          .fontColor(Colors.TEXT_SECONDARY)
          .lineHeight(this.isNarrow() ? 20 : 24)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')

      Column({ space: 10 }) {
        Text('训练包含 6 个阶段')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_TERTIARY)
          .width('100%')
          .textAlign(TextAlign.Center)

        Row({ space: 6 }) {
          ForEach(RELAX_PHASES, (phase: RelaxPhase, index: number) => {
            Column({ space: 4 }) {
              Text(`${index + 1}`)
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor(Colors.TEAL)
                .width(24)
                .height(24)
                .textAlign(TextAlign.Center)
                .backgroundColor('#1A13B5A8')
                .borderRadius(12)
              Text(phase.title.replace('练习', '').replace('感知', '').replace('调节', ''))
                .fontSize(9)
                .fontColor(Colors.TEXT_TERTIARY)
                .maxLines(1)
            }
            .alignItems(HorizontalAlign.Center)
            .layoutWeight(1)
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ top: 6, bottom: 6, left: 4, right: 4 })
      .backgroundColor(Colors.SURFACE_SOFT)
      .borderRadius(Dimensions.CARD_RADIUS_SM)

      Button('开始训练')
        .width('100%')
        .height(48)
        .fontWeight(FontWeight.Bold)
        .fontSize(16)
        .fontColor(Colors.ON_PRIMARY)
        .backgroundColor(Colors.TEAL)
        .borderRadius(Dimensions.PILL_RADIUS)
        .onClick(() => this.startTraining())
    }
    .width('100%')
  }

  @Builder
  ActiveGuidanceContent() {
    Column({ space: this.isNarrow() ? 14 : 18 }) {
      Column({ space: 6 }) {
        Row() {
          Column({ space: 3 }) {
            Text(this.currentPhase().title)
              .fontSize(this.isNarrow() ? 18 : 22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_PRIMARY)
            Text(this.currentPhase().subtitle)
              .fontSize(12)
              .fontColor(Colors.TEXT_TERTIARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 3 }) {
            Text(this.formatTime(this.phaseTimeLeft))
              .fontSize(this.isNarrow() ? 24 : 30)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.phaseTimeLeft <= 15 ? Colors.ORANGE : Colors.TEAL)
              .fontFamily('Hanken Grotesk')
            Text('剩余')
              .fontSize(10)
              .fontColor(Colors.TEXT_TERTIARY)
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')

        Stack({ alignContent: Alignment.Start }) {
          Column()
            .width('100%')
            .height(6)
            .backgroundColor(Colors.DIVIDER)
            .borderRadius(3)
          Column()
            .width(`${this.phaseProgressPercent()}%`)
            .height(6)
            .backgroundColor(Colors.TEAL)
            .borderRadius(3)
        }
        .width('100%')
      }
      .width('100%')

      Column({ space: 10 }) {
        Text('总进度')
          .fontSize(10)
          .fontColor(Colors.TEXT_TERTIARY)
          .width('100%')
        Stack({ alignContent: Alignment.Start }) {
          Column()
            .width('100%')
            .height(4)
            .backgroundColor(Colors.DIVIDER)
            .borderRadius(2)
          Column()
            .width(`${this.overallProgressPercent()}%`)
            .height(4)
            .backgroundColor(Colors.PRIMARY)
            .borderRadius(2)
        }
        .width('100%')
      }
      .width('100%')

      Divider().strokeWidth(0.5).color(Colors.DIVIDER)

      Column({ space: 10 }) {
        Text(this.currentPhase().guidance)
          .fontSize(this.isNarrow() ? 14 : 16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
          .lineHeight(this.isNarrow() ? 21 : 25)
          .width('100%')

        Text(this.currentPhase().sensation)
          .fontSize(this.isNarrow() ? 13 : 15)
          .fontColor(Colors.TEXT_SECONDARY)
          .lineHeight(this.isNarrow() ? 20 : 24)
          .width('100%')
          .padding({
            left: this.isNarrow() ? 12 : 16,
            top: this.isNarrow() ? 10 : 14,
            right: this.isNarrow() ? 12 : 16,
            bottom: this.isNarrow() ? 10 : 14
          })
          .backgroundColor(Colors.SURFACE_SOFT)
          .borderRadius(Dimensions.CARD_RADIUS_MD)
          .border({ width: 1, color: Colors.DIVIDER })
      }
      .width('100%')

      this.BreathGuide()

      Row({ space: 10 }) {
        Row() {
          Text('◀')
            .fontSize(14)
            .fontColor(this.phaseIndex > 0 ? Colors.TEXT_PRIMARY : Colors.TEXT_TERTIARY)
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.phaseIndex > 0 ? Colors.SURFACE_SOFT : Colors.GLASS)
        .border({ width: 1, color: Colors.OUTLINE })
        .borderRadius(Dimensions.PILL_RADIUS)
        .onClick(() => {
          if (this.phaseIndex > 0) this.prevPhase()
        })

        if (this.status === 'playing') {
          Button('暂停')
            .layoutWeight(1)
            .height(44)
            .fontColor(Colors.ON_PRIMARY)
            .backgroundColor(Colors.AMBER)
            .borderRadius(Dimensions.PILL_RADIUS)
            .onClick(() => this.pauseTraining())
        } else {
          Button('继续训练')
            .layoutWeight(1)
            .height(44)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.ON_PRIMARY)
            .backgroundColor(Colors.TEAL)
            .borderRadius(Dimensions.PILL_RADIUS)
            .onClick(() => this.startTraining())
        }

        Row() {
          Text('▶')
            .fontSize(14)
            .fontColor(this.phaseIndex < RELAX_PHASES.length - 1 ? Colors.TEXT_PRIMARY : Colors.TEXT_TERTIARY)
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.phaseIndex < RELAX_PHASES.length - 1 ? Colors.SURFACE_SOFT : Colors.GLASS)
        .border({ width: 1, color: Colors.OUTLINE })
        .borderRadius(Dimensions.PILL_RADIUS)
        .onClick(() => {
          if (this.phaseIndex < RELAX_PHASES.length - 1) this.nextPhase()
        })

        Button('重置')
          .width(72)
          .height(44)
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .backgroundColor(Colors.SURFACE_SOFT)
          .border({ width: 1, color: Colors.OUTLINE })
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => this.resetTraining())
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  BreathGuide() {
    Column({ space: 10 }) {
      Row() {
        Text('呼吸引导')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
        Text(`${this.breathLabel()} ${this.breathCountdown}s`)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.breathColor())
      }
      .width('100%')

      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(this.isNarrow() ? 100 : 120)
          .height(this.isNarrow() ? 100 : 120)
          .borderRadius(this.isNarrow() ? 50 : 60)
          .border({ width: 3, color: this.breathColor() + '40' })

        Column()
          .width(this.isNarrow() ? 100 : 120)
          .height(this.isNarrow() ? 100 : 120)
          .borderRadius(this.isNarrow() ? 50 : 60)
          .border({ width: 3, color: Colors.GLASS_BORDER })

        Column()
          .width(this.breathIndicatorSize())
          .height(this.breathIndicatorSize())
          .borderRadius(this.breathIndicatorSize() / 2)
          .backgroundColor(this.breathColor() + '30')
          .border({ width: 2, color: this.breathColor() })
          .animation({ duration: 300, curve: Curve.EaseInOut })

        Text(this.breathLabel())
          .fontSize(this.isNarrow() ? 16 : 18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.breathColor())
      }
      .width('100%')
      .padding({ top: 6, bottom: 6 })

      Row({ space: 4 }) {
        Text('吸 ' + this.currentPhase().breathInhaleSec + 's')
          .fontSize(10)
          .fontColor(this.breathPhase === 'inhale' ? Colors.PRIMARY : Colors.TEXT_TERTIARY)
          .fontWeight(this.breathPhase === 'inhale' ? FontWeight.Bold : FontWeight.Normal)
        Text('·')
          .fontSize(10)
          .fontColor(Colors.TEXT_TERTIARY)
        Text('屏 ' + this.currentPhase().breathHoldSec + 's')
          .fontSize(10)
          .fontColor(this.breathPhase === 'hold' ? Colors.AMBER : Colors.TEXT_TERTIARY)
          .fontWeight(this.breathPhase === 'hold' ? FontWeight.Bold : FontWeight.Normal)
        Text('·')
          .fontSize(10)
          .fontColor(Colors.TEXT_TERTIARY)
        Text('呼 ' + this.currentPhase().breathExhaleSec + 's')
          .fontSize(10)
          .fontColor(this.breathPhase === 'exhale' ? Colors.TEAL : Colors.TEXT_TERTIARY)
          .fontWeight(this.breathPhase === 'exhale' ? FontWeight.Bold : FontWeight.Normal)
      }
    }
    .width('100%')
    .padding(this.isNarrow() ? 12 : 16)
    .backgroundColor(Colors.SURFACE_SOFT)
    .borderRadius(Dimensions.CARD_RADIUS_MD)
    .alignItems(HorizontalAlign.Center)
  }

  private breathIndicatorSize(): number {
    const base = this.isNarrow() ? 100 : 120
    const phase = this.currentPhase()
    const totalCycle = phase.breathInhaleSec + phase.breathHoldSec + phase.breathExhaleSec
    if (totalCycle <= 0) return base * 0.5

    let progressInCycle = 0
    if (this.breathPhase === 'inhale') {
      progressInCycle = (phase.breathInhaleSec - this.breathCountdown) / totalCycle
    } else if (this.breathPhase === 'hold') {
      progressInCycle = (phase.breathInhaleSec + (phase.breathHoldSec - this.breathCountdown)) / totalCycle
    } else {
      progressInCycle = (phase.breathInhaleSec + phase.breathHoldSec + (phase.breathExhaleSec - this.breathCountdown)) / totalCycle
    }

    if (this.breathPhase === 'inhale') {
      const ratio = progressInCycle / (phase.breathInhaleSec / totalCycle)
      return base * (0.35 + 0.65 * ratio)
    } else if (this.breathPhase === 'hold') {
      return base
    } else {
      const exhaleRatio = phase.breathExhaleSec / totalCycle
      const exhaleStart = (phase.breathInhaleSec + phase.breathHoldSec) / totalCycle
      const exhaleProgress = (progressInCycle - exhaleStart) / exhaleRatio
      return base * (1.0 - 0.65 * exhaleProgress)
    }
  }

  @Builder
  MetricRow(label: string, value: number, color: string) {
    Column({ space: this.isNarrow() ? 3 : 5 }) {
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
    Column({ space: this.isNarrow() ? 12 : 14 }) {
      Text('实时脑电状态')
        .fontSize(this.isNarrow() ? 15 : 17)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT_PRIMARY)
        .width('100%')

      this.MetricRow('放松度', this.eegData.relax, Colors.TEAL)
      this.MetricRow('专注度', this.eegData.focus, Colors.PRIMARY)
      this.MetricRow('疲劳度', this.eegData.fatigue, Colors.ORANGE)
      this.MetricRow('信号质量', this.eegData.quality, Colors.MINT)
      this.MetricRow('置信度', this.eegData.confidence, Colors.AMBER)

      Divider().strokeWidth(0.5).color(Colors.DIVIDER)

      Column({ space: 6 }) {
        Row() {
          Text('当前状态')
            .fontSize(12)
            .fontColor(Colors.TEXT_SECONDARY)
          Blank()
          Text(this.eegData.state.length > 0 ? this.eegData.state : '--')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.eegData.relax >= 60 ? Colors.TEAL : Colors.PRIMARY_DARK)
        }
        .width('100%')

        Row() {
          Text('负荷指数')
            .fontSize(12)
            .fontColor(Colors.TEXT_SECONDARY)
          Blank()
          Text(`${this.eegData.load}%`)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
        }
        .width('100%')
      }
      .width('100%')

      Divider().strokeWidth(0.5).color(Colors.DIVIDER)

      Column({ space: 8 }) {
        Text('训练反馈')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')
        Text(this.relaxFeedbackText())
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .lineHeight(19)
          .width('100%')
      }
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
  DonePanel() {
    Column({ space: this.isNarrow() ? 12 : 16 }) {
      Text('🎉')
        .fontSize(48)

      Text('训练完成')
        .fontSize(this.isNarrow() ? 20 : 24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEAL)

      Text('你已完成全部 6 个阶段的自生放松训练。')
        .fontSize(this.isNarrow() ? 13 : 15)
        .fontColor(Colors.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
        .lineHeight(this.isNarrow() ? 20 : 24)

      Row({ space: 12 }) {
        Column({ space: 2 }) {
          Text('总用时')
            .fontSize(10)
            .fontColor(Colors.TEXT_TERTIARY)
          Text(this.formatTime(this.totalElapsed))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
            .fontFamily('Hanken Grotesk')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column({ space: 2 }) {
          Text('平均放松度')
            .fontSize(10)
            .fontColor(Colors.TEXT_TERTIARY)
          Text(`${this.eegData.relax}%`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEAL)
            .fontFamily('Hanken Grotesk')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .padding({ top: 6, bottom: 6 })

      Row({ space: 10 }) {
        Button('再来一轮')
          .layoutWeight(1)
          .height(44)
          .fontWeight(FontWeight.Bold)
          .fontSize(14)
          .fontColor(Colors.ON_PRIMARY)
          .backgroundColor(Colors.TEAL)
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => {
            this.resetTraining()
            this.startTraining()
          })
        Button('返回列表')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor(Colors.TEXT_SECONDARY)
          .backgroundColor(Colors.SURFACE_SOFT)
          .border({ width: 1, color: Colors.OUTLINE })
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => {
            this.clearAllTimers()
            this.onBack()
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(Dimensions.CARD_PADDING_SM)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .shadow({ radius: 20, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 7 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  DataSectionDivider() {
    Row({ space: 10 }) {
      Divider()
        .layoutWeight(1)
        .strokeWidth(1)
        .color(Colors.DIVIDER)
      Text('训练参数与实时数据')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_TERTIARY)
      Divider()
        .layoutWeight(1)
        .strokeWidth(1)
        .color(Colors.DIVIDER)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 2, bottom: 2 })
  }

  build() {
    Column({ space: 14 }) {
      this.HeaderBar()

      if (this.isWide()) {
        Row({ space: Dimensions.GUTTER }) {
          Scroll() {
            Column({ space: 16 }) {
              this.GuidancePanel()
              if (this.status === 'done') {
                this.DonePanel()
              }
            }
            .width('100%')
            .padding({ bottom: 8 })
          }
          .layoutWeight(1)
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)

          Scroll() {
            Column({ space: 16 }) {
              this.FeedbackPanel()
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
      } else if (this.isNarrow()) {
        Column({ space: 12 }) {
          this.GuidancePanel()
          if (this.status === 'done') {
            this.DonePanel()
          }

          this.DataSectionDivider()

          Scroll() {
            Column() {
              this.FeedbackPanel()
            }
            .width('100%')
            .padding({ bottom: this.bottomNavigationInset() })
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
        }
        .layoutWeight(1)
        .width('100%')
        .height('100%')
      } else {
        Scroll() {
          Column({ space: 16 }) {
            this.GuidancePanel()
            if (this.status === 'done') {
              this.DonePanel()
            }
            this.FeedbackPanel()
          }
          .width('100%')
          .padding({ bottom: this.bottomNavigationInset() })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
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
      if (width > 0) this.sw = width
    })
  }
}
