# Better Traffic Lights

[![CI](https://github.com/drfcy/better-traffic-lights/actions/workflows/ci.yml/badge.svg)](https://github.com/drfcy/better-traffic-lights/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/drfcy/better-traffic-lights)](https://github.com/drfcy/better-traffic-lights/releases/latest)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[简体中文](#简体中文) | [English](#english)

## 功能预览 / Feature Preview

<p align="center">
  <a href="docs/images/enlarged-traffic-lights.jpg">
    <img src="docs/images/enlarged-traffic-lights.jpg" alt="放大的 macOS 红绿灯按钮 / Enlarged macOS traffic lights" width="960">
  </a>
  <br>
  <sub>放大红绿灯 / Enlarged traffic lights</sub>
</p>

## 简体中文

Better Traffic Lights 是一个原生 macOS 菜单栏工具，可以把其他应用窗口左上角的关闭、最小化和缩放按钮放大，让它们更容易看清和点击。它不修改系统文件、不注入其他进程，也不需要关闭 SIP。

### 下载

从 [Releases](https://github.com/drfcy/better-traffic-lights/releases/latest) 下载最新版：

- `Better-Traffic-Lights-<版本>-arm64.dmg`：Apple Silicon Mac，推荐。
- `Better-Traffic-Lights-<版本>-x86_64.dmg`：Intel Mac，推荐。
- `Better-Traffic-Lights-<版本>-arm64.zip`：Apple Silicon Mac 的免 DMG 压缩包。
- `Better-Traffic-Lights-<版本>-x86_64.zip`：Intel Mac 的免 DMG 压缩包。
- `SHA256SUMS.txt`：用于校验下载文件。

当前公开构建使用 ad-hoc 签名，尚未经过 Apple 公证。macOS 首次阻止启动时，请在 Finder 中右键应用并选择“打开”。

### 功能

- 鼠标移入窗口红绿灯区域时，红、黄、绿按钮平滑放大；离开后收起。
- 可单独开启“单个按钮额外放大”，悬停到对应按钮时该按钮会进一步放大。
- 按钮尺寸可在 `18-48 pt` 范围内调整，按钮间距可单独调整。
- 红、黄、绿按钮分别执行 macOS 原本的关闭、最小化和缩放操作。
- 支持提供标准辅助功能窗口按钮的普通窗口、全屏窗口和多显示器。
- 窗口变化由系统应用和辅助功能事件触发更新，不进行周期性全量扫描。
- 设置保存在本机；应用不联网、不含分析统计、遥测、广告或账号系统。

### 系统要求

- macOS 13 Ventura 或更高版本。
- Apple Silicon 或 Intel Mac，请下载与芯片架构对应的发布文件。
- 目标应用需要提供标准 macOS 辅助功能窗口按钮。

### 安装与权限

1. 下载并打开 DMG，将 `Better Traffic Lights.app` 拖入“应用程序”。
2. 启动 Better Traffic Lights，从菜单栏图标打开“设置”。
3. 点击“打开辅助功能设置”，在“隐私与安全性 > 辅助功能”中允许 Better Traffic Lights。
4. 如果应用已在权限列表中但仍未生效，请关闭并重新启动应用。

辅助功能权限仅用于发现标准窗口按钮、读取窗口位置并执行用户配置的窗口操作。完整说明见 [PRIVACY.md](PRIVACY.md)。

### 使用

设置页可分别控制悬停放大和单个按钮额外放大，并调整按钮尺寸与间距。单个按钮额外放大依赖悬停放大。鼠标悬停在前台或后台窗口的红绿灯区域时都会触发放大；离开后收起。红、黄、绿按钮保留 macOS 原本操作。

### 已知限制

- 使用自行绘制标题栏、未暴露标准 AX 按钮的应用可能无法使用。
- 覆盖按钮属于独立的非激活面板，无法真正加入其他应用的窗口合成树。
- 当前公开构建未公证，因此首次启动可能出现 Gatekeeper 提示。

### 从源码构建

需要 Xcode Command Line Tools：

```sh
git clone https://github.com/drfcy/better-traffic-lights.git
cd better-traffic-lights
swift test
./scripts/build-app.sh
open "build/Better Traffic Lights.app"
```

`build-app.sh` 默认构建当前 Mac 的原生架构，也可以显式指定：

```sh
TARGET_ARCH=arm64 ./scripts/build-app.sh
TARGET_ARCH=x86_64 ./scripts/build-app.sh
```

生成两种架构的独立发布文件：

```sh
./scripts/package-dmg.sh
./scripts/package-zip.sh
```

产物分别带有 `-arm64` 和 `-x86_64` 后缀。发布打包使用独立临时应用，不会覆盖 `build/Better Traffic Lights.app` 中的本机开发构建。

默认使用 ad-hoc 签名。持有 Developer ID 的发布者可以设置：

```sh
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package-dmg.sh
```

### 实现方式

macOS 没有公开 API 可以跨进程修改原生红绿灯尺寸。本项目使用辅助功能 API 获取标准窗口按钮和执行操作，使用 WindowServer 窗口信息匹配位置与遮挡，再通过三个独立的非激活透明面板绘制放大按钮。所有处理均在本机完成。

### 参与贡献

提交改动前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)，并至少运行：

```sh
swift test
./scripts/build-app.sh
codesign --verify --deep --strict "build/Better Traffic Lights.app"
```

安全问题请按 [SECURITY.md](SECURITY.md) 中的方式报告，不要直接公开未修复漏洞。

### 许可证

Better Traffic Lights 采用 [MIT License](LICENSE)。

## English

Better Traffic Lights is a native macOS menu bar utility that enlarges the close, minimize, and zoom controls in the top-left corner of other application windows, making them easier to see and click. It does not modify system files, inject code into other processes, or require System Integrity Protection to be disabled.

### Interface Preview

<table>
  <tr>
    <td width="50%" align="center">
      <a href="docs/images/settings-en-top.png">
        <img src="docs/images/settings-en-top.png" alt="Top section of the Better Traffic Lights English settings interface">
      </a>
    </td>
    <td width="50%" align="center">
      <a href="docs/images/settings-en-bottom.png">
        <img src="docs/images/settings-en-bottom.png" alt="Bottom section of the Better Traffic Lights English settings interface">
      </a>
    </td>
  </tr>
  <tr>
    <td align="center"><sub>Settings, top section</sub></td>
    <td align="center"><sub>Settings, bottom section</sub></td>
  </tr>
</table>

### Download

Download the latest version from [Releases](https://github.com/drfcy/better-traffic-lights/releases/latest):

- `Better-Traffic-Lights-<version>-arm64.dmg`: recommended for Apple Silicon Macs.
- `Better-Traffic-Lights-<version>-x86_64.dmg`: recommended for Intel Macs.
- `Better-Traffic-Lights-<version>-arm64.zip`: ZIP package for Apple Silicon Macs.
- `Better-Traffic-Lights-<version>-x86_64.zip`: ZIP package for Intel Macs.
- `SHA256SUMS.txt`: checksums for verifying downloaded files.

Public builds currently use ad-hoc code signing and are not notarized by Apple. If macOS blocks the app on first launch, right-click it in Finder and choose **Open**.

### Features

- Adjustable traffic-light control size from `18-48 pt`.
- **Magnify on Hover** smoothly enlarges the red, yellow, and green controls when the pointer enters their area, then collapses them when it leaves.
- **Further Enlarge Hovered Button** independently enlarges the button under the pointer and requires hover magnification.
- Adjust control size from `18-48 pt` and set button spacing independently.
- The red, yellow, and green controls retain their native close, minimize, and zoom actions.
- Supports standard accessible window controls, including fullscreen windows and multiple displays.
- Window changes are tracked through workspace and Accessibility events, without periodic full-window scans.
- Settings are stored locally. The app makes no network requests and contains no analytics, telemetry, advertisements, or account system.

### Requirements

- macOS 13 Ventura or later.
- An Apple Silicon or Intel Mac. Download the package matching your Mac's architecture.
- Target applications must expose standard macOS window controls through the Accessibility API.

### Installation And Permissions

1. Download and open the DMG, then drag `Better Traffic Lights.app` into Applications.
2. Launch Better Traffic Lights and open Settings from its menu bar icon.
3. Select **Open Accessibility Settings**, then allow Better Traffic Lights under **Privacy & Security > Accessibility**.
4. If the app is already listed but does not work, quit and relaunch it.

Accessibility permission is used only to discover standard window controls, read window positions, and perform the window actions configured by the user. See [PRIVACY.md](PRIVACY.md) for details.

### Usage

Settings control hover magnification and additional enlargement of the hovered button, as well as button size and spacing. Both focused and background windows respond when the pointer enters their native traffic-light area. Leaving the area hides the overlay. The controls retain their native macOS actions.

### Known Limitations

- Applications with custom-drawn title bars that do not expose standard AX controls may not work.
- Overlay controls are separate non-activating panels and cannot become part of another application's window composition tree.
- Public builds are not notarized, so Gatekeeper may display a warning on first launch.

### Build From Source

Xcode Command Line Tools are required:

```sh
git clone https://github.com/drfcy/better-traffic-lights.git
cd better-traffic-lights
swift test
./scripts/build-app.sh
open "build/Better Traffic Lights.app"
```

`build-app.sh` builds for the current Mac architecture by default. You can also select one explicitly:

```sh
TARGET_ARCH=arm64 ./scripts/build-app.sh
TARGET_ARCH=x86_64 ./scripts/build-app.sh
```

Generate separate release packages for both architectures:

```sh
./scripts/package-dmg.sh
./scripts/package-zip.sh
```

Artifacts use `-arm64` and `-x86_64` suffixes. Release packaging uses isolated temporary app bundles and does not overwrite the native development build at `build/Better Traffic Lights.app`.

Ad-hoc signing is used by default. Publishers with a Developer ID certificate can set:

```sh
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package-dmg.sh
```

### How It Works

macOS does not provide a public API for resizing native traffic-light controls across processes. Better Traffic Lights uses the Accessibility API to discover standard controls and perform actions, WindowServer window information to match positions and occlusion, and three independent non-activating transparent panels to draw the enlarged controls. All processing happens locally on the Mac.

### Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting changes, and run at least:

```sh
swift test
./scripts/build-app.sh
codesign --verify --deep --strict "build/Better Traffic Lights.app"
```

Report security issues using the process in [SECURITY.md](SECURITY.md). Do not publicly disclose unresolved vulnerabilities.

### License

Better Traffic Lights is available under the [MIT License](LICENSE).
