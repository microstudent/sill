import XCTest
@testable import SillCore

final class WindowActivationTests: XCTestCase {
    func testRaiseWaitsForDelayedApplicationActivation() {
        let clock = TestClock()
        let desktop = Desktop()
        let driver = Driver(clock: clock, desktop: desktop, target: "selected")
        driver.activationDelay = 0.2
        var result: WindowActivationSession.Outcome?
        let session = WindowActivationSession(driver: driver, schedule: clock.schedule) { result = $0 }
        session.start()
        clock.run()
        XCTAssertEqual(result, .confirmed)
        XCTAssertEqual(desktop.focusedWindow, "selected")
        XCTAssertEqual(driver.raisesWhileInactive, 0)
        XCTAssertGreaterThan(driver.preparations, 1)
    }

    func testApplicationFrontmostWithWrongWindowIsNotSuccess() {
        let clock = TestClock()
        let desktop = Desktop()
        let driver = Driver(clock: clock, desktop: desktop, target: "selected")
        driver.ignoresRaise = true
        var outcomes: [WindowActivationSession.Outcome] = []
        let session = WindowActivationSession(driver: driver, schedule: clock.schedule) { outcomes.append($0) }
        session.start()
        clock.run()
        XCTAssertEqual(outcomes, [.unconfirmed])
        XCTAssertEqual(driver.preparations, 4)
        XCTAssertEqual(desktop.focusedWindow, "previous")
    }

    func testRetriesIfApplicationChangesFocusAfterFirstRaise() {
        let clock = TestClock()
        let desktop = Desktop()
        let driver = Driver(clock: clock, desktop: desktop, target: "selected")
        driver.resetsFocusAfterFirstRaise = true
        var result: WindowActivationSession.Outcome?
        let session = WindowActivationSession(driver: driver, schedule: clock.schedule) { result = $0 }
        session.start()
        clock.run()
        XCTAssertEqual(result, .confirmed)
        XCTAssertEqual(driver.raises, 2)
        XCTAssertEqual(desktop.focusedWindow, "selected")
    }

    func testUnrestoredMinimizedWindowDoesNotConfirm() {
        let clock = TestClock()
        let desktop = Desktop()
        let driver = Driver(clock: clock, desktop: desktop, target: "selected")
        driver.minimized = true
        var result: WindowActivationSession.Outcome?
        let session = WindowActivationSession(driver: driver, schedule: clock.schedule) { result = $0 }
        session.start()
        clock.run()
        XCTAssertEqual(result, .unconfirmed)
        XCTAssertEqual(driver.preparations, 4)
    }

    func testCancelledRequestCannotRaiseAfterNewSelection() {
        let clock = TestClock()
        let desktop = Desktop()
        let oldDriver = Driver(clock: clock, desktop: desktop, target: "old")
        let newDriver = Driver(clock: clock, desktop: desktop, target: "new")
        var oldResults: [WindowActivationSession.Outcome] = []
        var newResult: WindowActivationSession.Outcome?
        let old = WindowActivationSession(driver: oldDriver, schedule: clock.schedule) { oldResults.append($0) }
        let new = WindowActivationSession(driver: newDriver, schedule: clock.schedule) { newResult = $0 }
        old.start()
        old.cancel()
        new.start()
        clock.run()
        XCTAssertEqual(oldResults, [.cancelled])
        XCTAssertTrue(oldDriver.cancelled)
        XCTAssertEqual(oldDriver.raises, 0)
        XCTAssertEqual(newResult, .confirmed)
        XCTAssertEqual(desktop.focusedWindow, "new")
    }

    func testClosedTargetStopsWithoutRaisingAnotherWindow() {
        let clock = TestClock()
        let desktop = Desktop()
        let driver = Driver(clock: clock, desktop: desktop, target: "selected")
        driver.exists = false
        var result: WindowActivationSession.Outcome?
        let session = WindowActivationSession(driver: driver, schedule: clock.schedule) { result = $0 }
        session.start()
        clock.run()
        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(driver.raises, 0)
        XCTAssertEqual(driver.preparations, 1)
    }
}

private final class TestClock {
    var now: TimeInterval = 0
    private var events: [(time: TimeInterval, action: () -> Void)] = []
    func schedule(_ delay: TimeInterval, _ action: @escaping () -> Void) { events.append((now + delay, action)) }
    func run() {
        var count = 0
        while !events.isEmpty {
            events.sort { $0.time < $1.time }
            let event = events.removeFirst()
            now = event.time
            event.action()
            count += 1
            if count > 200 { XCTFail("Activation did not settle within bounded retries"); break }
        }
    }
}
private final class Desktop {
    var frontmost = false
    var focusedWindow = "previous"
}
private final class Driver: WindowActivationDriver {
    let clock: TestClock
    let desktop: Desktop
    let target: String
    var activationDelay: TimeInterval = 0
    var ignoresRaise = false
    var resetsFocusAfterFirstRaise = false
    var minimized = false
    var exists = true
    var preparations = 0
    var raises = 0
    var raisesWhileInactive = 0
    var cancelled = false
    private var activationPending = false
    init(clock: TestClock, desktop: Desktop, target: String) { self.clock = clock; self.desktop = desktop; self.target = target }
    func prepare(completion: @escaping (Bool) -> Void) { preparations += 1; completion(true) }
    func activate(completion: @escaping () -> Void) {
        if !desktop.frontmost && !activationPending {
            activationPending = true
            // AppKit returns before the application becomes active and restores
            // its old main window. This event deliberately outlives cancellation.
            clock.schedule(activationDelay) { [self] in desktop.frontmost = true; desktop.focusedWindow = "previous" }
        }
        completion()
    }
    func raise(completion: @escaping () -> Void) {
        raises += 1
        if !desktop.frontmost { raisesWhileInactive += 1 }
        if !ignoresRaise { desktop.focusedWindow = target }
        if resetsFocusAfterFirstRaise && raises == 1 {
            clock.schedule(0.04) { [self] in desktop.focusedWindow = "previous" }
        }
        completion()
    }
    func observe(completion: @escaping (WindowActivationObservation) -> Void) {
        completion(WindowActivationObservation(exists: exists, appIsFrontmost: desktop.frontmost, windowIsFocused: desktop.focusedWindow == target, windowIsMinimized: minimized))
    }
    func cancel() { cancelled = true }
}
