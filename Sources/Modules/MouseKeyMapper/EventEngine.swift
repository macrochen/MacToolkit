import Foundation
import CoreGraphics
import AppKit
import os.log
@preconcurrency import ApplicationServices

/// 鼠标事件映射引擎
/// 注意：此类在主线程运行，但为了兼容 CGEvent 回调不标记 @MainActor
class EventEngine: @unchecked Sendable {
    var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var activeMappings: [KeyMapping] = []

    // 滚轮防抖
    private var lastScrollTime: TimeInterval = 0
    private let scrollCooldown: TimeInterval = 0.15

    private let logger = Logger(subsystem: "com.mactoolkit", category: "EventEngine")

    init() {}

    func updateMappings(_ mappings: [KeyMapping]) {
        self.activeMappings = mappings
        logger.info("📝 Mappings updated: \(mappings.count) rules")
    }

    func start() {
        guard eventTap == nil else {
            logger.warning("start() called but eventTap already exists")
            return
        }

        // 检查辅助功能权限
        let isTrusted = AXIsProcessTrusted()
        logger.info("🔐 Accessibility permission: \(isTrusted)")

        if !isTrusted {
            logger.warning("App lacks Accessibility permissions! Requesting...")
            // 请求权限（会弹出系统对话框）
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }

        let eventMask = (1 << CGEventType.scrollWheel.rawValue) |
                        (1 << CGEventType.otherMouseDown.rawValue) |
                        (1 << CGEventType.otherMouseUp.rawValue)

        logger.info("🔧 Creating event tap with mask: \(eventMask)")

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,  // 被动监听，不拦截事件，pkill 时不会破坏系统事件链
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventTapCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            logger.error("❌ Failed to create event tap!")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logger.info("✅ EventEngine started successfully!")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }

    // MARK: - Event Logic

    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        logger.debug("🎯 Event received: type=\(type.rawValue), mappings=\(self.activeMappings.count)")

        guard let inputType = identifyInputType(type: type, event: event) else {
            return Unmanaged.passUnretained(event)
        }

        logger.debug("   -> Identified as: \(inputType.rawValue)")

        // 防抖 (仅针对滚轮)
        if inputType.rawValue.contains("scroll") {
            let now = Date().timeIntervalSince1970
            if now - lastScrollTime < scrollCooldown {
                return Unmanaged.passUnretained(event)
            }
            lastScrollTime = now
        }

        // 匹配规则
        if let mapping = activeMappings.first(where: { $0.inputType == inputType }) {
            logger.info("   -> ✅ Matched mapping: \(mapping.targetDescription ?? "nil"), performing keystroke")
            performKeystroke(mapping)
            return nil
        }

        logger.debug("   -> No mapping found, passing through")
        return Unmanaged.passUnretained(event)
    }

    private func identifyInputType(type: CGEventType, event: CGEvent) -> MouseInputType? {
        if type == .scrollWheel {
            let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
            if isContinuous != 0 { return nil }

            let deltaX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
            let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)

            if deltaX == 0 && deltaY == 0 { return nil }

            if abs(deltaX) > abs(deltaY) {
                return deltaX > 0 ? .scrollRight : .scrollLeft
            } else {
                return deltaY > 0 ? .scrollDown : .scrollUp
            }
        } else if type == .otherMouseDown {
            let btnNum = event.getIntegerValueField(.mouseEventButtonNumber)
            switch btnNum {
            case 2: return .middleButton
            case 3: return .button4
            case 4: return .button5
            default: return nil
            }
        }
        return nil
    }

    private func performKeystroke(_ mapping: KeyMapping) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: mapping.targetKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: mapping.targetKeyCode, keyDown: false) else {
            return
        }

        let flags = CGEventFlags(rawValue: mapping.targetModifiers)
        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cghidEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            keyUp.post(tap: .cghidEventTap)
        }
    }
}

func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let engine = Unmanaged<EventEngine>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout {
        if let tap = engine.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }

    return engine.handleEvent(proxy: proxy, type: type, event: event)
}
