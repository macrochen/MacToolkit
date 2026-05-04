import Foundation
import AppKit
import CoreGraphics

/// 导出服务
class ExportService {
    
    /// 保存图片到剪贴板
    static func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
    
    /// 保存图片到文件
    static func saveToFile(_ image: NSImage, directory: URL) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let filename = "Screenshot-\(formatter.string(from: Date())).png"
        let fileURL = directory.appendingPathComponent(filename)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        do {
            try pngData.write(to: fileURL)
            return fileURL
        } catch {
            print("保存文件失败: \(error)")
            return nil
        }
    }
    
    /// 弹出保存对话框
    static func showSavePanel(image: NSImage, defaultDirectory: URL) -> URL? {
        let panel = NSSavePanel()
        panel.title = "保存截图"
        panel.allowedContentTypes = [.png]
        panel.directoryURL = defaultDirectory
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        panel.nameFieldStringValue = "Screenshot-\(formatter.string(from: Date())).png"
        
        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        do {
            try pngData.write(to: url)
            return url
        } catch {
            print("保存文件失败: \(error)")
            return nil
        }
    }
    
    /// CGImage 转 NSImage
    static func nsImage(from cgImage: CGImage) -> NSImage {
        NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
