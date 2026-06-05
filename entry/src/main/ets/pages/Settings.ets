import router from '@ohos.router';
import { AppColor } from '../theme/AppColor';
import { MenuRow } from '../components/MenuRow';
import { initSettingsStorage } from '../store/SettingsStore';

@Entry
@Component
struct Settings {
  @StorageLink('language') private language: number = 0;
  @StorageLink('autoReconnect') private autoReconnect: boolean = true;
  @StorageLink('cloudSync') private cloudSync: boolean = true;
  @StorageLink('keepScreenOn') private keepScreenOn: boolean = false;
  @StorageLink('healthThreshold') private healthThreshold: number = 40;
  @StorageLink('fatigueThreshold') private fatigueThreshold: number = 80;
  @StorageLink('bgStyle') private bgStyle: number = 0;

  aboutToAppear(): void {
    initSettingsStorage();
  }

  private t(zh: string, en: string): string {
    return this.language === 0 ? zh : en;
  }

  build() {
    Column() {
      this.HeaderBar()

      Scroll() {
        Column({ space: 16 }) {
          this.SectionTitle(this.t('设备', 'Device'))
          Column() {
            MenuRow({
              title: this.t('设备管理', 'Device Management'),
              subtitle: this.t('Orange Pi 已连接', 'Orange Pi connected'),
              color: AppColor.Primary
            })
          }
          .backgroundColor(AppColor.Card)
          .borderRadius(16)
          .border({ width: 1, color: AppColor.Border })

          this.SectionTitle(this.t('通用', 'General'))
          Column({ space: 12 }) {
            this.LanguageSelector()
            this.SwitchRow(this.t('自动重连', 'Auto reconnect'), this.autoReconnect, (value: boolean) => {
              this.autoReconnect = value;
            })
            this.SwitchRow(this.t('云同步', 'Cloud sync'), this.cloudSync, (value: boolean) => {
              this.cloudSync = value;
            })
            this.SwitchRow(this.t('保持屏幕常亮', 'Keep screen on'), this.keepScreenOn, (value: boolean) => {
              this.keepScreenOn = value;
            })
          }
          .backgroundColor(AppColor.Card)
          .borderRadius(16)
          .padding(16)
          .border({ width: 1, color: AppColor.Border })

          this.SectionTitle(this.t('提醒与阈值', 'Alerts & Thresholds'))
          Column({ space: 12 }) {
            this.SliderHealthThreshold()
            this.SliderFatigueThreshold()
          }
          .backgroundColor(AppColor.Card)
          .borderRadius(16)
          .padding(16)
          .border({ width: 1, color: AppColor.Border })

          this.SectionTitle(this.t('外观', 'Appearance'))
          this.BackgroundPicker()
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.Surface)
  }

  @Builder
  HeaderBar() {
    Row() {
      Text('<')
        .fontSize(18)
        .fontColor(AppColor.Text)
        .padding({ left: 6, right: 6, top: 6, bottom: 6 })
        .onClick(() => {
          router.back();
        })
      Text(this.t('设置', 'Settings'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.Text)
        .margin({ left: 6 })
      Blank()
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor(AppColor.White)
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColor.Muted)
  }

  @Builder
  LanguageSelector() {
    Row() {
      Text(this.t('语言', 'Language'))
        .fontSize(15)
        .fontColor(AppColor.Text)
      Blank()
      Row({ space: 6 }) {
        Button(this.t('中文', 'CN'))
          .height(30)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.language === 0 ? Color.White : AppColor.Text)
          .backgroundColor(this.language === 0 ? AppColor.Primary : AppColor.Surface)
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.language = 0;
          })
        Button(this.t('EN', 'EN'))
          .height(30)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.language === 1 ? Color.White : AppColor.Text)
          .backgroundColor(this.language === 1 ? AppColor.Primary : AppColor.Surface)
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.language = 1;
          })
      }
    }
    .width('100%')
    .padding({ top: 2, bottom: 2 })
  }

  @Builder
  SwitchRow(label: string, checked: boolean, onChange: (value: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(AppColor.Text)
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: checked })
        .selectedColor(AppColor.Primary)
        .onChange((value: boolean) => {
          onChange(value);
        })
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  SliderHealthThreshold() {
    Column({ space: 8 }) {
      Row() {
        Text(this.t('健康阈值', 'Health threshold'))
          .fontSize(15)
          .fontColor(AppColor.Text)
        Blank()
        Text(Math.round(this.healthThreshold).toString() + '%')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Primary)
      }
      .width('100%')
      Slider({
        value: this.healthThreshold,
        min: 0,
        max: 100,
        step: 1,
        style: SliderStyle.InSet
      })
        .width('100%')
        .blockColor(AppColor.Primary)
        .trackColor(AppColor.PrimarySoft)
        .selectedColor(AppColor.Primary)
        .onChange((value: number) => {
          this.healthThreshold = value;
        })
    }
    .width('100%')
  }

  @Builder
  SliderFatigueThreshold() {
    Column({ space: 8 }) {
      Row() {
        Text(this.t('疲劳阈值', 'Fatigue threshold'))
          .fontSize(15)
          .fontColor(AppColor.Text)
        Blank()
        Text(Math.round(this.fatigueThreshold).toString() + '/100')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Danger)
      }
      .width('100%')
      Slider({
        value: this.fatigueThreshold,
        min: 0,
        max: 100,
        step: 1,
        style: SliderStyle.InSet
      })
        .width('100%')
        .blockColor(AppColor.Danger)
        .trackColor('#33FF4D4F')
        .selectedColor(AppColor.Danger)
        .onChange((value: number) => {
          this.fatigueThreshold = value;
        })
    }
    .width('100%')
  }

  @Builder
  BackgroundPicker() {
    Column({ space: 14 }) {
      Column({ space: 8 }) {
        Text(this.t('健康同步', 'Health Sync'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Text)
        Progress({ value: 74, total: 100, type: ProgressType.Linear })
          .height(8)
          .color(AppColor.Primary)
      }
      .width('100%')
      .padding(16)
      .borderRadius(14)
      .backgroundColor(AppColor.White)
      .border({ width: 1, color: AppColor.Border })

      Row({ space: 10 }) {
        this.BackgroundOption(this.t('白色', 'White'), '#FFFFFF', 0)
        this.BackgroundOption(this.t('蓝色', 'Blue'), '#E0F2FF', 1)
        this.BackgroundOption(this.t('暖色', 'Warm'), '#FFF3E0', 2)
      }

      Button(this.t('应用背景', 'Apply Background'))
        .height(44)
        .width('100%')
        .borderRadius(12)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(AppColor.Primary)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(AppColor.Card)
    .borderRadius(16)
    .border({ width: 1, color: AppColor.Border })
  }

  @Builder
  BackgroundOption(label: string, color: string, index: number) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor(index === this.bgStyle ? AppColor.Primary : AppColor.Muted)
        .fontWeight(index === this.bgStyle ? FontWeight.Bold : FontWeight.Regular)
    }
    .layoutWeight(1)
    .height(72)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(color)
    .borderRadius(14)
    .border({ width: index === this.bgStyle ? 2 : 1, color: index === this.bgStyle ? AppColor.Primary : AppColor.Border })
    .onClick(() => {
      this.bgStyle = index;
    })
  }
}
