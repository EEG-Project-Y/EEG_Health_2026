// DeviceCard.ets
// Slot A usage: import { DeviceCard } from '../components/DeviceCard', then place <DeviceCard /> at // <<< 插槽A >>>.

import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { mockDeviceList, refreshDeviceList, DeviceData } from '../utils/DeviceManager'

@Component
export struct DeviceCard {
  @State angle: number = 0
  @State isRefreshing: boolean = false
  @State device: DeviceData = mockDeviceList.length > 0 ? mockDeviceList[0] : {
    id: 'mock-main-device',
    name: '我的主设备',
    isConnected: true,
    lastSync: '刚刚',
    battery: 85
  }

  private refreshMockData(): void {
    refreshDeviceList().then(() => {
      if (mockDeviceList.length > 0) {
        this.device = mockDeviceList[0]
      }
    }).catch(() => {
      promptAction.showToast({ message: '刷新失败，请稍后再试', duration: 2000 })
    })
  }

  private openPage(url: string): void {
    router.pushUrl({ url: url }).catch(() => {
      promptAction.showToast({ message: '跳转失败，请检查路由配置', duration: 2000 })
    })
  }

  private startRefresh(): void {
    if (this.isRefreshing) {
      return
    }
    this.isRefreshing = true
    this.angle = 0
    animateTo({ duration: 2000, curve: Curve.Linear }, () => {
      this.angle = 720
    })
    this.refreshMockData()
    setTimeout(() => {
      this.angle = 0
      this.isRefreshing = false
    }, 2000)
  }

  @Builder
  ActionButton(label: string, icon: string, action: string) {
    Button() {
      Row() {
        Text(icon)
          .fontSize(15)
          .fontColor('#1677FF')
        Text(label)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1677FF')
          .margin({ left: 4 })
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .width('100%')
    }
    .height(42)
    .layoutWeight(1)
    .backgroundColor('#F2FFFFFF')
    .borderRadius(10)
    .rotate({ angle: action === 'refresh' ? this.angle : 0 })
    .onClick(() => {
      if (action === 'report') {
        this.openPage('pages/ReportPage')
      } else if (action === 'refresh') {
        this.startRefresh()
      } else if (action === 'settings') {
        this.openPage('pages/SettingsPage')
      }
    })
  }

  build() {
    Column() {
      Row() {
        Row() {
          Text('⌁')
            .fontSize(18)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
            .margin({ right: 8 })
          Text('我的主设备')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        Text('🟢 已连接')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor('#24FFFFFF')
          .borderRadius(12)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column() {
        Text(this.device.name)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`电量 ${this.device.battery}% · 最近同步 ${this.device.lastSync}`)
          .fontSize(13)
          .fontColor('#DCEBFF')
          .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 24, bottom: 24 })

      Row({ space: 8 }) {
        this.ActionButton('数据报告', '📊', 'report')
        this.ActionButton('刷新数据', '⟳', 'refresh')
        this.ActionButton('设备设置', '⚙', 'settings')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 18 })
    .linearGradient({
      angle: 135,
      colors: [['#1677FF', 0.0], ['#42A5F5', 0.55], ['#5C7CFA', 1.0]]
    })
    .borderRadius(18)
    .shadow({ radius: 18, color: '#241677FF', offsetX: 0, offsetY: 8 })
  }
}
