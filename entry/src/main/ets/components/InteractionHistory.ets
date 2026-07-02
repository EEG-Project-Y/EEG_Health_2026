// InteractionHistory.ets
// Slot B usage: import { InteractionHistory } from '../components/InteractionHistory', then place <InteractionHistory /> at // <<< 插槽B >>>.

import preferences from '@ohos.data.preferences'

@Component
export struct InteractionHistory {
  @State historyItems: string[] = []

  aboutToAppear(): void {
    preferences.getPreferences(getContext(this), 'command_history').then((prefs: preferences.Preferences) => {
      prefs.get('history', []).then((value: preferences.ValueType) => {
        const items = value as string[]
        this.historyItems = items ? items.slice(0, 5) : []
      }).catch(() => {
        this.historyItems = []
      })
    }).catch(() => {
      this.historyItems = []
    })
  }

  build() {
    Column() {
      Text('📋 交互管理')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')
        .margin({ bottom: 12 })

      if (this.historyItems.length === 0) {
        Column() {
          Text('暂无交互记录')
            .fontSize(14)
            .fontColor('#999999')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .height(96)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.historyItems, (item: string, index: number) => {
            ListItem() {
              Column() {
                Text(item)
                  .fontSize(14)
                  .fontColor('#374151')
                  .lineHeight(20)
                  .width('100%')
                  .padding({ top: 12, bottom: 12 })
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                if (index < this.historyItems.length - 1) {
                  Divider()
                    .strokeWidth(0.5)
                    .color('#E5E7EB')
                }
              }
              .width('100%')
            }
          }, (item: string, index: number) => `${index}_${item}`)
        }
        .width('100%')
        .height(260)
        .edgeEffect(EdgeEffect.None)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 18 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }
}
