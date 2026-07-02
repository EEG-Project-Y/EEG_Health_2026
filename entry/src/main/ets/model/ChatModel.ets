export interface ChatMessage {
  id: string
  role: 'user' | 'assistant'
  content: string
  timestamp: number
}

export interface ChatSession {
  id: string
  title: string
  deviceName: string
  updatedAt: string
  messages: ChatMessage[]
}

export class ChatMock {
  static getSessions(): ChatSession[] {
    const now: number = Date.now()
    return [
      {
        id: 'session-current',
        title: '设备运行概览',
        deviceName: '全部设备',
        updatedAt: '刚刚',
        messages: [
          {
            id: 'welcome-current',
            role: 'assistant',
            content: '你好，我是 息枢AI 移动交互管理助手。\n\n我可以帮你查看设备状态、疲劳告警、信号质量、校准流程、训练标注和日志复盘。你想先看哪一项？',
            timestamp: now
          }
        ]
      },
      {
        id: 'session-fatigue',
        title: '03 号设备疲劳告警',
        deviceName: 'EEG 移动终端 03',
        updatedAt: '18 分钟前',
        messages: [
          {
            id: 'fatigue-user',
            role: 'user',
            content: '03 号设备为什么触发疲劳告警？',
            timestamp: now - 1080000
          },
          {
            id: 'fatigue-assistant',
            role: 'assistant',
            content: '03 号设备最近一次状态中，疲劳度为 77%，同时信号质量只有 46%。\n\n建议先在平板端检查连接与佩戴，并等待边缘端输出下一轮 ToApp.json 状态。若疲劳度仍高于 75%，应暂停训练安排。',
            timestamp: now - 1020000
          }
        ]
      },
      {
        id: 'session-compare',
        title: '多设备状态对比',
        deviceName: '全部设备',
        updatedAt: '今天 09:42',
        messages: [
          {
            id: 'compare-user',
            role: 'user',
            content: '对比当前三台设备的专注和疲劳状态。',
            timestamp: now - 7200000
          },
          {
            id: 'compare-assistant',
            role: 'assistant',
            content: '01 号设备状态最好：专注度 82%，疲劳度 18%。\n02 号设备出现轻度疲劳：专注度 67%，疲劳度 54%。\n03 号设备需要优先处理：疲劳度 77%，且目前离线。',
            timestamp: now - 7140000
          }
        ]
      }
    ]
  }
}

