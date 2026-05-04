import SwiftUI

/// 选区视图
struct SelectionView: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    let screenSize: CGSize
    
    // 控制点大小
    private let handleSize: CGFloat = 8
    
    var body: some View {
        ZStack {
            // 选区边框
            SelectionBorder(selection: viewModel.selection)
            
            // 控制点（仅在 selected/annotating 状态显示）
            if viewModel.state == .selected || viewModel.state == .annotating {
                ResizeHandles(viewModel: viewModel, handleSize: handleSize)
            }
            
            // 选区内部拖拽区域（移动选区）
            if viewModel.state == .selected || viewModel.state == .annotating {
                SelectionDragArea(viewModel: viewModel)
            }
            
            // 选区创建拖拽区域
            if viewModel.state == .selecting {
                SelectionCreationArea(viewModel: viewModel, screenSize: screenSize)
            }
        }
    }
}

// MARK: - 选区边框

struct SelectionBorder: View {
    let selection: CGRect
    
    var body: some View {
        Rectangle()
            .stroke(Color.blue, lineWidth: 2)
            .frame(width: selection.width, height: selection.height)
            .position(x: selection.midX, y: selection.midY)
    }
}

// MARK: - 控制点

struct ResizeHandles: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    let handleSize: CGFloat
    
    var body: some View {
        let sel = viewModel.selection
        
        // 8 个控制点
        ForEach(ResizeHandle.allCases, id: \.self) { handle in
            ResizeHandleView(handle: handle, selection: sel, size: handleSize)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            resizeSelection(handle: handle, translation: value.translation)
                        }
                        .onEnded { _ in
                            // 确保选区有效
                            normalizeSelection()
                        }
                )
        }
    }
    
    private func resizeSelection(handle: ResizeHandle, translation: CGSize) {
        var sel = viewModel.selection
        let dx = translation.width
        let dy = translation.height
        
        switch handle {
        case .nw:
            sel.origin.x += dx
            sel.origin.y += dy
            sel.size.width -= dx
            sel.size.height -= dy
        case .n:
            sel.origin.y += dy
            sel.size.height -= dy
        case .ne:
            sel.origin.y += dy
            sel.size.width += dx
            sel.size.height -= dy
        case .e:
            sel.size.width += dx
        case .se:
            sel.size.width += dx
            sel.size.height += dy
        case .s:
            sel.size.height += dy
        case .sw:
            sel.origin.x += dx
            sel.size.width -= dx
            sel.size.height += dy
        case .w:
            sel.origin.x += dx
            sel.size.width -= dx
        }
        
        // 最小尺寸约束
        if sel.width >= 20 && sel.height >= 20 {
            viewModel.selection = sel
        }
    }
    
    private func normalizeSelection() {
        var sel = viewModel.selection
        if sel.width < 0 {
            sel.origin.x += sel.width
            sel.size.width = -sel.width
        }
        if sel.height < 0 {
            sel.origin.y += sel.height
            sel.size.height = -sel.height
        }
        viewModel.selection = sel
    }
}

// MARK: - 控制点枚举

enum ResizeHandle: CaseIterable {
    case nw, n, ne, e, se, s, sw, w
}

// MARK: - 控制点视图

struct ResizeHandleView: View {
    let handle: ResizeHandle
    let selection: CGRect
    let size: CGFloat
    
    var body: some View {
        Rectangle()
            .fill(Color.white)
            .stroke(Color.blue, lineWidth: 1)
            .frame(width: size, height: size)
            .position(position)
            .cursor(handle: handle)
    }
    
    private var position: CGPoint {
        switch handle {
        case .nw: return CGPoint(x: selection.minX, y: selection.minY)
        case .n:  return CGPoint(x: selection.midX, y: selection.minY)
        case .ne: return CGPoint(x: selection.maxX, y: selection.minY)
        case .e:  return CGPoint(x: selection.maxX, y: selection.midY)
        case .se: return CGPoint(x: selection.maxX, y: selection.maxY)
        case .s:  return CGPoint(x: selection.midX, y: selection.maxY)
        case .sw: return CGPoint(x: selection.minX, y: selection.maxY)
        case .w:  return CGPoint(x: selection.minX, y: selection.midY)
        }
    }
}

// MARK: - 光标修饰符

struct CursorModifier: ViewModifier {
    let handle: ResizeHandle
    
    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering {
                    cursorForHandle(handle).push()
                } else {
                    NSCursor.pop()
                }
            }
    }
    
    private func cursorForHandle(_ handle: ResizeHandle) -> NSCursor {
        switch handle {
        case .nw, .se: return NSCursor.crosshair  // nwse-resize
        case .ne, .sw: return NSCursor.crosshair  // nesw-resize
        case .n, .s:   return NSCursor.resizeUpDown
        case .e, .w:   return NSCursor.resizeLeftRight
        }
    }
}

extension View {
    func cursor(handle: ResizeHandle) -> some View {
        modifier(CursorModifier(handle: handle))
    }
}

// MARK: - 选区内部拖拽区域（移动选区）

struct SelectionDragArea: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: viewModel.selection.width, height: viewModel.selection.height)
            .position(x: viewModel.selection.midX, y: viewModel.selection.midY)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        viewModel.selection.origin.x += value.translation.width
                        viewModel.selection.origin.y += value.translation.height
                    }
            )
    }
}

// MARK: - 选区创建拖拽区域

struct SelectionCreationArea: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    let screenSize: CGSize
    
    @State private var dragStart: CGPoint?
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: screenSize.width, height: screenSize.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let start = value.startLocation
                        let end = CGPoint(x: start.x + value.translation.width,
                                         y: start.y + value.translation.height)
                        
                        let rect = CGRect(
                            x: min(start.x, end.x),
                            y: min(start.y, end.y),
                            width: abs(end.x - start.x),
                            height: abs(end.y - start.y)
                        )
                        
                        if rect.width >= 20 && rect.height >= 20 {
                            viewModel.selection = rect
                            viewModel.finishSelection()
                        }
                    }
            )
    }
}
