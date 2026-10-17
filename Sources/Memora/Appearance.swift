import AppKit
import SwiftUI

// Pale cream glass, warm ink and soft butter-colored controls.
enum Appearance {
  static let cream = Color(red: 0.988, green: 0.969, blue: 0.906)
  static let surface = Color(red: 1.0, green: 0.989, blue: 0.953)
  static let butter = Color(red: 0.943, green: 0.886, blue: 0.718)
  static let ink = Color(red: 0.32, green: 0.30, blue: 0.25)
  static let muted = Color(red: 0.48, green: 0.45, blue: 0.37)
  static let line = Color(red: 0.88, green: 0.84, blue: 0.74)
  static let accent = Color(red: 0.49, green: 0.42, blue: 0.27)
  static let controlRadius: CGFloat = 8
  static let moduleRadius: CGFloat = 16
}

struct FrostedMaterial: NSViewRepresentable {
  var material: NSVisualEffectView.Material = .sidebar
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  final class GlassView: NSVisualEffectView {
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      window?.isOpaque = false
      window?.backgroundColor = .clear
      window?.titlebarAppearsTransparent = true
      window?.titleVisibility = .hidden
      window?.titlebarSeparatorStyle = .none
      window?.styleMask.insert(.fullSizeContentView)
      window?.isMovableByWindowBackground = true
    }
  }

  func makeNSView(context: Context) -> GlassView {
    let view = GlassView()
    view.blendingMode = .behindWindow
    return view
  }
  func updateNSView(_ view: GlassView, context: Context) {
    view.material = material
    view.state = .followsWindowActiveState
    // Respect the system accessibility setting with a fully opaque fallback.
    view.wantsLayer = true
    view.layer?.backgroundColor =
      reduceTransparency ? NSColor(red: 0.988, green: 0.969, blue: 0.906, alpha: 1).cgColor : nil
  }
}

struct GlassBackground: View {
  var tint: Double = 0.12
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  var body: some View {
    ZStack {
      if reduceTransparency {
        Appearance.cream
      } else {
        FrostedMaterial()
        Appearance.cream.opacity(0.76 + tint * 0.4)
      }
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}

struct SoftSurface: ViewModifier {
  var radius: CGFloat = Appearance.moduleRadius
  var translucent = false
  func body(content: Content) -> some View {
    content
      .background(
        LinearGradient(
          colors: [
            Appearance.surface.opacity(translucent ? 0.65 : 1),
            Appearance.cream.opacity(translucent ? 0.45 : 1),
          ], startPoint: .topLeading, endPoint: .bottomTrailing),
        in: RoundedRectangle(cornerRadius: radius, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(
          translucent ? Appearance.surface.opacity(0.70) : Appearance.line.opacity(0.65),
          lineWidth: 1
        ).allowsHitTesting(false)
      )
      .shadow(color: .black.opacity(0.015), radius: 10, x: 0, y: 3)
  }
}

struct QuietButtonStyle: ButtonStyle {
  var prominent = false
  var radius: CGFloat = Appearance.controlRadius
  func makeBody(configuration: Configuration) -> some View {
    Feedback(configuration: configuration, prominent: prominent, radius: radius)
  }
  private struct Feedback: View {
    let configuration: ButtonStyle.Configuration
    let prominent: Bool
    let radius: CGFloat
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
      configuration.label
        .foregroundStyle(enabled ? Appearance.ink : Appearance.muted.opacity(0.55))
        .background(background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(
            Appearance.accent.opacity(enabled && hovering ? 0.28 : 0), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hovering)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: configuration.isPressed)
    }
    private var background: Color {
      if prominent {
        return !enabled
          ? Appearance.cream
          : configuration.isPressed
            ? Appearance.butter
            : hovering ? Appearance.butter.opacity(0.85) : Appearance.butter.opacity(0.65)
      }
      return Appearance.accent.opacity(
        !enabled ? 0 : configuration.isPressed ? 0.12 : hovering ? 0.065 : 0)
    }
  }
}

struct SoftField: ViewModifier {
  @FocusState private var focused: Bool
  func body(content: Content) -> some View {
    content.textFieldStyle(.plain)
      .font(.system(size: 13))
      .focused($focused)
      .padding(.horizontal, 11).padding(.vertical, 9)
      .background(
        Appearance.surface.opacity(0.62),
        in: RoundedRectangle(cornerRadius: Appearance.controlRadius, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: Appearance.controlRadius, style: .continuous).stroke(
          focused ? Appearance.accent : Appearance.line.opacity(0.65), lineWidth: 1
        ).allowsHitTesting(false))
  }
}

struct AppLogo: View {
  var size: CGFloat = 36
  @State private var logo: NSImage?

  private func reload() {
    var url = Bundle.module.url(forResource: "AppIcon", withExtension: "png")
    #if DEBUG
      // SwiftUI previews may retain a stale resource bundle. Development runs
      // read the editable asset; packaged apps always use their own bundle.
      if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        || Bundle.main.bundleURL.pathExtension != "app"
      {
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
          .appendingPathComponent("Resources/AppIcon.png")
        if FileManager.default.fileExists(atPath: source.path) { url = source }
      }
    #endif
    if let url, let data = try? Data(contentsOf: url) {
      logo = NSImage(data: data)
    }
  }

  var body: some View {
    Group {
      if let logo {
        Image(nsImage: logo).resizable().scaledToFit()
      } else {
        Color.clear
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: size * 0.20, style: .continuous))
    .accessibilityHidden(true)
    .onAppear { reload() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in reload() }
  }
}

/// Shared compact frosted action for secondary controls and sheets.
struct SoftActionButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .medium))
      .padding(.horizontal, 12).padding(.vertical, 8)
      .foregroundStyle(Appearance.ink)
      .modifier(SoftSurface(radius: 8, translucent: true))
      .overlay(
        RoundedRectangle(cornerRadius: 8).fill(
          Appearance.accent.opacity(configuration.isPressed ? 0.10 : 0))
      )
      .contentShape(RoundedRectangle(cornerRadius: 8))
      .opacity(enabled ? 1 : 0.45)
  }
}

