import CoreGraphics

enum ScreenshotResizeHandle: CaseIterable {
    case northWest
    case north
    case northEast
    case east
    case southEast
    case south
    case southWest
    case west
}

enum ScreenshotGeometry {
    static func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    static func movedSelection(
        _ selection: CGRect,
        translation: CGSize,
        bounds: CGSize
    ) -> CGRect {
        guard selection.width > 0, selection.height > 0 else { return .zero }

        let maxX = max(0, bounds.width - selection.width)
        let maxY = max(0, bounds.height - selection.height)
        return CGRect(
            x: clamp(selection.origin.x + translation.width, min: 0, max: maxX),
            y: clamp(selection.origin.y + translation.height, min: 0, max: maxY),
            width: selection.width,
            height: selection.height
        )
    }

    static func resizedSelection(
        _ selection: CGRect,
        handle: ScreenshotResizeHandle,
        translation: CGSize,
        bounds: CGSize,
        minimumSize: CGSize
    ) -> CGRect {
        let originalMinX = selection.minX
        let originalMinY = selection.minY
        let originalMaxX = selection.maxX
        let originalMaxY = selection.maxY

        var minX = originalMinX
        var minY = originalMinY
        var maxX = originalMaxX
        var maxY = originalMaxY

        switch handle {
        case .northWest:
            minX += translation.width
            minY += translation.height
        case .north:
            minY += translation.height
        case .northEast:
            maxX += translation.width
            minY += translation.height
        case .east:
            maxX += translation.width
        case .southEast:
            maxX += translation.width
            maxY += translation.height
        case .south:
            maxY += translation.height
        case .southWest:
            minX += translation.width
            maxY += translation.height
        case .west:
            minX += translation.width
        }

        minX = clamp(minX, min: 0, max: bounds.width)
        maxX = clamp(maxX, min: 0, max: bounds.width)
        minY = clamp(minY, min: 0, max: bounds.height)
        maxY = clamp(maxY, min: 0, max: bounds.height)

        if handle.movesLeftEdge {
            minX = min(minX, originalMaxX - minimumSize.width)
        } else if handle.movesRightEdge {
            maxX = max(maxX, originalMinX + minimumSize.width)
        }

        if handle.movesTopEdge {
            minY = min(minY, originalMaxY - minimumSize.height)
        } else if handle.movesBottomEdge {
            maxY = max(maxY, originalMinY + minimumSize.height)
        }

        minX = clamp(minX, min: 0, max: bounds.width)
        maxX = clamp(maxX, min: 0, max: bounds.width)
        minY = clamp(minY, min: 0, max: bounds.height)
        maxY = clamp(maxY, min: 0, max: bounds.height)

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func imageCropRect(
        selection: CGRect,
        screenSize: CGSize,
        imageSize: CGSize
    ) -> CGRect {
        guard screenSize.width > 0, screenSize.height > 0 else { return .zero }

        let scaleX = imageSize.width / screenSize.width
        let scaleY = imageSize.height / screenSize.height
        return CGRect(
            x: selection.minX * scaleX,
            y: selection.minY * scaleY,
            width: selection.width * scaleX,
            height: selection.height * scaleY
        ).integral
    }

    static func imagePoint(
        fromSelectionLocal point: CGPoint,
        selectionSize: CGSize,
        imageSize: CGSize
    ) -> CGPoint {
        guard selectionSize.width > 0, selectionSize.height > 0 else { return .zero }

        return CGPoint(
            x: point.x * imageSize.width / selectionSize.width,
            y: point.y * imageSize.height / selectionSize.height
        )
    }

    private static func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        min(max(value, minValue), maxValue)
    }
}

private extension ScreenshotResizeHandle {
    var movesLeftEdge: Bool {
        self == .northWest || self == .west || self == .southWest
    }

    var movesRightEdge: Bool {
        self == .northEast || self == .east || self == .southEast
    }

    var movesTopEdge: Bool {
        self == .northWest || self == .north || self == .northEast
    }

    var movesBottomEdge: Bool {
        self == .southWest || self == .south || self == .southEast
    }
}
