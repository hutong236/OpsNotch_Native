# 安全政策

## 支持范围

| 版本 | 状态 |
|---|---|
| 最新 GitHub Release | 接收安全修复 |
| main 分支 | 开发中 |
| 更早版本 | 建议先升级后复现 |

## 报告安全问题

请不要通过公开 Issue 披露可利用的漏洞、敏感数据或完整攻击步骤。

优先使用仓库的 GitHub Security Advisory 私密报告入口：

https://github.com/hutong236/OpsNotch_Native/security/advisories/new

如果该入口不可用，请通过维护者 GitHub 主页提供的联系方式发送最小必要信息，并注明“Ops Notch Security”。

报告建议包含：

- 受影响版本和 macOS 版本。
- 问题类型、影响范围与复现条件。
- 最小复现步骤或测试文件。
- 可行的缓解建议。
- 是否已在其他地方披露。

维护者确认问题前不会要求提交者公开细节。修复发布后，可在双方同意的范围内致谢报告者。

## 项目安全边界

Ops Notch 只允许打开本地绝对路径和 HTTP/HTTPS URL，不应执行 Shell、SSH、kubectl 或任意命令。任何绕过 SafeActionValidator、破坏数据目录隔离、导致剪贴板内容非预期泄露或引入未声明网络传输的行为，都应视为安全问题。