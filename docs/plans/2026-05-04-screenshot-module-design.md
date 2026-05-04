# Screenshot Module Design

> 设计时间：2026-05-04
> 模块名：ScreenshotModule
> 目标：实现类似微信的截图功能，支持选区、标注、OCR、保存

---

## 1. 功能概述

| 功能 | 说明 |
|------|------|
| 快捷键截图 | 全局热键触发，默认 ⌘+Shift+A，可自定义 |
| 选区 | 拖拽创建矩形选区，支持 8 控制点调整大小 + 拖拽移动 |
| 标注 | 矩形、箭头、画笔、文字、马赛克 |
| OCR | VisionKit 文字识别，支持中英文 |
| 保存 | 保存到文件（PNG）或复制到剪贴板 |

---

## 2. 目录结构

```
Sources/Modules/Screenshot/
├── ScreenshotModule.swift          # 模块入口
├── Views/
│   ├── ScreenshotTabView.swift     # 设置页
│   ├── ScreenshotOverlay.swift     # 全屏覆盖层
│   ├── AnnotationToolbar.swift     # 标注工具栏
│   ├── SelectionView.swift         # 选区视图
│   └── OCRResultPanel.swift        # OCR 结果面板
├── Services/
│   ├── ScreenCaptureService.swift  # 截图服务
│   ├── AnnotationEngine.swift      # 标注引擎
│   ├── OCRService.swift            # OCR 服务
│   └── ExportService.swift         # 导出服务
├── Models/
│   ├── Annotation.swift            # 标注数据模型
│   └── CaptureConfig.swift         # 截图配置
└── ViewModels/
    └── ScreenshotViewModel.swift   # 状态管理
```

---

## 3. 核心流程

```
快捷键触发
    ↓
ScreenCaptureService 截取全屏
    ↓
显示 ScreenshotOverlay（全屏透明窗口）
    ↓
用户拖拽选区 → SelectionView 绘制矩形
    ↓
选区确定 → 显示 AnnotationToolbar + 控制点
    ↓
用户标注 → AnnotationEngine 记录标注数据
    ↓
点击「保存文件」或「复制剪贴板」
    ↓
ExportService 导出 → 关闭 overlay
```

---

## 4. 选区交互

### 4.1 状态机

```
idle → selecting（拖拽创建选区）
selecting → selected（松手，选区确定）
selected → resizing（拖拽控制点）
selected → moving（拖拽选区内部）
resizing → selected（松手）
moving → selected（松手）
selected → idle（按 Esc 取消 / 完成导出）
```

### 4.2 控制点

- 8 个控制点：nw、n、ne、e、se、s、sw、w
- 尺寸：8x8pt 圆角矩形
- 样式：白色填充 + 蓝色边框
- 光标：nwse-resize、ns-resize、nesw-resize、ew-resize

### 4.3 手势优先级

1. 控制点 DragGesture（调整大小）
2. 选区内部 DragGesture（移动选区）

### 4.4 约束

- 选区不超出屏幕 bounds
- 最小选区 20x20pt
- 控制点拖拽时对边固定

---

## 5. 标注工具

### 5.1 工具栏

```
[矩形] [箭头] [画笔] [文字] [马赛克] [颜色] [撤销] [OCR] | [保存文件] [复制剪贴板]
```

### 5.2 工具说明

| 工具 | 图标 | 快捷键 | 交互 |
|------|------|--------|------|
| 矩形 | rectangle | R | 拖拽起点到终点 |
| 箭头 | arrow.up.right | A | 拖拽起点到终点 |
| 画笔 | pencil | P | 自由绘制 |
| 文字 | text | T | 点击位置输入 |
| 马赛克 | square.grid.3x3 | M | 拖拽选择区域 |
| 颜色 | circle.inset.filled | - | 预设 6 色 + 自定义 |
| 撤销 | arrow.uturn.backward | ⌘Z | 撤销上一步 |
| OCR | text.viewfinder | ⌘O | 识别文字 |
| 保存文件 | doc.badge.arrow.down | ⌘S | 保存 PNG |
| 复制剪贴板 | doc.on.doc | ⌘C / Enter | 复制到剪贴板 |

### 5.3 标注数据模型

```swift
enum AnnotationType {
    case rect, arrow, freehand, text, mosaic
}

struct Annotation: Identifiable {
    let id: UUID
    let type: AnnotationType
    var points: [CGPoint]
    var text: String?
    var color: Color
    var lineWidth: CGFloat
}
```

---

## 6. OCR 功能

- 使用 VisionKit VNRecognizeTextRequest
- 支持语言：zh-Hans、en-US
- 结果面板：显示识别文字，可编辑，「复制文字」按钮

---

## 7. 配置与权限

### 7.1 设置页面

- 快捷键配置（默认 ⌘+Shift+A）
- 默认保存目录（默认 ~/Downloads）
- 开机自启开关

### 7.2 权限

- 屏幕录制权限（必须）
- 辅助功能权限（全局快捷键，可复用 TextSnippet 模块）

### 7.3 导出

- 格式：固定 PNG
- 默认文件名：Screenshot-YYYY-MM-DD-HHmmss.png

---

## 8. 状态管理

```swift
enum ScreenshotState {
    case idle
    case selecting
    case selected
    case annotating
    case ocrLoading
    case ocrResult(text: String)
}

@MainActor
class ScreenshotViewModel: ObservableObject {
    @Published var state: ScreenshotState = .idle
    @Published var selection: CGRect = .zero
    @Published var annotations: [Annotation] = []
    @Published var currentTool: AnnotationType?
    @Published var currentColor: Color = .red
    var capturedImage: CGImage?
}
```
