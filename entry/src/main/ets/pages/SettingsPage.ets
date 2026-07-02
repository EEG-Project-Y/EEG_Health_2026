import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'

interface DeviceSettingsParams {
  deviceName?: string
  isConnected?: boolean
  technology?: string
  lastSync?: string
  quality?: number
  confidence?: number
  state?: string
  direction?: string
  sequence?: number
  edgeConnected?: boolean
  edgeName?: string
  dataSource?: string
  toAppUpdatedAt?: string
  modelVersion?: string
  modelEnabled?: boolean
  modelStatus?: string
  dataFileStatus?: string
}

@Entry
@Component
struct SettingsPage {
  @StorageProp('safeAreaTop') safeAreaTop: number = 0
  @State sw: number = 360
  @State activeSection: number = 0
  @State deviceName: string = '--'
  @State connectionStatus: string = '未知'
  @State technology: string = '--'
  @State lastSync: string = '--'
  @State quality: string = '--'
  @State confidence: string = '--'
  @State stateText: string = '--'
  @State directionText: string = '--'
  @State sequence: string = '--'
  @State edgeStatus: string = '未知'
  @State edgeName: string = 'OrangePi-EEG-Edge'
  @State dataSource: string = '--'
  @State toAppUpdatedAt: string = '--'
  @State modelName: string = '待扩展'
  @State modelStatus: string = '待扩展'
  @State dataFileStatus: string = '待扩展'
  @State fatigueThreshold: number = 70
  @State focusThreshold: number = 40
  @State qualityThreshold: number = 60
  @State confidenceThreshold: number = 50
  @State alertDelay: number = 30
  @State fatigueAlert: boolean = true
  @State focusAlert: boolean = true
  @State qualityAlert: boolean = true
  @State disconnectAlert: boolean = true
  @State highPrecisionEnabled: boolean = true

  private sections: string[] = [
    '设备总览',
    '香橙派管理',
    '脑电采集端',
    '预警设置',
    '数据采集',
    '模型与 AI',
    '日志与维护'
  ]

  aboutToAppear(): void {
    const params = router.getParams() as DeviceSettingsParams
    if (!params) return
    if (params.deviceName) this.deviceName = params.deviceName
    if (typeof params.isConnected === 'boolean') this.connectionStatus = params.isConnected ? '已连接' : '未连接'
    if (params.technology) this.technology = params.technology
    if (params.lastSync) this.lastSync = params.lastSync
    if (typeof params.quality === 'number') this.quality = `${params.quality}%`
    if (typeof params.confidence === 'number') {
      this.confidence = `${params.confidence}%`
      this.highPrecisionEnabled = params.confidence >= 80
    }
    if (params.state) this.stateText = params.state
    if (params.direction) this.directionText = params.direction
    if (typeof params.sequence === 'number') this.sequence = `${params.sequence}`
    if (typeof params.edgeConnected === 'boolean') this.edgeStatus = params.edgeConnected ? '在线' : '离线'
    if (params.edgeName) this.edgeName = params.edgeName
    if (params.dataSource) this.dataSource = params.dataSource
    if (params.toAppUpdatedAt) this.toAppUpdatedAt = params.toAppUpdatedAt
    if (params.modelVersion) this.modelName = params.modelVersion
    if (typeof params.modelEnabled === 'boolean') this.modelStatus = params.modelEnabled ? '运行中' : '已停用'
    if (params.modelStatus) this.modelStatus = params.modelStatus
    if (params.dataFileStatus) this.dataFileStatus = params.dataFileStatus
  }

  private isWide(): boolean {
    return this.sw >= 760
  }

  private sectionDescription(): string {
    const descriptions: string[] = [
      '查看采集端、香橙派与移动管理端的完整链路',
      '管理边缘处理主机及其服务状态',
      '查看前端脑电采集与通道连接状态',
      '配置移动端预警提醒策略',
      '查看由香橙派统一管理的采集参数',
      '查看香橙派本地 AI 建议生成状态',
      '辅助系统调试、链路排查和运行维护'
    ]
    return descriptions[this.activeSection]
  }

  private statusColor(status: string): string {
    if (status === '在线' || status === '已连接' || status === '正常' || status === '运行中') return Colors.SUCCESS
    if (status === '离线' || status === '未连接' || status === '中断' || status === '异常') return Colors.ERROR
    return Colors.TEXT_TERTIARY
  }

