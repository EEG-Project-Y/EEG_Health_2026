import { Dimensions } from '../constants/Dimensions'
import { Colors } from '../constants/Colors'
import { ToPadFrame } from '../model/ToPadModel'
import { ToPadMock } from '../model/ToPadMock'
import { display } from '@kit.ArkUI'

@Component
export struct FocusPage {
  @State timerState: string = 'idle'
  @State isWork: boolean = true
  @State remaining: number = 25 * 60
  @State workMin: number = 25
  @State restMin: number = 5
  @State showSettings: boolean = false
  @State cycles: number = 0
  @State eeg: ToPadFrame = ToPadMock.getCurrent()
  @State screenWidth: number = 360
  @State screenHeight: number = 1000
  private timer: number = -1

  aboutToAppear(): void { }

  aboutToDisappear(): void {
    this.clearTimer()
  }

  private isNarrow(): boolean {
    return this.screenWidth < Dimensions.BREAKPOINT_TABLET && !this.isLandscape()
  }

  private isLandscape(): boolean {
    return this.screenWidth > this.screenHeight
  }

  private clearTimer(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer)
      this.timer = -1
    }
  }

  private startTimer(): void {
    if (this.timerState === 'playing') return
    this.timerState = 'playing'
    this.timer = setInterval(() => {
      if (this.remaining > 0) {
        this.remaining--
      } else {
        this.clearTimer()
        this.vibrate()
        if (this.isWork) {
          this.cycles++
          this.isWork = false
          this.remaining = this.restMin * 60
        } else {
          this.isWork = true
          this.remaining = this.workMin * 60
        }
      }
    }, 1000)
  }

  private pauseTimer(): void {
    this.clearTimer()
    this.timerState = 'paused'
  }

  private resetTimer(): void {
    this.clearTimer()
    this.timerState = 'idle'
    this.isWork = true
    this.remaining = this.workMin * 60
  }

  private vibrate(): void {
    try {
      import('@ohos.vibrator').then((vibrator: ESObject) => {
        vibrator.vibrate({
          type: 'time',
          duration: 300
        })
      }).catch(() => { })
    } catch (e) { }
  }

  private formatTime(sec: number): string {
    const m = Math.floor(sec / 60)
    const s = sec % 60
    return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s
  }

  private progress(): number {
    const total = this.isWork ? this.workMin * 60 : this.restMin * 60
    return ((total - this.remaining) / total) * 100
  }

  build() {
    Column() {
      if (this.isLandscape()) {
        this.landscapeLayout()
      } else {
        this.portraitLayout()
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      const h = typeof newArea.height === 'string' ? parseFloat(newArea.height as string) : (newArea.height as number)
      if (w > 0) this.screenWidth = w
      if (h > 0) this.screenHeight = h
    })
  }

  @Builder
  portraitLayout() {
    Scroll() {
      Column({ space: this.isNarrow() ? 8 : 12 }) {
        this.timerSection()

        Row() {
          Text('时长设置')
            .fontSize(this.isNarrow() ? 13 : 15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
          Blank()
          Text(this.workMin + '分钟工作 / ' + this.restMin + '分钟休息')
            .fontSize(this.isNarrow() ? 11 : 12)
            .fontColor(Colors.TEXT_TERTIARY)
          Text(this.showSettings ? '▲' : '▼')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ left: 6 })
        }
        .width('100%')
        .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
        .backgroundColor(Colors.GLASS_ACTIVE)
        .backgroundBlurStyle(BlurStyle.Thin)
        .border({ width: 1, color: Colors.GLASS_BORDER })
        .borderRadius(Dimensions.CARD_RADIUS_XL)
        .shadow({ radius: 12, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 4 })
        .onClick(() => { this.showSettings = !this.showSettings })

        if (this.showSettings) {
          this.settingsSection()
        }

        this.eegSection()
      }
      .width('100%')
      .padding({
        left: this.isNarrow() ? 8 : (this.screenWidth > Dimensions.BREAKPOINT_TABLET ? Dimensions.SCREEN_MARGIN : Dimensions.SCREEN_MARGIN_SM),
        right: this.isNarrow() ? 8 : (this.screenWidth > Dimensions.BREAKPOINT_TABLET ? Dimensions.SCREEN_MARGIN : Dimensions.SCREEN_MARGIN_SM),
        top: this.isNarrow() ? 8 : Dimensions.SCREEN_MARGIN_SM,
        bottom: 118
      })
    }
    .width('100%')
    .height('100%')
   .scrollBar(BarState.Off)
   .edgeEffect(EdgeEffect.None)
 }

 @Builder
  landscapeLayout() {
    Row() {
     Scroll() {
       Column({ space: 10 }) {
         this.timerSection()
         if (this.showSettings) {
           this.settingsSection()
         }
       }
       .width('100%')
       .padding({ left: 16, right: 8, top: 12, bottom: 112 })
     }
     .layoutWeight(55)
     .height('100%')
     .scrollBar(BarState.Off)
     .edgeEffect(EdgeEffect.None)

     Scroll() {
        Column({ space: 10 }) {
          Row() {
            Text('时长设置')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            Text(this.workMin + '/' + this.restMin + '分')
              .fontSize(11)
              .fontColor(Colors.TEXT_TERTIARY)
            Text(this.showSettings ? '▲' : '▼')
              .fontSize(11)
              .fontColor(Colors.TEXT_TERTIARY)
              .margin({ left: 4 })
          }
          .width('100%')
          .padding(Dimensions.CARD_PADDING_SM)
          .backgroundColor(Colors.GLASS_ACTIVE)
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: Colors.GLASS_BORDER })
          .borderRadius(Dimensions.CARD_RADIUS_LG)
          .onClick(() => { this.showSettings = !this.showSettings })

          this.eegSection()
        }
        .width('100%')
        .padding({ left: 8, right: 16, top: 12, bottom: 112 })
      }
      .layoutWeight(45)
      .height('100%')
      .scrollBar(BarState.Off)
       .edgeEffect(EdgeEffect.None)
     }
     .width('100%')
     .height('100%')
   }

   @Builder
   timerSection() {
    Column({ space: 16 }) {
      Row() {
        Text(this.isWork ? '专注时间' : '休息时间')
          .fontSize(this.isNarrow() ? 18 : 22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
        Text('已完成' + this.cycles + ' 轮')
          .fontSize(this.isNarrow() ? 12 : 14)
          .fontColor(Colors.TEXT_TERTIARY)
      }.width('100%')

      if (this.isNarrow()) {
        Column({ space: 8 }) {
          Text(this.formatTime(this.remaining))
            .fontSize(42)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isWork ? Colors.PRIMARY_DARK : Colors.TEAL)
          Text(this.isWork ? '保持专注' : '放松一下')
            .fontSize(12)
            .fontColor(Colors.TEXT_SECONDARY)
          Progress({ value: this.progress(), total: 100, type: ProgressType.Linear })
            .width('100%')
            .height(8)
            .color(this.isWork ? Colors.PRIMARY : Colors.MINT)
            .backgroundColor(Colors.DIVIDER)
            .borderRadius(4)
        }
        .width('100%')
        .height(132)
        .padding({ left: 22, right: 22, top: 18, bottom: 18 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(Colors.SURFACE_SOFT)
        .border({ width: 1, color: Colors.OUTLINE })
        .borderRadius(32)
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Progress({ value: this.progress(), total: 100, type: ProgressType.Ring })
            .width(this.isLandscape() ? 200 : 240)
            .height(this.isLandscape() ? 200 : 240)
            .color(this.isWork ? Colors.PRIMARY : Colors.MINT)
            .backgroundColor(Colors.DIVIDER)

          Column({ space: 4 }) {
            Text(this.formatTime(this.remaining))
              .fontSize(this.isLandscape() ? 44 : 52)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isWork ? Colors.PRIMARY_DARK : Colors.TEAL)

            Text(this.isWork ? '保持专注' : '放松一下')
              .fontSize(14)
              .fontColor(Colors.TEXT_SECONDARY)
          }
        }
      }

      Row({ space: 10 }) {
        if (this.timerState === 'idle' || this.timerState === 'paused') {
          Button(this.timerState === 'idle' ? '开始' : '继续')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.ON_PRIMARY)
            .backgroundColor(Colors.PRIMARY)
            .height(40)
            .borderRadius(Dimensions.PILL_RADIUS)
            .layoutWeight(1)
            .onClick(() => this.startTimer())
        } else {
          Button('暂停')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.ON_PRIMARY)
            .backgroundColor(Colors.AMBER)
            .height(40)
            .borderRadius(Dimensions.PILL_RADIUS)
            .layoutWeight(1)
            .onClick(() => this.pauseTimer())
        }
        Button('重置')
          .fontSize(14)
          .fontColor(Colors.TEXT_SECONDARY)
          .backgroundColor(Colors.SURFACE_SOFT)
          .height(40)
          .borderRadius(Dimensions.PILL_RADIUS)
          .layoutWeight(1)
          .onClick(() => this.resetTimer())
      }.width('100%')
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: 12, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 4 })
  }

  @Builder
  settingsSection() {
    Column({ space: 10 }) {
      Row() {
        Text('工作时长').fontSize(13).fontColor(Colors.TEXT_SECONDARY)
        Blank()
        Row({ space: 8 }) {
          Text('-')
            .fontSize(16).fontColor(Colors.PRIMARY).fontWeight(FontWeight.Bold)
            .width(28).height(28).textAlign(TextAlign.Center)
            .backgroundColor(Colors.SURFACE_SOFT).borderRadius(6)
            .onClick(() => { if (this.workMin > 5 && this.timerState === 'idle') { this.workMin -= 5; this.remaining = this.workMin * 60 } })
          Text(this.workMin + '分')
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY)
            .width(44).textAlign(TextAlign.Center)
          Text('+')
            .fontSize(16).fontColor(Colors.PRIMARY).fontWeight(FontWeight.Bold)
            .width(28).height(28).textAlign(TextAlign.Center)
            .backgroundColor(Colors.SURFACE_SOFT).borderRadius(6)
            .onClick(() => { if (this.workMin < 60 && this.timerState === 'idle') { this.workMin += 5; this.remaining = this.workMin * 60 } })
        }
      }.width('100%')
      Row() {
        Text('休息时长').fontSize(13).fontColor(Colors.TEXT_SECONDARY)
        Blank()
        Row({ space: 8 }) {
          Text('-')
            .fontSize(16).fontColor(Colors.PRIMARY).fontWeight(FontWeight.Bold)
            .width(28).height(28).textAlign(TextAlign.Center)
            .backgroundColor(Colors.SURFACE_SOFT).borderRadius(6)
            .onClick(() => { if (this.restMin > 1 && this.timerState === 'idle') this.restMin -= 1 })
          Text(this.restMin + '分')
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY)
            .width(44).textAlign(TextAlign.Center)
          Text('+')
            .fontSize(16).fontColor(Colors.PRIMARY).fontWeight(FontWeight.Bold)
            .width(28).height(28).textAlign(TextAlign.Center)
            .backgroundColor(Colors.SURFACE_SOFT).borderRadius(6)
            .onClick(() => { if (this.restMin < 30 && this.timerState === 'idle') this.restMin += 1 })
        }
      }.width('100%')
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: 12, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 4 })
  }

  @Builder
  eegSection() {
    Column({ space: 8 }) {
      Row() {
        Text('脑电参数')
          .fontSize(this.isNarrow() ? 13 : 15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
        Text(`Sequence ${this.eeg.sequence}`)
          .fontSize(this.isNarrow() ? 10 : 11)
          .fontColor(Colors.TEXT_TERTIARY)
      }.width('100%')

      if (this.isNarrow()) {
        Column({ space: 4 }) {
          Row({ space: 4 }) {
            this.eegTile('专注', this.eeg.focus, Colors.PRIMARY)
            this.eegTile('疲劳', this.eeg.fatigue, Colors.ORANGE)
            this.eegTile('放松', this.eeg.relax, Colors.MINT)
          }.width('100%')
          Row({ space: 4 }) {
            this.eegTile('负荷', this.eeg.load, Colors.INDIGO)
            this.eegTile('质量', this.eeg.quality, Colors.TEAL)
            this.eegTile('置信', this.eeg.confidence, Colors.AMBER)
          }.width('100%')
        }.width('100%')
      } else {
        Column({ space: 6 }) {
          this.eegBar('专注度', this.eeg.focus, Colors.PRIMARY)
          this.eegBar('疲劳度', this.eeg.fatigue, Colors.ORANGE)
          this.eegBar('放松度', this.eeg.relax, Colors.MINT)
          this.eegBar('负荷', this.eeg.load, Colors.INDIGO)
        }.width('100%')
      }

      Text(this.eeg.advice)
        .fontSize(this.isNarrow() ? 11 : 12)
        .fontColor(Colors.TEXT_SECONDARY)
        .width('100%')
        .padding({ top: 8 })
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: 12, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 4 })
  }

  @Builder
  eegTile(label: string, value: number, color: string) {
    Column() {
      Text(label).fontSize(10).fontColor(Colors.TEXT_SECONDARY)
      Text(value + '%').fontSize(15).fontWeight(FontWeight.Bold).fontColor(color)
    }
    .layoutWeight(1)
    .padding(6)
    .backgroundColor(Colors.SURFACE_CARD)
    .borderRadius(6)
    .border({ width: 0.5, color: Colors.OUTLINE })
  }

  @Builder
  eegBar(label: string, value: number, color: string) {
    Column({ space: 4 }) {
      Row() {
        Text(label).fontSize(12).fontColor(Colors.TEXT_SECONDARY)
        Blank()
        Text(value + '%').fontSize(12).fontWeight(FontWeight.Medium).fontColor(Colors.TEXT_PRIMARY)
      }.width('100%')
      Stack({ alignContent: Alignment.Start }) {
        Column().width('100%').height(6).backgroundColor(Colors.DIVIDER).borderRadius(3)
        Column().width(value + '%').height(6).backgroundColor(color).borderRadius(3)
      }.width('100%')
    }
  }
}

