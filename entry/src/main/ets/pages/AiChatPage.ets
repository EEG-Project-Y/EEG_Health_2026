import { Colors } from '../constants/Colors'
import { Dimensions } from '../constants/Dimensions'
import { ChatMessage, ChatMock, ChatSession } from '../model/ChatModel'

@Component
export struct AiChatPage {
  @State sessions: ChatSession[] = ChatMock.getSessions()
  @State activeSessionId: string = 'session-current'
  @State inputText: string = ''
  @State sw: number = 360
  @State isTyping: boolean = false
  @State isHistoryOpen: boolean = false
  @State drawerProgress: number = 0
  @State isDrawerDragging: boolean = false
  private scrollController: Scroller = new Scroller()
  private replyTimer: number = -1

  aboutToDisappear(): void {
    if (this.replyTimer >= 0) {
      clearTimeout(this.replyTimer)
      this.replyTimer = -1
    }
  }

  private isWide(): boolean {
    return this.sw >= 820
  }

  private isNarrow(): boolean {
    return this.sw < Dimensions.BREAKPOINT_TABLET
  }

  private chatPaneWidth(): number {
    const sidebarWidth: number = this.isWide() ? 284 : 0
    return Math.max(320, this.sw - sidebarWidth)
  }

  private messageSidePadding(): number {
    if (this.isNarrow()) return 14
    if (this.isWide()) return 40
    return 24
  }

  private userBubbleMaxWidth(): number {
    const paneWidth: number = this.chatPaneWidth()
    if (this.isNarrow()) return Math.max(220, paneWidth - 52)
    return Math.min(560, Math.floor(paneWidth * 0.68))
  }

  private assistantBubbleMaxWidth(): number {
    const paneWidth: number = this.chatPaneWidth()
    if (this.isNarrow()) return Math.max(248, paneWidth - 36)
    return Math.min(760, Math.floor(paneWidth * 0.78))
  }

  private sidebarWidth(): number {
    if (this.isNarrow()) return Math.min(300, Math.floor(this.sw * 0.86))
    return 284
  }

  private composerMaxWidth(): number {
    return this.isNarrow() ? Math.max(280, this.sw - 28) : 920
  }

  private clampDrawerProgress(value: number): number {
    return Math.max(0, Math.min(1, value))
  }

