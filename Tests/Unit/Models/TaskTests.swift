import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("Task Model Tests")
struct TaskTests {
    @Test func taskStatusRawValues() {
        #expect(TaskStatus.backlog.rawValue == "backlog")
        #expect(TaskStatus.inProgress.rawValue == "in_progress")
        #expect(TaskStatus.blocked.rawValue == "blocked")
        #expect(TaskStatus.done.rawValue == "done")
    }

    @Test func taskPriorityRawValues() {
        #expect(TaskPriority.low.rawValue == "low")
        #expect(TaskPriority.medium.rawValue == "medium")
        #expect(TaskPriority.high.rawValue == "high")
    }

    @Test func ocTaskDecodeFromJSON() throws {
        let json = """
        {"id":"t1","domain":"dev","title":"Fix bug","status":"in_progress","priority":"high","tags":"[\\"swift\\",\\"ios\\"]","createdAtMs":1700000000000,"updatedAtMs":1700001000000}
        """
        let task = try JSONDecoder().decode(OCTask.self, from: Data(json.utf8))
        #expect(task.id == "t1")
        #expect(task.domain == "dev")
        #expect(task.title == "Fix bug")
        #expect(task.status == .inProgress)
        #expect(task.priority == .high)
        #expect(task.tags != nil)
    }

    @Test func ocTaskWithNilOptionals() throws {
        let json = """
        {"id":"t2"}
        """
        let task = try JSONDecoder().decode(OCTask.self, from: Data(json.utf8))
        #expect(task.id == "t2")
        #expect(task.domain == nil)
        #expect(task.title == nil)
        #expect(task.status == nil)
        #expect(task.priority == nil)
        #expect(task.tags == nil)
        #expect(task.createdAtMs == nil)
        #expect(task.updatedAtMs == nil)
    }
}
