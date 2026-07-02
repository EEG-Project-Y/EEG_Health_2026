import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'
import { ManagedDevice } from '../model/ToPadModel'

@Component
export struct DeviceFleetPanel {
  @Prop devices: ManagedDevice[] = []
  @Prop selectedDeviceId: string = ''
  onSelect: (id: string) => void = () => {}
  onToggle: (id: string) => void = () => {}
  @State sw: number = 360

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
  }

  private metricColor(value: number, inverse: boolean): string {
    if (inverse) {
      if (value >= 75) return Colors.ERROR
      if (value >= 50) return Colors.WARNING
      return Colors.SUCCESS
    }
    if (value >= 75) return Colors.SUCCESS
    if (value >= 50) return Colors.WARNING
    return Colors.ERROR
  }

  @Builder
  MiniMetric(label: string, value: number, inverse: boolean = false) {
    Column() {
      Text(`${value}%`)
        .fontSize(this.isNarrow() ? 16 : 20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.metricColor(value, inverse))
      Text(label)
        .fontSize(this.isNarrow() ? 10 : 11)
        .fontColor(Colors.TEXT_TERTIARY)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DeviceCard(device: ManagedDevice) {
    Column() {
      Row() {
        Column() {
          Text(device.deviceName)
            .fontSize(this.isNarrow() ? 14 : 17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${device.owner} · ${device.location}`)
            .fontSize(this.isNarrow() ? 10 : 12)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row() {
          Circle({ width: 7, height: 7 })
            .fill(device.isConnected ? Colors.SUCCESS : Colors.TEXT_TERTIARY)
          Text(device.isConnected ? '在线' : '离线')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(device.isConnected ? Colors.SUCCESS : Colors.TEXT_TERTIARY)
            .margin({ left: 5 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        this.MiniMetric('专注', device.frame.focus)
        this.MiniMetric('疲劳', device.frame.fatigue, true)
        this.MiniMetric('质量', device.frame.quality)
        this.MiniMetric('电量', device.battery)
      }
      .width('100%')
      .margin({ top: this.isNarrow() ? 12 : 16 })

      Row() {
        Text(`同步 ${device.lastSync}`)
          .fontSize(10)
          .fontColor(Colors.TEXT_TERTIARY)
          .layoutWeight(1)
        Button(device.isConnected ? '断开' : '连接')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(device.isConnected ? Colors.TEXT_SECONDARY : Colors.ON_PRIMARY)
          .backgroundColor(device.isConnected ? Colors.SURFACE_SOFT : Colors.PRIMARY)
          .borderRadius(Dimensions.PILL_RADIUS)
          .height(30)
          .width(64)
          .onClick(() => this.onToggle(device.id))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: this.isNarrow() ? 10 : 14 })
    }
    .width(this.isNarrow() ? '100%' : '32%')
    .padding(this.isNarrow() ? 14 : 18)
    .backgroundColor(this.selectedDeviceId === device.id ? Colors.INFO_CONTAINER : Colors.SURFACE_CARD)
    .border({
      width: this.selectedDeviceId === device.id ? 2 : 1,
      color: this.selectedDeviceId === device.id ? Colors.PRIMARY : Colors.OUTLINE
    })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .shadow({
      radius: this.selectedDeviceId === device.id ? 14 : 0,
      color: this.selectedDeviceId === device.id ? '#241677FF' : '#00000000',
      offsetX: 0,
      offsetY: 4
    })
    .margin({ right: this.isNarrow() ? 0 : 8, bottom: this.isNarrow() ? 10 : 8 })
    .onClick(() => this.onSelect(device.id))
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('设备总览')
            .fontSize(this.isNarrow() ? 16 : 21)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
          Text('选择设备可查看完整实时参数')
            .fontSize(this.isNarrow() ? 10 : 12)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text(`${this.devices.length} 台`)
          .fontSize(this.isNarrow() ? 11 : 13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.PRIMARY_DARK)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(Colors.INFO_CONTAINER)
          .borderRadius(Dimensions.PILL_RADIUS)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: this.isNarrow() ? 12 : 18 })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.devices, (device: ManagedDevice) => {
          this.DeviceCard(device)
        }, (device: ManagedDevice) => device.id)
      }
      .width('100%')
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({
      radius: Dimensions.ELEVATION_BLUR,
      color: Colors.SOFT_SHADOW,
      offsetX: 0,
      offsetY: Dimensions.ELEVATION_OFFSET
    })
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      if (w > 0) this.sw = w
    })
  }
}
