# Contributing

Thank you for your interest in contributing to Better Traffic Lights.

## Development workflow

1. Fork the repository and create a feature branch from `main`.
2. Keep changes focused. Do not commit `.build/`, `build/`, or personal system files.
3. Run `swift test`.
4. Run `./scripts/build-app.sh` and verify the app signature.
5. Open a pull request describing the behavior changes and how you verified them.

For changes involving window discovery, button behavior, or multi-display handling, add relevant tests and verify the changes with real macOS windows.

## 简体中文

感谢参与 Better Traffic Lights。

### 开发流程

1. Fork 仓库并从 `main` 创建功能分支。
2. 保持改动聚焦，避免提交 `.build/`、`build/` 或个人系统文件。
3. 运行 `swift test`。
4. 运行 `./scripts/build-app.sh` 并验证应用签名。
5. 提交 Pull Request，说明行为变化和验证方式。

涉及窗口定位、按钮行为或多显示器逻辑的修改，请补充对应测试，并在真实 macOS 窗口上验证。
