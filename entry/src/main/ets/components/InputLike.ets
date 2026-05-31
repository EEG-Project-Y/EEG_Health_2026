import { AppColor } from '../theme/AppColor';

@Component
export struct InputLike {
  label: string = '';
  value: string = '';

  build() {
    Column({ space: 6 }) {
      Text(this.label)
        .fontSize(12)
        .fontColor(AppColor.Muted)
      Text(this.value)
        .fontSize(14)
        .fontColor(AppColor.Text)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .width('100%')
        .borderRadius(10)
        .backgroundColor(AppColor.White)
        .border({ width: 1, color: AppColor.Border })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }
}
