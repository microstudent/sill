import Foundation

public struct WindowActivationObservation {
    public var exists: Bool
    public var appIsFrontmost: Bool
    public var windowIsFocused: Bool
    public var windowIsMinimized: Bool
    public init(exists: Bool = true, appIsFrontmost: Bool, windowIsFocused: Bool, windowIsMinimized: Bool = false) {
        self.exists = exists; self.appIsFrontmost = appIsFrontmost
        self.windowIsFocused = windowIsFocused; self.windowIsMinimized = windowIsMinimized
    }
    public var confirmed: Bool { exists && appIsFrontmost && windowIsFocused && !windowIsMinimized }
}

/// Implementations marshal completions back to the session's serial executor.
public protocol WindowActivationDriver: AnyObject {
    func prepare(completion: @escaping (Bool) -> Void)
    func activate(completion: @escaping () -> Void)
    func raise(completion: @escaping () -> Void)
    func observe(completion: @escaping (WindowActivationObservation) -> Void)
    func cancel()
}

/// Activation requests are asynchronous. A successful Raise alone is not proof
/// that the requested window is frontmost, so verify it after activation settles.
public final class WindowActivationSession {
    public enum Outcome: Equatable { case confirmed, unavailable, unconfirmed, cancelled }
    public typealias Scheduler = (TimeInterval, @escaping () -> Void) -> Void
    private let driver: WindowActivationDriver
    private let schedule: Scheduler
    private let completion: (Outcome) -> Void
    private let maximumAttempts: Int
    private var attempts = 0
    private var finished = false

    public init(driver: WindowActivationDriver, maximumAttempts: Int = 4, schedule: @escaping Scheduler, completion: @escaping (Outcome) -> Void) {
        self.driver = driver; self.maximumAttempts = max(1, maximumAttempts)
        self.schedule = schedule; self.completion = completion
    }
    public func start() { guard attempts == 0, !finished else { return }; attempt() }
    public func cancel() {
        guard !finished else { return }
        driver.cancel(); finish(.cancelled)
    }
    private func attempt() {
        guard !finished else { return }
        guard attempts < maximumAttempts else { finish(.unconfirmed); return }
        attempts += 1
        driver.prepare { [weak self] ready in
            guard let self, !self.finished else { return }
            guard ready else { self.retry(); return }
            self.driver.activate { [weak self] in
                guard let self, !self.finished else { return }
                self.schedule(0.08 * Double(self.attempts)) { [weak self] in self?.raiseWhenActive() }
            }
        }
    }
    private func raiseWhenActive() {
        guard !finished else { return }
        driver.observe { [weak self] observation in
            guard let self, !self.finished else { return }
            guard observation.exists else { self.finish(.unavailable); return }
            guard observation.appIsFrontmost else { self.retry(); return }
            self.driver.raise { [weak self] in
                guard let self, !self.finished else { return }
                self.schedule(0.12) { [weak self] in self?.verify() }
            }
        }
    }
    private func verify() {
        guard !finished else { return }
        driver.observe { [weak self] observation in
            guard let self, !self.finished else { return }
            if !observation.exists { self.finish(.unavailable) }
            else if observation.confirmed { self.finish(.confirmed) }
            else { self.retry() }
        }
    }
    private func retry() {
        guard !finished else { return }
        guard attempts < maximumAttempts else { finish(.unconfirmed); return }
        schedule(0.12) { [weak self] in self?.attempt() }
    }
    private func finish(_ outcome: Outcome) {
        guard !finished else { return }
        finished = true; completion(outcome)
    }
}
