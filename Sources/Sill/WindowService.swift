import AppKit
import ApplicationServices
import Combine
import SillCore

struct WindowItem: Identifiable {
    let id: UInt64
    let pid: pid_t
    let bundleID: String
    let appName: String
    let title: String
    let element: AXUIElement?
    let frame: CGRect // AppKit coordinates
    let minimized: Bool
    let hidden: Bool
    let fullscreen: Bool
    let onScreen: Bool
    let focused: Bool
    let lastUsed: TimeInterval
    var label: String { title.isEmpty ? appName : title }
}

func axValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
    return result
}
func axRect(_ element: AXUIElement) -> CGRect? {
    guard let p = axValue(element, kAXPositionAttribute), let s = axValue(element, kAXSizeAttribute),
          CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero; var size = CGSize.zero
    guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
    return CGRect(origin: point, size: size)
}

/// All blocking AX reads/writes run on one serial queue. Main-thread UI receives snapshots.
final class WindowService: ObservableObject {
    @Published private(set) var windows: [WindowItem] = []
    @Published private(set) var trusted = AXIsProcessTrusted()
    @Published var actionError: String?
    var onUpdate: (() -> Void)?
    private let queue = DispatchQueue(label: "app.sill.accessibility", qos: .userInitiated)
    private var observers: [pid_t: AXObserver] = [:]
    private var observedElements: [pid_t: [AXUIElement]] = [:]
    private var workspaceTokens: [NSObjectProtocol] = []
    private var timer: Timer?
    private var pending: DispatchWorkItem?
    private var scanning = false
    private var rescanRequested = false
    // Worker-queue state only:
    private var previous: [WindowItem] = []
    private var nextID: UInt64 = 1
    private var usage: [UInt64: TimeInterval] = [:]
    private var lastFocusedID: UInt64?
    private var icons: [pid_t: NSImage] = [:]

