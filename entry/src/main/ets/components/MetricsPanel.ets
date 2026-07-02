import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'
import { ToPadFrame } from '../model/ToPadModel'
import { MetricGauge } from './MetricGauge'

@Component
export struct MetricsPanel {
  @Prop data: ToPadFrame = {
    sequence: 0, focus: 0, fatigue: 0, relax: 0, load: 0,
    quality: 0, confidence: 0, state: '', direction: '', advice: '', alert: false
  }
  @State sw: number = 360

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
  }

  private fatigueColor(): string {
    if (this.data.fatigue >= 75) return Colors.ERROR
    if (this.data.fatigue >= 50) return Colors.WARNING
    return Colors.ORANGE
  }

  build() {
        Text('核心指标')
      Row() {
        Text('鏍稿績鎸囨爣')
          .fontSize(this.isNarrow() ? 15 : 20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
        Text(`Sequence ${this.data.sequence}`)
          .fontSize(this.isNarrow() ? 11 : 12)
          .fontColor(Colors.TEXT_TERTIARY)
      }
      .width('100%')
      .margin({ bottom: this.isNarrow() ? 8 : 14 })

      if (this.isNarrow()) {
        this.metricCompact()
      } else {
        this.metricRow()
      }
    }
    .width('100%')
    .padding(this.isNarrow() ? Dimensions.CARD_PADDING_SM : Dimensions.CARD_PADDING)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: Dimensions.ELEVATION_BLUR, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: Dimensions.ELEVATION_OFFSET })
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      if (w > 0) this.sw = w
    })
  }

  @Builder
  metricRow() {
    Row({ space: Dimensions.GUTTER }) {
      MetricGauge({ nameCn: '专注度', nameEn: 'Focus', value: this.data.focus, accent: Colors.PRIMARY })
        .layoutWeight(1)
      MetricGauge({ nameCn: '疲劳度', nameEn: 'Fatigue', value: this.data.fatigue, accent: this.fatigueColor(), featured: true })
        .layoutWeight(1)
      MetricGauge({ nameCn: '放松度', nameEn: 'Relax', value: this.data.relax, accent: Colors.MINT })
        .layoutWeight(1)
    }
    .width('100%')
    Row({ space: Dimensions.GUTTER }) {
      MetricGauge({ nameCn: '璐熻嵎', nameEn: 'Load', value: this.data.load, accent: Colors.INDIGO })
      MetricGauge({ nameCn: '负荷', nameEn: 'Load', value: this.data.load, accent: Colors.INDIGO })
      MetricGauge({ nameCn: '鏁版嵁璐ㄩ噺', nameEn: 'Quality', value: this.data.quality, accent: Colors.TEAL })
      MetricGauge({ nameCn: '数据质量', nameEn: 'Quality', value: this.data.quality, accent: Colors.TEAL })
      MetricGauge({ nameCn: '数据质量', nameEn: 'Quality', value: this.data.quality, accent: Colors.TEAL })
      MetricGauge({ nameCn: '置信度', nameEn: 'Confidence', value: this.data.confidence, accent: Colors.AMBER })
    }
    .width('100%')
    .margin({ top: Dimensions.GUTTER })
  }

  @Builder
  metricCompact() {
    Column({ space: Dimensions.GUTTER_SM }) {
      Row({ space: Dimensions.GUTTER_SM }) {
        MetricGauge({ nameCn: '专注度', nameEn: 'Focus', value: this.data.focus, accent: Colors.PRIMARY })
          .layoutWeight(1)
        MetricGauge({ nameCn: '疲劳度', nameEn: 'Fatigue', value: this.data.fatigue, accent: this.fatigueColor(), featured: true })
          .layoutWeight(1)
      }.width('100%')
      Row({ space: Dimensions.GUTTER_SM }) {
        MetricGauge({ nameCn: '放松度', nameEn: 'Relax', value: this.data.relax, accent: Colors.MINT })
          .layoutWeight(1)
        MetricGauge({ nameCn: '负荷', nameEn: 'Load', value: this.data.load, accent: Colors.INDIGO })
          .layoutWeight(1)
      }.width('100%')
      Row({ space: Dimensions.GUTTER_SM }) {
        MetricGauge({ nameCn: '数据质量', nameEn: 'Quality', value: this.data.quality, accent: Colors.TEAL })
          .layoutWeight(1)
        MetricGauge({ nameCn: '置信度', nameEn: 'Confidence', value: this.data.confidence, accent: Colors.AMBER })
          .layoutWeight(1)
      }.width('100%')
    }.width('100%')
  }
}
