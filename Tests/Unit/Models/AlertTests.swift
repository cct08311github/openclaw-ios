import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("Alert Model Tests")
struct AlertTests {
    @Test func alertSeverityRawValues() {
        #expect(AlertSeverity.info.rawValue == "info")
        #expect(AlertSeverity.warn.rawValue == "warn")
        #expect(AlertSeverity.error.rawValue == "error")
    }

    @Test func ocAlertDecodeFromJSON() throws {
        let json = """
        {"id":"a1","timestamp":1700000000000,"severity":"error","message":"CPU spike","source":"watchdog"}
        """
        let alert = try JSONDecoder().decode(OCAlert.self, from: Data(json.utf8))
        #expect(alert.id == "a1")
        #expect(alert.timestamp == 1700000000000)
        #expect(alert.severity == .error)
        #expect(alert.message == "CPU spike")
        #expect(alert.source == "watchdog")
    }

    @Test func ocAlertWithNilOptionals() throws {
        let json = """
        {"id":"a2"}
        """
        let alert = try JSONDecoder().decode(OCAlert.self, from: Data(json.utf8))
        #expect(alert.id == "a2")
        #expect(alert.timestamp == nil)
        #expect(alert.severity == nil)
        #expect(alert.message == nil)
        #expect(alert.source == nil)
    }
}
