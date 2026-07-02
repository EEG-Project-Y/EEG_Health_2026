import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'

@Component
export struct MetricGauge {
  @Prop nameCn: string = ''
  @Prop nameEn: string = ''
  @Prop value: number = 0
  @Prop accent: string = Colors.PRIMARY
  @Prop featured: boolean = false
  @State sw: number = 360

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.nameCn).fontSize(this.isNarrow() ? 12 : (this.featured ? 16 : 14)).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY)
          Text(this.nameEn).fontSize(this.isNarrow() ? 10 : 11).fontColor(Colors.TEXT_TERTIARY).margin({ top: 2 })
        }.alignItems(HorizontalAlign.Start)
        Blank()
        Text(`${this.value}%`).fontSize(this.isNarrow() ? 18 : (this.featured ? 30 : 24))
          .fontWeight(FontWeight.Bold).fontColor(this.featured ? Colors.ERROR : Colors.TEXT_PRIMARY)
      }.width('100%').alignItems(VerticalAlign.Top)
      Progress({ value: this.value, total: 100, type: ProgressType.Linear })
        .width('100%').height(this.isNarrow() ? 4 : (this.featured ? 8 : 6))
        .color(this.accent).backgroundColor(Colors.DIVIDER).margin({ top: this.isNarrow() ? 6 : 12 })
    }
    .width('100%')
    .padding(this.isNarrow() ? 8 : (this.featured ? 18 : 16))
    .backgroundColor(this.featured ? Colors.ERROR_CONTAINER : Colors.SURFACE_CARD)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: this.featured ? '#FFD0C7' : Colors.OUTLINE })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      if (w > 0) this.sw = w
    })
  }
}