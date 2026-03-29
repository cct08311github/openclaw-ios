import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("AppError Tests")
struct AppErrorTests {
    @Test func allCasesHaveNonNilDescription() {
        let cases: [AppError] = [
            .network(URLError(.timedOut)),
            .unauthorized,
            .serverError("test"),
            .decoding(NSError(domain: "test", code: -1)),
            .sseDisconnected,
            .unknown(NSError(domain: "test", code: -1))
        ]
        for error in cases {
            #expect(error.localizedDescription.isEmpty == false)
        }
    }

    @Test func networkErrorDescriptionContainsURLErrorInfo() {
        let urlError = URLError(.timedOut)
        let error = AppError.network(urlError)
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("網路錯誤"))
    }

    @Test func unauthorizedDescriptionIsChinese() {
        let error = AppError.unauthorized
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("驗證過期"))
    }

    @Test func serverErrorContainsMessage() {
        let error = AppError.serverError("DB connection failed")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("DB connection failed"))
    }

    @Test func sseDisconnectedDescription() {
        let error = AppError.sseDisconnected
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("即時連線中斷"))
    }
}
