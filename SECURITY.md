# Security Policy

Better Traffic Lights uses macOS Accessibility permission to read the positions of visible windows and activate their standard close, minimize, and zoom buttons. When you choose Check for Updates, Sparkle checks a signed update feed hosted on the project's GitHub Releases over HTTPS. New versions can be downloaded, verified, installed, and relaunched from the update window. Both the feed and update archive must pass Ed25519 signature verification using the public key embedded in the app. Background checking and unattended installation are disabled by default. The app contains no data collection or telemetry code.

Please do not disclose unresolved security vulnerabilities in public Issues. Submit reports through the repository's [GitHub Private Vulnerability Reporting](https://github.com/drfcy/Better-Traffic-Lights/security/advisories/new) and include:

- Affected versions;
- Steps to reproduce;
- Potential impact;
- A suggested fix, if available.

After confirming a report, the maintainers will coordinate remediation and the disclosure timeline.

## 简体中文

Better Traffic Lights 使用 macOS 辅助功能权限读取可见窗口的位置，并触发标准关闭、最小化和缩放按钮。用户选择“检查更新”时，Sparkle 通过 HTTPS 读取项目 GitHub Releases 上的签名更新源，并可在更新窗口中下载、验证、安装新版并重新启动。更新源和安装包均须通过应用内置公钥的 Ed25519 签名校验。默认关闭后台检查和无人值守安装。应用不包含数据收集或遥测代码。

请不要在公开 Issue 中披露未修复的安全问题。请使用仓库的 [GitHub Private Vulnerability Reporting](https://github.com/drfcy/Better-Traffic-Lights/security/advisories/new) 提交，并提供：

- 受影响版本；
- 可复现步骤；
- 潜在影响；
- 建议修复方式（如有）。

维护者确认问题后会协调修复和披露时间。
