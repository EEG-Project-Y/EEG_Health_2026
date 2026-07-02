import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'
import { ManagedDevice } from '../model/ToPadModel'

@Component
export struct ManagementOverview {
  @Prop devices: ManagedDevice[] = []
  onAddDevice: () => void = () => {}
  @State sw: number = 360

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
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

  @Builder
  SummaryItem(label: string, value: string, color: string) {
    Column() {
      Text(value)
        .fontSize(this.isNarrow() ? 22 : 30)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(this.isNarrow() ? 11 : 13)
        .fontColor(Colors.TEXT_SECONDARY)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('设备管理中心')
            .fontSize(this.isNarrow() ? 20 : 28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
          Text('集中查看脑电终端、连接状态与实时指标')
            .fontSize(this.isNarrow() ? 11 : 14)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 5 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button('添加设备')
          .fontSize(this.isNarrow() ? 11 : 13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.ON_PRIMARY)
          .backgroundColor(Colors.PRIMARY)
          .borderRadius(Dimensions.PILL_RADIUS)
          .height(this.isNarrow() ? 34 : 40)
          .padding({ left: this.isNarrow() ? 12 : 18, right: this.isNarrow() ? 12 : 18 })
          .onClick(() => this.onAddDevice())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        this.SummaryItem('设备总数', `${this.devices.length}`, Colors.TEXT_PRIMARY)
        this.SummaryItem('在线设备', `${this.onlineCount()}`, Colors.SUCCESS)
        this.SummaryItem('待处理告警', `${this.alertCount()}`, this.alertCount() > 0 ? Colors.ERROR : Colors.SUCCESS)
        if (!this.isNarrow()) {
          this.SummaryItem('数据通道', 'SLE', Colors.PRIMARY_DARK)
        }
      }
      .width('100%')
      .margin({ top: this.isNarrow() ? 16 : 22 })
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({
      radius: Dimensions.ELEVATION_BLUR,
      color: Colors.SHADOW_COLOR,
      offsetX: 0,
      offsetY: Dimensions.ELEVATION_OFFSET
    })
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      if (w > 0) this.sw = w
    })
  }
}
