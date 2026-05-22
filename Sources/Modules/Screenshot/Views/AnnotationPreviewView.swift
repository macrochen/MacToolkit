import SwiftUI

/// 标注预览视图 - 渲染已完成和正在绘制的标注
struct AnnotationPreviewView: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    
    var body: some View {
        ZStack {
            Canvas { context, size in
                for annotation in viewModel.annotationEngine.annotations where annotation.type != .mosaic {
                    drawAnnotation(annotation, context: context)
                }

                if !viewModel.annotationPreviewPoints.isEmpty,
                   let tool = viewModel.currentTool,
                   tool != .mosaic {
                    drawPreview(tool: tool, points: viewModel.annotationPreviewPoints, context: context)
                }
            }

            ForEach(viewModel.annotationEngine.annotations.filter { $0.type == .mosaic }) { annotation in
                MosaicPatchView(viewModel: viewModel, points: annotation.points)
            }

            if viewModel.currentTool == .mosaic, !viewModel.annotationPreviewPoints.isEmpty {
                MosaicPatchView(viewModel: viewModel, points: viewModel.annotationPreviewPoints)
            }
        }
        .allowsHitTesting(false) // 不拦截鼠标事件
    }
    
    // MARK: - 绘制已完成标注
    
    private func drawAnnotation(_ annotation: Annotation, context: GraphicsContext) {
        switch annotation.type {
        case .rect:
            drawRect(points: annotation.points, color: annotation.color, lineWidth: annotation.lineWidth, context: context)
            
        case .arrow:
            drawArrow(points: annotation.points, color: annotation.color, lineWidth: annotation.lineWidth, context: context)
            
        case .freehand:
            drawFreehand(points: annotation.points, color: annotation.color, lineWidth: annotation.lineWidth, context: context)
            
        case .text:
            drawText(annotation.text ?? "", points: annotation.points, color: annotation.color, context: context)

        case .mosaic:
            break
        }
    }
    
    // MARK: - 绘制预览
    
    private func drawPreview(tool: AnnotationType, points: [CGPoint], context: GraphicsContext) {
        let previewColor = viewModel.annotationEngine.currentColor
        let lineWidth = viewModel.annotationEngine.currentLineWidth
        
        switch tool {
        case .rect:
            if points.count >= 2 {
                drawRect(points: points, color: previewColor, lineWidth: lineWidth, context: context)
            }
            
        case .arrow:
            if points.count >= 2 {
                drawArrow(points: points, color: previewColor, lineWidth: lineWidth, context: context)
            }
            
        case .freehand:
            if points.count >= 2 {
                drawFreehand(points: points, color: previewColor, lineWidth: lineWidth, context: context)
            }
            
        case .text:
            if let point = points.first {
                drawText("文字", points: [point], color: previewColor, context: context)
            }

        case .mosaic:
            break
        }
    }
    
    // MARK: - 绘制矩形
    
    private func drawRect(points: [CGPoint], color: Color, lineWidth: CGFloat, context: GraphicsContext) {
        guard points.count >= 2 else { return }
        
        let start = points[0]
        let end = points[1]
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        context.stroke(Path(rect), with: .color(color), lineWidth: lineWidth)
    }
    
    // MARK: - 绘制箭头
    
    private func drawArrow(points: [CGPoint], color: Color, lineWidth: CGFloat, context: GraphicsContext) {
        guard points.count >= 2 else { return }
        
        let start = points[0]
        let end = points[1]
        
        // 箭头主体
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
        
        // 箭头头部
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 12
        let arrowAngle: CGFloat = .pi / 6
        
        let arrow1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let arrow2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        var arrowPath = Path()
        arrowPath.move(to: end)
        arrowPath.addLine(to: arrow1)
        arrowPath.move(to: end)
        arrowPath.addLine(to: arrow2)
        context.stroke(arrowPath, with: .color(color), lineWidth: lineWidth)
    }
    
    // MARK: - 绘制画笔
    
    private func drawFreehand(points: [CGPoint], color: Color, lineWidth: CGFloat, context: GraphicsContext) {
        guard points.count >= 2 else { return }
        
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }

    // MARK: - 绘制文字

    private func drawText(_ text: String, points: [CGPoint], color: Color, context: GraphicsContext) {
        guard let point = points.first, !text.isEmpty else { return }
        context.draw(
            Text(text).font(.system(size: 18, weight: .semibold)).foregroundStyle(color),
            at: point,
            anchor: .topLeading
        )
    }
    
}

private struct MosaicPatchView: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    let points: [CGPoint]

    var body: some View {
        if let rect = mosaicRect,
           let image = mosaicImage(for: rect) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .frame(width: rect.width, height: rect.height)
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                )
                .position(x: rect.midX, y: rect.midY)
        } else if let rect = mosaicRect {
            Rectangle()
                .fill(Color.black.opacity(0.25))
                .overlay(Rectangle().stroke(Color.white.opacity(0.9), lineWidth: 1))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }

    private var mosaicRect: CGRect? {
        guard points.count >= 2 else { return nil }
        return ScreenshotGeometry.normalizedRect(from: points[0], to: points[1])
    }

    private func mosaicImage(for rect: CGRect) -> NSImage? {
        guard let baseImage = viewModel.capturedImage else { return nil }
        return AnnotationRenderer.previewMosaicImage(
            baseImage: baseImage,
            localRect: rect,
            selection: viewModel.selection,
            screenSize: viewModel.activeScreenSize
        )
    }
}
