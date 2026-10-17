import AppKit
import CoreImage

/// One continuous texture: displacement, spectral separation and softening
/// increase smoothly within the outer band. No corner patches or tinted covers.
final class MemoryEdgeRenderer {
  private let source: CIImage
  private static let context = CIContext(options: [.cacheIntermediates: false])
  private static let kernel = CIKernel(
    source: """
      kernel vec4 memoryEdge(sampler photo, vec2 size, float band, float time) {
          vec2 p = destCoord();
          vec2 d = min(p, size - p);
          vec2 edge = 1.0 - smoothstep(vec2(0.0), vec2(band), d);
          vec2 outward = sign(p - size * 0.5);
          // Both the static stretch and its animation are confined to the corners.
          // Multiplying both distances fades the motion out along either side.
          float reach = min(band * 2.0, min(size.x, size.y) * 0.23);
          vec2 cornerFade = 1.0 - smoothstep(vec2(0.0), vec2(reach), d);
          float corner = cornerFade.x * cornerFade.y;
          vec2 wave = vec2(sin(p.y / size.y * 12.0 + time * 0.85),
                           sin(p.x / size.x * 13.0 - time * 0.73));
          vec2 pull = outward * edge * edge * band * corner * (0.32 + 0.18 * wave);
          vec2 q = p - pull;
          float strength = max(edge.x, edge.y);
          vec2 split = outward * edge * edge * band * (0.035 + 0.025 * sin(time * 0.9));
          float blur = strength * strength * band * (0.055 + 0.025 * sin(time * 0.7));
          vec2 lo = vec2(0.5);
          vec2 hi = size - lo;
          vec4 center = sample(photo, samplerTransform(photo, clamp(q, lo, hi)));
          vec4 red = sample(photo, samplerTransform(photo, clamp(q + split, lo, hi)));
          vec4 blue = sample(photo, samplerTransform(photo, clamp(q - split, lo, hi)));
          vec4 soft = (
              sample(photo, samplerTransform(photo, clamp(q + vec2(blur, blur), lo, hi))) +
              sample(photo, samplerTransform(photo, clamp(q + vec2(-blur, blur), lo, hi))) +
              sample(photo, samplerTransform(photo, clamp(q + vec2(blur, -blur), lo, hi))) +
              sample(photo, samplerTransform(photo, clamp(q - vec2(blur, blur), lo, hi)))
          ) * 0.25;
          vec4 color = mix(vec4(red.r, center.g, blue.b, center.a), soft, strength * 0.45);
          // Signed distance yields one unbroken feather around all sides and corners.
          vec2 outside = max(-d, vec2(0.0));
          float distance = max(min(d.x, d.y), 0.0) - length(outside);
          float alpha = smoothstep(-band * 0.38, band * 0.32, distance);
          return color * alpha;
      }
      """)

  init?(image: NSImage) {
    var rect = CGRect(origin: .zero, size: image.size)
    guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
      return nil
    }
    source = CIImage(cgImage: cg)
  }

  func frame(size: CGSize, time: Double) -> NSImage? {
    guard size.width > 0, size.height > 0, let kernel = Self.kernel else { return nil }
    let scale = min(2, 1600 / max(size.width, size.height))
    let pixels = CGSize(width: size.width * scale, height: size.height * scale)
    let photo = source.transformed(
      by: CGAffineTransform(
        scaleX: pixels.width / source.extent.width, y: pixels.height / source.extent.height))
    let band = min(44, min(size.width, size.height) * 0.16) * scale
    let padding = 24 * scale
    let extent = CGRect(origin: .zero, size: pixels).insetBy(dx: -padding, dy: -padding)
    guard
      let result = kernel.apply(
        extent: extent, roiCallback: { _, rect in rect.insetBy(dx: -band, dy: -band) },
        arguments: [photo, CIVector(x: pixels.width, y: pixels.height), band, time]),
      let cg = Self.context.createCGImage(result, from: extent)
    else { return nil }
    return NSImage(cgImage: cg, size: CGSize(width: size.width + 48, height: size.height + 48))
  }
}
