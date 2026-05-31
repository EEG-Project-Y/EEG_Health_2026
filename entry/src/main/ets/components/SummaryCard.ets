import { AppColor } from '../theme/AppColor';

@Component
export struct SummaryCard {
  title: string = '';
  value: string = '';
  color: string = AppColor.Primary;

  build() {
    Column() {
      Text(this.title)
        .fontSize(12)
        .fontColor(AppColor.Muted)
      Blank()
      Text(this.value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.color)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .height(122)
    .padding(14)
    .backgroundColor(AppColor.Card)
    .borderRadius(16)
    .border({ width: 1, color: AppColor.Border })
  }
}