  private linkStatus(): string {
    if (this.edgeStatus === '在线' && this.connectionStatus === '已连接') return '正常'
    if (this.edgeStatus === '离线' || this.connectionStatus === '未连接') return '中断'
    return '未知'
  }

  private showPending(message: string = '功能待接入香橙派管理接口'): void {
    promptAction.showToast({ message: message, duration: 1800 })
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
        Text('设备设置')
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
    .width(this.isWide() ? '100%' : 112)
    .height(42)
    .padding({ left: 14, right: 14 })
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
  GlassCard(title: string) {
    Text(title)
      .fontSize(17)
      .fontWeight(FontWeight.Bold)
      .fontColor(Colors.TEXT_PRIMARY)
      .width('100%')
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
        .maxLines(2)
      if (status.length > 0) {
        Text(status)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.statusColor(status))
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(Colors.SURFACE_SOFT)
          .borderRadius(Dimensions.PILL_RADIUS)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 50 })
    .padding({ top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  ActionButton(label: string, message: string = '功能待接入香橙派管理接口') {
    Button(label)
      .height(40)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(Colors.PRIMARY_DARK)
      .backgroundColor(Colors.SURFACE_SOFT)
      .border({ width: 1, color: Colors.OUTLINE })
      .borderRadius(Dimensions.CARD_RADIUS_SM)
      .margin({ right: 10, bottom: 10 })
      .onClick(() => this.showPending(message))
  }

  @Builder
  InfoCard(title: string, rows: string[][]) {
    Column() {
      this.GlassCard(title)
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
  OverviewSection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('设备总览', '脑电采集端负责采集，香橙派负责处理，平板端负责移动管理。')
      this.InfoCard('链路状态', [
        ['香橙派状态', this.edgeName, this.edgeStatus],
        ['脑电采集端状态', this.deviceName, this.connectionStatus],
        ['数据链路状态', '采集端 → 香橙派 → 平板端', this.linkStatus()],
        ['当前数据源', this.dataSource],
        ['当前运行模式', '--'],
        ['最近更新时间', this.toAppUpdatedAt !== '--' ? this.toAppUpdatedAt : this.lastSync]
      ])
      this.InfoCard('当前状态字段', [
        ['sequence', this.sequence],
        ['state', this.stateText],
        ['direction', this.directionText],
        ['channelMode', '--'],
        ['ch1Valid', '--'],
        ['ch2Valid', '--'],
        ['quality', this.quality],
        ['confidence', this.confidence]
      ])
      this.NoteCard('当前页面用于查看香橙派边缘处理主机与脑电采集端的整体运行状态。平板端仅作为移动管理入口，不直接处理原始脑电数据。')
    }
    .width('100%')
  }

  @Builder
  OrangePiSection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('香橙派管理', '香橙派是脑电数据解析、状态评估和本地 AI 建议生成中心。')
      this.InfoCard('边缘处理主机', [
        ['设备名称', this.edgeName],
        ['设备角色', '边缘处理主机'],
        ['服务地址', 'http://127.0.0.1:18080'],
        ['ToApp 服务状态', this.dataFileStatus, this.edgeStatus === '在线' ? '运行中' : '未知'],
        ['datarec', '待扩展', '待扩展'],
        ['dataproc', '待扩展', '待扩展'],
        ['eegprompt', '待扩展', '待扩展'],
        ['模型运行位置', '香橙派本地'],
        ['模型名称', this.modelName],
        ['local', '待扩展'],
        ['source / dataSource', this.dataSource],
        ['最近更新时间', this.toAppUpdatedAt]
      ])
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        this.ActionButton('刷新状态')
        this.ActionButton('查看当前数据')
        this.ActionButton('查看服务说明')
        this.ActionButton('重启服务')
        this.ActionButton('导出运行记录')
      }
      .width('100%')
      this.NoteCard('香橙派负责脑电数据接收、帧解析、状态评估、本地 AI 建议生成与接口分发，是本系统的数据处理主机。')
    }
    .width('100%')
  }

  @Builder
  CollectorSection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('脑电采集端', '查看前端采集设备和星闪链路状态。')
      this.InfoCard('采集端状态', [
        ['设备名称', this.deviceName],
        ['设备角色', '脑电采集端'],
        ['连接方式', this.technology],
        ['连接状态', this.connectionStatus, this.connectionStatus],
        ['数据帧格式', 'AA55'],
        ['校验方式', 'XOR 轻量校验'],
        ['通道模式', '--'],
        ['通道状态', '--'],
        ['CH1 状态', '未知'],
        ['CH2 状态', '未知'],
        ['信号质量', this.quality],
        ['置信度', this.confidence],
        ['最近更新时间', this.lastSync]
      ])
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        this.ActionButton('重新连接')
        this.ActionButton('断开连接')
        this.ActionButton('进入校准模式')
        this.ActionButton('查看通道状态')
      }
      .width('100%')
      this.NoteCard('脑电采集端负责前端脑电信号采集，并通过链路向香橙派边缘处理端上传数据。')
    }
    .width('100%')
  }

  @Builder
  ThresholdRow(label: string, value: number, kind: string) {
    Column() {
      Row() {
        Text(label)
          .fontSize(14)
          .fontColor(Colors.TEXT_PRIMARY)
          .layoutWeight(1)
        Text(`${value}`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.PRIMARY)
      }
      .width('100%')
      Slider({ value: value, min: 0, max: 100, step: 1, style: SliderStyle.OutSet })
        .width('100%')
        .selectedColor(Colors.PRIMARY)
        .trackColor(Colors.OUTLINE)
        .onChange((next: number) => {
          if (kind === 'fatigue') this.fatigueThreshold = Math.round(next)
          if (kind === 'focus') this.focusThreshold = Math.round(next)
          if (kind === 'quality') this.qualityThreshold = Math.round(next)
          if (kind === 'confidence') this.confidenceThreshold = Math.round(next)
        })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  ToggleRow(label: string, value: boolean, kind: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(Colors.TEXT_PRIMARY)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor(Colors.PRIMARY)
        .onChange((next: boolean) => {
          if (kind === 'fatigue') this.fatigueAlert = next
          if (kind === 'focus') this.focusAlert = next
          if (kind === 'quality') this.qualityAlert = next
          if (kind === 'disconnect') this.disconnectAlert = next
        })
    }
    .width('100%')
    .height(48)
  }

  @Builder
  AlertSection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('预警设置', '这些选项只控制移动端提醒，核心状态判断仍由香橙派完成。')
      Column() {
        this.GlassCard('阈值')
        this.ThresholdRow('疲劳预警阈值', this.fatigueThreshold, 'fatigue')
        this.ThresholdRow('专注过低阈值', this.focusThreshold, 'focus')
        this.ThresholdRow('信号质量过低阈值', this.qualityThreshold, 'quality')
        this.ThresholdRow('置信度过低阈值', this.confidenceThreshold, 'confidence')
        Row({ space: 8 }) {
          ForEach([10, 30, 60], (delay: number) => {
            Button(`${delay}s`)
              .layoutWeight(1)
              .height(38)
              .fontColor(this.alertDelay === delay ? Colors.ON_PRIMARY : Colors.PRIMARY_DARK)
              .backgroundColor(this.alertDelay === delay ? Colors.PRIMARY : Colors.SURFACE_SOFT)
              .borderRadius(Dimensions.CARD_RADIUS_SM)
              .onClick(() => {
                this.alertDelay = delay
              })
          })
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .width('100%')
      .padding(Dimensions.CARD_PADDING_SM)
      .backgroundColor(Colors.GLASS_ACTIVE)
      .backgroundBlurStyle(BlurStyle.Thin)
      .border({ width: 1, color: Colors.GLASS_BORDER })
      .borderRadius(Dimensions.CARD_RADIUS_XL)

      Column() {
        this.GlassCard('提醒开关')
        this.ToggleRow('疲劳预警', this.fatigueAlert, 'fatigue')
        this.ToggleRow('低专注预警', this.focusAlert, 'focus')
        this.ToggleRow('低信号质量提醒', this.qualityAlert, 'quality')
        this.ToggleRow('设备断连提醒', this.disconnectAlert, 'disconnect')
      }
      .width('100%')
      .padding(Dimensions.CARD_PADDING_SM)
      .backgroundColor(Colors.GLASS_ACTIVE)
      .backgroundBlurStyle(BlurStyle.Thin)
      .border({ width: 1, color: Colors.GLASS_BORDER })
      .borderRadius(Dimensions.CARD_RADIUS_XL)
      this.NoteCard('预警策略用于控制移动端提醒行为，仅作为状态参考；核心状态判断仍由香橙派边缘处理端完成。')
    }
    .width('100%')
  }

  @Builder
  CollectionSection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('数据采集设置', '采集参数由香橙派统一管理，平板端仅提供配置入口。')
      this.InfoCard('采集参数', [
        ['采样率', '待扩展'],
        ['采样窗口', '待扩展'],
        ['数据帧格式', 'AA55'],
        ['校验方式', 'XOR 轻量校验'],
        ['当前数据源', this.dataSource],
        ['当前通道模式', '--'],
        ['当前运行模式', '--'],
        ['最近 sequence', this.sequence],
        ['最近更新时间', this.toAppUpdatedAt]
      ])
      Flex({ wrap: FlexWrap.Wrap }) {
        this.ActionButton('开始采集')
        this.ActionButton('停止采集')
        this.ActionButton('重新校准')
        this.ActionButton('切换测试数据源')
        this.ActionButton('切换真实采集模式')
      }
      .width('100%')
      this.NoteCard('关键采集参数由香橙派端统一管理，平板端仅提供可视化配置入口。')
    }
    .width('100%')
  }

  @Builder
  ModelSection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('模型与 AI 建议', '查看香橙派本地模型与建议生成状态。')
      this.InfoCard('本地模型', [
        ['当前模型名称', this.modelName],
        ['模型运行位置', '香橙派本地'],
        ['本地推理状态', this.modelStatus],
        ['AI 建议生成状态', this.modelStatus],
        ['最近建议生成时间', this.toAppUpdatedAt],
        ['state', this.stateText],
        ['direction', this.directionText],
        ['advice', '待扩展'],
        ['focus / fatigue / relax / load', '待扩展']
      ])
      Row() {
        Text('高精度分析')
          .fontSize(14)
          .fontColor(Colors.TEXT_PRIMARY)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.highPrecisionEnabled })
          .selectedColor(Colors.PRIMARY)
          .onChange((next: boolean) => {
            this.highPrecisionEnabled = next
          })
      }
      .width('100%')
      .padding(Dimensions.CARD_PADDING_SM)
      .backgroundColor(Colors.GLASS_ACTIVE)
      .borderRadius(Dimensions.CARD_RADIUS_MD)
      this.ActionButton('手动重新生成建议', '功能待接入香橙派 AI 服务接口')
      this.NoteCard('AI 建议由香橙派本地模型生成，平板端负责展示与管理建议生成策略。')
    }
    .width('100%')
  }

  @Builder
  MaintenanceSection() {
    Column({ space: Dimensions.STACK_GAP_MD }) {
      this.SectionTitle('日志与维护', '用于辅助系统调试、链路排查和运行记录导出。')
      this.InfoCard('运行状态', [
        ['最近运行日志', '待扩展'],
        ['最近连接日志', '待扩展'],
        ['最近预警日志', '待扩展'],
        ['最近数据更新时间', this.toAppUpdatedAt],
        ['最近异常类型', '--'],
        ['最近一次刷新结果', '--'],
        ['当前 ToApp.json 状态', this.dataFileStatus],
        ['当前数据读取路径', '待扩展']
      ])
      Flex({ wrap: FlexWrap.Wrap }) {
        this.ActionButton('查看运行日志')
        this.ActionButton('查看连接日志')
        this.ActionButton('查看预警日志')
        this.ActionButton('导出日志')
        this.ActionButton('清空本地缓存')
        this.ActionButton('恢复默认设置')
      }
      .width('100%')
      this.NoteCard('日志与维护页面用于辅助系统调试、链路排查和运行记录导出。')
    }
    .width('100%')
  }

  @Builder
  SectionContent() {
    if (this.activeSection === 0) {
      this.OverviewSection()
    } else if (this.activeSection === 1) {
      this.OrangePiSection()
    } else if (this.activeSection === 2) {
      this.CollectorSection()
    } else if (this.activeSection === 3) {
      this.AlertSection()
    } else if (this.activeSection === 4) {
      this.CollectionSection()
    } else if (this.activeSection === 5) {
      this.ModelSection()
    } else {
      this.MaintenanceSection()
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
