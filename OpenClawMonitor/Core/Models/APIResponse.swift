import Foundation

/// Standard backend response wrapper: { success: bool, error?: string, ...payload }
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let error: String?

    // Allow flexible payload decoding via custom init
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
    }
}

struct LoginResponse: Codable {
    let success: Bool
    let username: String?
    let token: String?
    let error: String?
}

struct MeResponse: Codable {
    let success: Bool
    let username: String?
    let error: String?
}

struct SimpleResponse: Codable {
    let success: Bool
    let error: String?
}
