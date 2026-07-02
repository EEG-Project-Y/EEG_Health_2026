// 文件名：DeviceManager.ets
// 功能描述：设备模拟数据中心，提供 mockDeviceList、refreshDeviceList 等方法
import hilog from '@ohos.hilog'

// 设备数据接口
export interface DeviceData {
  id: string
  name: string
  isConnected: boolean
  lastSync: string
  battery: number
}

// 模拟设备列表
export let mockDeviceList: DeviceData[] = [
  { id: 'dev-01', name: '我的主设备', isConnected: true, lastSync: '刚刚', battery: 87 },
  { id: 'dev-02', name: '客厅脑电仪', isConnected: true, lastSync: '3 分钟前', battery: 62 },
  { id: 'dev-03', name: '书房检测器', isConnected: false, lastSync: '1 小时前', battery: 15 }
]

// 默认选中设备 id
export let selectedDeviceId: string = 'dev-01'

// 模拟刷新设备列表，返回 Promise 延时 2 秒后完成
export function refreshDeviceList(): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(() => {
      const now = new Date().toLocaleTimeString()
      for (let i = 0; i < mockDeviceList.length; i++) {
        if (mockDeviceList[i].isConnected) {
          mockDeviceList[i].lastSync = now
        }
      }
      hilog.info(0x0000, 'DeviceManager', '设备数据已刷新')
      resolve()
    }, 2000)
  })
}
