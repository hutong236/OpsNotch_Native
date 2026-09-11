# App Termination Behavior

## Requirement: explicit termination MUST restore managed menu-bar items first

Before OpsNotch completes a real application termination, it MUST release its menu-bar hiding geometry so third-party menu-bar items can return to the visible system menu bar.

### Scenario: 退出时普通隐藏区处于收起状态

- Given 菜单栏管理已启用且当前状态为 `collapsed`
- When 用户从 OpsNotch 状态栏菜单选择“退出”
- Then OpsNotch 先展开普通隐藏区
- And 第三方菜单栏图标恢复到系统菜单栏可见区域
- And 随后应用完成正常终止

### Scenario: 退出时存在持续隐藏区域

- Given 持续隐藏区域已启用且其中存在第三方菜单栏图标
- When OpsNotch 收到正常终止请求
- Then 普通隐藏 Spacer 与持续隐藏 Spacer 都恢复为展开几何
- And 持续隐藏区域中的第三方图标不再被 OpsNotch 的 Spacer 隐藏
- And 随后应用完成正常终止

## Requirement: termination recovery MUST NOT overwrite the user's persisted menu-bar state

The temporary all-expanded geometry used during termination MUST NOT become the user's next-launch menu-bar preference.

### Scenario: 收起状态退出后重新启动

- Given 用户退出前保存的 `menuBarLastState` 为 `collapsed`
- When OpsNotch 为退出恢复图标并终止
- Then 持久化的 `menuBarLastState` 仍为 `collapsed`
- And 下次启动继续遵循用户原来的启动与菜单栏状态设置

## Requirement: termination recovery MUST cover normal system termination paths

The recovery MUST be coordinated from the application termination delegate rather than only from the status-menu action.

### Scenario: macOS 发起正常终止

- Given OpsNotch 正在管理菜单栏隐藏区域
- When macOS 因注销、关机或正常应用终止流程请求 OpsNotch 退出
- Then OpsNotch 执行同一菜单栏恢复保护
- And 清理菜单栏、拖拽与剪贴板服务后终止

## Requirement: ⌘Q hide behavior MUST remain unchanged

### Scenario: 用户按下 ⌘Q

- Given OpsNotch 正在运行
- When 用户按下 `⌘Q`
- Then OpsNotch 仅隐藏自身界面
- And 不进入真实 termination 流程
- And 不触发退出前菜单栏恢复
