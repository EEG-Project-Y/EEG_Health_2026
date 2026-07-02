import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'

interface DeviceReportParams {
  deviceName?: string
  owner?: string
  location?: string
  isConnected?: boolean
  battery?: number
  lastSync?: string
  focus?: number
  fatigue?: number
  relax?: number
  load?: number
  quality?: number
  confidence?: number
  state?: string
  direction?: string
  advice?: string
  sequence?: number
  alert?: boolean
  source?: string
  dataSource?: string
  model?: string
  local?: boolean
  channelMode?: string
  channelStatus?: string
  ch1Valid?: boolean
  ch2Valid?: boolean
}

@Entry
@Component
struct ReportPage {
  @StorageProp('safeAreaTop') safeAreaTop: number = 0
  @State sw: number = 360
  @State activeSection: number = 0
  @State deviceName: string = '--'
  @State deviceMeta: string = '--'
  @State isConnected: boolean = false
  @State hasConnectionData: boolean = false
  @State lastSync: string = '--'
  @State focus: number = -1
  @State fatigue: number = -1
  @State relax: number = -1
  @State load: number = -1
  @State quality: number = -1
  @State confidence: number = -1
  @State stateText: string = '--'
  @State directionText: string = '--'
  @State advice: string = '--'
  @State sequence: string = '--'
  @State hasAlert: boolean = false
  @State dataSource: string = '--'
  @State modelName: string = '待扩展'
  @State localText: string = '待扩展'
  @State channelMode: string = '--'
  @State channelStatus: string = '--'
  @State ch1Status: string = '未知'
  @State ch2Status: string = '未知'

  private sections: string[] = [
    '实时状态',
    '单次监测',
    '趋势报告',
    '异常与预警',
    '信号质量',
    'AI 建议',
    '历史报告',
    '报告导出'
  ]

  aboutToAppear(): void {
    const params = router.getParams() as DeviceReportParams
    if (!params) return
    if (params.deviceName) this.deviceName = params.deviceName
    const owner: string = params.owner ? params.owner : ''
    const location: string = params.location ? params.location : ''
    const meta: string = `${owner}${owner && location ? ' · ' : ''}${location}`
    if (meta.length > 0) this.deviceMeta = meta
    if (typeof params.isConnected === 'boolean') {
      this.isConnected = params.isConnected
      this.hasConnectionData = true
    }
    if (params.lastSync) this.lastSync = params.lastSync
    if (typeof params.focus === 'number') this.focus = params.focus
    if (typeof params.fatigue === 'number') this.fatigue = params.fatigue
    if (typeof params.relax === 'number') this.relax = params.relax
    if (typeof params.load === 'number') this.load = params.load
    if (typeof params.quality === 'number') this.quality = params.quality
    if (typeof params.confidence === 'number') this.confidence = params.confidence
    if (params.state) this.stateText = params.state
    if (params.direction) this.directionText = params.direction
    if (params.advice) this.advice = params.advice
    if (typeof params.sequence === 'number') this.sequence = `${params.sequence}`
    if (typeof params.alert === 'boolean') this.hasAlert = params.alert
    if (params.dataSource) this.dataSource = params.dataSource
    if (params.source) this.dataSource = params.source
    if (params.model) this.modelName = params.model
    if (typeof params.local === 'boolean') this.localText = params.local ? '是' : '否'
    if (params.channelMode) this.channelMode = params.channelMode
    if (params.channelStatus) this.channelStatus = params.channelStatus
    if (typeof params.ch1Valid === 'boolean') this.ch1Status = params.ch1Valid ? '有效' : '无效'
    if (typeof params.ch2Valid === 'boolean') this.ch2Status = params.ch2Valid ? '有效' : '无效'
  }

  private isWide(): boolean {
    return this.sw >= 760
  }

  private valueText(value: number): string {
    return value >= 0 ? `${value}%` : '--'
  }

  private qualityStatus(): string {
    if (this.quality < 0) return '未知'
    if (this.quality >= 80) return '良好'
    if (this.quality >= 60) return '一般'
    return '较低'
  }

  private confidenceStatus(): string {
    if (this.confidence < 0) return '未知'
    return this.confidence >= 60 ? '可参考' : '仅供参考'
  }