  private openHistoryDrawer(): void {
    if (this.isWide()) return
    this.isHistoryOpen = true
    this.isDrawerDragging = false
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.drawerProgress = 1
    })
  }

  private closeHistoryDrawer(): void {
    if (this.isWide()) return
    this.isDrawerDragging = false
    animateTo({
      duration: 200,
      curve: Curve.EaseOut,
      onFinish: () => {
        this.isHistoryOpen = false
      }
    }, () => {
      this.drawerProgress = 0
    })
  }

  private beginDrawerGesture(opening: boolean): void {
    if (this.isWide()) return
    this.isHistoryOpen = true
    this.isDrawerDragging = true
    this.drawerProgress = opening ? 0 : 1
  }

  private updateDrawerGesture(offsetX: number, opening: boolean): void {
    const width: number = Math.max(1, this.sidebarWidth())
    const progress: number = opening ? offsetX / width : 1 + offsetX / width
    this.drawerProgress = this.clampDrawerProgress(progress)
  }

  private finishDrawerGesture(velocityX: number): void {
    const shouldOpen: boolean = velocityX > 650 ||
      (velocityX >= -650 && this.drawerProgress >= 0.42)
    this.isDrawerDragging = false
    if (shouldOpen) {
      this.openHistoryDrawer()
    } else {
      this.closeHistoryDrawer()
    }
  }

  private activeSessionIndex(): number {
    for (let i: number = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].id === this.activeSessionId) return i
    }
    return 0
  }

  private activeSession(): ChatSession {
    return this.sessions[this.activeSessionIndex()]
  }

  private replaceSession(session: ChatSession): void {
    const next: ChatSession[] = []
    for (let i: number = 0; i < this.sessions.length; i++) {
      next.push(this.sessions[i].id === session.id ? session : this.sessions[i])
    }
    this.sessions = next
  }

  private selectSession(id: string): void {
    this.activeSessionId = id
    this.inputText = ''
    this.closeHistoryDrawer()
    this.scrollToBottom()
  }

  private newChat(): void {
    if (this.isTyping) return
    const id: string = `session-${Date.now()}`
    const session: ChatSession = {
      id: id,
      title: '新建分析',
      deviceName: '全部设备',
      updatedAt: '刚刚',
      messages: [
        {
          id: `welcome-${Date.now()}`,
          role: 'assistant',
          content: '你好，我是 息枢AI 移动交互管理助手。你可以问我设备状态、疲劳告警、训练安排、校准、标注或日志复盘。',
          timestamp: Date.now()
        }
      ]
    }
    this.sessions = [session, ...this.sessions]
    this.activeSessionId = id
    this.inputText = ''
    this.closeHistoryDrawer()
    this.scrollToTop()
  }

  private clearChat(): void {
    if (this.isTyping) return
    const current: ChatSession = this.activeSession()
    this.replaceSession({
      id: current.id,
      title: '新建分析',
      deviceName: current.deviceName,
      updatedAt: '刚刚',
      messages: [
        {
          id: `clear-${Date.now()}`,
          role: 'assistant',
          content: '对话已清空。你可以继续询问设备状态、疲劳告警或训练安排。',
          timestamp: Date.now()
        }
      ]
    })
    this.scrollToTop()
  }

  private appendMessage(sessionId: string, message: ChatMessage): void {
    for (let i: number = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].id === sessionId) {
        const item: ChatSession = this.sessions[i]
        this.replaceSession({
          id: item.id,
          title: item.title,
          deviceName: item.deviceName,
          updatedAt: '刚刚',
          messages: [...item.messages, message]
        })
        return
      }
    }
  }

  private sendMessage(text: string): void {
    const content: string = text.trim()
    if (content.length === 0 || this.isTyping) return

    const current: ChatSession = this.activeSession()
    const nextTitle: string = current.messages.length <= 1
      ? (content.length > 14 ? content.substring(0, 14) + '…' : content)
      : current.title
    const session: ChatSession = {
      id: current.id,
      title: nextTitle,
      deviceName: current.deviceName,
      updatedAt: '刚刚',
      messages: [
        ...current.messages,
        {
          id: `user-${Date.now()}`,
          role: 'user',
          content: content,
          timestamp: Date.now()
        }
      ]
    }
    this.replaceSession(session)
    this.inputText = ''
    this.scrollToBottom()
    this.startReply(session.id, content)
  }

  private startReply(sessionId: string, input: string): void {
    this.isTyping = true
    const reply: string = this.generateReply(input)
    this.replyTimer = setTimeout(() => {
      this.appendMessage(sessionId, {
        id: `assistant-${Date.now()}`,
        role: 'assistant',
        content: reply,
        timestamp: Date.now()
      })
      this.isTyping = false
      this.replyTimer = -1
      this.scrollToBottom()
    }, 600)
  }

  private stopReply(): void {
    if (!this.isTyping) return
    if (this.replyTimer >= 0) clearTimeout(this.replyTimer)
    this.replyTimer = -1
    this.isTyping = false
    this.appendMessage(this.activeSessionId, {
      id: `stop-${Date.now()}`,
      role: 'assistant',
      content: '已停止生成。你可以补充条件后继续提问。',
      timestamp: Date.now()
    })
  }

  private regenerate(): void {
    if (this.isTyping) return
    const messages: ChatMessage[] = this.activeSession().messages
    for (let i: number = messages.length - 1; i >= 0; i--) {
      if (messages[i].role === 'user') {
        this.startReply(this.activeSessionId, messages[i].content)
        return
      }
    }
  }

  private generateReply(input: string): string {
    const lower: string = input.toLowerCase()
    if (lower.includes('链路')) {
      return '当前链路状态：\n\n边缘端在线，负责 AA55 帧解析、轻量特征提取、小模型推理、日志记录与 ToApp.json 输出。\n\n平板端定位为移动交互管理端，负责查看设备状态、控制采集流程、引导校准、辅助标注和复盘。'
    }
    if (lower.includes('校准') || lower.includes('baseline')) {
      return '静息基线校准入口已预留。当前 baselineReady 为 false，建议接入 60 秒静息采集倒计时，由边缘端输出校准状态，平板端负责引导用户、展示倒计时和保存结果。'
    }
    if (lower.includes('标注')) {
      return '训练数据标注入口已预留。可选标签包括：放松、专注、疲劳、佩戴异常。平板端负责交互标注和复盘展示，边缘端继续负责后台数据处理与日志输出。'
    }
    if (lower.includes('日志') || lower.includes('模型')) {
      return '日志与模型状态：边缘端负责记录运行日志、数据文件状态和轻量模型推理状态；平板端负责查看日志入口、模型版本和轮询频率。当前模型版本为 lightweight_eeg_classifier。'
    }
    if (lower.includes('对比') || lower.includes('多台') || lower.includes('全部')) {
      return '多设备对比：\n\n1. EEG_SLE_PAD 01 状态最好：专注 82%，疲劳 18%，信号质量 91%。\n2. EEG_SLE_PAD 02 出现轻度疲劳：专注 67%，疲劳 54%，建议本轮结束后休息。\n3. EEG 移动终端 03 需要优先处理：专注 43%，疲劳 77%，并且处于离线状态。'
    }
    if (lower.includes('疲劳') || lower.includes('告警')) {
      return '疲劳告警管理建议：\n\n03 号设备最近一次状态中，疲劳度为 77%，同时信号质量只有 46%。建议暂停对应训练安排，检查电极接触和设备连接，再等待下一轮状态复核。'
    }
    if (lower.includes('离线') || lower.includes('连接')) {
      return '连接排查建议：先检查 03 号设备电量、星闪状态和距离，确认边缘执行端在线，并查看 ToApp.json 最近更新时间。连接恢复后建议等待 2 分钟稳定状态。'
    }
    if (lower.includes('训练') || lower.includes('专注')) {
      return '训练交互管理建议：优先使用 01 号设备开展训练；02 号设备适合短时训练并增加休息；03 号设备在恢复连接和复测前不建议继续使用。'
    }
    if (lower.includes('信号') || lower.includes('质量')) {
      return '信号质量判断：01 和 02 号设备信号质量均高于 80%，适合做趋势判断；03 号设备质量为 46%，请先调整电极接触并重新采样。'
    }
    return '我已收到。当前最值得关注的是 03 号设备：它处于离线状态，最近一次疲劳 77%、信号质量 46%。建议先恢复连接、查看日志并完成必要标注，再等待边缘端输出新的 ToApp.json 状态。'
  }

  private formatTime(ts: number): string {
    const d: Date = new Date(ts)
    const h: string = d.getHours().toString().padStart(2, '0')
    const m: string = d.getMinutes().toString().padStart(2, '0')
    return `${h}:${m}`
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      this.scrollController.scrollTo({ xOffset: 0, yOffset: 9999 })
    }, 50)
  }

  private scrollToTop(): void {
    setTimeout(() => {
      this.scrollController.scrollTo({ xOffset: 0, yOffset: 0 })
    }, 50)
  }

  @Builder
  GlassIconButton(text: string, action: string) {
    Row() {
      Text(text)
        .fontSize(action === 'clear' ? 13 : 18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.PRIMARY_DARK)
        .textAlign(TextAlign.Center)
    }
    .width(40)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#E3FFFFFF')
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius(Dimensions.PILL_RADIUS)
    .shadow({ radius: 12, color: '#10000000', offsetX: 0, offsetY: 4 })
    .onClick(() => {
      if (action === 'open') {
        this.openHistoryDrawer()
      } else if (action === 'close') {
        this.closeHistoryDrawer()
      } else if (action === 'clear') {
        this.clearChat()
      }
    })
  }

  @Builder
  SessionItem(session: ChatSession) {
    Column() {
      Row() {
        Column() {
          Text(session.title)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.activeSessionId === session.id ? Colors.PRIMARY_DARK : Colors.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(`${session.deviceName} · ${session.updatedAt}`)
            .fontSize(10)
            .fontColor(Colors.TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .backgroundColor(this.activeSessionId === session.id ? Colors.INFO_CONTAINER : '#00FFFFFF')
    .border({
      width: 1,
      color: this.activeSessionId === session.id ? Colors.OUTLINE : '#00FFFFFF'
    })
    .borderRadius(Dimensions.CARD_RADIUS_SM)
    .margin({ bottom: 4 })
    .onClick(() => this.selectSession(session.id))
  }

  @Builder
  Sidebar(isOverlay: boolean) {
    Column() {
      Row() {
        Column() {
          Text('息枢AI')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
          Text('聊天记录')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (isOverlay) {
          this.GlassIconButton('×', 'close')
        }
      }
      .width('100%')
      .margin({ bottom: 18 })

      Button() {
        Row() {
          Text('新建对话')
            .fontSize(13)
            .fontColor(Colors.ON_PRIMARY)
            .fontWeight(FontWeight.Bold)
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .width('100%')
      }
      .width('100%')
      .height(44)
      .backgroundColor('#1677FF')
      .border({ width: 1, color: '#1468DD' })
      .borderRadius(Dimensions.PILL_RADIUS)
      .margin({ bottom: 14 })
      .shadow({ radius: 10, color: '#301677FF', offsetX: 0, offsetY: 4 })
      .onClick(() => this.newChat())

      Scroll() {
        Column() {
          ForEach(this.sessions, (session: ChatSession) => {
            this.SessionItem(session)
          }, (session: ChatSession) => session.id)
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)

      Text('仅供辅助管理参考')
        .fontSize(10)
        .fontColor(Colors.TEXT_TERTIARY)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 12 })
    }
    .width(this.sidebarWidth())
    .height('100%')
    .padding({ left: 16, right: 16, top: isOverlay ? 20 : 18, bottom: 22 })
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#E6FFFFFF')
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Colors.GLASS_BORDER })
    .borderRadius({
      topLeft: 0,
      topRight: isOverlay ? Dimensions.CARD_RADIUS_LG : 0,
      bottomLeft: 0,
      bottomRight: isOverlay ? Dimensions.CARD_RADIUS_LG : 0
    })
    .shadow({ radius: isOverlay ? 28 : 0, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 6 })
  }

  @Builder
  HeaderBar() {
    Row({ space: 12 }) {
      if (!this.isWide()) {
        this.GlassIconButton('☰', 'open')
      }

      Column() {
        Text(this.activeSession().title)
          .fontSize(this.isNarrow() ? 17 : 19)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`引用：${this.activeSession().deviceName}`)
          .fontSize(this.isNarrow() ? 10 : 11)
          .fontColor(Colors.TEXT_TERTIARY)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Start)

      this.GlassIconButton('清', 'clear')
    }
    .width('100%')
    .height(this.isNarrow() ? 64 : 70)
    .padding({
      left: this.isNarrow() ? 14 : 24,
      right: this.isNarrow() ? 14 : 24,
      top: 10,
      bottom: 8
    })
    .backgroundColor('#00FFFFFF')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  MessageRow(message: ChatMessage) {
    if (message.role === 'user') {
      Row() {
        Text(message.content)
          .fontSize(this.isNarrow() ? 14 : 15)
          .fontColor(Colors.ON_PRIMARY)
          .lineHeight(this.isNarrow() ? 21 : 24)
          .constraintSize({ maxWidth: this.userBubbleMaxWidth() })
          .padding({ left: 17, right: 17, top: 12, bottom: 12 })
          .backgroundColor('#E61677FF')
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: '#661677FF' })
          .borderRadius({ topLeft: 20, topRight: 20, bottomLeft: 20, bottomRight: 7 })
          .shadow({ radius: 14, color: '#201677FF', offsetX: 0, offsetY: 3 })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ left: this.messageSidePadding(), right: this.messageSidePadding() })
      .margin({ top: 12 })
    } else {
      Row() {
        Column({ space: 6 }) {
          Text(message.content)
            .fontSize(this.isNarrow() ? 14 : 15)
            .fontColor(Colors.TEXT_PRIMARY)
            .lineHeight(this.isNarrow() ? 22 : 25)
            .constraintSize({ maxWidth: this.assistantBubbleMaxWidth() })
            .padding({ left: 17, right: 17, top: 13, bottom: 13 })
            .backgroundColor('#D9FFFFFF')
            .backgroundBlurStyle(BlurStyle.Thin)
            .border({ width: 1, color: Colors.GLASS_BORDER })
            .borderRadius({ topLeft: 7, topRight: 20, bottomLeft: 20, bottomRight: 20 })
            .shadow({ radius: 12, color: Colors.SOFT_SHADOW, offsetX: 0, offsetY: 3 })

          Row({ space: 5 }) {
            Text(this.formatTime(message.timestamp))
              .fontSize(10)
              .fontColor(Colors.TEXT_TERTIARY)
              .height(23)
              .padding({ left: 8, right: 8 })
              .backgroundColor('#F4FFFFFF')
              .backgroundBlurStyle(BlurStyle.Thin)
              .border({ width: 1, color: Colors.GLASS_BORDER })
              .borderRadius(Dimensions.PILL_RADIUS)

            Text('重新生成')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.PRIMARY_DARK)
              .height(23)
              .padding({ left: 9, right: 9 })
              .backgroundColor('#F4FFFFFF')
              .backgroundBlurStyle(BlurStyle.Thin)
              .border({ width: 1, color: Colors.GLASS_BORDER })
              .borderRadius(Dimensions.PILL_RADIUS)
              .onClick(() => this.regenerate())
          }
        }
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: this.assistantBubbleMaxWidth() })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: this.messageSidePadding(), right: this.messageSidePadding() })
      .alignItems(VerticalAlign.Top)
      .margin({ top: 12 })
    }
  }

  @Builder
  SuggestionChips() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(['查看当前链路', '静息基线校准', '训练数据标注', '日志与模型状态'], (item: string) => {
        Text(item)
          .fontSize(this.isNarrow() ? 11 : 12)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.PRIMARY_DARK)
          .padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .backgroundColor('#E8FFFFFF')
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: Colors.GLASS_BORDER })
          .borderRadius(Dimensions.PILL_RADIUS)
          .shadow({ radius: 10, color: '#0D000000', offsetX: 0, offsetY: 3 })
          .margin({ right: 8, top: 8 })
          .onClick(() => this.sendMessage(item))
      })
    }
    .width('100%')
    .padding({ left: this.messageSidePadding(), right: this.messageSidePadding(), top: 4, bottom: 8 })
  }

  @Builder
  TypingRow() {
    Row() {
      Text('AI 正在思考...')
        .fontSize(13)
        .fontColor(Colors.TEXT_SECONDARY)
        .padding({ left: 17, right: 17, top: 11, bottom: 11 })
        .backgroundColor('#D9FFFFFF')
        .backgroundBlurStyle(BlurStyle.Thin)
        .border({ width: 1, color: Colors.GLASS_BORDER })
        .borderRadius({ topLeft: 7, topRight: 20, bottomLeft: 20, bottomRight: 20 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .padding({ left: this.messageSidePadding(), right: this.messageSidePadding(), top: 12 })
  }

  @Builder
  Composer() {
    Row() {
      Row() {
        TextInput({ placeholder: '询问 息枢AI', text: this.inputText })
          .height(48)
          .layoutWeight(1)
          .fontSize(16)
          .fontColor(Colors.TEXT_PRIMARY)
          .placeholderColor('#8A8A8A')
          .backgroundColor('#00FFFFFF')
          .padding({ left: 0, right: 0 })
          .onChange((value: string) => {
            this.inputText = value
          })
          .onSubmit(() => {
            this.sendMessage(this.inputText)
          })

        Stack({ alignContent: Alignment.Center }) {
          if (this.isTyping) {
            Text('■')
              .fontSize(12)
              .fontColor(Colors.ON_PRIMARY)
              .width(44)
              .height(44)
              .lineHeight(44)
              .textAlign(TextAlign.Center)
          } else {
            Text('↑')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.ON_PRIMARY)
              .width(44)
              .height(44)
              .lineHeight(44)
              .textAlign(TextAlign.Center)
          }
        }
        .width(44)
        .height(44)
        .backgroundColor(this.isTyping ? '#E5484D' : '#1677FF')
        .border({ width: 1, color: this.isTyping ? '#CF3D45' : '#1468DD' })
        .borderRadius(22)
        .margin({ left: 10 })
        .shadow({ radius: 12, color: this.isTyping ? '#30E5484D' : '#301677FF', offsetX: 0, offsetY: 4 })
        .onClick(() => {
          if (this.isTyping) {
            this.stopReply()
          } else {
            this.sendMessage(this.inputText)
          }
        })
      }
      .width('100%')
      .constraintSize({ maxWidth: this.composerMaxWidth() })
      .height(66)
      .padding({ left: this.isNarrow() ? 18 : 24, right: 10 })
      .backgroundColor('#E8FFFFFF')
      .backgroundBlurStyle(BlurStyle.Thin)
      .border({ width: 1, color: Colors.GLASS_BORDER })
      .borderRadius(24)
      .shadow({ radius: 28, color: '#16000000', offsetX: 0, offsetY: 10 })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 16 })
    .backgroundColor('#00FFFFFF')
    .margin({ bottom: this.isNarrow() ? 66 : 88 })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ChatArea() {
    Column() {
      this.HeaderBar()

      Scroll(this.scrollController) {
        Column() {
          ForEach(this.activeSession().messages, (message: ChatMessage) => {
            this.MessageRow(message)
          }, (message: ChatMessage) => message.id)

          if (this.isTyping) {
            this.TypingRow()
          }

          if (this.activeSession().messages.length <= 1) {
            this.SuggestionChips()
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
        .padding({ top: 6, bottom: 14 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)

      this.Composer()
    }
    .layoutWeight(1)
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#00FFFFFF')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row() {
        if (this.isWide()) {
          this.Sidebar(false)
        }
        this.ChatArea()
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Top)

      if (!this.isWide()) {
        Row()
          .width(24)
          .height('100%')
          .backgroundColor('#00FFFFFF')
          .gesture(
            PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 2 })
              .onActionStart(() => {
                if (!this.isHistoryOpen) this.beginDrawerGesture(true)
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.isDrawerDragging) this.updateDrawerGesture(event.offsetX, true)
              })
              .onActionEnd((event: GestureEvent) => {
                if (this.isDrawerDragging) this.finishDrawerGesture(event.velocityX)
              })
              .onActionCancel(() => {
                if (this.isDrawerDragging) this.finishDrawerGesture(0)
              })
          )
      }

      if (!this.isWide() && this.isHistoryOpen) {
        Stack({ alignContent: Alignment.TopStart }) {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('#33000000')
            .opacity(this.drawerProgress)
            .onClick(() => {
              this.closeHistoryDrawer()
            })

          Row() {
            this.Sidebar(true)
          }
          .width(this.sidebarWidth())
          .height('100%')
          .translate({ x: -this.sidebarWidth() * (1 - this.drawerProgress) })
          .gesture(
            PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 2 })
              .onActionStart(() => {
                this.beginDrawerGesture(false)
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.isDrawerDragging) this.updateDrawerGesture(event.offsetX, false)
              })
              .onActionEnd((event: GestureEvent) => {
                if (this.isDrawerDragging) this.finishDrawerGesture(event.velocityX)
              })
              .onActionCancel(() => {
                if (this.isDrawerDragging) this.finishDrawerGesture(0)
              })
          )
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BACKGROUND)
    .linearGradient({
      angle: 135,
      colors: [[Colors.BACKGROUND, 0.0], [Colors.BACKGROUND_DEEP, 0.55], ['#FFFFFF', 1.0]]
    })
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = typeof newArea.width === 'string' ? parseFloat(newArea.width as string) : (newArea.width as number)
      if (w > 0) {
        this.sw = w
        if (w >= 820) {
          this.isHistoryOpen = false
          this.isDrawerDragging = false
          this.drawerProgress = 0
        }
      }
    })
  }
}










