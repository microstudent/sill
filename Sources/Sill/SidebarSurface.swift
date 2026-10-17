import AppKit

final class SidebarSurface: NSView {
    let content = NSView()
    var hideGesture: (() -> Void)?
    private var gesture = SidebarGesture()
    private var background: NSView?
    private var currentMaterial = ""

    func updateMaterial(_ requested: String) {
        let material: String
        if #available(macOS 26.0, *), requested == "glass" || requested == "clearGlass" {
            material = requested
        } else {
            material = "frosted"
        }
        guard currentMaterial != material else { return }
        currentMaterial = material
        content.removeFromSuperview()
        background?.removeFromSuperview()

        let effect: NSView
        if #available(macOS 26.0, *), material != "frosted" {
            let glass = NSGlassEffectView()
            glass.style = material == "clearGlass" ? .clear : .regular
            glass.cornerRadius = 11
            // Only contentView is guaranteed to render above the native glass.
            glass.contentView = content
            effect = glass
        } else {
            let frosted = NSVisualEffectView()
            frosted.material = .popover
            frosted.blendingMode = .behindWindow
            frosted.state = .active
            frosted.wantsLayer = true
            frosted.layer?.cornerRadius = 11
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
