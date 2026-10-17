import AppKit
import XCTest

@testable import Memora

final class MemoryPreviewTests: XCTestCase {
  @MainActor func testContinuousEdgeAnimationKeepsCenterStill() throws {
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 400, pixelsHigh: 300, bitsPerSample: 8, samplesPerPixel: 4,
      hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    for y in 0..<300 {
      for x in 0..<400 {
        bitmap.setColor(
          NSColor(
            calibratedRed: CGFloat((x / 14) % 2) * 0.7 + 0.15, green: CGFloat(y) / 300,
            blue: CGFloat(x) / 400, alpha: 1), atX: x, y: y)
      }
    }
    let image = NSImage(size: NSSize(width: 400, height: 300))
    image.addRepresentation(bitmap)
    let renderer = try XCTUnwrap(MemoryEdgeRenderer(image: image))
    func render(_ time: Double) throws -> NSBitmapImageRep {
      let frame = try XCTUnwrap(renderer.frame(size: CGSize(width: 400, height: 300), time: time))
      var rect = CGRect(origin: .zero, size: frame.size)
      return NSBitmapImageRep(
        cgImage: try XCTUnwrap(frame.cgImage(forProposedRect: &rect, context: nil, hints: nil)))
    }
    let a = try render(0)
    let b = try render(2.0)
    var sides = [0, 0, 0, 0]
    for y in 0..<a.pixelsHigh {
      for x in 0..<a.pixelsWide {
        let ca = a.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
        let cb = b.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
        let delta =
          abs(ca.redComponent - cb.redComponent) + abs(ca.greenComponent - cb.greenComponent)
          + abs(ca.blueComponent - cb.blueComponent)
        let px = Double(x) / 2 - 24
        let py = Double(y) / 2 - 24
        if px > 60 && px < 340 && py > 60 && py < 240 { XCTAssertLessThan(delta, 0.001) }
        if delta > 0.02 {
          if px > 100 && px < 300 && py >= 0 && py < 18 { sides[0] += 1 }
          if px > 100 && px < 300 && py > 282 && py < 300 { sides[1] += 1 }
          if py > 75 && py < 225 && px >= 0 && px < 18 { sides[2] += 1 }
          if py > 75 && py < 225 && px > 382 && px < 400 { sides[3] += 1 }
        }
      }
    }
    for count in sides {
      XCTAssertGreaterThan(count, 30, "Every side must animate away from the corners")
    }
  }
}