  private connectionText(): string {
    if (!this.hasConnectionData) return '未知'
    return this.isConnected ? '已连接' : '未连接'
  }

  private conclusionText(): string {
    if (this.fatigue < 0) return '当前缺少可用于生成监测结论的数据。'
    if (this.fatigue >= 70) return '当前快照中疲劳指标偏高，建议短暂休息并检查佩戴状态；该结果仅作状态参考。'
    return '当前快照中的状态指标整体平稳，建议继续观察后续变化；该结果仅作状态参考。'
  }

  private sectionDescription(): string {
    const descriptions: string[] = [
      '查看香橙派最近一次输出的实时状态',
      '基于当前数据生成监测快照',
      '观察指标变化方向，不作医学诊断',
      '查看设备断连、疲劳和信号质量事件',
      '判断当前数据质量与参考可信度',
      '查看香橙派本地 AI 建议及依据',
      '查看已保存的监测报告',
      '管理后续可扩展的报告导出能力'
    ]
    return descriptions[this.activeSection]
  }

  private statusColor(status: string): string {
    if (status === '正常' || status === '良好' || status === '已连接' || status === '可参考' || status === '平稳') return Colors.SUCCESS
    if (status === '异常' || status === '较低' || status === '未连接' || status === '需关注') return Colors.ERROR
    if (status === '一般' || status === '仅供参考') return Colors.WARNING
    return Colors.TEXT_TERTIARY
  }

  @Builder
  HeaderBar() {
    Row({ space: 12 }) {
      Row() {
        Text('<')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(Colors.GLASS_ACTIVE)
      .backgroundBlurStyle(BlurStyle.Thin)
      .border({ width: 1, color: Colors.GLASS_BORDER })
      .borderRadius(22)
      .onClick(() => router.back())

      Column() {
        Text('数据报告')
          .fontSize(this.isWide() ? 22 : 19)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Text(this.sectionDescription())
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(this.isWide() ? 70 : 64)
    .padding({ left: 10, right: 18 })
    .backgroundColor(Colors.GLASS)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
    .shadow({ radius: 18, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 5 })
  }

  @Builder
  NavigationItem(label: string, index: number) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontWeight(this.activeSection === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.activeSection === index ? Colors.PRIMARY_DARK : Colors.TEXT_SECONDARY)
        .maxLines(1)
    }
    .width(this.isWide() ? '100%' : 104)
    .height(42)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .justifyContent(this.isWide() ? FlexAlign.Start : FlexAlign.Center)
    .backgroundColor(this.activeSection === index ? Colors.INFO_CONTAINER : '#00FFFFFF')
    .border({ width: this.activeSection === index ? 1 : 0, color: Colors.OUTLINE })
    .borderRadius(Dimensions.CARD_RADIUS_SM)
    .onClick(() => {
      this.activeSection = index
    })
  }

  @Builder
  SideNavigation() {
    Column({ space: 6 }) {
      ForEach(this.sections, (label: string, index: number) => {
        this.NavigationItem(label, index)
      }, (label: string) => label)
    }
    .width(210)
    .height('100%')
    .padding(Dimensions.CARD_PADDING_XS)
    .backgroundColor(Colors.GLASS)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_LG)
  }

  @Builder
  HorizontalNavigation() {
    Scroll() {
      Row({ space: 6 }) {
        ForEach(this.sections, (label: string, index: number) => {
          this.NavigationItem(label, index)
        }, (label: string) => label)
      }
    }
    .width('100%')
    .height(48)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
  }

