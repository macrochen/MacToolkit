import Foundation
import CoreGraphics
import AppKit

/// 截图服务
class ScreenCaptureService {
    
    /// 截取全屏
    static func captureFullScreen() -> CGImage? {
        let displayID = CGMainDisplayID()
        return CGDisplayCreateImage(displayID)
    }
    
    /// 截取指定区域
    static func captureRegion(_ rect: CGRect) -> CGImage? {
        guard let fullImage = captureFullScreen() else { return nil }
        return fullImage.cropping(to: rect)
    }
    
    /// 检查屏幕录制权限
    static func checkPermission() -> Bool {
        // macOS 10.15+ 需要屏幕录制权限
        if #available(macOS 10.15, *) {
            let stream = CGDisplayStream(
                display: CGMainDisplayID(),
                outputWidth: 1,
                outputHeight: 1,
                pixelFormat: Int32(kCVPixelFormatType_32BGRA),
                properties: nil,
                handler: { _, _, _, _ in }
            )
            return stream != nil
        }
        return true
    }
    
    /// 请求屏幕录制权限（打开系统偏好设置）
    static func requestPermission() {
        // 触发一次截屏尝试，系统会自动弹出权限请求
        _ = captureFullScreen()
    }
}
