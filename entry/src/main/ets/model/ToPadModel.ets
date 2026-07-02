export interface ToPadFrame {
  sequence: number
  focus: number
  fatigue: number
  relax: number
  load: number
  quality: number
  confidence: number
  state: string
  direction: string
  advice: string
  alert: boolean
}

export interface DeviceConnection {
  deviceName: string
  isConnected: boolean
  technology: string
}

export interface ManagedDevice {
  id: string
  deviceName: string
  owner: string
  location: string
  isConnected: boolean
  technology: string
  battery: number
  lastSync: string
  frame: ToPadFrame
}

export interface RuntimeManagementState {
  edgeRole: string
  padRole: string
  edgeName: string
  edgeConnected: boolean
  padName: string
  linkMode: string
  toAppUpdatedAt: string
  dataSource: string
  baselineReady: boolean
  calibrationStatus: string
  calibrationCountdown: number
  labelingEnabled: boolean
  labelOptions: string[]
  modelVersion: string
  modelEnabled: boolean
  pollingIntervalMs: number
  logAvailable: boolean
  logSummary: string
  dataFileStatus: string
  modelStatus: string
  managementAvailable: boolean
}

export interface ToPadProfile {
  userName: string
  currentMode: string
  mainDevice: string
  terminal: string
  communication: string
  privacyText: string
  appName: string
  version: string
}
