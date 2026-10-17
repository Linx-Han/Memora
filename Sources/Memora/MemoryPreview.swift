import AppKit
import SwiftUI

/// Presentation-only edge deformation; the source file is never changed.
struct MemoryPreview: View {
  let image: NSImage
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @State private var applicationActive = NSApplication.shared.isActive
  @State private var visible = false
  @State private var frame: NSImage?
  @State private var worker = PreviewFrameWorker()
  private struct RenderRequest: Equatable {
    let image: ObjectIdentifier
    let size: CGSize
    let animated: Bool
    let transparent: Bool
    let reduceMotion: Bool
  }
  @State private var elapsed: TimeInterval = 0
  @State private var resumedAt = Date()

  private var animated: Bool {
    visible && !reduceMotion && !reduceTransparency && applicationActive
  }

  var body: some View {
    GeometryReader { geometry in
      let size = fittedSize(in: geometry.size)
      ZStack {
        if !reduceTransparency, let frame {
          Image(nsImage: frame).resizable().interpolation(.high)
            .frame(width: size.width + 48, height: size.height + 48)
            .allowsHitTesting(false)
            .accessibilityLabel(L("原图预览"))
        } else {
          Image(nsImage: image).resizable().interpolation(.high)
            .frame(width: size.width, height: size.height)
            .accessibilityLabel(L("原图预览"))
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .task(
        id: RenderRequest(
          image: ObjectIdentifier(image), size: size, animated: animated,
          transparent: !reduceTransparency, reduceMotion: reduceMotion)
      ) {
        guard !reduceTransparency else { return }
        repeat {
          let started = Date()
          let time =
            reduceMotion ? 0 : elapsed + (animated ? started.timeIntervalSince(resumedAt) : 0)
          let rendered = await worker.frame(image: image, size: size, time: time)
          guard !Task.isCancelled else { return }
          frame = rendered
          if !animated { return }
          let remaining = max(0.001, 1.0 / 24 - Date().timeIntervalSince(started))
          do { try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) } catch {
            return
          }
        } while !Task.isCancelled
      }
      .mask {
        if !reduceTransparency {
          // Fade the outer halo before it reaches the preview container.
          PhotoFeather(size: geometry.size, width: 20)
        } else {
          Rectangle()
        }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .onAppear {
      visible = true
      applicationActive = NSApplication.shared.isActive
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in applicationActive = true }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification))
    { _ in applicationActive = false }
    .onDisappear { visible = false }
    .onChange(of: animated) { wasAnimated, isAnimated in
      if wasAnimated { elapsed += Date().timeIntervalSince(resumedAt) }
      if isAnimated { resumedAt = Date() }
    }
    .onChange(of: ObjectIdentifier(image)) {
      frame = nil
      elapsed = 0
      resumedAt = Date()
    }
  }

  private func fittedSize(in available: CGSize) -> CGSize {
    let width = max(1, available.width - 48)
    let height = max(1, available.height - 48)
    let scale = min(width / max(1, image.size.width), height / max(1, image.size.height))
    return CGSize(
      width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
  }

}

/// Multiply independent horizontal and vertical fades so all four sides and
/// corners reach zero alpha, while the interior remains fully opaque.
private struct PhotoFeather: View {
  let size: CGSize
  let width: CGFloat
  private func stops(for length: CGFloat) -> [Gradient.Stop] {
    let span = min(0.45, width / max(1, length))
    return [
      .init(color: .clear, location: 0),
      .init(color: .white.opacity(0.12), location: span * 0.25),
      .init(color: .white.opacity(0.50), location: span * 0.55),
      .init(color: .white.opacity(0.88), location: span * 0.82),
      .init(color: .white, location: span),
      .init(color: .white, location: 1 - span),
      .init(color: .white.opacity(0.88), location: 1 - span * 0.82),
      .init(color: .white.opacity(0.50), location: 1 - span * 0.55),
      .init(color: .white.opacity(0.12), location: 1 - span * 0.25),
      .init(color: .clear, location: 1),
    ]
  }
  var body: some View {
    LinearGradient(stops: stops(for: size.width), startPoint: .leading, endPoint: .trailing)
      .mask {
        LinearGradient(stops: stops(for: size.height), startPoint: .top, endPoint: .bottom)
      }
  }
}
