import { Dimensions } from '../constants/Dimensions'
import { Colors } from '../constants/Colors'
import { ToPadProfile } from '../model/ToPadModel'
import { ToPadMock } from '../model/ToPadMock'
import { UserInfoCard } from '../components/UserInfoCard'
import { DeviceInfoCard } from '../components/DeviceInfoCard'
import { PrivacySection } from '../components/PrivacySection'
import { AboutSection } from '../components/AboutSection'

@Component
export struct ProfilePage {
  @State profile: ToPadProfile = ToPadMock.getProfile()
  @State sw: number = 360
  onTestAlert?: () => void = undefined

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: this.isNarrow() ? 8 : Dimensions.STACK_GAP_SM }) {
          UserInfoCard({ profile: this.profile }).width('100%')
          AboutSection({ profile: this.profile }).width('100%')
          DeviceInfoCard({ profile: this.profile }).width('100%')
          PrivacySection({ content: this.profile.privacyText }).width('100%')
        }.width('100%')
        .padding({
          left: this.isNarrow() ? Dimensions.SCREEN_MARGIN_XS : (this.sw > Dimensions.BREAKPOINT_TABLET ? Dimensions.SCREEN_MARGIN : Dimensions.SCREEN_MARGIN_SM),
          right: this.isNarrow() ? Dimensions.SCREEN_MARGIN_XS : (this.sw > Dimensions.BREAKPOINT_TABLET ? Dimensions.SCREEN_MARGIN : Dimensions.SCREEN_MARGIN_SM),
          top: this.onTestAlert ? 90 : (this.isNarrow() ? Dimensions.SCREEN_MARGIN_SM : Dimensions.SCREEN_MARGIN),
          bottom: 118
        })
      }.width('100%').height('100%')
     .scrollBar(BarState.Off)
     .edgeEffect(EdgeEffect.None)

     if (this.onTestAlert) {
        Button('测试警报')
          .fontSize(11).fontColor(Colors.ERROR).backgroundColor(Colors.ERROR_CONTAINER)
          .height(32).borderRadius(Dimensions.PILL_RADIUS)
          .position({ x: 16, y: 50 })
          .onClick(() => { this.onTestAlert!() })
      }
    }.width('100%').height('100%')
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      if (w > 0) this.sw = w
    })
  }
}


