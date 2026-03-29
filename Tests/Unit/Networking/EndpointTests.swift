import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("Endpoint Tests")
struct EndpointTests {
    @Test func loginEndpoint() {
        let endpoint = Endpoint.login(username: "admin", password: "pass")
        #expect(endpoint.path == "/api/auth/login")
        #expect(endpoint.method == .POST)
        #expect(endpoint.bodyData != nil)
    }

    @Test func meEndpoint() {
        let endpoint = Endpoint.me
        #expect(endpoint.path == "/api/auth/me")
        #expect(endpoint.method == .GET)
    }

    @Test func cronToggleContainsId() {
        let endpoint = Endpoint.cronToggle(id: "job-123")
        #expect(endpoint.path.contains("job-123"))
        #expect(endpoint.method == .POST)
    }

    @Test func cronRunHas30sTimeout() {
        let endpoint = Endpoint.cronRun(id: "job-456")
        #expect(endpoint.timeoutInterval == 30)
    }

    @Test func tasksWithDomainIncludesQueryItems() {
        let endpoint = Endpoint.tasks(domain: "dev")
        #expect(endpoint.queryItems != nil)
        #expect(endpoint.queryItems?.first?.name == "domain")
        #expect(endpoint.queryItems?.first?.value == "dev")
    }

    @Test func tasksWithNilDomainHasNoQueryItems() {
        let endpoint = Endpoint.tasks(domain: nil)
        #expect(endpoint.queryItems == nil)
    }

    @Test func commandEndpointEncodesBody() {
        struct TestBody: Encodable { let command: String }
        let endpoint = Endpoint.command(body: TestBody(command: "status"))
        #expect(endpoint.path == "/api/control/command")
        #expect(endpoint.method == .POST)
        #expect(endpoint.bodyData != nil)
    }

    @Test func systemComprehensiveHas15sTimeout() {
        let endpoint = Endpoint.systemComprehensive
        #expect(endpoint.timeoutInterval == 15)
    }

    @Test func withBodyEncodesEncodableToData() {
        struct Body: Encodable { let key: String }
        let endpoint = Endpoint.withBody(path: "/test", body: Body(key: "value"))
        #expect(endpoint.bodyData != nil)
        let decoded = try? JSONDecoder().decode([String: String].self, from: endpoint.bodyData!)
        #expect(decoded?["key"] == "value")
    }
}
