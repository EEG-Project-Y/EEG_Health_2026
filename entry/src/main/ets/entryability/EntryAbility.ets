import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { display, window } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
  }

  private updateTopSafeArea(mainWindow: window.Window): void {
    let topHeightPx: number = 0
    try {
      const systemArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      topHeightPx = Math.max(topHeightPx, systemArea.topRect.height)
    } catch (error) {
      console.warn('Failed to read system avoid area:', JSON.stringify(error))
    }
    try {
      const cutoutArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT)
      topHeightPx = Math.max(topHeightPx, cutoutArea.topRect.height)
    } catch (error) {
      console.warn('Failed to read cutout avoid area:', JSON.stringify(error))
    }
    let topHeightVp: number = topHeightPx
    try {
      const density: number = display.getDefaultDisplaySync().densityPixels
      if (density > 0) topHeightVp = topHeightPx / density
    } catch (error) {
      console.warn('Failed to read display density:', JSON.stringify(error))
    }
    AppStorage.setOrCreate<number>('safeAreaTop', topHeightVp)
  }

  private applyPreferredOrientation(mainWindow: window.Window): void {
    try {
      const isPhone: boolean = deviceInfo.deviceType === 'phone' || deviceInfo.deviceType === 'default'
      const orientation: window.Orientation = isPhone
        ? window.Orientation.PORTRAIT
        : window.Orientation.UNSPECIFIED
      mainWindow.setPreferredOrientation(orientation).catch((error: Error) => {
        console.warn('Failed to apply preferred orientation:', JSON.stringify(error))
      })
    } catch (error) {
      console.warn('Failed to detect device size for orientation:', JSON.stringify(error))
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      const mainWindow = windowStage.getMainWindowSync()
      mainWindow.setWindowLayoutFullScreen(true)
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: '#13243A',
        navigationBarContentColor: '#13243A',
        isStatusBarLightIcon: false,
        isNavigationBarLightIcon: false
      })
      this.applyPreferredOrientation(mainWindow)
      this.updateTopSafeArea(mainWindow)
      mainWindow.on('avoidAreaChange', (options: window.AvoidAreaOptions) => {
        if (options.type === window.AvoidAreaType.TYPE_SYSTEM ||
          options.type === window.AvoidAreaType.TYPE_CUTOUT) {
          this.updateTopSafeArea(mainWindow)
        }
      })
    } catch (error) {
      console.error('Failed to apply window safe-area style:', JSON.stringify(error))
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        console.error('Failed to load content:', JSON.stringify(err))
        return
      }
    })
  }
}
