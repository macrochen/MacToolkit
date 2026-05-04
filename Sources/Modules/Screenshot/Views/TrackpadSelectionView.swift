import SwiftUI
import AppKit

/// 支持触摸板滑动的选区创建视图
struct TrackpadSelectionView: NSViewRepresentable {
    @ObservedObject var viewModel: ScreenshotViewModel
    let screenSize: CGSize
    let screen: NSScreen
    
    func makeNSView(context: Context) -> TrackpadSelectionNSView {
        let view = TrackpadSelectionNSView(screenSize: screenSize, screen: screen)
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: TrackpadSelectionNSView, context: Context) {
        // 更新视图状态
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, screenHeight: screen.frame.height)
    }
    
    @MainActor
    class Coordinator: NSObject, TrackpadSelectionDelegate {
        let viewModel: ScreenshotViewModel
        let screenHeight: CGFloat
        
        init(viewModel: ScreenshotViewModel, screenHeight: CGFloat) {
            self.viewModel = viewModel
            self.screenHeight = screenHeight
        }
        
        nonisolated func selectionDidUpdate(_ rect: CGRect) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // normalizedToScreen 已经输出 SwiftUI 坐标（Y=0 顶部，Y 向下）
                // 直接使用，无需翻转
                self.viewModel.selection = rect
            }
        }
        
        nonisolated func selectionDidFinish(_ rect: CGRect) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if rect.width >= 20 && rect.height >= 20 {
                    self.viewModel.selection = rect
                    self.viewModel.finishSelection()
                } else {
                    self.viewModel.selection = .zero
                }
            }
        }
        
        nonisolated func selectionDidCancel() {
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.selection = .zero
            }
        }
    }
}

protocol TrackpadSelectionDelegate: AnyObject {
    func selectionDidUpdate(_ rect: CGRect)
    func selectionDidFinish(_ rect: CGRect)
    func selectionDidCancel()
}

// MARK: - MultitouchSupport 3-Finger Drag Detector

/// 使用 MultitouchSupport 同时检测三指状态和位置
/// 坐标公式: x = norm.x * screenWidth, y = (1 - norm.y) * screenHeight
private class ThreeFingerDragDetector: @unchecked Sendable {
    weak var delegate: TrackpadSelectionDelegate?
    let screenSize: CGSize
    let screen: NSScreen
    
