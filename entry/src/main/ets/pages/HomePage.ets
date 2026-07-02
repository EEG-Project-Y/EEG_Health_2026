import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'
import { ManagedDevice, RuntimeManagementState } from '../model/ToPadModel'
import { ToPadMock } from '../model/ToPadMock'

@Component
export struct HomePage {
  @State devices: ManagedDevice[] = ToPadMock.getDevices()
  @State runtimeState: RuntimeManagementState = ToPadMock.getRuntimeState()
  @State selectedDeviceId: string = 'eeg-lab-01'
  @State alertConfirmed: boolean = false
  @State sw: number = 360
  onNavigateToSle?: () => void = undefined

  private selectedDevice(): ManagedDevice {
    for (let i: number = 0; i < this.devices.length; i++) {
      if (this.devices[i].id === this.selectedDeviceId) {
        return this.devices[i]
      }
    }
    return this.devices[0]
  }

  private selectedDeviceIndex(): number {
    for (let i: number = 0; i < this.devices.length; i++) {
      if (this.devices[i].id === this.selectedDeviceId) return i
    }
    return 0
  }

  private selectDevice(id: string): void {
    this.selectedDeviceId = id
    this.alertConfirmed = false
  }

  private refreshDeviceData(id: string): void {
    for (let i: number = 0; i < this.devices.length; i++) {
      if (this.devices[i].id === id) {
        this.devices[i].lastSync = '刚刚'
        this.devices[i].frame.sequence = this.devices[i].frame.sequence + 1
        this.selectedDeviceId = id
        break
      }
    }
    this.devices = [...this.devices]
    promptAction.showToast({ message: '设备数据已刷新', duration: 1500 })
  }

  private openDeviceReport(device: ManagedDevice): void {
    this.selectedDeviceId = device.id
    router.pushUrl({
      url: 'pages/ReportPage',
      params: {
        deviceId: device.id,
        deviceName: device.deviceName,
        owner: device.owner,
        location: device.location,
        isConnected: device.isConnected,
        battery: device.battery,
        lastSync: device.lastSync,
        focus: device.frame.focus,
        fatigue: device.frame.fatigue,
        relax: device.frame.relax,
        load: device.frame.load,
        quality: device.frame.quality,
        confidence: device.frame.confidence,
        state: device.frame.state,
        direction: device.frame.direction,
        advice: device.frame.advice,
        sequence: device.frame.sequence,
        dataSource: this.runtimeState.dataSource,
        model: this.runtimeState.modelVersion,
        local: this.runtimeState.modelEnabled,
        alert: device.frame.alert
      }
    }).catch(() => {
      promptAction.showToast({ message: '数据报告页面打开失败，请检查路由配置', duration: 2000 })
    })
  }

  private openDeviceSettings(device: ManagedDevice): void {
    this.selectedDeviceId = device.id
    router.pushUrl({
      url: 'pages/SettingsPage',
      params: {
        deviceId: device.id,
        deviceName: device.deviceName,
        isConnected: device.isConnected,
        lastSync: device.lastSync,
        quality: device.frame.quality,
        confidence: device.frame.confidence,
        state: device.frame.state,
        direction: device.frame.direction,
        sequence: device.frame.sequence,
        technology: device.technology,
        edgeConnected: this.runtimeState.edgeConnected,
        edgeName: this.runtimeState.edgeName,
        dataSource: this.runtimeState.dataSource,
        toAppUpdatedAt: this.runtimeState.toAppUpdatedAt,
        modelVersion: this.runtimeState.modelVersion,
        modelEnabled: this.runtimeState.modelEnabled,
        modelStatus: this.runtimeState.modelStatus,
        dataFileStatus: this.runtimeState.dataFileStatus
      }
    }).catch(() => {
      promptAction.showToast({ message: '设备设置页面打开失败，请检查路由配置', duration: 2000 })
    })
  }

  private onlineCount(): number {
    let count: number = 0
    for (let i: number = 0; i < this.devices.length; i++) {
      if (this.devices[i].isConnected) count++
    }
    return count
  }

