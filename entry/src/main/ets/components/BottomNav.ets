import { TabItem } from '../models/TabItem';
import { AppColor } from '../theme/AppColor';

@Component
export struct BottomNav {
  currentTab: number = 0;
  language: number = 0;
  onTabChange: (index: number) => void = (index: number) => {};

  private getTabItems(): TabItem[] {
    if (this.language === 0) {
      return [
        new TabItem('D', '仪表盘'),
        new TabItem('F', '专注'),
        new TabItem('S', '运动'),
        new TabItem('P', '个人')
      ];
    }
    return [
      new TabItem('D', 'Dashboard'),
      new TabItem('F', 'Focus'),
      new TabItem('S', 'Sports'),
      new TabItem('P', 'Profile')
    ];
  }

  build() {
    Row() {
      ForEach(this.getTabItems(), (item: TabItem, index: number) => {
        Column({ space: 4 }) {
          Text(item.icon)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(index === this.currentTab ? AppColor.Primary : AppColor.Muted)
          Text(item.name)
            .fontSize(12)
            .fontWeight(index === this.currentTab ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(index === this.currentTab ? AppColor.Primary : AppColor.Muted)
        }
        .layoutWeight(1)
        .height(54)
        .justifyContent(FlexAlign.Center)
        .borderRadius(16)
        .backgroundColor(index === this.currentTab ? '#1A0054CB' : '#00FFFFFF')
        .onClick(() => {
          this.onTabChange(index);
        })
      })
    }
    .height(82)
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    .backgroundColor('#F9F9FFEE')
    .border({ width: { top: 1 }, color: AppColor.Border })
  }
}
