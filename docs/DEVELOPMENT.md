# 开发与构建

[返回项目首页](../README.md)

## 开发环境

- macOS，安装 Xcode 26 或更新版本。
- Swift 6.2+。
- 网页保护逻辑的自动测试需要 Node.js。

最低部署版本设为 macOS 14.0。目前在 Apple Silicon、macOS 27.0 环境完成构建；旧版 macOS 和 Intel Mac 尚未实测。

## 使用 Xcode

1. 打开 `StillTyping.xcodeproj`。
2. 选择 **StillTyping** scheme 和 **My Mac**。
3. 按 **⌘R** 构建并运行，按 **⌘U** 运行测试。

工程包含 `StillTyping` App、`StillTypingCore` 框架、`StillTypingCoreTests` 测试三个 target，并提供共享的运行、测试和归档 scheme。本机开发采用 ad-hoc 签名，无需配置开发者团队。

应用版本与构建号在 App target 的 **General → Version / Build** 中设置，分别对应
`MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION`。`Packaging/Info.plist` 引用这两个构建设置，
运行和归档共用相同的版本来源。修改后需重新构建或归档，已有归档保留生成时的版本。

## 生成独立 App

在项目根目录运行：

```sh
zsh scripts/build.sh
```

脚本使用 Xcode Release 配置构建，验证代码签名，并生成 `build/StillTyping!!!.app`。当前尚未制作面向公众分发的公证安装包。

保留 SwiftPM 构建方式，与 Xcode 共用源码和资源：

```sh
swift build
```

## 运行测试

在项目根目录运行：

```sh
# Xcode / Swift Testing
xcodebuild -project StillTyping.xcodeproj -scheme StillTyping \
  -destination 'platform=macOS' -derivedDataPath build/Xcode test

# SwiftPM
swift test

# 网页保护逻辑
node --test Tests/WebGuard/guard.test.cjs
```

现有自动测试覆盖浏览器脚本与字典解析、连接和窗口检测、轮询、组词确认事件、普通回车、修饰键、长按、隐式表单提交、焦点切换及租约清理。已完成 Debug / Release 构建、SwiftPM 构建、资源打包与代码签名验证。

自动合成的网页事件不能替代真实输入法验证。人工验收方式见 [兼容性说明](COMPATIBILITY.md)。

## 源码位置

| 路径 | 内容 |
| --- | --- |
| `Sources/StillTyping` | 原生应用、界面、状态管理与浏览器自动化 |
| `Sources/StillTypingCore` | 浏览器脚本、字典解析与轮询逻辑 |
| `Sources/StillTyping/Resources/guard.js` | 网页输入法回车保护逻辑 |
| `Sources/StillTyping/Resources/lab.html` | 应用内输入测试页 |
| `Sources/StillTyping/Localization` | 简体中文与英文本地化资源 |
| `Sources/StillTyping/Assets.xcassets/AppIcon.appiconset` | Xcode Debug / Release 应用图标 |
| `Tests` | Swift 与 JavaScript 测试 |
| `docs/assets` | README 的 Logo 与使用示意图 |
| `docs/assets/app-icon.svg` | 应用图标的矢量源文件 |

## 实现概要

原生 App 通过 Apple Events，在当前网页安装捕获阶段的输入法事件保护逻辑。组词确认时保留输入法默认动作，阻止对应回车事件继续触发网页提交处理器，并处理关联的 `keypress`、`keyup` 和隐式表单提交。

保护脚本采用 4 秒租约，重复连接只续期现有保护。AppleScript 在独立 actor 中串行执行，设置 2 秒 Apple Events 超时并缓存固定脚本；运行时读取浏览器自身的脚本字典，生成对应命令。前台浏览器优先续期，后台浏览器轮换检查。

程序监听浏览器退出并检查窗口状态。浏览器退出或最后一个窗口关闭后，只断开对应连接，保护总开关仍由用户手动控制。重新打开浏览器后需要手动连接。
