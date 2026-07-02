import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import hilog from '@ohos.hilog'
import preferences from '@ohos.data.preferences'

interface CommandItem {
  type: 'page' | 'action'
  target: string
  keywords: string[]
}

const COMMAND_DATABASE: CommandItem[] = [
  { type: 'page', target: 'pages/Home', keywords: ['首页', '主页', '主界面', 'home', 'main'] },
  { type: 'page', target: 'pages/Profile', keywords: ['我的', '个人中心', 'profile', 'account'] },
  { type: 'page', target: 'pages/Settings', keywords: ['设置', '设定', 'settings'] },
  { type: 'action', target: 'refreshData', keywords: ['刷新', '重新加载', 'refresh', 'reload'] },
  { type: 'action', target: 'clearCache', keywords: ['清理缓存', '清除缓存', 'cache'] },
  { type: 'action', target: 'toggleTheme', keywords: ['夜间模式', '深色模式', 'dark mode'] },
]

function matchCommand(input: string): CommandItem | null {
  const lowerInput: string = input.toLowerCase()
  for (const item of COMMAND_DATABASE) {
    for (const keyword of item.keywords) {
      if (lowerInput === keyword.toLowerCase()) {
        return item
      }
    }
  }
  for (const item of COMMAND_DATABASE) {
    for (const keyword of item.keywords) {
      if (lowerInput.includes(keyword.toLowerCase())) {
        return item
      }
    }
  }
  return null
}

function pushPage(route: string, params?: object): void {
  router.pushUrl({
    url: route,
    params: params
  }).catch((err: Error) => {
    hilog.error(0x0000, 'CommandDispatcher', `跳转失败: ${err.message}`)
    promptAction.showToast({
      message: '未找到该页面，请检查路由配置',
      duration: 2000
    })
  })
}

class ViewModelBridge {
  static refreshData(): void {
    hilog.info(0x0000, 'Action', '执行了刷新数据')
  }
  static clearCache(): void {
    hilog.info(0x0000, 'Action', '执行了清除缓存')
  }
  static toggleTheme(): void {
    hilog.info(0x0000, 'Action', '执行了切换主题')
  }
}

function executeAction(actionName: string): boolean {
  switch (actionName) {
    case 'refreshData':
      ViewModelBridge.refreshData()
      return true
    case 'clearCache':
      hilog.warn(0x0000, 'CommandDispatcher', `未知功能: ${actionName}`)
      return true
    case 'toggleTheme':
      ViewModelBridge.toggleTheme()
      return true
    default:
      hilog.warn(0x0000, 'CommandDispatcher', `鏈煡鍔熻兘: ${actionName}`)
      return false
  }
}

  hilog.info(0x0000, 'Analytics', `指令: ${command}, 结果: ${result}`)
  hilog.info(0x0000, 'Analytics', `鎸囦护: ${command}, 缁撴灉: ${result}`)
  try {
    const context = getContext()
    const prefs = await preferences.getPreferences(context, 'command_history')
    let history: string[] = await prefs.get('history', []) as string[]
    const entry = `${new Date().toLocaleTimeString()} - ${command} (${result})`
    history.unshift(entry)
    if (history.length > 20) history.pop()
    await prefs.put('history', history)
    await prefs.flush()
  } catch (e) {
    hilog.error(0x0000, 'Analytics', `瀛樺偍澶辫触: ${JSON.stringify(e)}`)
    hilog.error(0x0000, 'Analytics', `存储失败: ${JSON.stringify(e)}`)
}

export function handleUserCommand(input: string): void {
  if (!input || input.trim().length === 0) {
    promptAction.showToast({ message: '请输入指令' })
    return
  }

  const matched: CommandItem | null = matchCommand(input.trim())
  if (!matched) {
    promptAction.showToast({ message: '未匹配到相关功能，请稍后再试' })
    trackLog(input, 'failed_no_match')
    return
  }

  let execSuccess: boolean = false
  if (matched.type === 'page') {
    pushPage(matched.target)
    execSuccess = true
  } else if (matched.type === 'action') {
    execSuccess = executeAction(matched.target)
  }

  promptAction.showToast({
    message: execSuccess ? '执行成功' : '执行失败，请查看日志',
    duration: 1500
  })

  trackLog(input, execSuccess ? 'success' : 'failed')
}
