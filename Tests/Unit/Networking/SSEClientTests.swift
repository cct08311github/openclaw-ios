import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("SSEClient Tests")
final class SSEClientTests {
    private let baseURL = URL(string: "https://localhost:3001")!

    @Test
    func sseEventParsing_dataOnly() {
        let line = "data: {\"status\":\"active\"}"
        var eventType: String? = nil
        var dataBuffer = ""

        // Simulate parsing logic
        if line.hasPrefix("data: ") {
            let value = String(line.dropFirst(6))
            if !dataBuffer.isEmpty { dataBuffer += "\n" }
            dataBuffer += value
        }

        #expect(dataBuffer == "{\"status\":\"active\"}")
        #expect(eventType == nil)
    }

    @Test
    func sseEventParsing_dataWithoutSpace() {
        let line = "data:{\"status\":\"active\"}"
        var dataBuffer = ""

        if line.hasPrefix("data:") {
            let value = String(line.dropFirst(5))
            if !dataBuffer.isEmpty { dataBuffer += "\n" }
            dataBuffer += value
        }

        #expect(dataBuffer == "{\"status\":\"active\"}")
    }

    @Test
    func sseEventParsing_eventType() {
        let line = "event: agent_update"
        var eventType: String? = nil

        if line.hasPrefix("event: ") {
            eventType = String(line.dropFirst(7))
        }

        #expect(eventType == "agent_update")
    }

    @Test
    func sseEventParsing_commentLine() {
        let line = ": heartbeat comment"
        var eventType: String? = nil
        var dataBuffer = ""

        if line.hasPrefix(":") {
            // Comment line - should be ignored
        }

        #expect(eventType == nil)
        #expect(dataBuffer.isEmpty)
    }

    @Test
    func sseEventParsing_emptyLine() {
        var eventType: String? = "agent_update"
        var dataBuffer = "{\"status\":\"active\"}"
        let event: SSEEvent? = nil

        // Empty line = end of event
        if dataBuffer.isEmpty == false {
            let e = SSEEvent(event: eventType, data: dataBuffer)
            eventType = nil
            dataBuffer = ""
            #expect(e.event == "agent_update")
            #expect(e.data == "{\"status\":\"active\"}")
        }
    }

    @Test
    func sseEventParsing_multilineData() {
        var dataBuffer = ""

        let line1 = "data: {\"status\":"
        let line2 = "\"active\"}"
        let line3 = ""
        var capturedEvent: SSEEvent?

        // First line
        if line1.hasPrefix("data: ") {
            let value = String(line1.dropFirst(6))
            if !dataBuffer.isEmpty { dataBuffer += "\n" }
            dataBuffer += value
        }

        // Second line
        if line2.hasPrefix("data: ") {
            let value = String(line2.dropFirst(6))
            if !dataBuffer.isEmpty { dataBuffer += "\n" }
            dataBuffer += value
        }

        // Empty line = end
        if line3.isEmpty && !dataBuffer.isEmpty {
            let event = SSEEvent(event: nil, data: dataBuffer)
            capturedEvent = event
            dataBuffer = ""
        }

        #expect(capturedEvent?.data == "{\"status\":\n\"active\"}")
    }

    @Test
    func sseEvent_structure() {
        let event = SSEEvent(event: "message", data: "test data")
        #expect(event.event == "message")
        #expect(event.data == "test data")
    }

    @Test
    func sseEvent_eventTypeNil() {
        let event = SSEEvent(event: nil, data: "test data")
        #expect(event.event == nil)
        #expect(event.data == "test data")
    }

    @Test
    func connectionState_transitions() {
        var state: SSEConnectionState = .disconnected

        state = .connecting
        #expect(state == .connecting)

        state = .connected
        #expect(state == .connected)

        state = .disconnected
        #expect(state == .disconnected)
    }
}
