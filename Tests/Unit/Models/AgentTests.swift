import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("Agent Model Tests")
struct AgentTests {
    // MARK: - AgentStatus rawValue

    @Test func agentStatusRawValues() {
        #expect(AgentStatus.activeExecuting.rawValue == "active_executing")
        #expect(AgentStatus.activeRecent.rawValue == "active_recent")
        #expect(AgentStatus.activeHistorical.rawValue == "active_historical")
        #expect(AgentStatus.dormant.rawValue == "dormant")
        #expect(AgentStatus.inactive.rawValue == "inactive")
        #expect(AgentStatus.error.rawValue == "error")
    }

    // MARK: - AgentStatus displayColor

    @Test func agentStatusDisplayColors() {
        #expect(AgentStatus.activeExecuting.displayColor == "green")
        #expect(AgentStatus.activeRecent.displayColor == "blue")
        #expect(AgentStatus.activeHistorical.displayColor == "cyan")
        #expect(AgentStatus.dormant.displayColor == "gray")
        #expect(AgentStatus.inactive.displayColor == "secondary")
        #expect(AgentStatus.error.displayColor == "red")
    }

    // MARK: - Agent Codable

    @Test func agentDecodeFromJSON() throws {
        let json = """
        {"id":"main","name":"Main","status":"active_executing","emoji":"🤖","label":"主控"}
        """
        let agent = try JSONDecoder().decode(Agent.self, from: Data(json.utf8))
        #expect(agent.id == "main")
        #expect(agent.name == "Main")
        #expect(agent.status == .activeExecuting)
        #expect(agent.emoji == "🤖")
        #expect(agent.label == "主控")
    }

    @Test func agentDecodeWithNilOptionals() throws {
        let json = """
        {"id":"test","name":"Test","status":"dormant"}
        """
        let agent = try JSONDecoder().decode(Agent.self, from: Data(json.utf8))
        #expect(agent.id == "test")
        #expect(agent.emoji == nil)
        #expect(agent.label == nil)
        #expect(agent.lastActivity == nil)
        #expect(agent.model == nil)
        #expect(agent.workspace == nil)
    }

    // MARK: - DashboardPayload

    @Test func dashboardPayloadDecode() throws {
        let json = """
        {"agents":[{"id":"a","name":"A","status":"dormant"}],"summary":{"totalAgents":5,"activeAgents":3}}
        """
        let payload = try JSONDecoder().decode(DashboardPayload.self, from: Data(json.utf8))
        #expect(payload.agents?.count == 1)
        #expect(payload.summary?.totalAgents == 5)
        #expect(payload.summary?.activeAgents == 3)
    }

    // MARK: - DashboardSummary

    @Test func dashboardSummaryDecode() throws {
        let json = """
        {"totalAgents":10,"activeAgents":4,"subAgentCount":2,"monthlyCostTWD":1500.5}
        """
        let summary = try JSONDecoder().decode(DashboardSummary.self, from: Data(json.utf8))
        #expect(summary.totalAgents == 10)
        #expect(summary.activeAgents == 4)
        #expect(summary.subAgentCount == 2)
        #expect(summary.monthlyCostTWD == 1500.5)
    }
}
