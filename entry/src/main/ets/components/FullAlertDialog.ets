import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'

@Component
export struct FullAlertDialog {
  @Prop title: string = '警告'
  @Prop message: string = ''
  @Prop detail: string = ''
  @Prop fatigueValue: number = 0
  @Prop focusValue: number = 0
  @Prop qualityValue: number = 0
  onDismiss: () => void = () => {}
  @State sw: number = 360

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: this.isNarrow() ? 8 : 16 }) {
          Text('⚠️').fontSize(this.isNarrow() ? 40 : 64)
          Text(this.title).fontSize(this.isNarrow() ? 26 : 42).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').textAlign(TextAlign.Center)
          Text(this.message).fontSize(this.isNarrow() ? 14 : 22).fontWeight(FontWeight.Medium).fontColor('#FFE0E0').textAlign(TextAlign.Center)
          Text(this.detail).fontSize(this.isNarrow() ? 12 : 16).fontColor('#FFC0C0').textAlign(TextAlign.Center)

          Row({ space: this.isNarrow() ? 12 : 24 }) {
            Column({ space: 2 }) { Text('疲劳度').fontSize(this.isNarrow() ? 10 : 13).fontColor('#FFD0D0'); Text(`${this.fatigueValue}`).fontSize(this.isNarrow() ? 18 : 28).fontWeight(FontWeight.Bold).fontColor('#FFFFFF') }.alignItems(HorizontalAlign.Center)
            Column({ space: 2 }) { Text('专注度').fontSize(this.isNarrow() ? 10 : 13).fontColor('#FFD0D0'); Text(`${this.focusValue}`).fontSize(this.isNarrow() ? 18 : 28).fontWeight(FontWeight.Bold).fontColor('#FFFFFF') }.alignItems(HorizontalAlign.Center)
            Column({ space: 2 }) { Text('信号质量').fontSize(this.isNarrow() ? 10 : 13).fontColor('#FFD0D0'); Text(`${this.qualityValue}`).fontSize(this.isNarrow() ? 18 : 28).fontWeight(FontWeight.Bold).fontColor('#FFFFFF') }.alignItems(HorizontalAlign.Center)
          }.justifyContent(FlexAlign.Center).width('100%')

          Button('我知道了').fontSize(this.isNarrow() ? 14 : 18).fontWeight(FontWeight.Bold).fontColor(Colors.PRIMARY_DARK)
            .backgroundColor('#E6FFFFFF').height(this.isNarrow() ? 44 : 56).width('70%')
            .constraintSize({ maxWidth: 320 }).borderRadius(Dimensions.PILL_RADIUS)
            .shadow({ radius: 24, color: '#40000000', offsetX: 0, offsetY: 4 })
            .onClick(() => { this.onDismiss() })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: this.isNarrow() ? 20 : 40, bottom: this.isNarrow() ? 20 : 40 })
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [['#CC0000', 0.0], ['#8B0000', 1.0]] })
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      if (w > 0) this.sw = w
    })
  }
}