    // MultitouchSupport 类型定义
    private typealias MTTouchCallback = @convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer, Int32, Double, Int32) -> Void
    private typealias MTDeviceCreateList_t = @convention(c) () -> CFArray
    private typealias MTRegisterCB_t = @convention(c) (CFTypeRef, MTTouchCallback, UnsafeMutableRawPointer?, Int32) -> Void
    private typealias MTDeviceStart_t = @convention(c) (CFTypeRef, Int32) -> Void
    
    // MultitouchSupport 触摸数据结构（96 字节，已验证）
    private struct MTTouchData {
        var frame: Int32
        var _pad0: Int32
        var timestamp: Double
        var identifier: Int32
        var state: Int32        // 1=began, 3/4=moving/stationary, 7=ended
        var fingerId: Int32
        var handId: Int32
        var posX: Float         // normalized 0-1
        var posY: Float
        var velX: Float
        var velY: Float
        var angle: Float
        var majorAxis: Float
        var minorAxis: Float
        var size: Float
        var pressure: Float
        var density: Float
        var quality: Float
        var z_position: Float
        var _pad1: Float
        var _pad2: Float
        var _pad3: Float
        var _pad4: Float
    }
    
    // 状态
    private var threeFingerDown = false
    private var startNorm: CGPoint?      // 三指开始时的触控板坐标
    private var startCursor: CGPoint?    // 三指开始时的光标位置（SwiftUI 坐标）
    private var currentPoint: CGPoint?
    private var endCheckCount = 0
    
    init(screenSize: CGSize, screen: NSScreen) {
        self.screenSize = screenSize
        self.screen = screen
    }
    
    func start() {
        let mtPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let mtLib = dlopen(mtPath, RTLD_NOW) else {
            print("[3FDrag] ⚠️ Failed to load MultitouchSupport.framework")
            return
        }
        
        guard let symCreate = dlsym(mtLib, "MTDeviceCreateList"),
              let symRegister = dlsym(mtLib, "MTRegisterContactFrameCallback"),
              let symStart = dlsym(mtLib, "MTDeviceStart") else {
            print("[3FDrag] ⚠️ MultitouchSupport symbols not found")
            return
        }
        
        let createList = unsafeBitCast(symCreate, to: MTDeviceCreateList_t.self)
        let mtRegister = unsafeBitCast(symRegister, to: MTRegisterCB_t.self)
        let mtStart = unsafeBitCast(symStart, to: MTDeviceStart_t.self)
        
        ThreeFingerDragBridge.shared.detector = self
        
        let deviceList = createList() as NSArray
        print("[3FDrag] 📱 Found \(deviceList.count) multitouch device(s)")
        
        for i in 0..<deviceList.count {
            let device = deviceList[i] as! CFTypeRef
            mtRegister(device, threeFingerDragCallback, nil, 0)
            mtStart(device, 0)
        }
        
        print("[3FDrag] ✅ 3-finger drag detector started")
    }
    
    func stop() { }
    
    // MARK: - 坐标转换
    
    /// 触控板归一化坐标 → SwiftUI 坐标
    /// MultitouchSupport: X(0=左,1=右), Y(0=顶,1=底)
    /// SwiftUI: (0,0)=左上角, Y 向下
    private func normalizedToSwiftUI(_ norm: CGPoint) -> CGPoint {
        return CGPoint(
            x: norm.x * screenSize.width,
            y: (1 - norm.y) * screenSize.height
        )
    }
    
    private func calculateRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        return CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
    
    // MARK: - Touch Handler（后台线程）
    
    nonisolated func handleTouch(rawTouches: UnsafeMutableRawPointer, numTouches: Int32) {
        let count = Int(numTouches)
        let touches = rawTouches.assumingMemoryBound(to: MTTouchData.self)
        
        var activeFingerCount = 0
        var allEnded = true
        var sumX: Float = 0
        var sumY: Float = 0
        
        for i in 0..<count {
            let t = touches[i]
            if t.state != 7 {
                allEnded = false
                activeFingerCount += 1
                sumX += t.posX
                sumY += t.posY
            }
        }
        
        // 三指开始
        if activeFingerCount >= 3 && !threeFingerDown {
            threeFingerDown = true
            endCheckCount = 0
            let norm = CGPoint(x: CGFloat(sumX / Float(activeFingerCount)),
                               y: CGFloat(sumY / Float(activeFingerCount)))
            startNorm = norm
            // 读取当前光标位置作为锚点（AppKit → SwiftUI）
            let cursor = NSEvent.mouseLocation
            let screenFrame = screen.frame
            let anchorX = cursor.x - screenFrame.origin.x
            let anchorY = screenSize.height - (cursor.y - screenFrame.origin.y)
            let anchor = CGPoint(x: anchorX, y: anchorY)
            startCursor = anchor
            currentPoint = anchor
            writeDebugLog("[3FDrag] START norm=\(String(format:"%.3f,%.3f", norm.x, norm.y)) cursor=\(Int(cursor.x)),\(Int(cursor.y)) anchor=\(Int(anchor.x)),\(Int(anchor.y))\n")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let rect = self.calculateRect(from: anchor, to: anchor)
                self.delegate?.selectionDidUpdate(rect)
            }
        }
        
        // 三指移动中 - 用增量
        if threeFingerDown && activeFingerCount >= 3 {
            endCheckCount = 0
            if let sn = startNorm, let sc = startCursor {
                let norm = CGPoint(x: CGFloat(sumX / Float(activeFingerCount)),
                                   y: CGFloat(sumY / Float(activeFingerCount)))
                // 触控板增量 × 屏幕尺寸 = 屏幕位移
                let dx = (norm.x - sn.x) * screenSize.width
                let dy = -(norm.y - sn.y) * screenSize.height  // Y 轴反转
                let swiftPos = CGPoint(x: sc.x + dx, y: sc.y + dy)
                currentPoint = swiftPos
                writeDebugLog("[3FDrag] MOVE delta=\(Int(dx)),\(Int(dy)) pos=\(Int(swiftPos.x)),\(Int(swiftPos.y))\n")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let rect = self.calculateRect(from: sc, to: swiftPos)
                    self.delegate?.selectionDidUpdate(rect)
                }
            }
        }
        
        // 手指短暂减少（系统手势干扰）→ 延迟结束
        if threeFingerDown && activeFingerCount < 3 && !allEnded {
            endCheckCount += 1
            if endCheckCount >= 10 {
                endDrag()
            }
            return
        }
        
        // 手指全部抬起 → 立即结束
        if threeFingerDown && allEnded {
            endDrag()
        }
    }
    
    private func endDrag() {
        threeFingerDown = false
        if let sc = startCursor, let end = currentPoint {
            writeDebugLog("[3FDrag] END sel=(\(Int(sc.x)),\(Int(sc.y)))→(\(Int(end.x)),\(Int(end.y)))\n")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let rect = self.calculateRect(from: sc, to: end)
                self.delegate?.selectionDidFinish(rect)
            }
        }
        startNorm = nil
        startCursor = nil
        currentPoint = nil
        endCheckCount = 0
    }
    
    nonisolated private func writeDebugLog(_ line: String) {
        if let data = line.data(using: .utf8) {
            let fh = FileHandle(forWritingAtPath: "/tmp/3fdrag_debug.log") ?? {
                FileManager.default.createFile(atPath: "/tmp/3fdrag_debug.log", contents: nil)
                return FileHandle(forWritingAtPath: "/tmp/3fdrag_debug.log")!
            }()
            fh.seekToEndOfFile()
            fh.write(data)
            fh.closeFile()
        }
    }
}

