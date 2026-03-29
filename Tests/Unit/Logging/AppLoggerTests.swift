import Testing
@testable import OpenClawMonitor

@Suite("AppLogger Tests")
struct AppLoggerTests {
    @Test func logEntryAddedAfterLogCall() async {
        let logger = AppLogger.shared
        await logger.clear()
        await logger.log(.info, .network, "test message")
        let entries = await logger.getEntries()
        #expect(entries.count >= 1)
        #expect(entries.last?.message == "test message")
    }

    @Test func ringBufferCapAt1000() async {
        let logger = AppLogger.shared
        await logger.clear()
        for i in 0..<1050 {
            await logger.log(.debug, .system, "msg \(i)")
        }
        let entries = await logger.getEntries()
        #expect(entries.count <= 1000)
    }

    @Test func getEntriesWithLevelFilter() async {
        let logger = AppLogger.shared
        await logger.clear()
        await logger.log(.debug, .network, "debug msg")
        await logger.log(.error, .network, "error msg")
        let errors = await logger.getEntries(level: .error)
        #expect(errors.allSatisfy { $0.level >= .error })
    }

    @Test func getEntriesWithCategoryFilter() async {
        let logger = AppLogger.shared
        await logger.clear()
        await logger.log(.info, .auth, "auth msg")
        await logger.log(.info, .network, "network msg")
        let authEntries = await logger.getEntries(category: .auth)
        #expect(authEntries.allSatisfy { $0.category == .auth })
    }

    @Test func clearRemovesAllEntries() async {
        let logger = AppLogger.shared
        await logger.log(.info, .ui, "some message")
        await logger.clear()
        let entries = await logger.getEntries()
        #expect(entries.isEmpty)
    }

    @Test func appLogLevelComparableOrdering() {
        #expect(AppLogLevel.debug < AppLogLevel.info)
        #expect(AppLogLevel.info < AppLogLevel.warning)
        #expect(AppLogLevel.warning < AppLogLevel.error)
        #expect(!(AppLogLevel.error < AppLogLevel.debug))
    }
}
