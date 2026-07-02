import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'
import { HomePage } from './HomePage'
import { FocusPage } from './FocusPage'
import { TrainPage } from './TrainPage'
import { ProfilePage } from './ProfilePage'
import { AiChatPage } from './AiChatPage'
import { FullAlertDialog } from '../components/FullAlertDialog'
import { ToPadFrame } from '../model/ToPadModel'
import { ToPadMock } from '../model/ToPadMock'

interface AlertThresholds {
  fatigueHigh: number
  focusLow: number
  qualityLow: number
  confidenceLow: number
}

const ALERT_THRESHOLDS: AlertThresholds = {
  fatigueHigh: 80,
  focusLow: 30,
  qualityLow: 40,
  confidenceLow: 40
}
const ALERT_COOLDOWN_MS: number = 60000

@Entry
@Component
struct Index {
  @StorageProp('safeAreaTop') safeAreaTop: number = 0
  @State currentIndex: number = 0
  @State screenWidth: number = 360
  @State screenHeight: number = 800
  @State navLayout: string = 'topbar'
  @State topbarBackVisible: boolean = false
  @State isAlertVisible: boolean = false
  @State alertTitle: string = ''
  @State alertMessage: string = ''
  @State alertDetail: string = ''
  @State alertFatigue: number = 0
  @State alertFocus: number = 0
  @State alertQuality: number = 0
  @State lastAlertTime: number = 0
  @State lastAlertSequence: number = -1
  @State eegData: ToPadFrame = ToPadMock.getCurrent()
  private checkTimer: number = -1
  private topbarBackAction: () => void = () => {}

  aboutToAppear(): void {
    this.checkTimer = setInterval(() => {
      this.checkAlert()
    }, 2000)
  }

  aboutToDisappear(): void {
    if (this.checkTimer >= 0) {
      clearInterval(this.checkTimer)
      this.checkTimer = -1
    }
  }

  private checkAlert(): void {
    const data: ToPadFrame = this.eegData
    if (this.isAlertVisible) return
    if (data.sequence === this.lastAlertSequence) return
    const now = Date.now()
    if (now - this.lastAlertTime < ALERT_COOLDOWN_MS) return

    if (data.fatigue >= ALERT_THRESHOLDS.fatigueHigh) {
      this.showAlert('警告', '检测到疲劳风险过高', '当前疲劳度已超过安全阈值，建议立即停止训练并休息。', data)
      return
    }
    if (data.focus <= ALERT_THRESHOLDS.focusLow) {
      this.showAlert('注意', '专注度过低', '当前专注度低于安全阈值，建议调整状态。', data)
      return
    }
    if (data.quality <= ALERT_THRESHOLDS.qualityLow) {
      this.showAlert('提示', '信号质量较差', '当前信号质量较低，数据可能不准确。', data)
      return
    }
    if (data.confidence <= ALERT_THRESHOLDS.confidenceLow) {
      this.showAlert('提示', '数据置信度过低', '当前数据置信度较低，请检查设备佩戴。', data)
    }
  }

  private showAlert(title: string, message: string, detail: string, data: ToPadFrame): void {
    this.alertTitle = title
    this.alertMessage = message
    this.alertDetail = detail
    this.alertFatigue = data.fatigue
    this.alertFocus = data.focus
    this.alertQuality = data.quality
    this.isAlertVisible = true
    this.vibrate()
  }

  private dismissAlert(): void {
    this.lastAlertTime = Date.now()
    this.lastAlertSequence = this.eegData.sequence
    this.isAlertVisible = false
  }

  private testAlert(): void {
    this.vibrate()
    this.eegData = {
      sequence: 999,
      focus: 15,
      fatigue: 85,
      relax: 30,
      load: 90,
      quality: 50,
      confidence: 60,
      state: '高疲劳',
      direction: 'up',
      advice: '请立即休息',
      alert: true
    }
    this.lastAlertSequence = -1
    this.lastAlertTime = 0
    this.checkAlert()
  }

  private vibrate(): void {
    try {
      import('@ohos.vibrator').then((vibrator: ESObject) => {
        vibrator.vibrate({
          type: 'time',
          duration: 500
        })
      }).catch(() => {})
    } catch (e) {}
  }

  private openBluetoothSettings(): void {
    console.log('Opening Bluetooth settings...')
  }

  private usesTabletNavigation(): boolean {
    return this.screenWidth >= Dimensions.BREAKPOINT_TABLET
  }

  private topNavigationWidth(): number {
    return Math.min(760, Math.max(0, this.screenWidth - 32))
  }