  private alertCount(): number {
    let count: number = 0
    for (let i: number = 0; i < this.devices.length; i++) {
      if (this.devices[i].frame.alert || this.devices[i].frame.fatigue >= 75) count++
    }
    return count
  }

  private avgFocus(): number {
    const connected: number = this.onlineCount()
    if (connected === 0) return 0
    let sum: number = 0
    for (let i: number = 0; i < this.devices.length; i++) {
      if (this.devices[i].isConnected) sum += this.devices[i].frame.focus
    }
    return Math.round(sum / connected)
  }

  private avgFatigue(): number {
    const connected: number = this.onlineCount()
    if (connected === 0) return 0
    let sum: number = 0
    for (let i: number = 0; i < this.devices.length; i++) {
      if (this.devices[i].isConnected) sum += this.devices[i].frame.fatigue
    }
    return Math.round(sum / connected)
  }

  private fleetAdvice(): string {
    if (this.onlineCount() === 0) {
      return '所有设备均离线，请逐台检查电量、星闪连接和佩戴状态后再开始任务。'
    }
    if (this.alertCount() === 0) {
      return `${this.onlineCount()} 台设备运行正常，可安排训练或专注任务，建议每 45 分钟复查一次状态。`
    }
    let advice: string = ''
    for (let i: number = 0; i < this.devices.length; i++) {
      const d: ManagedDevice = this.devices[i]
      if (!d.isConnected) {
        advice += `${d.deviceName} 离线，需检查连接与电量。`
      } else if (d.frame.fatigue >= 75) {
        advice += `${d.deviceName} 疲劳度 ${d.frame.fatigue}%，建议暂停并休息。`
      } else if (d.frame.quality < 60) {
        advice += `${d.deviceName} 信号质量 ${d.frame.quality}%，请调整电极接触。`
      }
    }
    return advice
  }

