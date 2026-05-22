import SwiftUI

struct SelectionView: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    let screenSize: CGSize
    let screen: NSScreen

    private let handleSize: CGFloat = 8

    var body: some View {
        ZStack {
            SelectionBorder(selection: viewModel.selection)

            if viewModel.state == .selected {
                SelectionDragArea(viewModel: viewModel)
            }

            if viewModel.state == .selected || viewModel.state == .annotating {
                ResizeHandles(
                    viewModel: viewModel,
                    handleSize: handleSize,
                    usesResizeCursors: viewModel.state == .selected
                )
            }

            if viewModel.state == .selecting {
                TrackpadSelectionView(viewModel: viewModel, screenSize: screenSize, screen: screen)
            }
        }
    }
}

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

struct ResizeHandles: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    let handleSize: CGFloat
    let usesResizeCursors: Bool

    @State private var dragOriginalSelection: CGRect?

    var body: some View {
        ForEach(ScreenshotResizeHandle.allCases, id: \.self) { handle in
            ResizeHandleView(
                handle: handle,
                selection: viewModel.selection,
                size: handleSize,
                usesResizeCursor: usesResizeCursors
            )
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            let original = dragOriginalSelection ?? viewModel.selection
                            dragOriginalSelection = original
                            viewModel.resizeSelection(from: original, handle: handle, translation: value.translation)
                        }
                        .onEnded { _ in
                            dragOriginalSelection = nil
                        }
                )
        }
    }
}

struct ResizeHandleView: View {
    let handle: ScreenshotResizeHandle
    let selection: CGRect
    let size: CGFloat
    let usesResizeCursor: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 24, height: 24)

            Rectangle()
                .fill(Color.white)
                .stroke(Color.blue, lineWidth: 1)
                .frame(width: size, height: size)
        }
        .contentShape(Rectangle())
        .position(position)
    }

    private var position: CGPoint {
        switch handle {
        case .northWest: return CGPoint(x: selection.minX, y: selection.minY)
        case .north: return CGPoint(x: selection.midX, y: selection.minY)
        case .northEast: return CGPoint(x: selection.maxX, y: selection.minY)
        case .east: return CGPoint(x: selection.maxX, y: selection.midY)
        case .southEast: return CGPoint(x: selection.maxX, y: selection.maxY)
        case .south: return CGPoint(x: selection.midX, y: selection.maxY)
        case .southWest: return CGPoint(x: selection.minX, y: selection.maxY)
        case .west: return CGPoint(x: selection.minX, y: selection.midY)
        }
    }

}

struct SelectionDragArea: View {
    @ObservedObject var viewModel: ScreenshotViewModel

    @State private var dragOriginalSelection: CGRect?

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: viewModel.selection.width, height: viewModel.selection.height)
            .position(x: viewModel.selection.midX, y: viewModel.selection.midY)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let original = dragOriginalSelection ?? viewModel.selection
                        dragOriginalSelection = original
                        viewModel.moveSelection(from: original, translation: value.translation)
                    }
                    .onEnded { _ in
                        dragOriginalSelection = nil
                    }
            )
    }
}