  private sidebarNavigationWidth(): number {
    return this.screenWidth < 900 ? 140 : 196
  }

  private sidebarNavigationHeight(): number {
    return Math.max(320, this.screenHeight - this.safeAreaTop - 32)
  }

  private contentTopPadding(): number {
    if (!this.usesTabletNavigation()) return this.safeAreaTop
    return this.navLayout === 'topbar' ? this.safeAreaTop + 76 : this.safeAreaTop
  }

  private contentLeftPadding(): number {
    if (!this.usesTabletNavigation() || this.navLayout !== 'sidebar') return 0
    return this.sidebarNavigationWidth() + 28
  }

  private selectMainIndex(index: number): void {
    this.currentIndex = index
    if (index !== 2) {
      this.topbarBackVisible = false
      this.topbarBackAction = () => {}
    }
  }

  private updateTopbarBack(visible: boolean, action: () => void): void {
    this.topbarBackVisible = visible
    this.topbarBackAction = visible ? action : () => {}
  }

  @Builder
  NavItem(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(this.screenWidth > Dimensions.BREAKPOINT_TABLET ? 16 : (this.screenWidth < Dimensions.BREAKPOINT_PHONE ? 12 : 14))
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentIndex === index ? Colors.PRIMARY_DARK : Colors.TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .height(this.screenWidth > Dimensions.BREAKPOINT_TABLET ? 48 : (this.screenWidth < Dimensions.BREAKPOINT_PHONE ? 36 : 44))
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#00FFFFFF')
    .borderRadius(Dimensions.PILL_RADIUS)
    .opacity(this.currentIndex === index ? 1.0 : 0.7)
    .animation({ duration: 200, curve: Curve.EaseOut })
    .shadow(this.currentIndex === index ? {
      radius: 16,
      color: '#30075AB8',
      offsetX: 0,
      offsetY: 0
    } : {
      radius: 0,
      color: '#00000000',
      offsetX: 0,
      offsetY: 0
    })
    .onClick(() => {
      this.selectMainIndex(index)
    })
  }

