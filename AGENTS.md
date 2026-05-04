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

### 其他

- `Models.swift` 同名会导致 SPM 构建冲突，需重命名
