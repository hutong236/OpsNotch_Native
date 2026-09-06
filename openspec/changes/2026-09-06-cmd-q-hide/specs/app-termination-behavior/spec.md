# App Termination Behavior

## Requirement: ⌘Q MUST hide instead of terminate

When OpsNotch receives the standard `⌘Q` application command, it MUST hide its UI and MUST NOT terminate the process.

### Scenario: 用户误按 ⌘Q

- Given OpsNotch 正在运行且界面可见
- When 用户按下 `⌘Q`
- Then OpsNotch 界面被隐藏
- And OpsNotch 进程保持运行
- And 状态栏图标保持可用
- And 常驻服务继续运行

## Requirement: explicit status-menu quit MUST terminate

The explicit “退出” action in the OpsNotch status menu MUST terminate the process.

### Scenario: 用户明确退出

- Given OpsNotch 正在运行
- When 用户从 OpsNotch 状态栏菜单选择“退出”
- Then 应用执行正常终止流程
- And `applicationWillTerminate` 清理逻辑正常执行

## Requirement: system termination MUST remain unaffected

The `⌘Q` protection MUST NOT globally cancel application termination requests.

### Scenario: 系统终止应用

- Given macOS 正在执行正常的系统级应用终止流程
- When OpsNotch 收到系统终止请求
- Then 应用不得因 `⌘Q` 防误退逻辑而取消该请求
