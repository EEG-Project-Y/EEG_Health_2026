export const SettingsDefaults = {
  language: 0,
  autoReconnect: true,
  cloudSync: true,
  keepScreenOn: false,
  focusThreshold: 40,
  fatigueThreshold: 80,
  bgStyle: 0
};

export function initSettingsStorage(): void {
  AppStorage.SetOrCreate('language', SettingsDefaults.language);
  AppStorage.SetOrCreate('autoReconnect', SettingsDefaults.autoReconnect);
  AppStorage.SetOrCreate('cloudSync', SettingsDefaults.cloudSync);
  AppStorage.SetOrCreate('keepScreenOn', SettingsDefaults.keepScreenOn);
  AppStorage.SetOrCreate('focusThreshold', SettingsDefaults.focusThreshold);
  AppStorage.SetOrCreate('fatigueThreshold', SettingsDefaults.fatigueThreshold);
  AppStorage.SetOrCreate('bgStyle', SettingsDefaults.bgStyle);
}
