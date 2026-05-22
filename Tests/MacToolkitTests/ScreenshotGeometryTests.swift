import XCTest
@testable import MacToolkit

final class ScreenshotGeometryTests: XCTestCase {
    func testImageCropRectKeepsTopLeftOverlaySelectionInTopLeftImagePixels() {
        let selection = CGRect(x: 100, y: 50, width: 300, height: 200)
        let crop = ScreenshotGeometry.imageCropRect(
            selection: selection,
            screenSize: CGSize(width: 800, height: 600),
            imageSize: CGSize(width: 1600, height: 1200)
        )

        XCTAssertEqual(crop, CGRect(x: 200, y: 100, width: 600, height: 400))
    }

    func testResizingWestHandleKeepsEastEdgeFixedAndClampsToMinimumSize() {
        let selection = CGRect(x: 100, y: 80, width: 120, height: 90)
        let resized = ScreenshotGeometry.resizedSelection(
            selection,
            handle: .west,
            translation: CGSize(width: 200, height: 0),
            bounds: CGSize(width: 500, height: 400),
            minimumSize: CGSize(width: 20, height: 20)
        )

        XCTAssertEqual(resized, CGRect(x: 200, y: 80, width: 20, height: 90))
    }

    func testMovingSelectionClampsInsideScreenBounds() {
        let selection = CGRect(x: 430, y: 330, width: 80, height: 80)
        let moved = ScreenshotGeometry.movedSelection(
            selection,
            translation: CGSize(width: 100, height: 100),
            bounds: CGSize(width: 500, height: 400)
        )

        XCTAssertEqual(moved, CGRect(x: 420, y: 320, width: 80, height: 80))
    }
}
