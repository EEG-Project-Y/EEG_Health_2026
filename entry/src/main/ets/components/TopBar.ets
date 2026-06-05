import router from '@ohos.router';
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
      const zhNames: string[] = ['仪表盘', '专注'];
      return zhNames[index] ?? zhNames[0];
    }
    const enNames: string[] = ['Dashboard', 'Focus'];
    return enNames[index] ?? enNames[0];
  }

  build() {
    Row() {
      Column({ space: 2 }) {
        Text(this.currentTab === 0 ? this.t('早上好', 'Good morning') : this.t('健康同步', 'HealthSync'))
          .fontSize(12)
          .fontColor(AppColor.Muted)
        Text(this.getTabName(this.currentTab))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Text)
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text(this.t('设置', 'Settings'))
        .fontSize(12)
        .fontColor(AppColor.Muted)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(12)
        .backgroundColor(AppColor.Surface)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Settings' });
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
    .backgroundColor(AppColor.White)
  }
}
