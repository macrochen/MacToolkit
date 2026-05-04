import Foundation
import CoreGraphics
import AppKit
import os.log
@preconcurrency import ApplicationServices

/// 触摸板手势事件引擎 - 使用 MultitouchSupport.framework 检测多指点击
class GestureEventEngine: @unchecked Sendable {
    private var devices: NSArray?
    private let logger = Logger(subsystem: "com.mactoolkit", category: "GestureEngine")
    
    var activeMappings: [GestureMapping] = []
    
    // Tap detection state
    private var activeTouches: [Int32: Date] = [:]
    private var maxFingersInGesture: Int = 0
    private var gestureActive = false
    private let tapMaxDuration: TimeInterval = 0.5  // Max duration for a "tap" vs "hold"
    
    // MultitouchSupport function pointers
    private typealias TouchCallback = @convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer, Int32, Double, Int32) -> Void
    private typealias MTDeviceCreateList_t = @convention(c) () -> CFArray
    private typealias MTRegisterCB_t = @convention(c) (CFTypeRef, TouchCallback, UnsafeMutableRawPointer?, Int32) -> Void
    private typealias MTDeviceStart_t = @convention(c) (CFTypeRef, Int32) -> Void
    
    private var mtRegister: MTRegisterCB_t?
    private var mtStart: MTDeviceStart_t?
    
    // Touch data struct (96 bytes, verified by hex dump analysis)
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
    
    init() {}
    
    func updateMappings(_ mappings: [GestureMapping]) {
        self.activeMappings = mappings
        logger.info("📝 Gesture mappings updated: \(mappings.count) rules")
    }
    
    func start() {
        guard devices == nil else {
            print("[GestureEngine] start() called but already running")
            return
        }
        
        // Load MultitouchSupport.framework
        let mtPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let mtLib = dlopen(mtPath, RTLD_NOW) else {
            print("[GestureEngine] ❌ Failed to load MultitouchSupport.framework")
            return
        }
        
        guard let symCreate = dlsym(mtLib, "MTDeviceCreateList"),
              let symRegister = dlsym(mtLib, "MTRegisterContactFrameCallback"),
              let symStart = dlsym(mtLib, "MTDeviceStart") else {
            print("[GestureEngine] ❌ MultitouchSupport symbols not found")
            return
        }
        
        let createList = unsafeBitCast(symCreate, to: MTDeviceCreateList_t.self)
        mtRegister = unsafeBitCast(symRegister, to: MTRegisterCB_t.self)
        mtStart = unsafeBitCast(symStart, to: MTDeviceStart_t.self)
        
        let deviceList = createList() as NSArray
        devices = deviceList
        
        print("[GestureEngine] 📱 Found \(deviceList.count) multitouch device(s)")
        
        for i in 0..<deviceList.count {
            let device = deviceList[i] as! CFTypeRef
            mtRegister?(device, onTouchCallback, nil, 0)
            mtStart?(device, 0)
            print("[GestureEngine] ✅ Device \(i) registered and started")
        }
        
        print("[GestureEngine] ✅ GestureEventEngine started (MultitouchSupport)")
    }
    
    func stop() {
        devices = nil
        mtRegister = nil
        mtStart = nil
        print("[GestureEngine] ⏹ GestureEventEngine stopped")
    }
    
    // MARK: - Touch callback handler
    
    fileprivate func handleTouch(
        rawTouches: UnsafeMutableRawPointer,
        numTouches: Int32
    ) {
        let count = Int(numTouches)
        let touches = rawTouches.assumingMemoryBound(to: MTTouchData.self)
        
        // Collect current touch IDs
        var currentIds = Set<Int32>()
        for i in 0..<count {
            let t = touches[i]
            currentIds.insert(t.identifier)
            
            // New touch (state 1 = began)
            if t.state == 1 && !activeTouches.keys.contains(t.identifier) {
                activeTouches[t.identifier] = Date()
                if !gestureActive {
                    gestureActive = true
                    maxFingersInGesture = 0
                }
            }
        }
        
        // Update max finger count
        if count > maxFingersInGesture {
            maxFingersInGesture = count
        }
        if count > 0 && count < maxFingersInGesture {
            // Fingers lifting one by one - keep max
        }
        
        // Remove disappeared touches
        let endedIds = activeTouches.keys.filter { !currentIds.contains($0) }
        for id in endedIds {
            activeTouches.removeValue(forKey: id)
        }
        
        // All fingers lifted = tap!
        if gestureActive && activeTouches.isEmpty {
            let fingerCount = maxFingersInGesture
            
            guard fingerCount > 0 else {
                gestureActive = false
                return
            }
            
            // Map finger count to gesture type
            guard let gestureType = mapFingerCountToGesture(fingerCount) else {
                logger.debug("No gesture mapping for \(fingerCount)-finger tap")
                gestureActive = false
                maxFingersInGesture = 0
                return
            }
            
            print("[GestureEngine] 🎯 \(fingerCount)-FINGER TAP detected → \(gestureType.displayName)")
            
            // Match and perform action
            if let mapping = activeMappings.first(where: { $0.gestureType == gestureType }) {
                print("[GestureEngine]   ✅ Matched: \(gestureType.displayName) → \(mapping.actionType.displayName)")
                performAction(mapping.actionType)
            } else {
                print("[GestureEngine]   ⚠️ No mapping for \(gestureType.displayName)")
            }
            
            gestureActive = false
            maxFingersInGesture = 0
        }
    }
    
    private func mapFingerCountToGesture(_ count: Int) -> TouchpadGestureType? {
        switch count {
        case 2:  return .threeFingerTap   // 2 fingers on trackpad = 3-finger tap convention
        case 3:  return .fourFingerTap    // 3 fingers = 4-finger tap
        case 4:  return .fourFingerTap    // 4 fingers also = 4-finger tap
        default: return nil
        }
    }
    
    // MARK: - Action execution
    
    private func performAction(_ actionType: GestureActionType) {
        let center = CGPoint(x: NSEvent.mouseLocation.x, y: NSScreen.main!.frame.height - NSEvent.mouseLocation.y)
        
        switch actionType {
        case .cmdClick:
            sendCmdClick(at: center)
        case .cmdT:
            sendKeyCombo(keyCode: 0x11, modifiers: .maskCommand)
        case .cmdW:
            sendKeyCombo(keyCode: 0x0D, modifiers: .maskCommand)
        case .cmdShiftT:
            sendKeyCombo(keyCode: 0x11, modifiers: [.maskCommand, .maskShift])
        case .cmdLeftBracket:
            sendKeyCombo(keyCode: 0x21, modifiers: .maskCommand)
        case .cmdRightBracket:
            sendKeyCombo(keyCode: 0x1E, modifiers: .maskCommand)
        case .custom:
            break
        }
    }
    
    private func sendCmdClick(at location: CGPoint) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        
        if let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: location, mouseButton: .left) {
            mouseDown.flags = .maskCommand
            mouseDown.post(tap: .cghidEventTap)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: location, mouseButton: .left) {
                mouseUp.flags = .maskCommand
                mouseUp.post(tap: .cghidEventTap)
            }
        }
    }
    
    private func sendKeyCombo(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            keyDown.flags = modifiers
            keyDown.post(tap: .cghidEventTap)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
                keyUp.flags = modifiers
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }
}

// MARK: - C callback bridge

/// C-compatible callback that bridges to the GestureEventEngine instance
private func onTouchCallback(
    device: UnsafeMutableRawPointer,
    rawTouches: UnsafeMutableRawPointer,
    numTouches: Int32,
    timestamp: Double,
    frame: Int32
) {
    // Find the engine instance via the module registry
    // Since we can't pass userInfo through this callback signature,
    // we use a shared singleton pattern
    GestureEventEngineBridge.shared.engine?.handleTouch(
        rawTouches: rawTouches,
        numTouches: numTouches
    )
}

/// Bridge singleton to connect C callback to Swift instance
class GestureEventEngineBridge: @unchecked Sendable {
    static let shared = GestureEventEngineBridge()
    weak var engine: GestureEventEngine?
}
