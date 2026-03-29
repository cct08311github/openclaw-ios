import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("APIClient Tests")
struct APIClientTests {
    @Test func successfulResponseDecoded() async throws {
        let mockClient = MockAPIClient()
        mockClient.requestDataHandler = { _ in
            Data(#"{"success":true,"username":"admin"}"#.utf8)
        }

        let response: MeResponse = try await mockClient.request(.me)
        #expect(response.success == true)
        #expect(response.username == "admin")
    }

    @Test func unauthorizedThrowsError() async {
        let mockClient = MockAPIClient()
        mockClient.requestDataHandler = { _ in
            throw AppError.unauthorized
        }

        do {
            let _: MeResponse = try await mockClient.request(.me)
            Issue.record("Expected unauthorized error")
        } catch let error as AppError {
            if case .unauthorized = error {
                // Expected
            } else {
                Issue.record("Expected .unauthorized, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func serverErrorThrows() async {
        let mockClient = MockAPIClient()
        mockClient.requestDataHandler = { _ in
            throw AppError.serverError("Internal Server Error")
        }

        do {
            let _: SimpleResponse = try await mockClient.request(.health)
            Issue.record("Expected server error")
        } catch let error as AppError {
            if case .serverError(let msg) = error {
                #expect(msg == "Internal Server Error")
            } else {
                Issue.record("Expected .serverError, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func requestCallCountIncremented() async throws {
        let mockClient = MockAPIClient()
        mockClient.requestDataHandler = { _ in
            Data(#"{"success":true}"#.utf8)
        }

        let _: SimpleResponse = try await mockClient.request(.health)
        let _: SimpleResponse = try await mockClient.request(.dashboard)
        #expect(mockClient.requestCallCount == 2)
    }

    @Test func lastEndpointTracked() async throws {
        let mockClient = MockAPIClient()
        mockClient.requestDataHandler = { _ in
            Data(#"{"success":true}"#.utf8)
        }

        let _: SimpleResponse = try await mockClient.request(.me)
        #expect(mockClient.lastEndpoint?.path == "/api/auth/me")
    }
}
