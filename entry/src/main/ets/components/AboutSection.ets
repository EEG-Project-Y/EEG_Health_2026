import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'
import { ToPadProfile } from '../model/ToPadModel'

@Component
export struct AboutSection {
  @Prop profile: ToPadProfile = { userName: '', currentMode: '', mainDevice: '', terminal: '', communication: '', privacyText: '', appName: '', version: '' }
  @State sw: number = 360

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
  }

  build() {
    Column() {
      Text('关于系统').fontSize(this.isNarrow() ? 16 : 20).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY).margin({ bottom: this.isNarrow() ? 8 : 16 })
      Text(this.profile.appName).fontSize(this.isNarrow() ? 18 : 24).fontWeight(FontWeight.Bold).fontColor(Colors.PRIMARY_DARK)
      Text(this.profile.version).fontSize(this.isNarrow() ? 13 : 16).fontWeight(FontWeight.Medium).fontColor(Colors.TEXT_SECONDARY).margin({ top: this.isNarrow() ? 6 : 12 })
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