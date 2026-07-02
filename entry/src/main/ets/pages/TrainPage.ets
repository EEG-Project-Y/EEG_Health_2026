import { Dimensions } from '../constants/Dimensions'
import { Colors } from '../constants/Colors'
import { ToPadFrame } from '../model/ToPadModel'
import { ToPadMock } from '../model/ToPadMock'
import { VisualAttentionTrainingPage } from './VisualAttentionTrainingPage'
import { AutogenicRelaxationTrainingPage } from './AutogenicRelaxationTrainingPage'
import { display } from '@kit.ArkUI'

interface TrainingResult { gameType: string; gridSize: number; durationMs: number; errorCount: number; completedAt: number; focus: number; fatigue: number; relax: number; load: number; quality: number; confidence: number }
interface MemoryBox { id: number; number: number; x: number; y: number; state: string }
interface Position { x: number; y: number }

@Component
export struct TrainPage {
  @Prop useGlobalTopbarBack: boolean = false
  onTopbarBackChange: (visible: boolean, action: () => void) => void =
    (_visible: boolean, _action: () => void) => {}
  @State trainingView: string = 'menu'
  @State cg: string = 'schulte'
  @State gs: string = 'idle'
  @State dd: boolean = false
  @State eeg: ToPadFrame = ToPadMock.getCurrent()
  @State ss: number = 5
  @State sn: number[] = []
  @State st: number = 1
  @State sw: number = -1
  @State ml: number = 0
  @State mb: MemoryBox[] = []
  @State mt: number = 1
  @State mtotal: number = 3
  @State mcd: number = 0
  @State mcl: boolean = false
  @State mhs: number = 0
  @State md: string = 'normal'
  @State stime: number = 0
  @State ptime: number = 0
  @State el: number = 0
  @State er: number = 0
  @State sw2: number = 360
  @State gameAreaWidth: number = 300
  private t1: number = -1
  private t2: number = -1
  private t3: number = -1
  private t4: number = -1

  aboutToAppear(): void { }

  aboutToDisappear(): void {
    this.ct()
    this.onTopbarBackChange(false, () => {})
  }

  private ct(): void {
    if (this.t1 >= 0) { clearInterval(this.t1); this.t1 = -1 }
    if (this.t2 >= 0) { clearInterval(this.t2); this.t2 = -1 }
    if (this.t3 >= 0) { clearTimeout(this.t3); this.t3 = -1 }
    if (this.t4 >= 0) { clearTimeout(this.t4); this.t4 = -1 }
  }

  private ra(): void {
    this.ct()
    this.gs = 'idle'
    this.stime = 0; this.ptime = 0; this.el = 0; this.er = 0
    this.sn = []; this.st = 1; this.sw = -1
    this.mb = []; this.mt = 1; this.ml = 0; this.mcd = 0; this.mcl = false
  }

  private fmt(ms: number): string {
    const s = Math.floor(ms / 1000)
    const m = Math.floor(s / 60)
    const sc = s % 60
    const t = Math.floor((ms % 1000) / 100)
    return (m < 10 ? '0' : '') + m + ':' + (sc < 10 ? '0' : '') + sc + '.' + t
  }