  @Builder
  SectionTitle(title: string, description: string) {
    Column() {
      Text(title)
        .fontSize(this.isWide() ? 24 : 20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT_PRIMARY)
      Text(description)
        .fontSize(13)
        .fontColor(Colors.TEXT_SECONDARY)
        .lineHeight(20)
        .margin({ top: 5 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  StatusTag(status: string) {
    Text(status)
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.statusColor(status))
      .padding({ left: 9, right: 9, top: 4, bottom: 4 })
      .backgroundColor(Colors.SURFACE_SOFT)
      .borderRadius(Dimensions.PILL_RADIUS)
  }

  @Builder
  MetricTile(label: string, value: string, status: string, color: string) {
    Column() {
      Row() {
        Text(label)
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .layoutWeight(1)
        this.StatusTag(status)
      }
      .width('100%')
      Text(value)
        .fontSize(this.isWide() ? 24 : 21)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .width('100%')
        .margin({ top: 12 })
    }
    .width(this.isWide() ? '31%' : (this.sw < Dimensions.BREAKPOINT_PHONE ? '100%' : '48%'))
    .constraintSize({ minHeight: 108 })
    .padding(Dimensions.CARD_PADDING_XS)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_MD)
    .margin({ right: 8, bottom: 8 })
  }

  @Builder
  InfoRow(label: string, value: string, status: string = '') {
    Row({ space: 10 }) {
      Text(label)
        .fontSize(14)
        .fontColor(Colors.TEXT_SECONDARY)
        .layoutWeight(1)
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_PRIMARY)
        .textAlign(TextAlign.End)
        .maxLines(3)
      if (status.length > 0) {
        this.StatusTag(status)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 50 })
    .padding({ top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  InfoCard(title: string, rows: string[][]) {
    Column() {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT_PRIMARY)
        .width('100%')
      ForEach(rows, (row: string[]) => {
        this.InfoRow(row[0], row[1], row.length > 2 ? row[2] : '')
        Divider().strokeWidth(0.5).color(Colors.DIVIDER)
      }, (row: string[]) => row[0])
    }
    .width('100%')
    .padding(Dimensions.CARD_PADDING_SM)
    .backgroundColor(Colors.GLASS_ACTIVE)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.CARD_RADIUS_XL)
    .shadow({ radius: 20, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 6 })
  }

  @Builder
  NoteCard(text: string) {
    Text(text)
      .width('100%')
      .fontSize(13)
      .lineHeight(21)
      .fontColor(Colors.TEXT_SECONDARY)
      .padding(Dimensions.CARD_PADDING_SM)
      .backgroundColor(Colors.INFO_CONTAINER)
      .border({ width: 1, color: Colors.OUTLINE })
      .borderRadius(Dimensions.CARD_RADIUS_MD)
  }

  @Builder
  RealtimeSection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('实时状态报告', '展示香橙派最近一次输出的状态结果。')
      Flex({ wrap: FlexWrap.Wrap }) {
        this.MetricTile('当前专注度', this.valueText(this.focus), this.focus >= 0 ? '状态参考' : '未知', Colors.PRIMARY)
        this.MetricTile('当前疲劳度', this.valueText(this.fatigue), this.fatigue >= 70 ? '需关注' : (this.fatigue >= 0 ? '正常' : '未知'), Colors.WARNING)
        this.MetricTile('当前放松度', this.valueText(this.relax), this.relax >= 0 ? '状态参考' : '未知', Colors.TEAL)
        this.MetricTile('当前负荷', this.valueText(this.load), this.load >= 0 ? '状态参考' : '未知', Colors.INDIGO)
        this.MetricTile('信号质量', this.valueText(this.quality), this.qualityStatus(), Colors.SUCCESS)
        this.MetricTile('置信度', this.valueText(this.confidence), this.confidenceStatus(), Colors.PRIMARY_DARK)
      }
      .width('100%')
      this.InfoCard('状态详情', [
        ['设备', this.deviceName],
        ['当前状态 state', this.stateText],
        ['状态方向 direction', this.directionText],
        ['AI 建议 advice', this.advice],
        ['最近更新时间', this.lastSync],
        ['数据来源 source / dataSource', this.dataSource],
        ['sequence', this.sequence]
      ])
      this.NoteCard('本报告基于香橙派边缘处理端输出的实时状态结果生成，仅作为状态参考。')
    }
    .width('100%')
  }

