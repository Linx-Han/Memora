import AppKit
import ImageIO

/// Decode a display-sized image off the main actor, leaving the original intact.
actor PreviewLoader {
  private let cache = NSCache<NSString, NSImage>()
  init() { cache.totalCostLimit = 64 * 1024 * 1024 }

  func load(_ url: URL) -> NSImage? {
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    let stamp = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
    let key = "\(url.path)|\(stamp)|\(attributes?[.size] ?? 0)" as NSString
    if let cached = cache.object(forKey: key) { return cached }
    guard
      let source = CGImageSourceCreateWithURL(
        url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
      let thumbnail = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: 1600,
          kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    else { return nil }
    let image = NSImage(
      cgImage: thumbnail, size: CGSize(width: thumbnail.width, height: thumbnail.height))
    cache.setObject(image, forKey: key, cost: thumbnail.bytesPerRow * thumbnail.height)
    return image
  }
}

/// Serial background rendering prevents animation work from blocking input.
actor PreviewFrameWorker {
  private var imageID: ObjectIdentifier?
  private var renderer: MemoryEdgeRenderer?
  func frame(image: NSImage, size: CGSize, time: Double) -> NSImage? {
    if imageID != ObjectIdentifier(image) {
      renderer = MemoryEdgeRenderer(image: image)
      imageID = ObjectIdentifier(image)
    }
    return renderer?.frame(size: size, time: time)
  }
}
