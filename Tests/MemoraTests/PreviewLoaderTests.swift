import AppKit
import XCTest

@testable import Memora

final class PreviewLoaderTests: XCTestCase {
  func testLargePreviewIsDownsampledAndCached() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".png")
    defer { try? FileManager.default.removeItem(at: url) }
    let bitmap = try XCTUnwrap(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 3200, pixelsHigh: 1800, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0))
    let original = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    try original.write(to: url)
    let loader = PreviewLoader()
    let first = await loader.load(url)
    let image = try XCTUnwrap(first)
    XCTAssertEqual(image.size.width, 1600)
    XCTAssertEqual(image.size.height, 900)
    let second = await loader.load(url)
    XCTAssertTrue(image === second)
    XCTAssertEqual(try Data(contentsOf: url), original)
    let worker = PreviewFrameWorker()
    let rendered = await worker.frame(image: image, size: CGSize(width: 400, height: 225), time: 0)
    XCTAssertNotNil(rendered)
  }
}
