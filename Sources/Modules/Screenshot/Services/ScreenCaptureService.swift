import Foundation
import CoreGraphics
import AppKit

/// 截图服务
class ScreenCaptureService {
    
    /// 截取全屏（主显示器）
    static func captureFullScreen() -> CGImage? {
        let displayID = CGMainDisplayID()
        return CGDisplayCreateImage(displayID)
    }
    
    /// 截取指定屏幕
    static func captureScreen(_ screen: NSScreen) -> CGImage? {
        guard let displayID = screen.displayID else {
            // fallback 到主显示器
            return captureFullScreen()
        }
        return CGDisplayCreateImage(displayID)
    }
    
    /// 截取指定区域
    static func captureRegion(_ rect: CGRect) -> CGImage? {
        guard let fullImage = captureFullScreen() else { return nil }
        return fullImage.cropping(to: rect)
    }
    
    /// 检查屏幕录制权限
    /// 通过实际尝试截屏来检测，而不是依赖已废弃的 CGDisplayStream
    static func checkPermission() -> Bool {
        if #available(macOS 10.15, *) {
            // 直接尝试截取一小块区域来测试权限
            let testImage = CGDisplayCreateImage(CGMainDisplayID())
            return testImage != nil
        }
        return true
    }
    
    /// 请求屏幕录制权限（打开系统偏好设置）
    static func requestPermission() {
        print("[ScreenCaptureService] requestPermission called")
        
        // macOS 13+ (Ventura) 使用新的 URL scheme
        if #available(macOS 13.0, *) {
            // 尝试多种 URL scheme
            let urls = [
                "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity?Privacy_ScreenCapture"
            ]
            
            for urlString in urls {
                if let url = URL(string: urlString) {
                    print("[ScreenCaptureService] Trying URL: \(urlString)")
                    let success = NSWorkspace.shared.open(url)
                    if success {
                        print("[ScreenCaptureService] ✅ Successfully opened System Preferences")
                        return
                    }
                }
            }
            
            // 如果所有 URL 都失败，尝试直接打开系统设置
            print("[ScreenCaptureService] Trying to open System Settings directly")
            if let url = URL(string: "x-apple.systempreferences:") {
                NSWorkspace.shared.open(url)
            }
        } else if #available(macOS 10.15, *) {
            // macOS 10.15 - 12.x 使用旧的 URL scheme
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                print("[ScreenCaptureService] Opening old System Preferences")
                NSWorkspace.shared.open(url)
            }
        } else {
            // 旧版 macOS，尝试截屏触发权限请求
            _ = captureFullScreen()
        }
    }
}

// MARK: - NSScreen displayID 扩展

extension NSScreen {
    /// 获取屏幕对应的 CGDisplayID
    var displayID: CGDirectDisplayID? {
        // 通过 NSDeviceDescriptionKey 获取 displayID
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }
}