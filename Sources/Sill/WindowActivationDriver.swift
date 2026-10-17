import AppKit
import ApplicationServices
import OSLog
import SillCore

/// AX calls stay off the main thread. This instance owns one explicitly selected
/// window; retries never substitute another window from the same application.
final class AccessibilityWindowActivation: WindowActivationDriver {
    private let app: NSRunningApplication
    private let element: AXUIElement?
    private let root: AXUIElement
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var cancelled = false
    private let log = Logger(subsystem: "local.sill.app", category: "WindowActivation")
    init(app: NSRunningApplication, element: AXUIElement?, queue: DispatchQueue) {
        self.app = app; self.element = element; self.queue = queue
        root = AXUIElementCreateApplication(app.processIdentifier)
    }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    private var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    private func work(_ action: @escaping () -> Void) {
        queue.async { [self] in guard !isCancelled else { return }; action() }
    }
    private func complete(_ action: @escaping () -> Void) {
        DispatchQueue.main.async { [self] in guard !isCancelled else { return }; action() }
    }
    func prepare(completion: @escaping (Bool) -> Void) {
        work { [self] in
            guard !app.isTerminated else { complete { completion(false) }; return }
            AXUIElementSetMessagingTimeout(root, 0.2)
            if let element {
                AXUIElementSetMessagingTimeout(element, 0.2)
                if axValue(element, kAXMinimizedAttribute) as? Bool == true {
                    let result = AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                    log.debug("restore pid=\(self.app.processIdentifier) status=\(result.rawValue)")
                }
                guard !isCancelled else { return }
                // Select before activating; otherwise the app restores its old main window.
                setIfWritable(element, kAXMainAttribute, kCFBooleanTrue)
            }
            complete { completion(true) }
        }
    }
    func activate(completion: @escaping () -> Void) {
        guard !isCancelled else { return }
        app.unhide()
        let accepted: Bool
        if NSApp.isActive {
            NSApp.yieldActivation(to: app)
            accepted = app.activate(from: .current, options: [])
        } else {
            accepted = app.activate(options: [])
        }
        log.debug("activate pid=\(self.app.processIdentifier) accepted=\(accepted)")
        // A nonactivating sidebar can issue the request while Sill is in the
        // background. Use the authorized AX frontmost operation as a fallback.
        work { [self] in
            if axValue(root, kAXFrontmostAttribute) as? Bool != true {
                setIfWritable(root, kAXFrontmostAttribute, kCFBooleanTrue)
            }
            complete(completion)
        }
    }
    func raise(completion: @escaping () -> Void) {
        work { [self] in
            if let element {
                setIfWritable(element, kAXMainAttribute, kCFBooleanTrue)
                guard !isCancelled else { return }
                setIfWritable(root, kAXFocusedWindowAttribute, element)
                guard !isCancelled else { return }
                setIfWritable(element, kAXFocusedAttribute, kCFBooleanTrue)
                guard !isCancelled else { return }
                let result = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
                // Some apps reject Raise but do focus the window. The subsequent
                // observation, not this return code, decides whether we succeeded.
                log.debug("raise pid=\(self.app.processIdentifier) status=\(result.rawValue)")
            }
            complete(completion)
        }
    }
    func observe(completion: @escaping (WindowActivationObservation) -> Void) {
        work { [self] in
            let frontmost = axValue(root, kAXFrontmostAttribute) as? Bool == true
            var exists = !app.isTerminated
            var focused = true
            var minimized = false
            if let element {
                var role: CFTypeRef?
                let status = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
                if status == .invalidUIElement { exists = false }
                focused = axValue(root, kAXFocusedWindowAttribute).map { CFEqual($0, element) } ?? false
                var minimizedValue: CFTypeRef?
                let minimizedStatus = AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &minimizedValue)
                // Dialogs may not support minimizing. Other read failures are
                // not evidence that a previously minimized window was restored.
                minimized = minimizedStatus == .attributeUnsupported ? false : (minimizedValue as? Bool ?? true)
            }
            let observation = WindowActivationObservation(exists: exists, appIsFrontmost: frontmost, windowIsFocused: focused, windowIsMinimized: minimized)
            log.debug("observe pid=\(self.app.processIdentifier) front=\(frontmost) focused=\(focused) minimized=\(minimized)")
            complete { completion(observation) }
        }
    }
    private func setIfWritable(_ target: AXUIElement, _ attribute: String, _ value: CFTypeRef) {
        guard !isCancelled else { return }
        var writable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(target, attribute as CFString, &writable) == .success, writable.boolValue, !isCancelled {
            AXUIElementSetAttributeValue(target, attribute as CFString, value)
        }
    }
}
