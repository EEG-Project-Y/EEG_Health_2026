import { AppColor } from '../theme/AppColor';

@Component
export struct MenuRow {
  title: string = '';
  subtitle: string = '';
  color: string = AppColor.Primary;

  build() {
    Row() {
      Column({ space: 4 }) {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.Text)
        Text(this.subtitle)
          .fontSize(12)
          .fontColor(AppColor.Muted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('>')
        .fontSize(22)
        .fontColor(this.color)
    }
    .padding(16)
    .width('100%')
  }
}
