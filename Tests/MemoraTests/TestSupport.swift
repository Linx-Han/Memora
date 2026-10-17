import AppKit

@testable import Memora

enum TestFixtures {
  static func image(_ type: NSBitmapImageRep.FileType, ext: String, folder: URL) throws -> URL {
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 24, bitsPerSample: 8, samplesPerPixel: 3,
      hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    for y in 0..<24 {
      for x in 0..<32 {
        bitmap.setColor(
          NSColor(calibratedRed: CGFloat(x) / 32, green: CGFloat(y) / 24, blue: 0.5, alpha: 1),
          atX: x, y: y)
      }
    }
    let url = folder.appendingPathComponent("原始 照片.\(ext)")
    try bitmap.representation(using: type, properties: [:])!.write(to: url)
    return url
  }
}

extension MetadataDate {
  static func equivalent(_ actual: String, _ expected: String) -> Bool {
    guard let lhs = canonical(actual), let rhs = canonical(expected) else { return false }
    return lhs == rhs
  }

}

// Test-only image-data measurements; never invoked by application saving.
extension MetadataEngine {
  func digest(_ url: URL) throws -> String {
    let data = try run(["-api", "RequestAll=3", "-s3", "-ImageDataMD5", url.path])
    let hash =
      String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard hash.count == 32, hash.allSatisfy({ $0.isHexDigit }) else {
      throw MetadataError(message: "Test fixture does not expose an image-data digest.")
    }
    return hash
  }

}
