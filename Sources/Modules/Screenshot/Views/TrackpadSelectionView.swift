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
                self.viewModel.updateSelection(rect)
            }
        }
        
        nonisolated func selectionDidFinish(_ rect: CGRect) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if rect.width >= 20 && rect.height >= 20 {
                    self.viewModel.updateSelection(rect)
                    self.viewModel.finishSelection()
                } else {
                    self.viewModel.updateSelection(.zero)
                }
            }
        }
        
        nonisolated func selectionDidCancel() {
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.updateSelection(.zero)
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

/// 使用 MultitouchSupport 只检测三指状态，真实光标位置由 CGEventTap 提供。
private class ThreeFingerDragDetector: @unchecked Sendable {
    var onStart: (@Sendable () -> Void)?
    var onEnd: (@Sendable () -> Void)?
    
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
    private var endCheckCount = 0
    
    init() {}
    
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
            let device = deviceList[i] as CFTypeRef
            mtRegister(device, threeFingerDragCallback, nil, 0)
            mtStart(device, 0)
        }
        
        print("[3FDrag] ✅ 3-finger drag detector started")
    }
    
    func stop() { }
    
    // MARK: - Touch Handler（后台线程）
    
    nonisolated func handleTouch(rawTouches: UnsafeMutableRawPointer, numTouches: Int32) {
        let count = Int(numTouches)
        let touches = rawTouches.assumingMemoryBound(to: MTTouchData.self)
        
        var activeFingerCount = 0
        var allEnded = true
        
        for i in 0..<count {
            let t = touches[i]
            if t.state != 7 {
                allEnded = false
                activeFingerCount += 1
            }
        }
        
        // 三指开始
        if activeFingerCount >= 3 && !threeFingerDown {
            threeFingerDown = true
            endCheckCount = 0
            DispatchQueue.main.async { [onStart] in onStart?() }
        }
        
        // 三指移动由 CGEventTap 的 mouseMoved 事件处理。
        if threeFingerDown && activeFingerCount >= 3 {
            endCheckCount = 0
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
        DispatchQueue.main.async { [onEnd] in onEnd?() }
        endCheckCount = 0
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
        didSet {}
    }
    let screenSize: CGSize
    let screen: NSScreen
    
    private var dragDetector: ThreeFingerDragDetector?
    private var mouseMoveTap: CFMachPort?
    private var mouseMoveSource: CFRunLoopSource?
    
    // NSEvent fallback 状态
    private var isSelecting = false
    private var pendingThreeFingerStart = false
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var lastPointerScreenPoint: CGPoint?
    private enum SelectionSource {
        case none
        case mouse
        case touchFallback
        case threeFinger
    }
    private var selectionSource: SelectionSource = .none
    
    init(screenSize: CGSize, screen: NSScreen) {
        self.screenSize = screenSize
        self.screen = screen
        super.init(frame: NSRect(origin: .zero, size: screenSize))
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        
        // 启用 MultitouchSupport 3 指拖动检测
        startMouseMoveTap()

        let detector = ThreeFingerDragDetector()
        detector.onStart = { [weak self] in
            Task { @MainActor in
                self?.beginThreeFingerSelection()
            }
        }
        detector.onEnd = { [weak self] in
            Task { @MainActor in
                self?.finishThreeFingerSelection()
            }
        }
        detector.start()
        self.dragDetector = detector
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        dragDetector?.stop()
        MainActor.assumeIsolated {
            stopMouseMoveTap()
        }
    }
    
    override var acceptsFirstResponder: Bool { true }

    // MARK: - 坐标转换
    
    /// AppKit 屏幕坐标 → SwiftUI 坐标
    /// SwiftUI: (0,0) = 屏幕左上角, Y 向下
    private func screenToSwiftUI(_ screenPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: screenPoint.x - screen.frame.origin.x,
            y: screen.frame.origin.y + screenSize.height - screenPoint.y
        )
    }

    private func eventToSwiftUI(_ event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        return CGPoint(x: point.x, y: bounds.height - point.y)
    }
    
    private func calculateRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        ScreenshotGeometry.normalizedRect(from: start, to: end)
    }

    // MARK: - CGEventTap mouse tracking for three-finger selection

    private func startMouseMoveTap() {
        let mask = CGEventMask(1 << CGEventType.mouseMoved.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseDragged.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                if type == .tapDisabledByTimeout, let refcon {
                    let view = Unmanaged<TrackpadSelectionNSView>.fromOpaque(refcon).takeUnretainedValue()
                    if let tap = view.mouseMoveTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                guard let refcon else { return Unmanaged.passUnretained(event) }
                let view = Unmanaged<TrackpadSelectionNSView>.fromOpaque(refcon).takeUnretainedValue()
                let location = event.location
                DispatchQueue.main.async { [weak view] in
                    view?.handlePointerMoved(screenPoint: location)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            return
        }

        mouseMoveTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        mouseMoveSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopMouseMoveTap() {
        if let source = mouseMoveSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            mouseMoveSource = nil
        }
        if let tap = mouseMoveTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            mouseMoveTap = nil
        }
    }

    private func beginThreeFingerSelection() {
        pendingThreeFingerStart = true
        isSelecting = false
        selectionSource = .none
        startPoint = nil
        currentPoint = nil
        handlePointerMoved(screenPoint: latestPointerScreenPoint())
    }

    private func finishThreeFingerSelection() {
        if selectionSource == .threeFinger {
            handlePointerMoved(screenPoint: latestPointerScreenPoint())
        }

        guard !pendingThreeFingerStart else {
            pendingThreeFingerStart = false
            resetSelection()
            delegate?.selectionDidCancel()
            return
        }
        guard isSelecting, let start = startPoint, let end = currentPoint else {
            resetSelection()
            return
        }

        delegate?.selectionDidFinish(calculateRect(from: start, to: end))
        resetSelection()
    }

    private func handlePointerMoved(screenPoint: CGPoint) {
        lastPointerScreenPoint = screenPoint
        guard pendingThreeFingerStart || selectionSource == .threeFinger else { return }
        let swiftPoint = screenToSwiftUI(screenPoint)

        if pendingThreeFingerStart {
            pendingThreeFingerStart = false
            isSelecting = true
            selectionSource = .threeFinger
            startPoint = swiftPoint
            currentPoint = swiftPoint
            delegate?.selectionDidUpdate(calculateRect(from: swiftPoint, to: swiftPoint))
            return
        }

        guard isSelecting, let start = startPoint else { return }
        currentPoint = swiftPoint
        delegate?.selectionDidUpdate(calculateRect(from: start, to: swiftPoint))
    }

    private func latestPointerScreenPoint() -> CGPoint {
        if let location = CGEvent(source: nil)?.location {
            return location
        }
        if let lastPointerScreenPoint {
            return lastPointerScreenPoint
        }
        return NSEvent.mouseLocation
    }
    
    // MARK: - NSEvent Touch Events（如果 MultitouchSupport 不可用时的备用）
    
    override func touchesBegan(with event: NSEvent) {
        let touches = event.touches(matching: .began, in: self)
        guard touches.first != nil else { return }
        
        let swiftUILocation = eventToSwiftUI(event)
        startPoint = swiftUILocation
        currentPoint = swiftUILocation
        isSelecting = true
        selectionSource = .touchFallback
        
        let rect = calculateRect(from: swiftUILocation, to: swiftUILocation)
        delegate?.selectionDidUpdate(rect)
    }
    
    override func touchesMoved(with event: NSEvent) {
        guard selectionSource == .touchFallback, isSelecting, let start = startPoint else { return }
        
        let swiftUILocation = eventToSwiftUI(event)
        currentPoint = swiftUILocation
        
        let rect = calculateRect(from: start, to: swiftUILocation)
        delegate?.selectionDidUpdate(rect)
    }
    
    override func touchesEnded(with event: NSEvent) {
        guard selectionSource == .touchFallback, isSelecting, let start = startPoint, let end = currentPoint else {
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
        let swiftUILocation = eventToSwiftUI(event)
        startPoint = swiftUILocation
        currentPoint = swiftUILocation
        isSelecting = true
        selectionSource = .mouse
        
        let rect = calculateRect(from: swiftUILocation, to: swiftUILocation)
        delegate?.selectionDidUpdate(rect)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard selectionSource == .mouse, isSelecting, let start = startPoint else { return }
        
        let swiftUILocation = eventToSwiftUI(event)
        currentPoint = swiftUILocation
        
        let rect = calculateRect(from: start, to: swiftUILocation)
        delegate?.selectionDidUpdate(rect)
    }
    
    override func mouseUp(with event: NSEvent) {
        guard selectionSource == .mouse, isSelecting, let start = startPoint, let end = currentPoint else {
            resetSelection()
            return
        }
        
        let rect = calculateRect(from: start, to: end)
        delegate?.selectionDidFinish(rect)
        resetSelection()
    }
    
    private func resetSelection() {
        isSelecting = false
        pendingThreeFingerStart = false
        selectionSource = .none
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
