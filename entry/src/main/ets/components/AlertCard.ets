import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'
import { ToPadFrame } from '../model/ToPadModel'

@Component
export struct AlertCard {
  @Prop data: ToPadFrame = {
    sequence: 0, focus: 0, fatigue: 0, relax: 0, load: 0,
    quality: 0, confidence: 0, state: '', direction: '', advice: '', alert: false
  }
  @Prop confirmed: boolean = false
  onConfirm: () => void = () => {}
  @State sw: number = 360

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
  }

  private isFatigueAlert(): boolean {
    return this.data.alert || this.data.fatigue >= 75
  }

    if (this.isFatigueAlert()) return '疲劳预警'
    if (this.data.fatigue >= 50) return '注意休息'
    return '正常'
    return '姝ｅ父'
  }

    if (this.confirmed && this.isFatigueAlert()) return '提醒已确认，建议稍后复测疲劳状态。'
    if (this.isFatigueAlert()) return '检测到疲劳风险，请休息 5 分钟'
    if (this.data.fatigue >= 50) return '疲劳指标略有上升，建议调整节奏并留意休息。'
    return '当前脑电状态平稳，保持专注并按计划定时休息。'
    return '当前脑电状态平稳，保持专注并按计划定时休息。'
  }

  private accentColor(): string {
    if (this.isFatigueAlert()) return Colors.ERROR
    if (this.data.fatigue >= 50) return Colors.WARNING
    return Colors.SUCCESS
  }

  private containerColor(): string {
    if (this.isFatigueAlert()) return Colors.ERROR_CONTAINER
    if (this.data.fatigue >= 50) return Colors.WARNING_CONTAINER
    return Colors.SUCCESS_CONTAINER
  }

  build() {
    Column() {
      Row() {
          Text('当前状态').fontSize(this.isNarrow() ? 13 : 15).fontColor(Colors.TEXT_TERTIARY)
          Text('当前状态').fontSize(this.isNarrow() ? 13 : 15).fontColor(Colors.TEXT_TERTIARY)
          Text(this.statusText()).fontSize(this.isNarrow() ? 18 : 26).fontWeight(FontWeight.Bold).fontColor(this.accentColor()).margin({ top: this.isNarrow() ? 4 : 6 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column() {
          Text(`${this.data.fatigue}%`).fontSize(this.isNarrow() ? 24 : 36).fontWeight(FontWeight.Bold).fontColor(this.accentColor())
          Text('Fatigue').fontSize(this.isNarrow() ? 10 : 12).fontColor(Colors.TEXT_TERTIARY).margin({ top: 2 })
        }.width(this.isNarrow() ? 70 : 100).alignItems(HorizontalAlign.End)
      }.width('100%')
      Text(this.messageText())
        .fontSize(this.isNarrow() ? 12 : (this.isFatigueAlert() ? 16 : 14))
        .fontWeight(this.isFatigueAlert() ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(Colors.TEXT_PRIMARY).lineHeight(this.isNarrow() ? 16 : 22)
        .margin({ top: this.isNarrow() ? 8 : 14 })
      Button(this.confirmed ? '已确认' : '确认提醒')
      Button(this.confirmed ? '已确认' : '确认提醒')
        .fontSize(this.isNarrow() ? 12 : 14).fontWeight(FontWeight.Bold)
        .fontColor(this.isFatigueAlert() ? Colors.ON_PRIMARY : Colors.TEXT_TERTIARY)
        .backgroundColor(this.isFatigueAlert() ? this.accentColor() : Colors.SURFACE_SOFT)
        .borderRadius(Dimensions.PILL_RADIUS)
        .height(this.isNarrow() ? 32 : 40).width(this.isNarrow() ? 90 : 110)
        .enabled(this.isFatigueAlert() && !this.confirmed)
        .margin({ top: this.isNarrow() ? 8 : 14 })
        .onClick(() => this.onConfirm())
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(this.containerColor())
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: this.isFatigueAlert() ? '#FFC8C2' : '#D7F4E5' })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: Dimensions.ELEVATION_BLUR, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: Dimensions.ELEVATION_OFFSET })
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      if (w > 0) this.sw = w
    })
  }
}