  private shf(a: number[]): number[] {
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      const tmp = a[i]; a[i] = a[j]; a[j] = tmp
    }
    return a
  }

  private iw(): boolean {
    return this.sw2 > Dimensions.BREAKPOINT_TABLET
  }

  private isPortrait(): boolean {
    try {
      const d = display.getDefaultDisplaySync()
      return d.height > d.width
    } catch (e) {
      return false
    }
  }

  private in(): boolean {
    return this.sw2 < Dimensions.BREAKPOINT_TABLET
  }

  private bottomNavigationInset(): number {
    if (!this.in()) return 8
    return this.sw2 < Dimensions.BREAKPOINT_PHONE ? 68 : 84
  }

  private csz(): number {
    const gap = this.in() ? 2 : 6
    const gamePad = this.in() ? 14 : 26
    const outerPad = this.in() ? 12 : 24
    const avail = this.iw() ? 420 : (this.sw2 - outerPad * 2 - gamePad * 2)
    return Math.floor((avail - (this.ss - 1) * gap) / this.ss)
  }

  private msz(): number {
    const gamePad = this.in() ? 14 : 26
    const outerPad = this.in() ? 12 : 24
    return Math.min(this.sw2 - outerPad * 2 - gamePad * 2, this.in() ? 240 : 360)
  }

  private ssch(): void {
    this.ct(); this.st = 1; this.el = 0; this.ptime = 0; this.er = 0; this.sw = -1
    const n = this.ss * this.ss
    const a: number[] = []
    for (let i = 1; i <= n; i++) a.push(i)
    this.sn = this.shf(a)
    this.gs = 'playing'; this.stime = Date.now()
    this.t1 = setInterval(() => { if (this.gs === 'playing') this.el = Date.now() - this.stime }, 100)
  }

  private csch(i: number): void {
    if (this.gs !== 'playing') return
    const v = this.sn[i]
    if (v === this.st) {
      this.sw = -1
      if (this.st === this.ss * this.ss) {
        this.el = Date.now() - this.stime; this.ct(); this.gs = 'done'; this.lr('schulte')
      } else {
        this.st++
      }
    } else {
      this.er++; this.sw = i
      const c = i
      this.t3 = setTimeout(() => { if (this.sw === c) this.sw = -1 }, 600)
    }
  }

  private pg(): void {
    if (this.gs === 'playing') { this.ct(); this.ptime = this.el; this.gs = 'paused' }
  }

  private rg(): void {
    if (this.gs === 'paused') {
      this.stime = Date.now() - this.ptime; this.gs = 'playing'
      this.t1 = setInterval(() => { if (this.gs === 'playing') this.el = Date.now() - this.stime }, 100)
    }
  }

  private sm(): void {
    this.ct(); this.ml = 0; this.el = 0; this.ptime = 0; this.er = 0; this.mb = []
    this.gs = 'playing'; this.stime = Date.now()
    this.nml()
  }

  private nml(): void {
    if (this.t2 >= 0) { clearInterval(this.t2); this.t2 = -1 }
    this.mt = 1; this.mcl = false
    let b = 3; let mu = 0.9; let tb = 2500; let tr = 2500; let tred = 120; let tm = 800
    if (this.md === 'easy') { b = 3; mu = 0.5; tb = 3500; tr = 2000; tred = 80; tm = 1200 }
    else if (this.md === 'hard') { b = 4; mu = 1.2; tb = 2000; tr = 2000; tred = 150; tm = 600 }
    this.mtotal = b + Math.floor(this.ml * mu)
    const boxSize = this.in() ? 32 : 60
    const gap = this.in() ? 6 : 15
    const areaW = this.iw() ? 420 : this.msz()
    const areaH = areaW
    const mx = areaW - boxSize
    const my = areaH - boxSize
    const pos: Position[] = []; const boxes: MemoryBox[] = []
    for (let i = 1; i <= this.mtotal; i++) {
      let x = 0; let y = 0; let ok = false; let att = 0
      while (!ok && att < 500) {
        x = Math.random() * mx; y = Math.random() * my; ok = true
        for (let j = 0; j < pos.length; j++) {
          if (Math.sqrt((x - pos[j].x) ** 2 + (y - pos[j].y) ** 2) < boxSize + gap) { ok = false; break }
        }
        att++
      }
      pos.push({ x, y })
      boxes.push({ id: i, number: i, x, y, state: 'show' })
    }
    this.mb = boxes
    const dt = Math.max(tm, tb + Math.floor(Math.random() * tr) - this.ml * tred)
    this.mcd = Math.ceil(dt / 100)
    this.t2 = setInterval(() => {
      if (this.gs !== 'playing') return
      this.mcd--
      if (this.mcd <= 0) {
        if (this.t2 >= 0) { clearInterval(this.t2); this.t2 = -1 }
        const u: MemoryBox[] = []
        for (let i = 0; i < this.mb.length; i++) {
          const o = this.mb[i]
          u.push({ id: o.id, number: o.number, x: o.x, y: o.y, state: 'hidden' })
        }
        this.mb = u; this.mcl = true
        this.t1 = setInterval(() => { if (this.gs === 'playing') this.el = Date.now() - this.stime }, 100)
      }
    }, 100)
  }

  private cm(box: MemoryBox): void {
    if (!this.mcl || box.state === 'revealed' || box.state === 'wrong') return
    if (box.number === this.mt) {
      const u: MemoryBox[] = []
      for (let i = 0; i < this.mb.length; i++) {
        const b = this.mb[i]
        if (b.id === box.id) { u.push({ id: b.id, number: b.number, x: b.x, y: b.y, state: 'revealed' }) }
        else { u.push(b) }
      }
      this.mb = u; this.mt++
      if (this.mt > this.mtotal) {
        this.ml++; if (this.ml > this.mhs) this.mhs = this.ml
        this.t4 = setTimeout(() => { this.nml() }, 600)
      }
    } else {
      this.er++; const u: MemoryBox[] = []
      for (let i = 0; i < this.mb.length; i++) {
        const b = this.mb[i]
        if (b.id === box.id) { u.push({ id: b.id, number: b.number, x: b.x, y: b.y, state: 'wrong' }) }
        else if (b.state === 'hidden') { u.push({ id: b.id, number: b.number, x: b.x, y: b.y, state: 'show' }) }
        else { u.push(b) }
      }
      this.mb = u; this.mcl = false; this.el = Date.now() - this.stime
      this.ct(); this.gs = 'done'; this.lr('memory')
    }
  }

  private lr(t: string): void {
    // TODO: 后续可接入训练记录持久化与脑电反馈闭环，当前仅做控制台输出验证
    const result: TrainingResult = {
      gameType: t, gridSize: t === 'schulte' ? this.ss : this.mtotal,
      durationMs: this.el, errorCount: this.er, completedAt: Date.now(),
      focus: this.eeg.focus, fatigue: this.eeg.fatigue, relax: this.eeg.relax,
      load: this.eeg.load, quality: this.eeg.quality, confidence: this.eeg.confidence
    }
    console.info('TrainingResult: ' + JSON.stringify(result))
  }

  private sr(): number[] {
    const r: number[] = []; for (let i = 0; i < this.ss; i++) r.push(i); return r
  }

  private scc(): number[] {
    const r: number[] = []; for (let i = 0; i < this.ss; i++) r.push(i); return r
  }

  private openTraining(view: string): void {
    this.ra()
    this.trainingView = view
    if (view === 'neuro') {
      this.cg = 'schulte'
      this.dd = false
    }
    this.onTopbarBackChange(true, () => this.backToTrainingHub())
  }

  private backToTrainingHub(): void {
    this.ra()
    this.trainingView = 'menu'
    this.dd = false
    this.onTopbarBackChange(false, () => {})
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.trainingView === 'menu') {
        this.trainingHub()
      } else if (this.trainingView === 'relax') {
        AutogenicRelaxationTrainingPage({
          eegData: this.eeg,
          showBackButton: !this.useGlobalTopbarBack,
          onBack: () => this.backToTrainingHub()
        })
          .transition(TransitionEffect.OPACITY.animation({ duration: 260, curve: Curve.EaseOut }))
      } else if (this.trainingView === 'cognitive') {
        VisualAttentionTrainingPage({
          eegData: this.eeg,
          showBackButton: !this.useGlobalTopbarBack,
          onBack: () => this.backToTrainingHub()
        })
          .transition(TransitionEffect.OPACITY.animation({ duration: 260, curve: Curve.EaseOut }))
      } else {
        if (this.iw() && !this.isPortrait()) {
          this.wideLayout()
        } else if (this.in()) {
          Column({ space: 8 }) {
            Column({ space: 8 }) {
              this.titleBar()
              this.difficultyBar()
              this.gameArea()
            }
            .width('100%')

            this.dataSectionDivider('训练参数与实时数据')

            Scroll() {
              Column({ space: 8 }) {
                this.statusCard()
                this.eegCard()
                this.adviceCard()
              }
              .width('100%')
              .padding({ bottom: this.bottomNavigationInset() })
            }
            .layoutWeight(1)
            .width('100%')
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.None)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 8, right: 8, top: 8, bottom: 0 })
          .transition(TransitionEffect.OPACITY.animation({ duration: 260, curve: Curve.EaseOut }))
        } else {
          Scroll() {
            Column({ space: 12 }) {
              Column({ space: 12 }) {
                this.titleBar()
                this.difficultyBar()
                this.gameArea()
              }
              .width('100%')

              Row({ space: 12 }) {
                this.statusCard()
                this.eegCard()
              }
              .width('100%')
              this.adviceCard()
            }
            .width('100%')
            .padding({
              left: Dimensions.SCREEN_MARGIN_SM,
              right: Dimensions.SCREEN_MARGIN_SM,
              top: Dimensions.SCREEN_MARGIN_SM,
              bottom: 118
            })
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.OPACITY.animation({ duration: 260, curve: Curve.EaseOut }))
        }
        if (this.gs === 'done') {
          this.doneOverlay()
        }
        if (this.in() && this.gs === 'paused') {
          this.pauseOverlay()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BACKGROUND)
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      if (w > 0) this.sw2 = w
    })
  }

  @Builder trainingHub() {
    Scroll() {
      Column({ space: this.in() ? 16 : 20 }) {
        Column({ space: 6 }) {
          Text('训练中心')
            .fontSize(this.in() ? 24 : 30)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
          Text('选择训练模块，开始专注与认知练习')
            .fontSize(this.in() ? 13 : 15)
            .fontColor(Colors.TEXT_SECONDARY)
            .lineHeight(this.in() ? 20 : 23)
            .width('100%')
        }
        .width('100%')

        if (this.iw() && !this.isPortrait()) {
          Row({ space: Dimensions.GUTTER }) {
            this.trainingEntryCard(
              'relax',
              '脑放松训练',
              '跟随呼吸与自然节奏，放松身心。'
            )
            this.trainingEntryCard(
              'neuro',
              '神经反馈训练',
              '结合注意反馈，进入舒尔特表训练。'
            )
            this.trainingEntryCard(
              'cognitive',
              '认知能力训练',
              '通过目标选择，练习视觉注意与反应。'
            )
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        } else {
          Column({ space: 16 }) {
            this.trainingEntryCard(
              'relax',
              '脑放松训练',
              '跟随呼吸与自然节奏，放松身心。'
            )
            this.trainingEntryCard(
              'neuro',
              '神经反馈训练',
              '结合注意反馈，进入舒尔特表训练。'
            )
            this.trainingEntryCard(
              'cognitive',
              '认知能力训练',
              '通过目标选择，练习视觉注意与反应。'
            )
          }
          .width('100%')
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: Dimensions.CONTENT_MAX_WIDTH })
      .padding({
        left: this.in() ? 12 : Dimensions.SCREEN_MARGIN,
        right: this.in() ? 12 : Dimensions.SCREEN_MARGIN,
        top: this.in() ? 12 : Dimensions.SCREEN_MARGIN_SM,
        bottom: 118
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .transition(TransitionEffect.OPACITY.animation({ duration: 240, curve: Curve.EaseOut }))
  }

  @Builder trainingEntryCard(kind: string, title: string, description: string) {
    Column() {
      if (kind === 'relax') {
        Image($r('app.media.training_relax'))
          .width('100%')
          .height(this.iw() && !this.isPortrait() ? 170 : 138)
          .objectFit(ImageFit.Cover)
          .borderRadius({ topLeft: Dimensions.CARD_RADIUS_LG, topRight: Dimensions.CARD_RADIUS_LG })
      } else if (kind === 'neuro') {
        this.schultePreview()
      } else {
        this.cognitivePreview()
      }

      Column({ space: this.in() ? 5 : 10 }) {
        Text(title)
          .fontSize(this.in() ? 18 : 20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')
        Text(description)
          .fontSize(this.in() ? 12 : 13)
          .fontColor(Colors.TEXT_SECONDARY)
          .lineHeight(this.in() ? 17 : 20)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (!this.in()) {
          Row() {
            Text(kind === 'neuro' ? '进入舒尔特表训练' : '进入训练')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(kind === 'relax' ? Colors.TEAL : (kind === 'neuro' ? Colors.PRIMARY : Colors.INDIGO))
            Blank()
            Text('→')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(kind === 'relax' ? Colors.TEAL : (kind === 'neuro' ? Colors.PRIMARY : Colors.INDIGO))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ top: 4 })
        }
      }
      .width('100%')
      .padding(this.in() ? { left: 14, right: 14, top: 12, bottom: 12 } : Dimensions.CARD_PADDING_SM)
    }
    .layoutWeight(this.iw() && !this.isPortrait() ? 1 : 0)
    .width('100%')
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .shadow({ radius: 20, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 7 })
    .onClick(() => {
      this.openTraining(kind)
    })
  }

  @Builder schultePreview() {
    Column({ space: 5 }) {
      ForEach([[7, 2, 9], [4, 1, 6], [8, 5, 3]], (row: number[]) => {
        Row({ space: 5 }) {
          ForEach(row, (value: number) => {
            Text(`${value}`)
              .width(38)
              .height(38)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(value === 1 ? Colors.ON_PRIMARY : Colors.TEXT_PRIMARY)
              .textAlign(TextAlign.Center)
              .backgroundColor(value === 1 ? Colors.PRIMARY : '#EFFFFFFF')
              .border({ width: 1, color: value === 1 ? Colors.PRIMARY : Colors.OUTLINE })
              .borderRadius(8)
          })
        }
      })
    }
    .width('100%')
    .height(this.iw() && !this.isPortrait() ? 170 : 138)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .linearGradient({
      angle: 135,
      colors: [[Colors.INFO_CONTAINER, 0.0], ['#E9E8FF', 0.58], ['#FFF8E8', 1.0]]
    })
    .borderRadius({ topLeft: Dimensions.CARD_RADIUS_LG, topRight: Dimensions.CARD_RADIUS_LG })
  }

  @Builder cognitivePreview() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(this.in() ? 92 : 108)
        .height(this.in() ? 92 : 108)
        .borderRadius(54)
        .backgroundColor('#D9FFFFFF')
        .border({ width: 10, color: '#55D6FF' })
      Column()
        .width(this.in() ? 46 : 54)
        .height(this.in() ? 46 : 54)
        .borderRadius(27)
        .backgroundColor(Colors.INDIGO)
      Row()
        .width(this.in() ? 128 : 148)
        .height(10)
        .borderRadius(5)
        .backgroundColor('#A6FFFFFF')
        .rotate({ angle: 32 })
    }
    .width('100%')
    .height(this.iw() && !this.isPortrait() ? 170 : 138)
    .linearGradient({
      angle: 145,
      colors: [['#E8FFF7', 0.0], ['#EAF1FF', 0.52], ['#FFEDE8', 1.0]]
    })
    .borderRadius({ topLeft: Dimensions.CARD_RADIUS_LG, topRight: Dimensions.CARD_RADIUS_LG })
  }

  @Builder placeholderTraining(title: string, description: string, status: string, kind: string) {
    Scroll() {
      Column({ space: this.in() ? 14 : 20 }) {
        Row({ space: 12 }) {
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
          .onClick(() => this.backToTrainingHub())

          Column({ space: 3 }) {
            Text(title)
              .fontSize(this.in() ? 20 : 24)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_PRIMARY)
            Text('训练中心')
              .fontSize(11)
              .fontColor(Colors.TEXT_TERTIARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        Column() {
          if (kind === 'relax') {
            Image($r('app.media.training_relax'))
              .width('100%')
              .height(this.in() ? 210 : 300)
              .objectFit(ImageFit.Cover)
              .borderRadius(Dimensions.CARD_RADIUS_LG)
          } else {
            this.cognitivePreview()
          }
        }
        .width('100%')

        Column({ space: 12 }) {
          Text(status)
            .fontSize(this.in() ? 20 : 24)
            .fontWeight(FontWeight.Bold)
            .fontColor(kind === 'relax' ? Colors.TEAL : Colors.INDIGO)
          Text(description)
            .fontSize(this.in() ? 13 : 15)
            .fontColor(Colors.TEXT_SECONDARY)
            .lineHeight(this.in() ? 21 : 24)
            .textAlign(TextAlign.Center)
          Text('完整训练内容将在后续版本接入。')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding(this.in() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(Colors.GLASS_ACTIVE)
        .backgroundBlurStyle(BlurStyle.Thin)
        .border({ width: 1, color: Colors.GLASS_BORDER })
        .borderRadius(Dimensions.CARD_RADIUS_LG)
      }
      .width('100%')
      .constraintSize({ maxWidth: 820 })
      .padding({
        left: this.in() ? 12 : Dimensions.SCREEN_MARGIN,
        right: this.in() ? 12 : Dimensions.SCREEN_MARGIN,
        top: this.in() ? 12 : Dimensions.SCREEN_MARGIN_SM,
        bottom: 118
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
  }

  @Builder dataSectionDivider(label: string) {
    Row({ space: 10 }) {
      Divider()
        .layoutWeight(1)
        .strokeWidth(1)
        .color(Colors.DIVIDER)
      Text(label)
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
    .padding({ top: 4, bottom: 4 })
  }

  @Builder wideLayout() {
    Row({ space: Dimensions.GUTTER }) {
      Column({ space: 16 }) {
        this.titleBar()
        this.difficultyBar()
        this.gameArea()
      }
      .layoutWeight(55)

      Column({ space: 12 }) {
        this.statusCard()
        this.eegCard()
        this.adviceCard()
      }
      .layoutWeight(45)
    }
    .width('100%')
    .height('100%')
    .padding({ left: Dimensions.SCREEN_MARGIN, right: Dimensions.SCREEN_MARGIN, top: Dimensions.SCREEN_MARGIN, bottom: 140 })
    .alignItems(VerticalAlign.Center)
    .transition(TransitionEffect.OPACITY.animation({ duration: 260, curve: Curve.EaseOut }))
  }

  @Builder titleBar() {
    Row({ space: 12 }) {
      if (!this.useGlobalTopbarBack) {
        Row() {
          Text('<')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(Colors.GLASS_ACTIVE)
        .backgroundBlurStyle(BlurStyle.Thin)
        .border({ width: 1, color: Colors.GLASS_BORDER })
        .borderRadius(Dimensions.PILL_RADIUS)
        .onClick(() => this.backToTrainingHub())
      }

      Text('舒尔特表训练')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT_PRIMARY)

      Blank()

      if (this.gs === 'idle') {
        Button('开始训练')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.ON_PRIMARY)
          .backgroundColor(Colors.PRIMARY)
          .height(36)
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => { this.ssch() })
      } else if (this.gs === 'playing') {
        Button('暂停')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.ON_PRIMARY)
          .backgroundColor(Colors.AMBER)
          .height(36)
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => { this.pg() })
      } else if (this.gs === 'paused') {
        if (this.in()) {
          Text('已暂停')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.AMBER)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(Colors.WARNING_CONTAINER)
            .borderRadius(Dimensions.PILL_RADIUS)
        } else {
          Row({ space: 8 }) {
            Button('继续')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.ON_PRIMARY)
              .backgroundColor(Colors.PRIMARY)
              .height(36)
              .borderRadius(Dimensions.PILL_RADIUS)
              .onClick(() => { this.rg() })
            Button('重新开始')
              .fontSize(12)
              .fontColor(Colors.TEXT_SECONDARY)
              .backgroundColor(Colors.SURFACE_SOFT)
              .height(36)
              .borderRadius(Dimensions.PILL_RADIUS)
              .onClick(() => { this.ssch() })
            Button('结束')
              .fontSize(12)
              .fontColor(Colors.TEXT_SECONDARY)
              .backgroundColor(Colors.SURFACE_SOFT)
              .height(36)
              .borderRadius(Dimensions.PILL_RADIUS)
              .onClick(() => { this.ra() })
          }
        }
      }
    }
    .width('100%')
  }

  @Builder difficultyBar() {
    if (this.cg === 'schulte') {
      Row({ space: 8 }) {
        Text('难度').fontSize(13).fontColor(Colors.TEXT_TERTIARY)
        Text('3×3')
          .fontSize(12)
          .fontColor(this.ss === 3 ? Colors.ON_PRIMARY : Colors.TEXT_SECONDARY)
          .backgroundColor(this.ss === 3 ? Colors.PRIMARY : Colors.SURFACE_SOFT)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => { if (this.gs !== 'playing') { this.ss = 3; this.ra() } })
        Text('4×4')
          .fontSize(12)
          .fontColor(this.ss === 4 ? Colors.ON_PRIMARY : Colors.TEXT_SECONDARY)
          .backgroundColor(this.ss === 4 ? Colors.PRIMARY : Colors.SURFACE_SOFT)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => { if (this.gs !== 'playing') { this.ss = 4; this.ra() } })
        Text('5×5')
          .fontSize(12)
          .fontColor(this.ss === 5 ? Colors.ON_PRIMARY : Colors.TEXT_SECONDARY)
          .backgroundColor(this.ss === 5 ? Colors.PRIMARY : Colors.SURFACE_SOFT)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => { if (this.gs !== 'playing') { this.ss = 5; this.ra() } })
      }
    } else {
      Row({ space: 8 }) {
        Text('难度').fontSize(13).fontColor(Colors.TEXT_TERTIARY)
        Text('简单')
          .fontSize(12)
          .fontColor(this.md === 'easy' ? Colors.ON_PRIMARY : Colors.TEXT_SECONDARY)
          .backgroundColor(this.md === 'easy' ? Colors.PRIMARY : Colors.SURFACE_SOFT)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => { if (this.gs !== 'playing') { this.md = 'easy'; this.ra() } })
        Text('普通')
          .fontSize(12)
          .fontColor(this.md === 'normal' ? Colors.ON_PRIMARY : Colors.TEXT_SECONDARY)
          .backgroundColor(this.md === 'normal' ? Colors.PRIMARY : Colors.SURFACE_SOFT)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => { if (this.gs !== 'playing') { this.md = 'normal'; this.ra() } })
        Text('困难')
          .fontSize(12)
          .fontColor(this.md === 'hard' ? Colors.ON_PRIMARY : Colors.TEXT_SECONDARY)
          .backgroundColor(this.md === 'hard' ? Colors.PRIMARY : Colors.SURFACE_SOFT)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => { if (this.gs !== 'playing') { this.md = 'hard'; this.ra() } })
      }
    }
  }

  @Builder gameArea() {
    Column() {
      if (this.cg === 'schulte') {
        if (this.sn.length === 0) {
          Text('点击上方按钮开始')
            .fontSize(this.in() ? 14 : 16)
            .fontColor(Colors.TEXT_TERTIARY)
            .width('100%')
            .height(this.iw() ? 420 : this.msz())
            .textAlign(TextAlign.Center)
        } else {
          Column({ space: this.in() ? 4 : 6 }) {
            ForEach(this.sr(), (row: number) => {
              Row({ space: this.in() ? 4 : 6 }) {
                ForEach(this.scc(), (col: number) => {
                  Text(`${this.sn[row * this.ss + col]}`)
                    .width(this.csz())
                    .height(this.csz())
                    .fontSize(this.in() ? (this.ss <= 3 ? 22 : (this.ss <= 4 ? 18 : 14)) : (this.ss <= 3 ? 28 : (this.ss <= 4 ? 22 : 18)))
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.sn[row * this.ss + col] < this.st ? Colors.TEXT_TERTIARY : (this.sw === row * this.ss + col ? Colors.ERROR : Colors.TEXT_PRIMARY))
                    .textAlign(TextAlign.Center)
                    .backgroundColor(this.sn[row * this.ss + col] < this.st ? Colors.SURFACE_SOFT : (this.sw === row * this.ss + col ? Colors.ERROR_CONTAINER : Colors.SURFACE_CARD))
                    .borderRadius(this.in() ? 6 : 8)
                    .border({ width: this.sw === row * this.ss + col ? 2 : 1, color: this.sw === row * this.ss + col ? Colors.ERROR : Colors.OUTLINE })
                    .onClick(() => { this.csch(row * this.ss + col) })
                })
              }
            })
          }
        }
      } else {
        if (this.mb.length === 0) {
          Text('点击上方按钮开始')
            .fontSize(this.in() ? 14 : 16)
            .fontColor(Colors.TEXT_TERTIARY)
            .width('100%')
            .height(this.iw() ? 420 : this.msz())
            .textAlign(TextAlign.Center)
        } else {
          Stack() {
            ForEach(this.mb, (box: MemoryBox) => {
              Text(box.state === 'hidden' ? '' : `${box.number}`)
                .width(this.in() ? 32 : 60)
                .height(this.in() ? 32 : 60)
                .fontSize(this.in() ? 16 : 28)
                .fontWeight(FontWeight.Bold)
                .fontColor(box.state === 'wrong' ? Colors.ERROR : (box.state === 'revealed' ? Colors.ON_PRIMARY : Colors.TEXT_PRIMARY))
                .textAlign(TextAlign.Center)
                .backgroundColor(box.state === 'wrong' ? Colors.ERROR_CONTAINER : (box.state === 'revealed' ? Colors.SUCCESS : Colors.SURFACE_CARD))
                .borderRadius(this.in() ? 6 : 10)
                .position({ x: box.x, y: box.y })
                .onClick(() => { this.cm(box) })
            })
          }
          .width('100%')
          .height(this.iw() ? 420 : this.msz())

          if (this.mcd > 0) {
            Text('记忆: ' + (this.mcd / 10).toFixed(1) + 's')
              .fontSize(this.in() ? 12 : 14)
              .fontColor(Colors.AMBER)
              .fontWeight(FontWeight.Bold)
          }

          Row({ space: this.in() ? 10 : 16 }) {
            Text('关卡: ' + this.ml).fontSize(this.in() ? 11 : 13).fontColor(Colors.TEXT_SECONDARY)
            Text('最高: ' + this.mhs).fontSize(this.in() ? 11 : 13).fontColor(Colors.AMBER)
          }
        }
      }
    }
    .width('100%')
    .borderRadius(this.in() ? 10 : 16)
    .border({ width: 1, color: Colors.PRIMARY })
    .padding(this.in() ? 5 : 12)
  }

  @Builder statusCard() {
    Column({ space: this.in() ? 8 : 12 }) {
      Text('训练状态').fontSize(this.in() ? 13 : 15).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY)
      if (this.in()) {
        Column({ space: 8 }) {
          Row() {
            Text(this.cg === 'schulte' ? '目标' : '关卡').fontSize(11).fontColor(Colors.TEXT_TERTIARY)
            Blank()
            Text(this.gs === 'idle' ? '-' : (this.gs === 'done' ? '完成' : (this.cg === 'schulte' ? `${this.st}` : `${this.ml}`)))
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.gs === 'done' ? Colors.SUCCESS : Colors.PRIMARY_DARK)
          }.width('100%')
          Row() {
            Text('用时').fontSize(11).fontColor(Colors.TEXT_TERTIARY)
            Blank()
            Text(this.fmt(this.el)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY)
          }.width('100%')
          Row() {
            Text('错误').fontSize(11).fontColor(Colors.TEXT_TERTIARY)
            Blank()
            Text(`${this.er}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.er > 0 ? Colors.ERROR : Colors.TEXT_PRIMARY)
          }.width('100%')
        }.width('100%')
      } else {
        Row({ space: 16 }) {
          Column({ space: 2 }) {
            Text(this.cg === 'schulte' ? '目标' : '关卡').fontSize(11).fontColor(Colors.TEXT_TERTIARY)
            Text(this.gs === 'idle' ? '-' : (this.gs === 'done' ? '完成' : (this.cg === 'schulte' ? `${this.st}` : `${this.ml}`)))
              .fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.gs === 'done' ? Colors.SUCCESS : Colors.PRIMARY_DARK)
          }.layoutWeight(1).alignItems(HorizontalAlign.Center)
          Column({ space: 2 }) {
            Text('用时').fontSize(11).fontColor(Colors.TEXT_TERTIARY)
            Text(this.fmt(this.el)).fontSize(22).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY)
          }.layoutWeight(1).alignItems(HorizontalAlign.Center)
          Column({ space: 2 }) {
            Text('错误').fontSize(11).fontColor(Colors.TEXT_TERTIARY)
            Text(`${this.er}`).fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.er > 0 ? Colors.ERROR : Colors.TEXT_PRIMARY)
          }.layoutWeight(1).alignItems(HorizontalAlign.Center)
        }.width('100%')
      }
    }
    .layoutWeight(this.in() ? 0 : 1)
    .padding(this.in() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .shadow({ radius: 12, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 4 })
  }

  @Builder eegCard() {
    Column({ space: this.in() ? 8 : 12 }) {
      Text('脑电参数').fontSize(this.in() ? 13 : 15).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY)
      Column({ space: this.in() ? 6 : 10 }) {
        this.metricRow('专注度', this.eeg.focus, Colors.PRIMARY)
        this.metricRow('疲劳度', this.eeg.fatigue, Colors.ORANGE)
        this.metricRow('放松度', this.eeg.relax, Colors.MINT)
        this.metricRow('负荷', this.eeg.load, Colors.INDIGO)
      }.width('100%')
    }
    .layoutWeight(this.in() ? 0 : 1)
    .padding(this.in() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .shadow({ radius: 12, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 4 })
  }

  @Builder metricRow(label: string, value: number, color: string) {
    Column({ space: this.in() ? 2 : 4 }) {
      Row() {
        Text(label).fontSize(this.in() ? 11 : 12).fontColor(Colors.TEXT_SECONDARY)
        Blank()
        Text(`${value}`).fontSize(this.in() ? 11 : 12).fontWeight(FontWeight.Medium).fontColor(Colors.TEXT_PRIMARY)
      }.width('100%')
      Stack({ alignContent: Alignment.Start }) {
        Column().width('100%').height(this.in() ? 4 : 6).backgroundColor(Colors.DIVIDER).borderRadius(3)
        Column().width(`${value}%`).height(this.in() ? 4 : 6).backgroundColor(color).borderRadius(3)
      }.width('100%')
    }
  }

  @Builder adviceCard() {
    Column({ space: this.in() ? 8 : 12 }) {
      Text('状态与建议').fontSize(this.in() ? 13 : 15).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY)
      if (this.in()) {
        Row() {
          Text('当前状态').fontSize(11).fontColor(Colors.TEXT_SECONDARY)
          Blank()
          Text(this.eeg.state).fontSize(12).fontWeight(FontWeight.Medium).fontColor(Colors.PRIMARY_DARK)
        }.width('100%')
        this.metricRow('信号质量', this.eeg.quality, Colors.TEAL)
        this.metricRow('置信度', this.eeg.confidence, Colors.AMBER)
        Divider().strokeWidth(0.5).color(Colors.DIVIDER)
      } else {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text('状态').fontSize(11).fontColor(Colors.TEXT_TERTIARY)
            Text(this.eeg.state).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Colors.PRIMARY_DARK)
          }.layoutWeight(1).alignItems(HorizontalAlign.Center)
          Column({ space: 4 }) {
            Text('质量').fontSize(11).fontColor(Colors.TEXT_TERTIARY)
            Text(`${this.eeg.quality}%`).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Colors.TEAL)
          }.layoutWeight(1).alignItems(HorizontalAlign.Center)
          Column({ space: 4 }) {
            Text('置信度').fontSize(11).fontColor(Colors.TEXT_TERTIARY)
            Text(`${this.eeg.confidence}%`).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Colors.AMBER)
          }.layoutWeight(1).alignItems(HorizontalAlign.Center)
        }.width('100%')
      }
      Text(this.eeg.advice).fontSize(this.in() ? 12 : 13).fontColor(Colors.TEXT_SECONDARY).width('100%')
    }
    .width('100%')
    .padding(this.in() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .shadow({ radius: 12, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 4 })
  }

  @Builder doneOverlay() {
    Column({ space: 12 }) {
      Text('训练完成').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Colors.SUCCESS)
      Row({ space: 24 }) {
        Column({ space: 2 }) {
          Text('用时').fontSize(11).fontColor(Colors.TEXT_TERTIARY)
          Text(this.fmt(this.el)).fontSize(18).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY)
        }.alignItems(HorizontalAlign.Center)
        Column({ space: 2 }) {
          Text('错误').fontSize(11).fontColor(Colors.TEXT_TERTIARY)
          Text(`${this.er}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.er > 0 ? Colors.ERROR : Colors.TEXT_PRIMARY)
        }.alignItems(HorizontalAlign.Center)
      }
      Row({ space: 12 }) {
        Button('结束')
          .fontSize(13)
          .fontColor(Colors.TEXT_SECONDARY)
          .backgroundColor(Colors.SURFACE_SOFT)
          .layoutWeight(1)
          .height(40)
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => { this.ra() })
        Button('再来一轮')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.ON_PRIMARY)
          .backgroundColor(Colors.PRIMARY)
          .layoutWeight(1)
          .height(40)
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => { this.ssch() })
      }.width('100%')
    }
    .width(this.iw() ? 320 : '90%')
    .padding(20)
    .backgroundColor(Colors.SURFACE_CARD)
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .shadow({ radius: 24, color: '#30000000', offsetX: 0, offsetY: 8 })
    .border({ width: 1, color: Colors.GLASS_BORDER })
  }

  @Builder pauseOverlay() {
    Column() {
      Column({ space: 14 }) {
        Text('训练已暂停')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Text('请选择接下来的操作')
          .fontSize(12)
          .fontColor(Colors.TEXT_TERTIARY)

        Button('继续训练')
          .width('100%')
          .height(42)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.ON_PRIMARY)
          .backgroundColor(Colors.PRIMARY)
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => this.rg())
        Button('重新开始')
          .width('100%')
          .height(42)
          .fontColor(Colors.PRIMARY_DARK)
          .backgroundColor(Colors.INFO_CONTAINER)
          .border({ width: 1, color: Colors.OUTLINE })
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => this.ssch())
        Button('结束本轮')
          .width('100%')
          .height(42)
          .fontColor(Colors.TEXT_SECONDARY)
          .backgroundColor(Colors.SURFACE_SOFT)
          .borderRadius(Dimensions.PILL_RADIUS)
          .onClick(() => this.ra())
      }
      .width(this.iw() ? 340 : '86%')
      .constraintSize({ maxWidth: 380 })
      .padding(20)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(Colors.SURFACE_CARD)
      .border({ width: 1, color: Colors.GLASS_BORDER })
      .borderRadius(Dimensions.CARD_RADIUS_LG)
      .shadow({ radius: 28, color: '#38000000', offsetX: 0, offsetY: 10 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#52000000')
    .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
  }
}
