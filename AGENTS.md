# MacToolkit

macOS 菜单栏工具箱应用，Swift Package Manager 构建。

## 项目结构

- 路径: `~/workspace/MacToolkit`
- GitHub: https://github.com/macrochen/MacToolkit
- 构建: `bash build_app.sh --open`

## 模块

| 模块 | 功能 |
|------|------|
| TextSnippet | 快捷短语（全局热键触发文本片段） |
| StandUpTimer | 久坐提醒 |
| MouseKeyMapper | 鼠标按键映射 |
| FinderDockHelper | Finder Dock 辅助 |
| TouchpadGestureHelper | 触控板手势映射 |
| Screenshot | 截图 + 标注 + OCR |

## 架构

- `ToolkitModule` 协议 + `ModuleRegistry` 注册
- 设置窗口: `SettingsWindowController` + HSplitView 左侧固定列表
- UI 偏好: 紧凑布局、左右分栏、避免滚动条

## 技术要点

### 全局热键方案（macOS 26 + MenuBarExtra accessory 模式）

1. **Carbon EventHotKey** → 静默失败（返回 noErr 但回调不触发）
2. **NSEvent.addGlobalMonitorForEvents** → 能监听但无法吞噬事件（原始字符仍输出）
3. **CGEventTap** → ✅ 正确方案：拦截并吞噬匹配按键

### Swift 6 并发注意事项

- `ToolkitModule` 协议标记 `@MainActor`
- CGEvent 回调不能用 `@MainActor` 方法，需 `@unchecked Sendable` + `nonisolated func`
- `NSEvent.ModifierFlags.shift` 与自定义 `enum Modifier.shift` 冲突，需完全限定名
- `NSImageView` 拦截鼠标事件 → 用自定义 `PassthroughNSImageView`（hitTest 返回 nil）
- `keyCode 0` = A 键（有效值），displayString/register/录制器三处需同步处理

### CGEvent tap 最佳实践

1. 截图等非关键功能用 `.cgSessionEventTap` + `.listenOnly`，不干扰系统手势
2. `.cghidEventTap` + `.defaultTap` 会阻塞触控板手势（4指滑动等），慎用
3. 必须处理 `.tapDisabledByTimeout` 重新启用 tap
4. CGEvent tap 回调中避免过多 print，影响性能

### 其他

- `Models.swift` 同名会导致 SPM 构建冲突，需重命名

### 截图覆盖窗口安全规则

全屏覆盖窗口（`.screenSaver` level）必须实现多重退出机制，防止用户被锁死：
1. CGEvent tap 级别处理 Escape（最可靠）
2. 可视关闭按钮（右上角）
3. 双击空白区域退出
4. 5分钟安全超时自动关闭
5. 底部操作提示文字

关键陷阱：
- 使用 `orderOut` 代替 `close`（防止 app 退出）
- 设置 `isReleasedWhenClosed = false` + `isExcludedFromWindowsMenu = true`
- CGEvent tap 中 Escape 直接调用 cancel，不用 DispatchQueue.main.async
- 不要在 SwiftUI 中同时用 `onKeyPress(.escape)`（冲突导致 app 退出两次）

详见 `macos-overlay-window-safety-skill`。

### 截图坐标系转换

三个坐标系混用是主要 bug 来源：
- **NSView**：左下角原点，Y 向上（mouseDown/touchesBegan 事件）
- **SwiftUI**：左上角原点，Y 向下（View position、DragGesture）
- **CGImage**：左下角原点，Y 向上（cropping、像素坐标）

触摸板选区 → SwiftUI 选区：`swiftY = screenHeight - nsViewY`
SwiftUI 选区 → CGImage 裁剪：`imageY = imageH - (selY + selH) * scaleH`

触摸板滑动选区需用 NSViewRepresentable（SwiftUI DragGesture 需要点击才能开始）。

### 三指拖动光标位置获取

`CGEvent.mouseLocation()` 在 MultitouchSupport 后台线程回调中返回缓存值（不更新）。
MultitouchSupport 的 posX/posY 归一化坐标不能直接映射到屏幕位置（有未知偏移）。

正确方案：**MultitouchSupport 检测三指状态 + CGEventTap 监听 mouseMoved 获取真实光标位置**。
- MultitouchSupport：只检测 `activeFingerCount >= 3`（开始）和 `< 3`（结束）
- CGEventTap `.listenOnly`：监听 `mouseMoved`，`event.location` 即真实光标位置
- AppKit → SwiftUI 转换：`swiftY = screenOriginY + screenHeight - appKitY`
- CGEventTap 必须加到 `CFRunLoopGetMain()`，窗口关闭时 `tapEnable(enable: false)` 清理

### StandUpTimer 久坐提醒 UI 规范

- 猫咪动画用 GeometryReader + scaledToFit，尺寸为屏幕 80%宽 x 70%高
- 提示文字必须加半透明背景（Capsule + black.opacity(0.45)），纯文字+阴影在不同屏幕背景下看不清
