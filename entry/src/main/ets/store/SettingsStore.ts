export const SettingsDefaults = {
  language: 0,
  autoReconnect: true,
  cloudSync: true,
  keepScreenOn: false,
  warningEnabled: true,
  focusThreshold: 40,
  fatigueThreshold: 80,
  qualityThreshold: 40,
  confidenceThreshold: 40,
  bgStyle: 0,
  managementQuery: false
};

export function initSettingsStorage(): void {
  if (!AppStorage.Has('language')) {
    AppStorage.SetOrCreate('language', SettingsDefaults.language);
  }
  AppStorage.SetOrCreate('autoReconnect', SettingsDefaults.autoReconnect);
  AppStorage.SetOrCreate('cloudSync', SettingsDefaults.cloudSync);
  AppStorage.SetOrCreate('keepScreenOn', SettingsDefaults.keepScreenOn);
  AppStorage.SetOrCreate('warningEnabled', SettingsDefaults.warningEnabled);
  AppStorage.SetOrCreate('focusThreshold', SettingsDefaults.focusThreshold);
  AppStorage.SetOrCreate('fatigueThreshold', SettingsDefaults.fatigueThreshold);
  AppStorage.SetOrCreate('qualityThreshold', SettingsDefaults.qualityThreshold);
  AppStorage.SetOrCreate('confidenceThreshold', SettingsDefaults.confidenceThreshold);
  AppStorage.SetOrCreate('bgStyle', SettingsDefaults.bgStyle);
  AppStorage.SetOrCreate('managementQuery', SettingsDefaults.managementQuery);
}