    func start() {
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification, NSWorkspace.didHideApplicationNotification,
                     NSWorkspace.didUnhideApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didWakeNotification] {
            workspaceTokens.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.scheduleRefresh() })
        }
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refresh() }
        timer?.tolerance = 0.5
        refresh()
    }
    func stop() {
        timer?.invalidate(); pending?.cancel()
        workspaceTokens.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        queue.sync {
            for observer in observers.values { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
            observers.removeAll(); observedElements.removeAll()
        }
    }
    func icon(for item: WindowItem) -> NSImage? {
        if let image = icons[item.pid] { return image }
        let image = NSRunningApplication(processIdentifier: item.pid)?.icon
        icons[item.pid] = image
        return image
    }
    func scheduleRefresh() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }
    func refresh() {
        trusted = AXIsProcessTrusted()
        guard trusted else {
            if !windows.isEmpty { windows = []; onUpdate?() }
            return
        }
        guard !scanning else { rescanRequested = true; return }
        scanning = true
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        queue.async { [weak self] in
            guard let self else { return }
            self.synchronizeObservers(apps)
            let list = self.scan(apps: apps, primaryHeight: primaryHeight, frontPID: frontPID)
            self.synchronizeWindowObservers(list)
            DispatchQueue.main.async {
                self.scanning = false
                self.windows = list
                self.onUpdate?()
                if self.rescanRequested { self.rescanRequested = false; self.scheduleRefresh() }
            }
        }
    }
    private func synchronizeObservers(_ apps: [NSRunningApplication]) {
        let pids = Set(apps.map(\.processIdentifier))
        for pid in Array(observers.keys) where !pids.contains(pid) {
            if let observer = observers.removeValue(forKey: pid) { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
            observedElements.removeValue(forKey: pid)
            DispatchQueue.main.async { self.icons.removeValue(forKey: pid) }
        }
        for app in apps where observers[app.processIdentifier] == nil {
            var observer: AXObserver?
            let callback: AXObserverCallback = { _, _, _, context in
                guard let context else { return }
                let service = Unmanaged<WindowService>.fromOpaque(context).takeUnretainedValue()
                service.scheduleRefresh()
            }
            guard AXObserverCreate(app.processIdentifier, callback, &observer) == .success, let observer else { continue }
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, 0.15)
            for name in [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification, kAXApplicationHiddenNotification, kAXApplicationShownNotification] {
                AXObserverAddNotification(observer, element, name as CFString, Unmanaged.passUnretained(self).toOpaque())
            }
            observers[app.processIdentifier] = observer
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
    }
    private func synchronizeWindowObservers(_ items: [WindowItem]) {
        let names = [kAXUIElementDestroyedNotification, kAXTitleChangedNotification, kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification, kAXMovedNotification, kAXResizedNotification]
        for (pid, observer) in observers {
            let current = items.filter { $0.pid == pid }.compactMap(\.element)
            let old = observedElements[pid] ?? []
            for element in old where !current.contains(where: { CFEqual($0, element) }) {
                for name in names { AXObserverRemoveNotification(observer, element, name as CFString) }
            }
            for element in current where !old.contains(where: { CFEqual($0, element) }) {
                for name in names { AXObserverAddNotification(observer, element, name as CFString, Unmanaged.passUnretained(self).toOpaque()) }
            }
            observedElements[pid] = current
        }
    }
    private func scan(apps: [NSRunningApplication], primaryHeight: CGFloat, frontPID: pid_t?) -> [WindowItem] {
        let visible = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []).filter { ($0[kCGWindowLayer as String] as? Int) == 0 }
        var result: [WindowItem] = []
        for app in apps {
            let pid = app.processIdentifier
            let root = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(root, 0.15)
            var raw: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(root, kAXWindowsAttribute as CFString, &raw)
            if status == .cannotComplete {
                // A stalled application must not make its windows flicker out of the list.
                result += previous.filter { $0.pid == pid }; continue
            }
            let elements = raw as? [AXUIElement] ?? []
            let focused = axValue(root, kAXFocusedWindowAttribute)
            var validCount = 0
            for element in elements {
                guard let subrole = axValue(element, kAXSubroleAttribute) as? String,
                      [kAXStandardWindowSubrole, kAXDialogSubrole].contains(subrole),
                      let rect = axRect(element), rect.width > 40, rect.height > 30 else { continue }
                validCount += 1
                let old = previous.first { $0.pid == pid && $0.element.map { CFEqual($0, element) } == true }
                let id = old?.id ?? nextID
                if old == nil { nextID += 1 }
                let isFocused = frontPID == pid && focused.map { CFEqual($0, element) } == true
                if isFocused && lastFocusedID != id { usage[id] = Date.timeIntervalSinceReferenceDate; lastFocusedID = id }
                let onScreen = visible.contains { info in
                    guard (info[kCGWindowOwnerPID as String] as? Int32) == pid,
                          let bounds = info[kCGWindowBounds as String] as? [String: Any],
                          let cgRect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
                    return abs(cgRect.minX - rect.minX) < 3 && abs(cgRect.minY - rect.minY) < 3 && abs(cgRect.width - rect.width) < 3 && abs(cgRect.height - rect.height) < 3
                }
                result.append(WindowItem(id: id, pid: pid, bundleID: app.bundleIdentifier ?? "", appName: app.localizedName ?? "", title: axValue(element, kAXTitleAttribute) as? String ?? "", element: element,
                    frame: SidebarGeometry.accessibilityRect(rect, primaryHeight: primaryHeight),
                    minimized: axValue(element, kAXMinimizedAttribute) as? Bool ?? false, hidden: app.isHidden,
                    fullscreen: axValue(element, "AXFullScreen") as? Bool ?? false, onScreen: onScreen, focused: isFocused, lastUsed: usage[id] ?? 0))
            }
            if validCount == 0 {
                let old = previous.first { $0.pid == pid && $0.element == nil }
                let id = old?.id ?? nextID
                if old == nil { nextID += 1 }
                result.append(WindowItem(id: id, pid: pid, bundleID: app.bundleIdentifier ?? "", appName: app.localizedName ?? "", title: "", element: nil, frame: .zero, minimized: false, hidden: app.isHidden, fullscreen: false, onScreen: false, focused: false, lastUsed: usage[id] ?? 0))
            }
        }
        previous = result
        usage = usage.filter { entry in result.contains { $0.id == entry.key } }
        return result
    }
    func activate(_ item: WindowItem) {
        guard let app = NSRunningApplication(processIdentifier: item.pid) else { scheduleRefresh(); return }
        app.unhide()
        app.activate(options: [])
        queue.async {
            guard let element = item.element else { return }
            AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
            let result = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
            DispatchQueue.main.async {
                if result != .success { self.actionError = L("该应用未响应窗口切换，请重试。", "This app did not respond to window switching. Try again.") }
                self.scheduleRefresh()
            }
        }
    }
    func minimize(_ item: WindowItem) { perform(item) { AXUIElementSetAttributeValue($0, kAXMinimizedAttribute as CFString, kCFBooleanTrue) } }
    func close(_ item: WindowItem) {
        perform(item) { element in
            guard let button = axValue(element, kAXCloseButtonAttribute), CFGetTypeID(button) == AXUIElementGetTypeID() else { return .actionUnsupported }
            return AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
        }
    }
    private func perform(_ item: WindowItem, action: @escaping (AXUIElement) -> AXError) {
        guard let element = item.element else { return }
        queue.async {
            let result = action(element)
            DispatchQueue.main.async {
                if result != .success { self.actionError = L("此窗口不支持该操作或已关闭。", "This window does not support that action or has closed.") }
                self.scheduleRefresh()
            }
        }
    }
    func setFrame(_ frame: CGRect, for item: WindowItem, completion: ((Bool) -> Void)? = nil) {
        guard let element = item.element else { completion?(false); return }
        let height = NSScreen.screens.first?.frame.height ?? 0
        let rect = SidebarGeometry.accessibilityRect(frame, primaryHeight: height)
        queue.async {
            var canResize = DarwinBoolean(false)
            var canMove = DarwinBoolean(false)
            AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &canResize)
            AXUIElementIsAttributeSettable(element, kAXPositionAttribute as CFString, &canMove)
            guard canResize.boolValue && canMove.boolValue else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            let original = axRect(element)
            var p = rect.origin; var s = rect.size
            let sizeResult = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &s)!)
            let positionResult = sizeResult == .success ? AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &p)!) : sizeResult
            let success = sizeResult == .success && positionResult == .success
            if !success, sizeResult == .success, var originalSize = original?.size {
                AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &originalSize)!)
            }
            DispatchQueue.main.async { completion?(success); self.scheduleRefresh() }
        }
    }
}