struct InspectorSection<Content: View>: View {
  let title: String
  @ViewBuilder var content: () -> Content
  @State private var expanded = false
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        expanded.toggle()
      } label: {
        HStack {
          Text(L(title)).font(.system(size: 14, weight: .medium))
          Spacer()
          Image(systemName: expanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Appearance.muted)
        }.padding(.horizontal, 10).padding(.vertical, 12)
          .frame(maxWidth: .infinity).contentShape(Rectangle())
      }.buttonStyle(QuietButtonStyle())
        .accessibilityValue(L(expanded ? "已展开" : "已收起"))
      if expanded { content() }
    }
  }
}

/// Slim native overlay scrollers keep dragging, wheel and trackpad behavior.
struct WarmScrollView<Content: View>: View {
  @ViewBuilder var content: () -> Content
  var body: some View {
    ScrollView {
      content().padding(.trailing, 8)
        .background(ScrollAppearance())
    }
  }
}

private struct ScrollAppearance: NSViewRepresentable {
  final class Probe: NSView {
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      DispatchQueue.main.async { [weak self] in self?.configure() }
    }
    func configure() {
      guard let scroll = enclosingScrollView else { return }
      scroll.scrollerStyle = .overlay
      scroll.autohidesScrollers = true
      scroll.drawsBackground = false
      if !(scroll.verticalScroller is CreamScroller) {
        scroll.verticalScroller = CreamScroller()
      }
    }
  }
  func makeNSView(context: Context) -> Probe { Probe() }
  func updateNSView(_ view: Probe, context: Context) {
    DispatchQueue.main.async { view.configure() }
  }
}

private final class CreamScroller: NSScroller {
  override class var isCompatibleWithOverlayScrollers: Bool { true }
  override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}
  override func drawKnob() {
    let knob = rect(for: .knob)
    guard knob.height > 0 else { return }
    let slim = NSRect(
      x: knob.midX - 2.5, y: knob.minY + 2, width: 5, height: max(0, knob.height - 4))
    NSColor(calibratedRed: 0.57, green: 0.50, blue: 0.36, alpha: 0.48).setFill()
    NSBezierPath(roundedRect: slim, xRadius: 2.5, yRadius: 2.5).fill()
  }
}

struct WelcomeEntrance: ViewModifier {
  let delay: Double
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false

  func body(content: Content) -> some View {
    content
      .mask { WelcomeVeil(progress: appeared || reduceMotion ? 1 : 0) }
      .allowsHitTesting(appeared || reduceMotion)
      .task {
        guard !appeared else { return }
        if reduceMotion {
          appeared = true
          return
        }
        do { try await Task.sleep(nanoseconds: UInt64((0.05 + delay) * 1_000_000_000)) } catch {
          return
        }
        withAnimation(.linear(duration: 1.15)) { appeared = true }
      }
      .onDisappear { appeared = false }
  }
}

/// Only opacity changes across the stationary content; a broad, soft front
/// travels at constant speed, with no slide or deceleration of the artwork.
private struct WelcomeVeil: View, Animatable {
  var progress: Double
  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }
  var body: some View {
    let leading = -1.4 + 2.4 * progress
    LinearGradient(
      stops: [
        .init(color: .white, location: 0),
        .init(color: .white.opacity(0.95), location: 0.2),
        .init(color: .white.opacity(0.72), location: 0.4),
        .init(color: .white.opacity(0.28), location: 0.6),
        .init(color: .white.opacity(0.05), location: 0.8),
        .init(color: .clear, location: 1),
      ], startPoint: UnitPoint(x: leading, y: 0.5),
      endPoint: UnitPoint(x: leading + 1.4, y: 0.5))
  }
}
