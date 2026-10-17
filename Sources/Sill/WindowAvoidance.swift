import AppKit
import SillCore

final class WindowAvoidance {
    private struct Adjustment {
        let original: CGRect
        var applied: CGRect
        let item: WindowItem
        var cooldownUntil: TimeInterval = 0
    }
    private let service: WindowService
    private var adjustments: [UInt64: Adjustment] = [:]
    private var inFlight = Set<UInt64>()
    private var retryAfter: [UInt64: TimeInterval] = [:]
    private var generation: UInt64 = 0
    private var pausedUntil: TimeInterval = 0
    init(service: WindowService) { self.service = service }
    func update(screens: [NSScreen]) {
        let p = Preferences.shared
        let now = Date.timeIntervalSinceReferenceDate
        guard p.autoAvoid, p.resting != .hidden, now > pausedUntil else { return }
        let ids = Set(service.windows.map(\.id))
        adjustments = adjustments.filter { ids.contains($0.key) }
        retryAfter = retryAfter.filter { ids.contains($0.key) && $0.value > now }
        for item in service.windows where item.onScreen && !item.fullscreen && !item.minimized && !item.hidden && item.element != nil {
            guard !inFlight.contains(item.id), retryAfter[item.id] == nil else { continue }
            if var adjustment = adjustments[item.id], !approximatelyEqual(item.frame, adjustment.applied) {
                if adjustment.cooldownUntil == 0 {
                    adjustment.cooldownUntil = now + 60
                    adjustments[item.id] = adjustment
                }
                if now < adjustment.cooldownUntil { continue }
                adjustments.removeValue(forKey: item.id)
            }
            guard let screen = screens.first(where: { $0.frame.contains(CGPoint(x: item.frame.midX, y: item.frame.midY)) }),
                  let proposed = SidebarGeometry.avoidingStrip(window: item.frame, visibleFrame: screen.visibleFrame, edge: p.edge, width: p.restingWidth) else { continue }
            let original = adjustments[item.id]?.original ?? item.frame
            let revision = generation
            inFlight.insert(item.id)
            service.setFrame(proposed, for: item) { [weak self] success in
                guard let self else { return }
                self.inFlight.remove(item.id)
                if revision != self.generation {
                    if success { self.service.setFrame(original, for: item) }
                    return
                }
                if success { self.adjustments[item.id] = Adjustment(original: original, applied: proposed, item: item) }
                else { self.retryAfter[item.id] = Date.timeIntervalSinceReferenceDate + 60 }
            }
        }
    }
    func restore(pauseFor seconds: TimeInterval = 60) {
        generation &+= 1
        pausedUntil = Date.timeIntervalSinceReferenceDate + seconds
        for (id, adjustment) in adjustments {
            guard let current = service.windows.first(where: { $0.id == id }), approximatelyEqual(current.frame, adjustment.applied) else { continue }
            service.setFrame(adjustment.original, for: current)
        }
        adjustments.removeAll()
    }
    private func approximatelyEqual(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX-b.minX) < 3 && abs(a.minY-b.minY) < 3 && abs(a.width-b.width) < 3 && abs(a.height-b.height) < 3
    }
}
