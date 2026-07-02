import { DeviceConnection, ManagedDevice, RuntimeManagementState, ToPadFrame, ToPadProfile } from './ToPadModel'

export class ToPadMock {
  static getDevices(): ManagedDevice[] {
    return [
      {
        id: 'eeg-lab-01',
        deviceName: 'EEG_SLE_PAD 01',
        owner: '张同学',
        location: '认知实验室 A',
        isConnected: true,
        technology: 'SLE / 星闪',
        battery: 86,
        lastSync: '刚刚',
        frame: {
          sequence: 128,
          focus: 82,
          fatigue: 18,
          relax: 64,
          load: 31,
          quality: 91,
          confidence: 86,
          state: '专注',
          direction: 'stable',
          advice: '当前状态良好，建议保持节奏并定时休息。',
          alert: false
        }
      },
      {
        id: 'eeg-lab-02',
        deviceName: 'EEG_SLE_PAD 02',
        owner: '李同学',
        location: '认知实验室 B',
        isConnected: true,
        technology: 'SLE / 星闪',
        battery: 62,
        lastSync: '1 分钟前',
        frame: {
          sequence: 94,
          focus: 67,
          fatigue: 54,
          relax: 48,
          load: 58,
          quality: 84,
          confidence: 81,
          state: '轻度疲劳',
          direction: 'up',
          advice: '疲劳指标正在上升，建议完成本轮任务后休息 5 分钟。',
          alert: false
        }
      },
      {
        id: 'eeg-mobile-03',
        deviceName: 'EEG 移动终端 03',
        owner: '王老师',
        location: '训练室 2',
        isConnected: false,
        technology: 'SLE / 星闪',
        battery: 34,
        lastSync: '18 分钟前',
        frame: {
          sequence: 61,
          focus: 43,
          fatigue: 77,
          relax: 35,
          load: 72,
          quality: 46,
          confidence: 52,
          state: '需关注',
          direction: 'up',
          advice: '设备已离线且最近一次疲劳指标偏高，请确认佩戴状态并重新连接。',
          alert: true
        }
      }
    ]
  }

  static getCurrent(): ToPadFrame {
    return ToPadMock.getDevices()[0].frame
  }

  static getRuntimeState(): RuntimeManagementState {
    return {
      edgeRole: 'executor',
      padRole: 'interactive_manager',
      edgeName: '香橙派边缘执行端',
      edgeConnected: true,
      padName: '移动交互管理端',
      linkMode: 'basic_or_managed',
      toAppUpdatedAt: '刚刚',
      dataSource: 'ToApp.json（边缘端输出，当前为模拟状态）',
      baselineReady: false,
      calibrationStatus: '待校准',
      calibrationCountdown: 60,
      labelingEnabled: true,
      labelOptions: ['放松', '专注', '疲劳', '佩戴异常'],
      modelVersion: 'lightweight_eeg_classifier',
      modelEnabled: true,
      pollingIntervalMs: 1000,
      logAvailable: true,
      logSummary: 'AA55 帧解析正常，日志入口待接入真实文件服务',
      dataFileStatus: 'ToApp.json 等待轮询刷新',
      modelStatus: '小模型推理运行中（边缘端）',
      managementAvailable: true
    }
  }

  static getConnection(): DeviceConnection {
    const device: ManagedDevice = ToPadMock.getDevices()[0]
    return {
      deviceName: device.deviceName,
      isConnected: device.isConnected,
      technology: device.technology
    }
  }

  static getProfile(): ToPadProfile {
    return {
      userName: '默认用户',
      currentMode: '隐私同步模式',
      mainDevice: '香橙派边缘执行端',
      terminal: '移动交互管理端',
      communication: 'SLE / 星闪',
      privacyText: '香橙派负责脑电数据接收、AA55 帧解析、轻量特征提取、小模型推理、日志记录与 ToApp.json 输出；平板端负责查看、控制、校准、标注与复盘。',
      appName: 'EEG Pad Alert',
      version: 'V1.8 移动交互管理端'
    }
  }
}