// MARK: - C Callback Bridge

/// Bridge singleton
private class ThreeFingerDragBridge: @unchecked Sendable {
    static let shared = ThreeFingerDragBridge()
    weak var detector: ThreeFingerDragDetector?
}

/// MultitouchSupport C-compatible callback
private func threeFingerDragCallback(
    device: UnsafeMutableRawPointer,
    rawTouches: UnsafeMutableRawPointer,
    numTouches: Int32,
    timestamp: Double,
    frame: Int32
) {
    ThreeFingerDragBridge.shared.detector?.handleTouch(
        rawTouches: rawTouches,
        numTouches: numTouches
    )
}

// MARK: - NSView（NSEvent fallback + 鼠标事件）

/// 支持触摸板滑动的 NSView
class TrackpadSelectionNSView: NSView {
    weak var delegate: TrackpadSelectionDelegate? {
        didSet {
            dragDetector?.delegate = delegate
        }
    }
    let screenSize: CGSize
    let screen: NSScreen
    
    private var dragDetector: ThreeFingerDragDetector?
    
    // NSEvent fallback 状态
    private var isSelecting = false
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    
    init(screenSize: CGSize, screen: NSScreen) {
        self.screenSize = screenSize
        self.screen = screen
        super.init(frame: NSRect(origin: .zero, size: screenSize))
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        
        // 启用 MultitouchSupport 3 指拖动检测
        let detector = ThreeFingerDragDetector(screenSize: screenSize, screen: screen)
        detector.start()
        self.dragDetector = detector
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        dragDetector?.stop()
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    // MARK: - 坐标转换
    
    /// AppKit 屏幕坐标 → SwiftUI 坐标
    /// AppKit: (0,0) = 屏幕左下角, Y 向上
    /// SwiftUI: (0,0) = 屏幕左上角, Y 向下
    private func screenToSwiftUI(_ screenPoint: CGPoint) -> CGPoint {
        let screenHeight = screenSize.height
        return CGPoint(
            x: screenPoint.x - screen.frame.origin.x,
            y: screenHeight - (screenPoint.y - screen.frame.origin.y)
        )
    }
    
    private func calculateRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        return CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
    
    // MARK: - NSEvent Touch Events（如果 MultitouchSupport 不可用时的备用）
    
    override func touchesBegan(with event: NSEvent) {
        let touches = event.touches(matching: .began, in: self)
        guard touches.first != nil else { return }
        
        let screenPoint = NSEvent.mouseLocation
        let swiftUILocation = screenToSwiftUI(screenPoint)
        startPoint = swiftUILocation
        currentPoint = swiftUILocation
        isSelecting = true
        
        let rect = calculateRect(from: swiftUILocation, to: swiftUILocation)
        delegate?.selectionDidUpdate(rect)
    }
    
    override func touchesMoved(with event: NSEvent) {
        guard isSelecting, let start = startPoint else { return }
        
        let screenPoint = NSEvent.mouseLocation
        let swiftUILocation = screenToSwiftUI(screenPoint)
        currentPoint = swiftUILocation
        
        let rect = calculateRect(from: start, to: swiftUILocation)
        delegate?.selectionDidUpdate(rect)
    }
    
    override func touchesEnded(with event: NSEvent) {
        guard isSelecting, let start = startPoint, let end = currentPoint else {
            resetSelection()
            return
        }
        
        let rect = calculateRect(from: start, to: end)
        delegate?.selectionDidFinish(rect)
        resetSelection()
    }
    
    override func touchesCancelled(with event: NSEvent) {
        delegate?.selectionDidCancel()
        resetSelection()
    }
    
    // MARK: - 鼠标事件处理（备用，点击拖拽）
    
    override func mouseDown(with event: NSEvent) {
        // 直接用屏幕坐标，避免 view 坐标转换误差
        let screenPoint = NSEvent.mouseLocation
        let swiftUILocation = screenToSwiftUI(screenPoint)
        startPoint = swiftUILocation
        currentPoint = swiftUILocation
        isSelecting = true
        
        // DEBUG
        let debugLine = "[mouseDown] screen=(\(Int(screenPoint.x)),\(Int(screenPoint.y))) swiftUI=(\(Int(swiftUILocation.x)),\(Int(swiftUILocation.y))) screenOrigin=(\(Int(screen.frame.origin.x)),\(Int(screen.frame.origin.y))) screenSize=\(Int(screenSize.width))x\(Int(screenSize.height))\n"
        if let data = debugLine.data(using: .utf8) {
            let fh = FileHandle(forWritingAtPath: "/tmp/screenshot_coord_debug.log") ?? {
                FileManager.default.createFile(atPath: "/tmp/screenshot_coord_debug.log", contents: nil)
                return FileHandle(forWritingAtPath: "/tmp/screenshot_coord_debug.log")!
            }()
            fh.seekToEndOfFile()
            fh.write(data)
            fh.closeFile()
        }
        
        let rect = calculateRect(from: swiftUILocation, to: swiftUILocation)
        delegate?.selectionDidUpdate(rect)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isSelecting, let start = startPoint else { return }
        
        let screenPoint = NSEvent.mouseLocation
        let swiftUILocation = screenToSwiftUI(screenPoint)
        currentPoint = swiftUILocation
        
        let rect = calculateRect(from: start, to: swiftUILocation)
        delegate?.selectionDidUpdate(rect)
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isSelecting, let start = startPoint, let end = currentPoint else {
            resetSelection()
            return
        }
        
        let rect = calculateRect(from: start, to: end)
        delegate?.selectionDidFinish(rect)
        resetSelection()
    }
    
    private func resetSelection() {
        isSelecting = false
        startPoint = nil
        currentPoint = nil
    }
    
    // 绘制选区预览
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let start = startPoint, let end = currentPoint else { return }
        
        let nsStart = CGPoint(x: start.x, y: screenSize.height - start.y)
        let nsEnd = CGPoint(x: end.x, y: screenSize.height - end.y)
        
        let rect = CGRect(
            x: min(nsStart.x, nsEnd.x),
            y: min(nsStart.y, nsEnd.y),
            width: abs(nsEnd.x - nsStart.x),
            height: abs(nsEnd.y - nsStart.y)
        )
        
        NSColor.blue.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.stroke()
    }
}
