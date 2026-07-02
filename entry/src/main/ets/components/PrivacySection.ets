import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'

@Component
export struct PrivacySection {
  @Prop content: string = ''
  @State sw: number = 360

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
  }

  build() {
    Column() {
      Text('隐私说明').fontSize(this.isNarrow() ? 16 : 20).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY).margin({ bottom: this.isNarrow() ? 8 : 14 })
      Text(this.content).fontSize(this.isNarrow() ? 13 : 16).fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_SECONDARY).lineHeight(this.isNarrow() ? 18 : 24)
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.INFO_CONTAINER).backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: '#D7EFFF' }).borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: Dimensions.ELEVATION_BLUR, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: Dimensions.ELEVATION_OFFSET })
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      if (w > 0) this.sw = w
    })
  }
}