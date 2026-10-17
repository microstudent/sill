import AppKit

class MaterialSurface: NSView {
    let content = MaterialContentView()
    private let cornerRadius: CGFloat
    private var background: NSView?
    private var currentMaterial = ""

    init(cornerRadius: CGFloat = 11) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }

    func updateMaterial(_ requested: String) {
        let material: String
        if #available(macOS 26.0, *), requested == "glass" || requested == "clearGlass" {
            material = requested
        } else {
            material = "frosted"
        }
        guard currentMaterial != material else { return }
        currentMaterial = material
        content.clearGlass = material == "clearGlass"
        content.cornerRadius = cornerRadius
        content.removeFromSuperview()
        background?.removeFromSuperview()

        let effect: NSView
        if #available(macOS 26.0, *), material != "frosted" {
            let glass = NSGlassEffectView()
            glass.style = material == "clearGlass" ? .clear : .regular
            glass.cornerRadius = cornerRadius
            // Only contentView is guaranteed to render above the native glass.
            glass.contentView = content
            effect = glass
        } else {
            let frosted = NSVisualEffectView()
            frosted.material = .popover
            frosted.blendingMode = .behindWindow
            frosted.state = .active
            frosted.wantsLayer = true
            frosted.layer?.cornerRadius = cornerRadius
            frosted.layer?.masksToBounds = true
            frosted.addSubview(content)
            effect = frosted
        }
        effect.frame = bounds
        effect.autoresizingMask = [.width, .height]
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(effect)
        background = effect
    }
}

/// Clear glass can sit over arbitrary desktop content. A translucent neutral
/// wash keeps dense text legible while retaining the native glass edges.
final class MaterialContentView: NSView {
    var clearGlass = false { didSet { needsDisplay = true } }
    var cornerRadius: CGFloat = 11
    override func draw(_ dirtyRect: NSRect) {
        guard clearGlass else { return }
        NSColor.windowBackgroundColor.withAlphaComponent(0.68).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius).fill()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

final class SidebarSurface: MaterialSurface {
    var hideGesture: (() -> Void)?
    private var gesture = SidebarGesture()

    override func scrollWheel(with event: NSEvent) {
        if gesture.consume(event) { hideGesture?() }
        else { super.scrollWheel(with: event) }
    }
}

/// A scroll view normally consumes horizontal events before its parent sees them.
final class SidebarScrollView: NSScrollView {
    var willScroll: (() -> Void)?
    var hideGesture: (() -> Void)?
    private var gesture = SidebarGesture()
    override func scrollWheel(with event: NSEvent) {
        willScroll?()
        if gesture.consume(event) { hideGesture?() }
        else { super.scrollWheel(with: event) }
    }
}

private struct SidebarGesture {
    private var horizontal: CGFloat = 0
    private var lastTime: TimeInterval = 0
    mutating func consume(_ event: NSEvent) -> Bool {
        guard event.momentumPhase.isEmpty, abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return false }
        if event.phase == .began || event.timestamp - lastTime > 0.3 { horizontal = 0 }
        lastTime = event.timestamp
        // A dismissal follows the physical gesture, independently of Natural Scrolling.
        horizontal += event.scrollingDeltaX * (event.isDirectionInvertedFromDevice ? -1 : 1)
        let sign: CGFloat = Preferences.shared.edge == .left ? 1 : -1
        if horizontal * sign > 30 { horizontal = 0; return true }
        return false
    }
}