  private statusColor(): string {
    const fatigue: number = this.avgFatigue()
    if (fatigue >= 75) return Colors.ERROR
    if (fatigue >= 50) return Colors.WARNING
    return Colors.SUCCESS
  }

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
  }

  private toggleConnection(id: string): void {
    for (let i: number = 0; i < this.devices.length; i++) {
      if (this.devices[i].id === id) {
        this.devices[i].isConnected = !this.devices[i].isConnected
        this.devices[i].lastSync = this.devices[i].isConnected ? '刚刚' : '连接已断开'
        break
      }
    }
    this.devices = [...this.devices]
  }

  private addDevice(): void {
    const next: number = this.devices.length + 1
    const newDevice: ManagedDevice = {
      id: `eeg-new-${Date.now()}`,
      deviceName: `待配置终端 ${next < 10 ? '0' + next : next}`,
      owner: '未分配',
      location: '待设置',
      isConnected: false,
      technology: 'SLE / 星闪',
      battery: 100,
      lastSync: '尚未连接',
      frame: {
        sequence: 0,
        focus: 0,
        fatigue: 0,
        relax: 0,
        load: 0,
        quality: 0,
        confidence: 0,
        state: '待配置',
        direction: 'stable',
        advice: '请完成设备配对并分配使用者。',
        alert: false
      }
    }
    this.devices = [...this.devices, newDevice]
    this.selectedDeviceId = newDevice.id
    this.alertConfirmed = false
  }

  @Builder
  HealthRing(size: number, value: number, color: string, label: string) {
    Column() {
      Stack() {
        Progress({ value: value, total: 100, type: ProgressType.Ring })
          .width(size)
          .height(size)
          .style({ strokeWidth: this.isNarrow() ? 8 : 10 })
          .color(color)
          .backgroundColor(Colors.DIVIDER)
        Column() {
          Text(`${value}`)
            .fontSize(size * 0.28)
            .fontWeight(FontWeight.Bold)
            .fontColor(color)
          Text('%')
            .fontSize(size * 0.12)
            .fontColor(Colors.TEXT_TERTIARY)
        }
      }
      .width(size)
      .height(size)
      Text(label)
        .fontSize(this.isNarrow() ? 11 : 12)
        .fontColor(Colors.TEXT_SECONDARY)
        .margin({ top: 6 })
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  StatusHeader() {
    Row() {
      Column() {
        Text('设备管理')
          .fontSize(this.isNarrow() ? 22 : 28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Text(`${this.onlineCount()} 台在线 · ${this.devices.length} 台总计`)
          .fontSize(this.isNarrow() ? 12 : 14)
          .fontColor(Colors.TEXT_SECONDARY)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('+ 添加')
        .fontSize(this.isNarrow() ? 12 : 13)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.ON_PRIMARY)
        .backgroundColor(Colors.PRIMARY)
        .borderRadius(Dimensions.PILL_RADIUS)
        .height(this.isNarrow() ? 34 : 38)
        .padding({ left: 14, right: 14 })
        .onClick(() => this.addDevice())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  OverviewCard() {
    Column() {
      Row() {
        Column() {
          this.HealthRing(this.isNarrow() ? 64 : 80, this.avgFocus(), Colors.PRIMARY, '平均专注')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          this.HealthRing(this.isNarrow() ? 64 : 80, this.avgFatigue(), this.statusColor(), '平均疲劳')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text(`${this.onlineCount()}`)
            .fontSize(this.isNarrow() ? 22 : 28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.SUCCESS)
          Text('在线')
            .fontSize(this.isNarrow() ? 11 : 12)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)

        Column() {
          Text(`${this.alertCount()}`)
            .fontSize(this.isNarrow() ? 22 : 28)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.alertCount() > 0 ? Colors.ERROR : Colors.SUCCESS)
          Text('告警')
            .fontSize(this.isNarrow() ? 11 : 12)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text('设备状态概览')
        .fontSize(this.isNarrow() ? 10 : 11)
        .fontColor(Colors.TEXT_TERTIARY)
        .margin({ top: 12 })
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: Dimensions.ELEVATION_BLUR, color: Colors.SHADOW_COLOR, offsetX: 0, offsetY: Dimensions.ELEVATION_OFFSET })
  }

  @Builder
  AiAdviceCard() {
    Column() {
      Row() {
        Text('AI 建议')
          .fontSize(this.isNarrow() ? 15 : 19)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
        Text('全部设备')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.PRIMARY_DARK)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(Colors.INFO_CONTAINER)
          .borderRadius(Dimensions.PILL_RADIUS)
      }
      .width('100%')

      Text(this.fleetAdvice())
        .fontSize(this.isNarrow() ? 12 : 14)
        .fontColor(Colors.TEXT_PRIMARY)
        .lineHeight(this.isNarrow() ? 18 : 22)
        .margin({ top: 10 })
        .width('100%')

      Text('香橙派完成后台处理与 ToApp.json 输出，平板端用于查看、控制、校准、标注与复盘。')
        .fontSize(this.isNarrow() ? 10 : 11)
        .fontColor(Colors.TEXT_TERTIARY)
        .lineHeight(this.isNarrow() ? 15 : 17)
        .margin({ top: 8 })
        .width('100%')
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: Dimensions.ELEVATION_BLUR, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: Dimensions.ELEVATION_OFFSET })
  }

  @Builder
  LogPanel() {
    Column() {
      Row() {
        Text('日志')
          .fontSize(this.isNarrow() ? 16 : 20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
        Text(`${this.devices.length} 台设备`)
          .fontSize(this.isNarrow() ? 11 : 12)
          .fontColor(Colors.TEXT_TERTIARY)
      }
      .width('100%')
      .margin({ bottom: this.isNarrow() ? 10 : 14 })

      ForEach(this.devices, (device: ManagedDevice) => {
        Row() {
          Row() {
            Circle({ width: 6, height: 6 })
              .fill(device.isConnected ? Colors.SUCCESS : Colors.TEXT_TERTIARY)
            Text(device.deviceName)
              .fontSize(this.isNarrow() ? 12 : 13)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
              .margin({ left: 6 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(VerticalAlign.Center)
          .layoutWeight(1)

          Text(`专 ${device.frame.focus}%  疲 ${device.frame.fatigue}%  质 ${device.frame.quality}%`)
            .fontSize(this.isNarrow() ? 11 : 12)
            .fontColor(Colors.TEXT_SECONDARY)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor(Colors.SURFACE_CARD)
        .border({ width: 1, color: Colors.OUTLINE })
        .borderRadius(Dimensions.CARD_RADIUS_MD)
        .margin({ bottom: 6 })
      }, (device: ManagedDevice) => device.id)
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: Dimensions.ELEVATION_BLUR, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: Dimensions.ELEVATION_OFFSET })
  }

  @Builder
  DeviceStrip() {
    Column() {
      Row() {
        Text('设备列表')
          .fontSize(this.isNarrow() ? 16 : 20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
        Text(`${this.devices.length} 台`)
          .fontSize(this.isNarrow() ? 11 : 12)
          .fontColor(Colors.TEXT_TERTIARY)
      }
      .width('100%')
      .margin({ bottom: this.isNarrow() ? 10 : 14 })

      if (this.isNarrow()) {
        Swiper() {
          ForEach(this.devices, (device: ManagedDevice) => {
            Row() {
              this.DeviceMiniCard(device)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }, (device: ManagedDevice) => device.id)
        }
        .width('100%')
        .height(104)
        .index(this.selectedDeviceIndex())
        .loop(false)
        .autoPlay(false)
        .indicator(true)
        .duration(220)
        .onChange((index: number) => {
          if (index >= 0 && index < this.devices.length) {
            this.selectDevice(this.devices[index].id)
          }
        })
      } else {
        Scroll() {
          Row({ space: 14 }) {
            ForEach(this.devices, (device: ManagedDevice) => {
              this.DeviceMiniCard(device)
            }, (device: ManagedDevice) => device.id)
          }
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: Dimensions.ELEVATION_BLUR, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: Dimensions.ELEVATION_OFFSET })
  }

  @Builder
  DeviceGlassButton(label: string, color: string, device: ManagedDevice, action: string) {
    Row() {
      Text(label)
        .fontSize(this.isNarrow() ? 10 : 11)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(this.isNarrow() ? 28 : 30)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 6, right: 6 })
    .backgroundColor(this.selectedDeviceId === device.id ? '#52FFFFFF' : '#72FFFFFF')
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: this.selectedDeviceId === device.id ? '#A6FFFFFF' : Colors.GLASS_BORDER })
    .borderRadius(Dimensions.PILL_RADIUS)
    .shadow({ radius: 8, color: '#12000000', offsetX: 0, offsetY: 2 })
    .onClick(() => {
      if (action === 'report') {
        this.openDeviceReport(device)
      } else if (action === 'refresh') {
        this.refreshDeviceData(device.id)
      } else if (action === 'settings') {
        this.openDeviceSettings(device)
      }
    })
  }

  @Builder
  DeviceMiniCard(device: ManagedDevice) {
    Column() {
      if (this.isNarrow()) {
        Row() {
          Circle({ width: 8, height: 8 })
            .fill(device.isConnected ? Colors.SUCCESS : Colors.TEXT_TERTIARY)
          Text(device.isConnected ? '在线' : '离线')
            .fontSize(10)
            .fontColor(device.isConnected ? Colors.SUCCESS : Colors.TEXT_TERTIARY)
            .margin({ left: 4 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        Text(device.deviceName)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.selectedDeviceId === device.id ? Colors.PRIMARY_DARK : Colors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })
      } else {
        Row() {
          Circle({ width: 8, height: 8 })
            .fill(device.isConnected ? Colors.SUCCESS : Colors.TEXT_TERTIARY)
          Text(device.isConnected ? '在线' : '离线')
            .fontSize(10)
            .fontColor(device.isConnected ? Colors.SUCCESS : Colors.TEXT_TERTIARY)
            .margin({ left: 4 })
        }
        .margin({ bottom: 6 })

        Text(device.deviceName)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.selectedDeviceId === device.id ? Colors.PRIMARY_DARK : Colors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(device.owner)
          .fontSize(11)
          .fontColor(Colors.TEXT_TERTIARY)
          .margin({ top: 3 })

        Row() {
          Column() {
            Text(`${device.frame.focus}%`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.PRIMARY_DARK)
            Text('专注')
              .fontSize(9)
              .fontColor(Colors.TEXT_TERTIARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          Column() {
            Text(`${device.frame.fatigue}%`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(device.frame.fatigue >= 75 ? Colors.ERROR :
                (device.frame.fatigue >= 50 ? Colors.WARNING : Colors.TEXT_PRIMARY))
            Text('疲劳')
              .fontSize(9)
              .fontColor(Colors.TEXT_TERTIARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .margin({ top: 10 })

        Row() {
          Text(`${device.battery}%`)
            .fontSize(9)
            .fontColor(Colors.TEXT_TERTIARY)
          Blank()
          Button(this.selectedDeviceId === device.id ? '查看' : '选中')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.selectedDeviceId === device.id ? Colors.ON_PRIMARY : Colors.PRIMARY_DARK)
            .backgroundColor(this.selectedDeviceId === device.id ? Colors.PRIMARY : Colors.INFO_CONTAINER)
            .borderRadius(Dimensions.PILL_RADIUS)
            .height(24)
            .width(48)
            .onClick(() => this.selectDevice(device.id))
        }
        .width('100%')
        .margin({ top: 8 })
        .alignItems(VerticalAlign.Center)
      }
    }
    .onClick(() => this.selectDevice(device.id))
    .width(this.isNarrow() ? '86%' : 160)
    .padding(this.isNarrow() ? 12 : 16)
    .alignItems(this.isNarrow() ? HorizontalAlign.Center : HorizontalAlign.Start)
    .backgroundColor(this.selectedDeviceId === device.id ? Colors.INFO_CONTAINER : Colors.SURFACE_CARD)
    .border({ width: this.selectedDeviceId === device.id ? 2 : 1, color: this.selectedDeviceId === device.id ? Colors.PRIMARY : Colors.OUTLINE })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .shadow({ radius: this.selectedDeviceId === device.id ? 12 : 0, color: this.selectedDeviceId === device.id ? '#201677FF' : '#00000000', offsetX: 0, offsetY: 3 })
  }

  @Builder
  DeviceDetail() {
    Column() {
      Row() {
        Column() {
          Text(this.selectedDevice().deviceName)
            .fontSize(this.isNarrow() ? 17 : 22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
          Text(this.isNarrow() ? this.selectedDevice().technology :
            `${this.selectedDevice().owner} · ${this.selectedDevice().location}`)
            .fontSize(this.isNarrow() ? 11 : 13)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row() {
          Circle({ width: 7, height: 7 })
            .fill(this.selectedDevice().isConnected ? Colors.SUCCESS : Colors.TEXT_TERTIARY)
          Text(this.selectedDevice().isConnected ? '在线' : '离线')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.selectedDevice().isConnected ? Colors.SUCCESS : Colors.TEXT_TERTIARY)
            .margin({ left: 5 })
        }
        .margin({ right: 10 })

        Button(this.selectedDevice().isConnected ? '断开' : '连接')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.selectedDevice().isConnected ? Colors.TEXT_SECONDARY : Colors.ON_PRIMARY)
          .backgroundColor(this.selectedDevice().isConnected ? Colors.SURFACE_SOFT : Colors.PRIMARY)
          .borderRadius(Dimensions.PILL_RADIUS)
          .height(34)
          .width(72)
          .onClick(() => this.toggleConnection(this.selectedDeviceId))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: this.isNarrow() ? 12 : 16 })

      if (this.isNarrow()) {
        Column({ space: 7 }) {
          this.DeviceMetaRow('使用者', this.selectedDevice().owner)
          this.DeviceMetaRow('位置', this.selectedDevice().location)
          this.DeviceMetaRow('电量', `${this.selectedDevice().battery}%`)
          this.DeviceMetaRow('最近同步', this.selectedDevice().lastSync)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor(Colors.SURFACE_SOFT)
        .borderRadius(Dimensions.CARD_RADIUS_MD)
        .margin({ bottom: 12 })
      }

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        this.MetricItem('专注度', this.selectedDevice().frame.focus, Colors.PRIMARY)
        this.MetricItem('疲劳度', this.selectedDevice().frame.fatigue, this.selectedDevice().frame.fatigue >= 75 ? Colors.ERROR : (this.selectedDevice().frame.fatigue >= 50 ? Colors.WARNING : Colors.MINT))
        this.MetricItem('放松度', this.selectedDevice().frame.relax, Colors.MINT)
        this.MetricItem('负荷', this.selectedDevice().frame.load, Colors.INDIGO)
        this.MetricItem('数据质量', this.selectedDevice().frame.quality, Colors.TEAL)
        this.MetricItem('置信度', this.selectedDevice().frame.confidence, Colors.AMBER)
      }
      .width('100%')

      if (this.isNarrow()) {
        Row({ space: 8 }) {
          this.DeviceGlassButton('数据报告', Colors.PRIMARY, this.selectedDevice(), 'report')
          this.DeviceGlassButton('刷新数据', Colors.TEAL, this.selectedDevice(), 'refresh')
          this.DeviceGlassButton('设备设置', Colors.INDIGO, this.selectedDevice(), 'settings')
        }
        .width('100%')
        .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: Dimensions.ELEVATION_BLUR, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: Dimensions.ELEVATION_OFFSET })
  }

  @Builder
  DeviceMetaRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(11)
        .fontColor(Colors.TEXT_TERTIARY)
      Blank()
      Text(value)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }

  @Builder
  MetricItem(label: string, value: number, color: string) {
    Column() {
      Row() {
        Text(`${value}`)
          .fontSize(this.isNarrow() ? 20 : 26)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
        Text('%')
          .fontSize(this.isNarrow() ? 11 : 13)
          .fontColor(Colors.TEXT_TERTIARY)
          .margin({ left: 1 })
          .alignSelf(ItemAlign.End)
      }
      .alignItems(VerticalAlign.Bottom)

      Text(label)
        .fontSize(this.isNarrow() ? 10 : 11)
        .fontColor(Colors.TEXT_SECONDARY)
        .margin({ top: 4 })

      Progress({ value: value, total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(this.isNarrow() ? 3 : 4)
        .color(color)
        .backgroundColor(Colors.DIVIDER)
        .margin({ top: 6 })
    }
    .width('30%')
    .padding(this.isNarrow() ? 10 : 14)
    .backgroundColor(Colors.SURFACE_CARD)
    .border({ width: 1, color: Colors.OUTLINE })
    .borderRadius(Dimensions.CARD_RADIUS_MD)
    .margin({ bottom: this.isNarrow() ? 8 : 10 })
  }

  @Builder
  InteractionPanel() {
    Column() {
      Row() {
        Text('交互管理')
          .fontSize(this.isNarrow() ? 16 : 20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
        Text(this.runtimeState.managementAvailable ? '管理端可用' : '待接入')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.runtimeState.managementAvailable ? Colors.SUCCESS : Colors.TEXT_TERTIARY)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(this.runtimeState.managementAvailable ? Colors.SUCCESS_CONTAINER : Colors.SURFACE_SOFT)
          .borderRadius(Dimensions.PILL_RADIUS)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        this.ManagementEntry('静息基线校准', this.runtimeState.baselineReady ? 'baselineReady: true' : `倒计时 ${this.runtimeState.calibrationCountdown}s`, '用于引导静息基线采集。', this.runtimeState.baselineReady ? Colors.SUCCESS : Colors.WARNING)
        this.ManagementEntry('训练数据标注', this.runtimeState.labelingEnabled ? '可标注' : '待启用', '整理后续训练数据标签。', Colors.PRIMARY)
        this.ManagementEntry('日志与模型状态', this.runtimeState.logAvailable ? this.runtimeState.modelStatus : '待接入', this.runtimeState.logSummary, Colors.TEAL)
        this.ManagementEntry('设置与数据服务', `轮询 ${this.runtimeState.pollingIntervalMs}ms`, `模型版本：${this.runtimeState.modelVersion}`, Colors.INDIGO)
      }
      .width('100%')
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: Dimensions.ELEVATION_BLUR, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: Dimensions.ELEVATION_OFFSET })
  }

  @Builder
  ManagementEntry(title: string, status: string, desc: string, color: string) {
    Column() {
      Row() {
        Circle({ width: 7, height: 7 }).fill(color)
        Text(title)
          .fontSize(this.isNarrow() ? 12 : 14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
          .margin({ left: 6 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(status)
        .fontSize(this.isNarrow() ? 10 : 11)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
        .margin({ top: 8 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(desc)
        .fontSize(this.isNarrow() ? 10 : 11)
        .fontColor(Colors.TEXT_SECONDARY)
        .lineHeight(this.isNarrow() ? 15 : 17)
        .margin({ top: 6 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width(this.isNarrow() ? '48%' : '24%')
    .padding(this.isNarrow() ? 11 : 13)
    .backgroundColor(Colors.SURFACE_CARD)
    .border({ width: 1, color: Colors.OUTLINE })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .margin({ bottom: 8 })
  }

  @Builder
  AlertPanel() {
    Column() {
      Row() {
        Text('最近告警')
          .fontSize(this.isNarrow() ? 16 : 20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
        if (this.alertCount() > 0) {
          Text(`${this.alertCount()} 条`)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.ON_PRIMARY)
            .backgroundColor(Colors.ERROR)
            .borderRadius(Dimensions.PILL_RADIUS)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        }
      }
      .width('100%')
      .margin({ bottom: this.isNarrow() ? 10 : 14 })

      if (this.alertCount() === 0) {
        Column() {
          Text('暂无告警')
            .fontSize(13)
            .fontColor(Colors.TEXT_TERTIARY)
          Text('所有设备状态正常')
            .fontSize(11)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ top: 2 })
        }
        .width('100%')
        .padding({ top: 20, bottom: 20 })
        .alignItems(HorizontalAlign.Center)
      } else {
        ForEach(this.devices, (device: ManagedDevice) => {
          if (device.frame.alert || device.frame.fatigue >= 75) {
            Row() {
              Column() {
                Text(device.deviceName)
                  .fontSize(this.isNarrow() ? 12 : 14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Colors.TEXT_PRIMARY)
                Text(`${device.frame.state} · 疲劳度 ${device.frame.fatigue}%`)
                  .fontSize(this.isNarrow() ? 10 : 11)
                  .fontColor(Colors.TEXT_SECONDARY)
                  .margin({ top: 4 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Text(device.frame.fatigue >= 75 ? '紧急' : '注意')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(device.frame.fatigue >= 75 ? Colors.ON_PRIMARY : Colors.WARNING)
                .backgroundColor(device.frame.fatigue >= 75 ? Colors.ERROR : Colors.WARNING_CONTAINER)
                .borderRadius(Dimensions.PILL_RADIUS)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 12, bottom: 12 })
            .backgroundColor(Colors.SURFACE_CARD)
            .border({ width: 1, color: Colors.OUTLINE })
            .borderRadius(Dimensions.CARD_RADIUS_MD)
            .margin({ bottom: 8 })
          }
        }, (device: ManagedDevice) => device.id)
      }
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: Dimensions.ELEVATION_BLUR, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: Dimensions.ELEVATION_OFFSET })
  }

  build() {
    Scroll() {
      Column({ space: this.isNarrow() ? 10 : Dimensions.STACK_GAP_MD }) {
        this.StatusHeader()
        this.OverviewCard()
        this.AiAdviceCard()
        this.LogPanel()
        this.DeviceStrip()
        this.DeviceDetail()
        this.InteractionPanel()
        this.AlertPanel()
      }
      .width('100%')
      .padding({
        left: this.isNarrow() ? 8 : (this.sw > Dimensions.BREAKPOINT_TABLET ? Dimensions.SCREEN_MARGIN : Dimensions.SCREEN_MARGIN_SM),
        right: this.isNarrow() ? 8 : (this.sw > Dimensions.BREAKPOINT_TABLET ? Dimensions.SCREEN_MARGIN : Dimensions.SCREEN_MARGIN_SM),
        top: this.isNarrow() ? 8 : Dimensions.SCREEN_MARGIN_SM,
        bottom: 118
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      if (w > 0) this.sw = w
    })
  }
}

