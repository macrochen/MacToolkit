import SwiftUI
import AppKit

/// SPM 资源 bundle 查找
extension Bundle {
    static var moduleBundle: Bundle {
        // 在 MacToolkit 中，资源 bundle 名为 MacToolkit_MacToolkit.bundle
        if let bundles = Bundle.main.urls(forResourcesWithExtension: "bundle", subdirectory: nil) {
            for bundleURL in bundles {
                if bundleURL.lastPathComponent.contains("MacToolkit") {
                    if let bundle = Bundle(url: bundleURL) {
                        return bundle
                    }
                }
            }
        }
        return Bundle.main
    }
}

/// 用 NSImageView 播放 APNG 动画，displaySeconds 后停止
struct CatVideoPlayerView: NSViewRepresentable {
    let imageName: String
    let displaySeconds: Int

    func makeNSView(context: Context) -> NSImageView {
        let imageView = PassthroughNSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        imageView.isEditable = false

        let resourceBundle = Bundle.moduleBundle
        if let url = resourceBundle.url(forResource: imageName, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            imageView.image = image
            // displaySeconds 后停止动画
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(displaySeconds)) {
                imageView.animates = false
            }
        }

        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {}
}

/// 不拦截鼠标事件的 NSImageView
class PassthroughNSImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}