  @Builder
  NavItemActive(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(this.screenWidth > Dimensions.BREAKPOINT_TABLET ? 16 : (this.screenWidth < Dimensions.BREAKPOINT_PHONE ? 12 : 14))
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.PRIMARY_DARK)
    }
    .layoutWeight(1)
    .height(this.screenWidth > Dimensions.BREAKPOINT_TABLET ? 48 : (this.screenWidth < Dimensions.BREAKPOINT_PHONE ? 36 : 44))
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#26EAF6FF')
    .backdropBlur(40)
    .backgroundBlurStyle(BlurStyle.Regular)
    .borderRadius(Dimensions.PILL_RADIUS)
    .opacity(1.0)
    .animation({ duration: 200, curve: Curve.EaseOut })
    .shadow({
      radius: 16,
      color: '#30075AB8',
      offsetX: 0,
      offsetY: 0
    })
    .onClick(() => {
      this.selectMainIndex(index)
    })
  }

  @Builder
  TabletTopNavItem(title: string, index: number) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.currentIndex === index ? Colors.PRIMARY_DARK : Colors.TEXT_SECONDARY)
    }
    .layoutWeight(1)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.currentIndex === index ? '#26EAF6FF' : '#00FFFFFF')
    .backdropBlur(this.currentIndex === index ? 40 : 0)
    .backgroundBlurStyle(BlurStyle.Regular)
    .border({
      width: 1,
      color: this.currentIndex === index ? '#70FFFFFF' : '#00FFFFFF'
    })
    .borderRadius(Dimensions.PILL_RADIUS)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .shadow(this.currentIndex === index ? {
      radius: 16,
      color: '#30075AB8',
      offsetX: 0,
      offsetY: 0
    } : {
      radius: 0,
      color: '#00000000',
      offsetX: 0,
      offsetY: 0
    })
    .onClick(() => {
      this.selectMainIndex(index)
    })
  }

  @Builder
  TabletTopSafeAreaGlass() {
    Column() {
      Blank()
      Divider()
        .strokeWidth(1)
        .color('#4DFFFFFF')
    }
    .width('100%')
    .height(this.safeAreaTop + 76)
    .backgroundColor('#72EAF6FF')
    .backdropBlur(56)
    .backgroundBlurStyle(BlurStyle.Thin)
    .position({ x: 0, y: 0 })
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.EaseOut })
        .combine(TransitionEffect.translate({ y: -30 }).animation({ duration: 240, curve: Curve.EaseOut })),
      TransitionEffect.OPACITY.animation({ duration: 140, curve: Curve.EaseIn })
        .combine(TransitionEffect.translate({ y: -20 }).animation({ duration: 180, curve: Curve.EaseIn }))
    ))
  }

  @Builder
  TabletTopNavigation() {
    Row({ space: 4 }) {
      Row() {
        Text('☰')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.PRIMARY_DARK)
          .textAlign(TextAlign.Center)
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#52FFFFFF')
      .border({ width: 1, color: Colors.GLASS_BORDER })
      .borderRadius(Dimensions.PILL_RADIUS)
      .onClick(() => {
        this.navLayout = 'sidebar'
      })

      if (this.topbarBackVisible) {
        Row() {
          Text('<')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.PRIMARY_DARK)
            .textAlign(TextAlign.Center)
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('#52FFFFFF')
        .border({ width: 1, color: Colors.GLASS_BORDER })
        .borderRadius(Dimensions.PILL_RADIUS)
        .shadow({ radius: 12, color: '#18075AB8', offsetX: 0, offsetY: 2 })
        .onClick(() => {
          this.topbarBackAction()
        })
      }

      this.TabletTopNavItem('首页', 0)
      this.TabletTopNavItem('专注', 1)
      this.TabletTopNavItem('训练', 2)
      this.TabletTopNavItem('聊天', 3)
      this.TabletTopNavItem('我的', 4)
    }
    .width(this.topNavigationWidth())
    .height(56)
    .padding({ left: 7, right: 7, top: 7, bottom: 7 })
    .backgroundColor('#B8EAF6FF')
    .backdropBlur(48)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: '#8CFFFFFF' })
    .borderRadius(Dimensions.PILL_RADIUS)
    .shadow({ radius: 18, color: '#18000000', offsetX: 0, offsetY: 5 })
    .position({
      x: (this.screenWidth - this.topNavigationWidth()) / 2,
      y: this.safeAreaTop + 10
    })
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.EaseOut })
        .combine(TransitionEffect.translate({ y: -30 }).animation({ duration: 240, curve: Curve.EaseOut })),
      TransitionEffect.OPACITY.animation({ duration: 140, curve: Curve.EaseIn })
        .combine(TransitionEffect.translate({ y: -20 }).animation({ duration: 180, curve: Curve.EaseIn }))
    ))
  }

  @Builder
  TabletSidebarNavItem(title: string, index: number) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.currentIndex === index ? Colors.PRIMARY_DARK : Colors.TEXT_SECONDARY)
    }
    .width('100%')
    .height(46)
    .padding({ left: 18, right: 18 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.currentIndex === index ? '#26EAF6FF' : '#18FFFFFF')
    .backdropBlur(this.currentIndex === index ? 40 : 0)
    .backgroundBlurStyle(BlurStyle.Regular)
    .border({
      width: 1,
      color: this.currentIndex === index ? '#78FFFFFF' : '#00FFFFFF'
    })
    .borderRadius(Dimensions.PILL_RADIUS)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .shadow(this.currentIndex === index ? {
      radius: 16,
      color: '#30075AB8',
      offsetX: 0,
      offsetY: 0
    } : {
      radius: 0,
      color: '#00000000',
      offsetX: 0,
      offsetY: 0
    })
    .onClick(() => {
      this.selectMainIndex(index)
    })
  }

  @Builder
  TabletSidebarNavigation() {
    Column({ space: 10 }) {
      Row() {
        Row() {
          Text('‹')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.PRIMARY_DARK)
            .textAlign(TextAlign.Center)
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('#52FFFFFF')
        .border({ width: 1, color: Colors.GLASS_BORDER })
        .borderRadius(Dimensions.PILL_RADIUS)
        .onClick(() => {
          this.navLayout = 'topbar'
        })
        Blank()
      }
      .width('100%')
      .margin({ bottom: 4 })

      this.TabletSidebarNavItem('首页', 0)
      this.TabletSidebarNavItem('专注', 1)
      this.TabletSidebarNavItem('训练', 2)
      this.TabletSidebarNavItem('聊天', 3)
      this.TabletSidebarNavItem('我的', 4)
      Blank()
    }
    .width(this.sidebarNavigationWidth())
    .height(this.sidebarNavigationHeight())
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor('#DCEFF8FF')
    .backdropBlur(50)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: '#5213243A' })
    .borderRadius(28)
    .shadow({ radius: 22, color: '#24000000', offsetX: 3, offsetY: 7 })
    .position({ x: 12, y: this.safeAreaTop + 12 })
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseOut })
        .combine(TransitionEffect.translate({ x: -60 }).animation({ duration: 260, curve: Curve.EaseOut })),
      TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseIn })
        .combine(TransitionEffect.translate({ x: -40 }).animation({ duration: 200, curve: Curve.EaseIn }))
    ))
  }

  @Builder
  BottomNav() {
    Row() {
      if (this.currentIndex === 0) {
        this.NavItemActive('首页', 0)
      } else {
        this.NavItem('首页', 0)
      }
      if (this.currentIndex === 1) {
        this.NavItemActive('专注', 1)
      } else {
        this.NavItem('专注', 1)
      }
      if (this.currentIndex === 2) {
        this.NavItemActive('训练', 2)
      } else {
        this.NavItem('训练', 2)
      }
      if (this.currentIndex === 3) {
        this.NavItemActive('聊天', 3)
      } else {
        this.NavItem('聊天', 3)
      }
      if (this.currentIndex === 4) {
        this.NavItemActive('我的', 4)
      } else {
        this.NavItem('我的', 4)
      }
    }
    .width('90%')
    .constraintSize({ maxWidth: 600 })
    .height(this.screenWidth > Dimensions.BREAKPOINT_TABLET ? 64 : (this.screenWidth < Dimensions.BREAKPOINT_PHONE ? 48 : 56))
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: this.screenWidth < Dimensions.BREAKPOINT_PHONE ? 4 : 6,
      right: this.screenWidth < Dimensions.BREAKPOINT_PHONE ? 4 : 6,
      top: this.screenWidth > Dimensions.BREAKPOINT_TABLET ? 8 : (this.screenWidth < Dimensions.BREAKPOINT_PHONE ? 4 : 6),
      bottom: this.screenWidth > Dimensions.BREAKPOINT_TABLET ? 8 : (this.screenWidth < Dimensions.BREAKPOINT_PHONE ? 4 : 6)
    })
    .backgroundColor('#80EAF6FF')
    .backdropBlur(60)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: '#80FFFFFF' })
    .borderRadius(Dimensions.PILL_RADIUS)
    .shadow({
      radius: 24,
      color: '#20000000',
      offsetX: 0,
      offsetY: 4
    })
    .margin({ bottom: this.screenWidth > Dimensions.BREAKPOINT_TABLET ? Dimensions.NAV_BOTTOM : (this.screenWidth < Dimensions.BREAKPOINT_PHONE ? 8 : 16) })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Colors.BACKGROUND)
        .linearGradient({
          angle: 135,
          colors: [[Colors.BACKGROUND, 0.0], [Colors.BACKGROUND_DEEP, 0.55], ['#FFFFFF', 1.0]]
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      Column() {
        if (this.currentIndex === 0) {
          HomePage({ onNavigateToSle: () => this.openBluetoothSettings() })
            .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        } else if (this.currentIndex === 1) {
          FocusPage()
            .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        } else if (this.currentIndex === 2) {
          TrainPage({
            useGlobalTopbarBack: this.usesTabletNavigation() && this.navLayout === 'topbar',
            onTopbarBackChange: (visible: boolean, action: () => void) => {
              this.updateTopbarBack(visible, action)
            }
          })
            .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        } else if (this.currentIndex === 3) {
          AiChatPage()
            .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        } else {
          ProfilePage({ onTestAlert: () => this.testAlert() })
            .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        }
      }
      .width('100%')
      .height('100%')
      .padding({
        left: this.contentLeftPadding(),
        top: this.contentTopPadding()
      })
      .animation({ duration: 280, curve: Curve.EaseInOut })

      if (this.usesTabletNavigation()) {
        if (this.navLayout === 'sidebar') {
          this.TabletSidebarNavigation()
        } else {
          this.TabletTopSafeAreaGlass()
          this.TabletTopNavigation()
        }
        this.BottomNav()
      }

      if (this.isAlertVisible) {
        FullAlertDialog({
          title: this.alertTitle,
          message: this.alertMessage,
          detail: this.alertDetail,
          fatigueValue: this.alertFatigue,
          focusValue: this.alertFocus,
          qualityValue: this.alertQuality,
          onDismiss: () => this.dismissAlert()
        })
        .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BACKGROUND)
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      const h = typeof newArea.height === 'string' ? parseFloat(newArea.height as string) : (newArea.height as number)
      if (w > 0) {
        if (this.screenWidth < Dimensions.BREAKPOINT_TABLET && w >= Dimensions.BREAKPOINT_TABLET) {
          this.navLayout = 'topbar'
        }
        this.screenWidth = w
      }
      if (h > 0) this.screenHeight = h
    })
  }
}
