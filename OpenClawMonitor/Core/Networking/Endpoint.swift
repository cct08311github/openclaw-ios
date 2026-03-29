import Foundation

enum HTTPMethod: String, Sendable {
    case GET, POST, PATCH, DELETE
}

struct Endpoint: Sendable {
    let path: String
    let method: HTTPMethod
    let bodyData: Data?
    let queryItems: [URLQueryItem]?
    let timeoutInterval: TimeInterval

    init(
        path: String,
        method: HTTPMethod = .GET,
        bodyData: Data? = nil,
        queryItems: [URLQueryItem]? = nil,
        timeout: TimeInterval = 10
    ) {
        self.path = path
        self.method = method
        self.bodyData = bodyData
        self.queryItems = queryItems
        self.timeoutInterval = timeout
    }

    /// Convenience: encode an Encodable body to JSON Data at call site
    static func withBody<T: Encodable>(
        path: String,
        method: HTTPMethod = .POST,
        body: T,
        queryItems: [URLQueryItem]? = nil,
        timeout: TimeInterval = 10
    ) -> Endpoint {
        let data = try? JSONEncoder().encode(body)
        return Endpoint(path: path, method: method, bodyData: data, queryItems: queryItems, timeout: timeout)
    }
}

// MARK: - Predefined Endpoints

extension Endpoint {
    // Auth
    static func login(username: String, password: String) -> Endpoint {
        struct Body: Encodable { let username, password: String }
        return .withBody(path: "/api/auth/login", body: Body(username: username, password: password))
    }
    static let me = Endpoint(path: "/api/auth/me")
    static let logout = Endpoint(path: "/api/auth/logout", method: .POST)

    // Dashboard
    static let dashboard = Endpoint(path: "/api/read/dashboard")
    static let dashboardStream = Endpoint(path: "/api/read/stream")
    static let agents = Endpoint(path: "/api/agents")

    // Sessions
    static func sessions(agentId: String) -> Endpoint {
        Endpoint(path: "/api/agents/\(agentId)/sessions")
    }
    static func sessionContent(agentId: String, sessionId: String) -> Endpoint {
        Endpoint(path: "/api/agents/\(agentId)/sessions/\(sessionId)")
    }

    // Logs
    static let logsStream = Endpoint(path: "/api/logs/stream")

    // Cron
    static let cronJobs = Endpoint(path: "/api/cron/jobs")
    static func cronToggle(id: String) -> Endpoint {
        Endpoint(path: "/api/cron/jobs/\(id)/toggle", method: .POST)
    }
    static func cronRun(id: String) -> Endpoint {
        Endpoint(path: "/api/cron/jobs/\(id)/run", method: .POST, timeout: 30)
    }
    static func cronDelete(id: String) -> Endpoint {
        Endpoint(path: "/api/cron/jobs/\(id)", method: .DELETE)
    }

    // TaskHub
    static let taskHubStats = Endpoint(path: "/api/taskhub/stats")
    static func tasks(domain: String? = nil) -> Endpoint {
        var items: [URLQueryItem]? = nil
        if let domain { items = [URLQueryItem(name: "domain", value: domain)] }
        return Endpoint(path: "/api/taskhub/tasks", queryItems: items)
    }
    static func createTask<T: Encodable>(body: T) -> Endpoint {
        .withBody(path: "/api/taskhub/tasks", body: body)
    }
    static func updateTask<T: Encodable>(domain: String, id: String, body: T) -> Endpoint {
        .withBody(path: "/api/taskhub/tasks/\(domain)/\(id)", method: .PATCH, body: body)
    }
    static func deleteTask(domain: String, id: String) -> Endpoint {
        Endpoint(path: "/api/taskhub/tasks/\(domain)/\(id)", method: .DELETE)
    }

    // Alerts
    static let alertsRecent = Endpoint(path: "/api/alerts/recent")
    static let alertsConfig = Endpoint(path: "/api/alerts/config")

    // System
    static let systemComprehensive = Endpoint(path: "/api/system/comprehensive", timeout: 15)
    static let health = Endpoint(path: "/api/health")
    static let dependencies = Endpoint(path: "/api/read/dependencies")

    // Control
    static func command<T: Encodable>(body: T) -> Endpoint {
        .withBody(path: "/api/control/command", body: body, timeout: 30)
    }
}
