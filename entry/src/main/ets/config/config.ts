/**
 * 模拟机演示模式开关
 * 仅用于 DevEco 预览 / 模拟机 / 本地调试展示。
 * 真机打包前必须设为 false。
 */
export const SIMULATOR_DEMO_MODE: boolean = false;

export const AppConfig = {
  enableMockFallback: true,
  managerBridgeBaseUrl: 'http://127.0.0.1:18080',
  eegHttpEndpoints: [
    'http://127.0.0.1:18080/ToApp.json'
  ],
  eegLocalFiles: [
    '/data/local/tmp/eeg_health/runtime/ToApp.json',
    '/data/eeg_health/runtime/ToApp.json',
    '/data/eeg_health/runtime/currentData.json'
  ]
};
