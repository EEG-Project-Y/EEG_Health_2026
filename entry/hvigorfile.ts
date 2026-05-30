/**
 * hvigorfile.ts - 模块级 Hvigor 构建任务配置
 *
 * 定义模块的构建系统任务和插件。
 * Hvigor 是 HarmonyOS 的官方构建系统，负责编译、打包、签名等流程。
 *
 * 配置说明：
 * - system：系统构建任务，hapTasks 包含 HAP 打包所需的所有默认任务
 * - plugins：自定义构建插件列表，可扩展构建流程
 */

// 导入 HAP 构建任务集合（包含编译、资源处理、打包等默认任务）
import { hapTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  // 系统构建任务：使用官方 HAP 打包任务
  system: hapTasks,
  // 自定义插件（当前为空，可按需添加混淆、代码检查等插件）
  plugins: []
}