  @Builder
  SessionSection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('单次监测报告', '当前没有历史周期数据时，使用最近一次 ToApp 状态生成快照。')
      this.InfoCard('当前监测快照', [
        ['监测开始时间', '--'],
        ['监测结束时间', '--'],
        ['监测时长', '--'],
        ['平均专注度', this.valueText(this.focus)],
        ['平均疲劳度', this.valueText(this.fatigue)],
        ['平均放松度', this.valueText(this.relax)],
        ['平均负荷', this.valueText(this.load)],
        ['平均信号质量', this.valueText(this.quality)],
        ['有效数据占比', '--'],
        ['异常次数', '--'],
        ['综合状态', this.stateText]
      ])
      this.InfoCard('报告结论', [
        ['结论', this.conclusionText()],
        ['数据时间', this.lastSync],
        ['数据序号', this.sequence]
      ])
      this.NoteCard('该快照不替代完整监测周期报告，也不作为医学诊断依据。')
    }
    .width('100%')
  }

  @Builder
  TrendSection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('趋势报告', '当前缺少历史序列时，不生成虚构曲线。')
      Flex({ wrap: FlexWrap.Wrap }) {
        this.MetricTile('专注度趋势', '待扩展', '待扩展', Colors.PRIMARY)
        this.MetricTile('疲劳度趋势', '待扩展', '待扩展', Colors.WARNING)
        this.MetricTile('放松度趋势', '待扩展', '待扩展', Colors.TEAL)
        this.MetricTile('负荷趋势', '待扩展', '待扩展', Colors.INDIGO)
        this.MetricTile('信号质量趋势', '待扩展', '待扩展', Colors.SUCCESS)
      }
      .width('100%')
      this.InfoCard('趋势字段', [
        ['focusTrend', '待扩展'],
        ['fatigueTrend', '待扩展'],
        ['relaxTrend', '待扩展'],
        ['loadTrend', '待扩展']
      ])
      this.NoteCard('趋势报告用于观察用户状态变化方向，而不是医学诊断结论。')
    }
    .width('100%')
  }

  @Builder
  AlertSection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('异常与预警报告', '汇总疲劳、信号质量和设备连接等管理事件。')
      this.InfoCard('当前预警状态', [
        ['最近一次预警类型', '--'],
        ['最近一次预警时间', '--'],
        ['当前疲劳状态', this.fatigue >= 70 ? '需关注' : (this.fatigue >= 0 ? '正常' : '未知'), this.fatigue >= 70 ? '需关注' : '正常'],
        ['当前信号质量状态', this.qualityStatus(), this.qualityStatus()],
        ['当前设备连接状态', this.connectionText(), this.connectionText()],
        ['当前预警策略', '待扩展']
      ])
      Column() {
        Text('预警记录')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')
        Text('暂无异常预警记录')
          .fontSize(14)
          .fontColor(Colors.TEXT_TERTIARY)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 34, bottom: 34 })
      }
      .width('100%')
      .padding(Dimensions.CARD_PADDING_SM)
      .backgroundColor(Colors.GLASS_ACTIVE)
      .backgroundBlurStyle(BlurStyle.Thin)
      .border({ width: 1, color: Colors.GLASS_BORDER })
      .borderRadius(Dimensions.CARD_RADIUS_XL)
      this.NoteCard('预警用于移动端管理和休息提醒，状态判断由香橙派边缘处理端完成。')
    }
    .width('100%')
  }

  @Builder
  SignalSection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('信号质量报告', '说明当前数据质量及状态判断的参考可信度。')
      this.InfoCard('信号与通道', [
        ['当前信号质量', this.valueText(this.quality), this.qualityStatus()],
        ['当前置信度', this.valueText(this.confidence), this.confidenceStatus()],
        ['CH1 是否有效', this.ch1Status],
        ['CH2 是否有效', this.ch2Status],
        ['channelMode', this.channelMode],
        ['channelStatus', this.channelStatus],
        ['低质量提醒状态', this.quality >= 0 && this.quality < 60 ? '需提醒' : (this.quality >= 0 ? '正常' : '未知')],
        ['数据是否可信', this.confidenceStatus()],
        ['最近更新时间', this.lastSync]
      ])
      this.NoteCard(this.quality >= 0 && this.quality < 60
        ? '当前信号质量较低，建议检查佩戴或连接状态；当前判断仅供参考。'
        : '信号质量会影响状态判断可信度，建议结合佩戴和连接状态综合查看。')
    }
    .width('100%')
  }

  @Builder
  AiSection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('AI 建议报告', '展示香橙派本地 AI 建议的输入依据和输出结果。')
      this.InfoCard('生成依据', [
        ['当前输入状态 state', this.stateText],
        ['direction', this.directionText],
        ['focus', this.valueText(this.focus)],
        ['fatigue', this.valueText(this.fatigue)],
        ['relax', this.valueText(this.relax)],
        ['load', this.valueText(this.load)],
        ['quality', this.valueText(this.quality)],
        ['confidence', this.valueText(this.confidence)],
        ['AI 建议 advice', this.advice],
        ['模型名称 model', this.modelName],
        ['是否本地生成 local', this.localText],
        ['生成位置', '香橙派本地'],
        ['最近生成时间', this.lastSync]
      ])
      this.NoteCard('AI 建议基于香橙派处理后的状态指标生成，仅作为状态参考和休息提醒，不作为医学诊断依据。')
    }
    .width('100%')
  }

  @Builder
  HistorySection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('历史报告', '历史存储尚未接入时保持真实空状态。')
      Column() {
        Text('暂无历史报告')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Text('完成一次监测后将在此生成记录。')
          .fontSize(14)
          .fontColor(Colors.TEXT_TERTIARY)
          .margin({ top: 8 })
      }
      .width('100%')
      .height(180)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(Colors.GLASS_ACTIVE)
      .backgroundBlurStyle(BlurStyle.Thin)
      .border({ width: 1, color: Colors.GLASS_BORDER })
      .borderRadius(Dimensions.CARD_RADIUS_XL)
    }
    .width('100%')
  }

  @Builder
  ExportButton(label: string) {
    Button(label)
      .width(this.isWide() ? '31%' : (this.sw < Dimensions.BREAKPOINT_PHONE ? '100%' : '48%'))
      .height(48)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(Colors.PRIMARY_DARK)
      .backgroundColor(Colors.SURFACE_SOFT)
      .border({ width: 1, color: Colors.OUTLINE })
      .borderRadius(Dimensions.CARD_RADIUS_MD)
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        promptAction.showToast({ message: '导出功能待接入', duration: 1800 })
      })
  }

  @Builder
  ExportSection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('报告导出', '展示后续可扩展的报告与运行记录导出能力。')
      Flex({ wrap: FlexWrap.Wrap }) {
        this.ExportButton('导出 PDF 报告')
        this.ExportButton('导出 CSV 数据')
        this.ExportButton('导出运行日志')
        this.ExportButton('导出 AI 建议记录')
        this.ExportButton('导出异常预警记录')
      }
      .width('100%')
      .padding(Dimensions.CARD_PADDING_SM)
      .backgroundColor(Colors.GLASS_ACTIVE)
      .backgroundBlurStyle(BlurStyle.Thin)
      .border({ width: 1, color: Colors.GLASS_BORDER })
      .borderRadius(Dimensions.CARD_RADIUS_XL)
      this.NoteCard('报告导出功能用于保存监测结果、运行日志和异常记录，便于后续分析与项目演示。')
    }
    .width('100%')
  }

  @Builder
  SectionContent() {
    if (this.activeSection === 0) {
      this.RealtimeSection()
    } else if (this.activeSection === 1) {
      this.SessionSection()
    } else if (this.activeSection === 2) {
      this.TrendSection()
    } else if (this.activeSection === 3) {
      this.AlertSection()
    } else if (this.activeSection === 4) {
      this.SignalSection()
    } else if (this.activeSection === 5) {
      this.AiSection()
    } else if (this.activeSection === 6) {
      this.HistorySection()
    } else {
      this.ExportSection()
    }
  }

  @Builder
  ContentScroll() {
    Scroll() {
      Row() {
        Column() {
          this.SectionContent()
        }
        .width('100%')
        .constraintSize({ maxWidth: Dimensions.CONTENT_MAX_WIDTH })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: this.isWide() ? 0 : 10, bottom: Dimensions.SCREEN_MARGIN })
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Colors.BACKGROUND)
        .linearGradient({
          angle: 135,
          colors: [[Colors.BACKGROUND, 0.0], [Colors.BACKGROUND_DEEP, 0.58], ['#FFFFFF', 1.0]]
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      Column({ space: 12 }) {
        this.HeaderBar()
        if (this.isWide()) {
          Row({ space: Dimensions.STACK_GAP_MD }) {
            this.SideNavigation()
            this.ContentScroll()
          }
          .layoutWeight(1)
          .width('100%')
          .alignItems(VerticalAlign.Top)
        } else {
          this.HorizontalNavigation()
          this.ContentScroll()
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: this.safeAreaTop })
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      if (w > 0) this.sw = w
    })
  }
}
