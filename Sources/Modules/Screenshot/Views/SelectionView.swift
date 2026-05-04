import SwiftUI

/// 选区视图
struct SelectionView: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    let screenSize: CGSize
    let screen: NSScreen
    
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
            
            // 选区创建区域 - 支持触摸板滑动
            if viewModel.state == .selecting {
                TrackpadSelectionView(viewModel: viewModel, screenSize: screenSize, screen: screen)
            }
        }
    }
}

// MARK: - 选区边框

struct SelectionBorder: View {
    let selection: CGRect
    
    var body: some View {
        if selection.width > 0 && selection.height > 0 {
            Rectangle()
                .stroke(Color.blue, lineWidth: 2)
                .frame(width: selection.width, height: selection.height)
                .position(x: selection.midX, y: selection.midY)
        }
    }
}

// MARK: - 控制点

struct ResizeHandles: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    let handleSize: CGFloat
    
    var body: some View {
        let sel = viewModel.selection
        
        // 8 个控制点
        ForEach(ScreenshotViewModel.ResizeHandle.allCases, id: \.self) { handle in
            ResizeHandleView(handle: handle, selection: sel, size: handleSize)
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if !viewModel.isDragging {
                                viewModel.isDragging = true
                                viewModel.activeHandle = handle
                            }
                            resizeSelection(handle: handle, translation: value.translation)
                        }
                        .onEnded { _ in
                            viewModel.isDragging = false
                            viewModel.activeHandle = .none
                            normalizeSelection()
                        }
                )
        }
    }
    
    private func resizeSelection(handle: ScreenshotViewModel.ResizeHandle, translation: CGSize) {
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
        case .none:
            break
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

// MARK: - 控制点视图

struct ResizeHandleView: View {
    let handle: ScreenshotViewModel.ResizeHandle
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
        case .none: return .zero
        }
    }
}

// MARK: - 光标修饰符

struct CursorModifier: ViewModifier {
    let handle: ScreenshotViewModel.ResizeHandle
    
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
    
    private func cursorForHandle(_ handle: ScreenshotViewModel.ResizeHandle) -> NSCursor {
        switch handle {
        case .nw, .se: return NSCursor.crosshair  // nwse-resize
        case .ne, .sw: return NSCursor.crosshair  // nesw-resize
        case .n, .s:   return NSCursor.resizeUpDown
        case .e, .w:   return NSCursor.resizeLeftRight
        case .none:    return NSCursor.arrow
        }
    }
}

extension View {
    func cursor(handle: ScreenshotViewModel.ResizeHandle) -> some View {
        modifier(CursorModifier(handle: handle))
    }
}

// MARK: - 选区内部拖拽区域（移动选区）

struct SelectionDragArea: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    
    @State private var dragStart: CGPoint?
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: viewModel.selection.width, height: viewModel.selection.height)
            .position(x: viewModel.selection.midX, y: viewModel.selection.midY)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = CGPoint(
                                x: viewModel.selection.origin.x,
                                y: viewModel.selection.origin.y
                            )
                        }
                        if let start = dragStart {
                            viewModel.selection.origin.x = start.x + value.translation.width
                            viewModel.selection.origin.y = start.y + value.translation.height
                        }
                    }
                    .onEnded { _ in
                        dragStart = nil
                    }
            )
    }
}

// MARK: - 选区创建拖拽区域

struct SelectionCreationArea: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    let screenSize: CGSize
    
    @State private var dragStart: CGPoint?
    @State private var currentEnd: CGPoint?
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: screenSize.width, height: screenSize.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = value.startLocation
                        }
                        currentEnd = CGPoint(
                            x: value.startLocation.x + value.translation.width,
                            y: value.startLocation.y + value.translation.height
                        )
                        
                        // 实时更新选区
                        if let start = dragStart, let end = currentEnd {
                            let rect = CGRect(
                                x: min(start.x, end.x),
                                y: min(start.y, end.y),
                                width: abs(end.x - start.x),
                                height: abs(end.y - start.y)
                            )
                            viewModel.selection = rect
                        }
                    }
                    .onEnded { value in
                        if let start = dragStart, let end = currentEnd {
                            let rect = CGRect(
                                x: min(start.x, end.x),
                                y: min(start.y, end.y),
                                width: abs(end.x - start.x),
                                height: abs(end.y - start.y)
                            )
                            
                            if rect.width >= 20 && rect.height >= 20 {
                                viewModel.selection = rect
                                viewModel.finishSelection()
                            } else {
                                // 选区太小，重置
                                viewModel.selection = .zero
                            }
                        }
                        
                        dragStart = nil
                        currentEnd = nil
                    }
            )
    }
}
