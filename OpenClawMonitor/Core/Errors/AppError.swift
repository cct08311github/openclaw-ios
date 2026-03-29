import Foundation

enum AppError: LocalizedError {
    case network(URLError)
    case unauthorized
    case serverError(String)
    case decoding(Error)
    case sseDisconnected
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .network(let error): "網路錯誤：\(error.localizedDescription)"
        case .unauthorized: "驗證過期，請重新登入"
        case .serverError(let msg): "伺服器錯誤：\(msg)"
        case .decoding(let error): "資料解析錯誤：\(error.localizedDescription)"
        case .sseDisconnected: "即時連線中斷"
        case .unknown(let error): "未知錯誤：\(error.localizedDescription)"
        }
    }
}
