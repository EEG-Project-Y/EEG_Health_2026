import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'

@Component
export struct AiSuggestionPanel {
  @Prop advice: string = ''
  @State sw: number = 360

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
  }

  build() {
      Text('AI 建议').fontSize(this.isNarrow() ? 14 : 17).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY)
      Text('AI 寤鸿').fontSize(this.isNarrow() ? 14 : 17).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY)
      Text(this.advice).fontSize(this.isNarrow() ? 12 : 14).fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_PRIMARY).lineHeight(this.isNarrow() ? 16 : 22)
        .margin({ top: this.isNarrow() ? 6 : 10 })
        .maxLines(this.isNarrow() ? 2 : 4).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text('基于边缘端处理后的 ToPad 状态结果').fontSize(this.isNarrow() ? 10 : 11).fontColor(Colors.TEXT_TERTIARY)
        .margin({ top: this.isNarrow() ? 6 : 10 })
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE).backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER }).borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: Dimensions.ELEVATION_BLUR, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: Dimensions.ELEVATION_OFFSET })
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      if (w > 0) this.sw = w
    })
  }
}
