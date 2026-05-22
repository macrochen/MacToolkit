import AppKit
import SwiftUI

enum AnnotationRenderer {
    static func render(
        baseImage: CGImage,
        selection: CGRect,
        screenSize: CGSize,
        annotations: [Annotation]
    ) -> NSImage? {
        let imageSize = CGSize(width: baseImage.width, height: baseImage.height)
        let cropRect = ScreenshotGeometry.imageCropRect(
            selection: selection,
            screenSize: screenSize,
            imageSize: imageSize
        )

        guard cropRect.width > 0,
              cropRect.height > 0,
              let cropped = baseImage.cropping(to: cropRect) else {
            return nil
        }

        let outputSize = NSSize(width: cropped.width, height: cropped.height)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: cropped.width,
            pixelsHigh: cropped.height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.interpolationQuality = .high

        let drawRect = NSRect(origin: .zero, size: outputSize)
        NSImage(cgImage: cropped, size: outputSize).draw(in: drawRect)

        for annotation in annotations {
            draw(annotation, baseImage: cropped, selectionSize: selection.size, outputSize: outputSize)
        }

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: outputSize)
        image.addRepresentation(bitmap)
        return image
    }

    static func cropForOCR(
        baseImage: CGImage,
        selection: CGRect,
        screenSize: CGSize
    ) -> CGImage? {
        let imageSize = CGSize(width: baseImage.width, height: baseImage.height)
        let cropRect = ScreenshotGeometry.imageCropRect(
            selection: selection,
            screenSize: screenSize,
            imageSize: imageSize
        )
        guard cropRect.width > 0, cropRect.height > 0 else { return nil }
        return baseImage.cropping(to: cropRect)
    }

    static func pixelatedImage(from image: CGImage, pixelBlockSize: Int = 14) -> NSImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        let smallWidth = max(1, width / max(1, pixelBlockSize))
        let smallHeight = max(1, height / max(1, pixelBlockSize))

        guard let smallRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: smallWidth,
            pixelsHigh: smallHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let smallContext = NSGraphicsContext(bitmapImageRep: smallRep) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = smallContext
        smallContext.cgContext.interpolationQuality = .low
        NSImage(cgImage: image, size: NSSize(width: smallWidth, height: smallHeight))
            .draw(in: NSRect(x: 0, y: 0, width: smallWidth, height: smallHeight))
        NSGraphicsContext.restoreGraphicsState()

        guard let smallImage = smallRep.cgImage,
              let outputRep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ),
              let outputContext = NSGraphicsContext(bitmapImageRep: outputRep) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = outputContext
        outputContext.cgContext.interpolationQuality = .none
        NSImage(cgImage: smallImage, size: NSSize(width: width, height: height))
            .draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(outputRep)
        return image
    }

    static func previewMosaicImage(
        baseImage: CGImage,
        localRect: CGRect,
        selection: CGRect,
        screenSize: CGSize
    ) -> NSImage? {
        guard localRect.width > 1, localRect.height > 1 else { return nil }

        let globalRect = CGRect(
            x: selection.minX + localRect.minX,
            y: selection.minY + localRect.minY,
            width: localRect.width,
            height: localRect.height
        )
        let imageSize = CGSize(width: baseImage.width, height: baseImage.height)
        let cropRect = ScreenshotGeometry.imageCropRect(
            selection: globalRect,
            screenSize: screenSize,
            imageSize: imageSize
        )
        guard let cropped = baseImage.cropping(to: cropRect) else { return nil }
        return pixelatedImage(from: cropped)
    }

    private static func draw(_ annotation: Annotation, baseImage: CGImage, selectionSize: CGSize, outputSize: CGSize) {
        if annotation.type == .mosaic {
            drawMosaic(annotation: annotation, baseImage: baseImage, selectionSize: selectionSize, outputSize: outputSize)
            return
        }

        let points = annotation.points.map {
            let point = ScreenshotGeometry.imagePoint(fromSelectionLocal: $0, selectionSize: selectionSize, imageSize: outputSize)
            return CGPoint(x: point.x, y: outputSize.height - point.y)
        }

        switch annotation.type {
        case .rect:
            drawRect(points: points, color: annotation.color, lineWidth: scaledLineWidth(annotation.lineWidth, selectionSize: selectionSize, outputSize: outputSize))
        case .arrow:
            drawArrow(points: points, color: annotation.color, lineWidth: scaledLineWidth(annotation.lineWidth, selectionSize: selectionSize, outputSize: outputSize))
        case .freehand:
            drawFreehand(points: points, color: annotation.color, lineWidth: scaledLineWidth(annotation.lineWidth, selectionSize: selectionSize, outputSize: outputSize))
        case .text:
            drawText(annotation.text ?? "", points: points, color: annotation.color, selectionSize: selectionSize, outputSize: outputSize)
        case .mosaic:
            break
        }
    }

    private static func drawRect(points: [CGPoint], color: Color, lineWidth: CGFloat) {
        guard points.count >= 2 else { return }
        let rect = ScreenshotGeometry.normalizedRect(from: points[0], to: points[1])
        let path = NSBezierPath(rect: rect)
        path.lineWidth = lineWidth
        NSColor(color).setStroke()
        path.stroke()
    }

    private static func drawArrow(points: [CGPoint], color: Color, lineWidth: CGFloat) {
        guard points.count >= 2 else { return }
        let start = points[0]
        let end = points[1]

        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = lineWidth
        NSColor(color).setStroke()
        path.stroke()

        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength = max(12, lineWidth * 5)
        let arrowAngle = CGFloat.pi / 6
        let first = CGPoint(x: end.x - arrowLength * cos(angle - arrowAngle), y: end.y - arrowLength * sin(angle - arrowAngle))
        let second = CGPoint(x: end.x - arrowLength * cos(angle + arrowAngle), y: end.y - arrowLength * sin(angle + arrowAngle))

        let arrowPath = NSBezierPath()
        arrowPath.move(to: end)
        arrowPath.line(to: first)
        arrowPath.move(to: end)
        arrowPath.line(to: second)
        arrowPath.lineWidth = lineWidth
        arrowPath.stroke()
    }

    private static func drawFreehand(points: [CGPoint], color: Color, lineWidth: CGFloat) {
        guard points.count >= 2 else { return }
        let path = NSBezierPath()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.line(to: point)
        }
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        NSColor(color).setStroke()
        path.stroke()
    }

    private static func drawText(_ text: String, points: [CGPoint], color: Color, selectionSize: CGSize, outputSize: CGSize) {
        guard let point = points.first, !text.isEmpty else { return }
        let scale = max(outputSize.width / max(selectionSize.width, 1), outputSize.height / max(selectionSize.height, 1))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18 * scale, weight: .semibold),
            .foregroundColor: NSColor(color)
        ]
        NSString(string: text).draw(at: point, withAttributes: attributes)
    }

    private static func drawMosaic(annotation: Annotation, baseImage: CGImage, selectionSize: CGSize, outputSize: CGSize) {
        guard annotation.points.count >= 2 else { return }
        let localRect = ScreenshotGeometry.normalizedRect(from: annotation.points[0], to: annotation.points[1])
        let imageRect = CGRect(
            x: localRect.minX * outputSize.width / max(selectionSize.width, 1),
            y: localRect.minY * outputSize.height / max(selectionSize.height, 1),
            width: localRect.width * outputSize.width / max(selectionSize.width, 1),
            height: localRect.height * outputSize.height / max(selectionSize.height, 1)
        ).integral

        guard let mosaicCrop = baseImage.cropping(to: imageRect),
              let pixelated = pixelatedImage(from: mosaicCrop) else {
            return
        }

        let drawRect = NSRect(
            x: imageRect.minX,
            y: outputSize.height - imageRect.maxY,
            width: imageRect.width,
            height: imageRect.height
        )
        pixelated.draw(in: drawRect)
    }

    private static func scaledLineWidth(_ lineWidth: CGFloat, selectionSize: CGSize, outputSize: CGSize) -> CGFloat {
        let scale = max(outputSize.width / max(selectionSize.width, 1), outputSize.height / max(selectionSize.height, 1))
        return max(1, lineWidth * scale)
    }
}
