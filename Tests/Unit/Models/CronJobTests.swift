import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("CronJob Model Tests")
struct CronJobTests {
    @Test func cronJobDecodeFromJSON() throws {
        let json = """
        {"id":"daily-check","name":"Daily Check","enabled":true,"state":{"lastRunAtMs":1700000000000,"nextRunAtMs":1700086400000,"lastStatus":"ok"},"updatedAtMs":1700000000000}
        """
        let job = try JSONDecoder().decode(CronJob.self, from: Data(json.utf8))
        #expect(job.id == "daily-check")
        #expect(job.name == "Daily Check")
        #expect(job.enabled == true)
        #expect(job.state?.lastStatus == "ok")
        #expect(job.state?.lastRunAtMs == 1700000000000)
        #expect(job.state?.nextRunAtMs == 1700086400000)
    }

    @Test func cronJobStateDecodeAllFields() throws {
        let json = """
        {"lastRunAtMs":1700000000000,"nextRunAtMs":1700086400000,"lastStatus":"error"}
        """
        let state = try JSONDecoder().decode(CronJobState.self, from: Data(json.utf8))
        #expect(state.lastRunAtMs == 1700000000000)
        #expect(state.nextRunAtMs == 1700086400000)
        #expect(state.lastStatus == "error")
    }

    @Test func cronJobWithNilOptionals() throws {
        let json = """
        {"id":"simple"}
        """
        let job = try JSONDecoder().decode(CronJob.self, from: Data(json.utf8))
        #expect(job.id == "simple")
        #expect(job.name == nil)
        #expect(job.enabled == nil)
        #expect(job.state == nil)
        #expect(job.updatedAtMs == nil)
    }
}
