import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("APIResponse Model Tests")
struct APIResponseTests {
    @Test func loginResponseDecodeSuccess() throws {
        let json = """
        {"success":true,"username":"admin","token":"abc123"}
        """
        let response = try JSONDecoder().decode(LoginResponse.self, from: Data(json.utf8))
        #expect(response.success == true)
        #expect(response.username == "admin")
        #expect(response.token == "abc123")
        #expect(response.error == nil)
    }

    @Test func loginResponseDecodeError() throws {
        let json = """
        {"success":false,"error":"Invalid credentials"}
        """
        let response = try JSONDecoder().decode(LoginResponse.self, from: Data(json.utf8))
        #expect(response.success == false)
        #expect(response.error == "Invalid credentials")
        #expect(response.token == nil)
    }

    @Test func meResponseDecode() throws {
        let json = """
        {"success":true,"username":"admin"}
        """
        let response = try JSONDecoder().decode(MeResponse.self, from: Data(json.utf8))
        #expect(response.success == true)
        #expect(response.username == "admin")
    }

    @Test func simpleResponseDecode() throws {
        let json = """
        {"success":true}
        """
        let response = try JSONDecoder().decode(SimpleResponse.self, from: Data(json.utf8))
        #expect(response.success == true)
        #expect(response.error == nil)
    }
}
