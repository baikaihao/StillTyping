# StillTyping!!! · Cursor + Return

用高亮的输入光标挡住回车箭头，表达「我还在输入，先别提交」。
光标比箭头更高，保留持续输入的视觉重心；圆头、等粗线条方便小尺寸识别。

## 文件

- `stilltyping-preview.png`：整体设计预览。
- `stilltyping-logo.svg` / `stilltyping-logo-dark.svg`：横向组合，分别用于浅色 / 深色背景；文字已转曲。
- `stilltyping-wordmark.svg`：独立字标，文字已转曲。
- `stilltyping-mark.svg` / `stilltyping-mark-dark.svg`：透明底独立标识。
- `stilltyping-mark-mono.svg` / `stilltyping-mark-white.svg`：黑 / 白单色版本。
- `stilltyping-app-icon.svg` / `.png`：1024 × 1024 macOS 图标，外边缘透明。
- `StillTyping.icns` / `StillTyping.iconset`：macOS 应用图标及尺寸资源。
- 同名 PNG：透明底栅格版本。

## 颜色与使用

| 颜色 | 色值 | 用途 |
| --- | --- | --- |
| Graphite | `#202321` | 主标识、字标、深色底 |
| Cursor | `#C5F36B` | 光标、三个感叹号 |
| Paper | `#F7F7F2` | 展示背景 |

独立标识建议不小于 16 px；16–24 px 或低对比环境使用单色版。
深色背景使用 `-dark` 或 `-white` 文件。浅色底上的绿色作为装饰使用，
不承担界面正文、状态文字或唯一的信息表达。
图形四周建议保留至少一个光标宽度的空白。

菜单栏采用去掉底板的单色 Logo，随系统深浅色自动变色；保护暂停时淡化显示。
该版本由 `Sources/StillTyping/MenuBarLogo.swift` 以矢量绘制，尺寸为 16 pt。

SVG 为可编辑矢量；字标由 Avenir Next Bold 转成轮廓，导出文件无需安装字体。
macOS 图标已接入 Xcode 的 Debug / Release 配置。应用资源位于
`Sources/StillTyping/Assets.xcassets/AppIcon.appiconset`；若重新设计并导出图标，
需将 `StillTyping.iconset` 内的同名 PNG 同步至该目录。

如需重新导出，在 macOS 上安装 Python 的 `Pillow` 后运行：

```sh
npm install --prefix Design/Logo
python3 Design/Logo/generate.py
```
