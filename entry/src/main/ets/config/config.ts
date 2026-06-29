/**
 * 模拟机演示模式开关
 * 仅用于 DevEco 预览 / 模拟机 / 本地调试展示。
 * 真机打包前必须设为 false。
 */
export const SIMULATOR_DEMO_MODE: boolean = true;

export const AppConfig = {
  eegHttpEndpoints: [
    'http://127.0.0.1:18080/ToApp.json'
  ],
  eegLocalFiles: [
    '/data/eeg_health/runtime/ToApp.json',
    '/data/eeg_health/runtime/currentData.json'
  ]
};
