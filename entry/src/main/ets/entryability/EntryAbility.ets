/**
 * EntryAbility - 应用主入口 Ability
 *
 * HarmonyOS Stage 模型的核心入口组件，负责：
 * 1. 应用生命周期管理（创建、销毁、前后台切换）
 * 2. 窗口创建与页面加载
 * 3. 全局初始化配置
 *
 * 生命周期流程：
 *   onCreate → onWindowStageCreate → onForeground
 *   → onBackground → onWindowStageDestroy → onDestroy
 */

// 导入 HarmonyOS Ability 框架核心类型
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
// 导入窗口管理模块，用于控制应用窗口行为
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  /**
   * Ability 创建回调
   * 应用首次启动时调用，用于执行一次性初始化操作
   * @param want - 启动意图，包含启动参数和来源信息
   * @param launchParam - 启动参数，包含启动原因等
   */
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 可在此处添加：数据库初始化、全局配置加载、日志系统初始化等
  }

  /**
   * 窗口舞台创建回调（Stage 模型核心方法）
   * 系统准备好窗口环境后调用，负责加载主页面内容
   * @param windowStage - 窗口舞台实例，管理应用窗口生命周期
   */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 加载主页面：将 Index 页面渲染到窗口上
    // 'pages/Index' 对应 main_pages.json 中注册的页面路径
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        // 页面加载失败时输出错误信息，便于问题定位
        console.error(`Failed to load page. Code is ${err.code}, message is ${err.message}`);
      }
    });
  }
}
