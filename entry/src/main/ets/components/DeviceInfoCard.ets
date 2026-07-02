import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'
import { ToPadProfile } from '../model/ToPadModel'

@Component
export struct DeviceInfoCard {
  @Prop profile: ToPadProfile = { userName: '', currentMode: '', mainDevice: '', terminal: '', communication: '', privacyText: '', appName: '', version: '' }
  @State sw: number = 360

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(this.isNarrow() ? 13 : 15).fontColor(Colors.TEXT_TERTIARY)
      Blank()
      Text(value).fontSize(this.isNarrow() ? 14 : 16).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY)
    }.width('100%').padding({ top: this.isNarrow() ? 6 : 10, bottom: this.isNarrow() ? 6 : 10 })
  }

  build() {
    Column() {
      Text('设备信息').fontSize(this.isNarrow() ? 16 : 20).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY).margin({ bottom: this.isNarrow() ? 4 : 8 })
      this.InfoRow('主设备', this.profile.mainDevice)
      Divider().color(Colors.DIVIDER)
      this.InfoRow('协同终端', this.profile.terminal)
      Divider().color(Colors.DIVIDER)
      this.InfoRow('通信方式', this.profile.communication)
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
