import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'
import { DeviceConnection } from '../model/ToPadModel'

@Component
export struct SleConnectionCard {
  @Prop connection: DeviceConnection = { deviceName: 'EEG_SLE_PAD', isConnected: false, technology: 'SLE / 星闪' }
  onToggle: () => void = () => {}
  onNavigateToSle?: () => void = undefined
  @State sw: number = 360

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('连接设备').fontSize(this.isNarrow() ? 16 : 22).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT_PRIMARY)
          Row() {
            Circle({ width: 8, height: 8 }).fill(this.connection.isConnected ? Colors.SUCCESS : Colors.TEXT_TERTIARY).margin({ right: 6 })
            Text(this.connection.isConnected ? `已连接 ${this.connection.deviceName}` : '未连接设备')
              .fontSize(this.isNarrow() ? 12 : 15).fontWeight(FontWeight.Medium)
              .fontColor(this.connection.isConnected ? Colors.SUCCESS : Colors.TEXT_SECONDARY)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.margin({ top: this.isNarrow() ? 6 : 10 }).alignItems(VerticalAlign.Center)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column() {
          Text(this.connection.technology).fontSize(this.isNarrow() ? 11 : 13).fontWeight(FontWeight.Medium)
            .fontColor(Colors.PRIMARY_DARK).padding({ left: 10, right: 10, top: 5, bottom: 5 })
          Button(this.connection.isConnected ? '断开' : '连接')
          Button(this.connection.isConnected ? '鏂紑' : '杩炴帴')
            .fontSize(this.isNarrow() ? 12 : 14).fontWeight(FontWeight.Bold)
            .fontColor(this.connection.isConnected ? Colors.TEXT_SECONDARY : Colors.ON_PRIMARY)
            .backgroundColor(this.connection.isConnected ? Colors.SURFACE_SOFT : Colors.PRIMARY)
            .borderRadius(Dimensions.PILL_RADIUS).height(this.isNarrow() ? 34 : 40).width(this.isNarrow() ? 70 : 100)
            .onClick(() => this.onToggle())
        }.alignItems(HorizontalAlign.End)
      }.width('100%').alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE).backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER }).borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: Dimensions.ELEVATION_BLUR, color: Colors.SHADOW_COLOR, offsetX: 0, offsetY: Dimensions.ELEVATION_OFFSET })
    .onClick(() => { if (this.onNavigateToSle) this.onNavigateToSle() })
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      if (w > 0) this.sw = w
    })
  }
}
