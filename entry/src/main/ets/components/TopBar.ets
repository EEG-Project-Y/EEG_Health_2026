import { AppColor } from '../theme/AppColor';

@Component
export struct TopBar {
  @Prop currentTab: number = 0;
  @Prop language: number = 0;

  private t(zh: string, en: string): string {
    return this.language === 0 ? zh : en;
  }

  private getTabName(index: number): string {
    if (this.language === 0) {
      const zhNames: string[] = ['仪表盘', '专注', '个人'];
      return zhNames[index];
    }
    const enNames: string[] = ['Dashboard', 'Focus', 'Profile'];
    return enNames[index];
  }

  build() {
    Row() {
      Text(this.currentTab === 2 ? 'HS' : 'AI')
        .width(42)
        .height(42)
        .borderRadius(21)
        .textAlign(TextAlign.Center)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.Primary)
        .backgroundColor(AppColor.PrimarySoft)

      Column() {
        Text(this.currentTab === 0 ? this.t('早上好', 'Good morning') : this.t('健康同步', 'HealthSync'))
          .fontSize(12)
          .fontColor(AppColor.Muted)
        Text(this.getTabName(this.currentTab))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Primary)
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      Blank()

      Button(this.t('提醒', 'Alert'))
        .height(36)
        .fontSize(13)
        .fontColor(AppColor.Text)
        .backgroundColor(AppColor.Surface)
        .borderRadius(18)
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#F9F9FFCC')
    .shadow({ radius: 8, color: '#10000000', offsetY: 2 })
  }
}
