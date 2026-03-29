import Foundation
import Security

@Observable @MainActor
final class AuthManager {
    var isAuthenticated = false
    var username: String?
    var isLoading = false
    var error: String?

    private let apiClient: APIClient
    private nonisolated static let keychainService = "com.openclaw.monitor"
    private nonisolated static let keychainAccount = "session-token"

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        // Token provider reads from Keychain (thread-safe OS API)
        apiClient.setTokenProvider {
            AuthManager.loadTokenStatic()
        }
    }

    /// Try to restore session from Keychain on app launch
    func restoreSession() async {
        guard Self.loadTokenStatic() != nil else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response: MeResponse = try await apiClient.request(.me)
            if response.success {
                isAuthenticated = true
                username = response.username
            } else {
                clearToken()
            }
        } catch {
            clearToken()
        }
    }

    func login(username: String, password: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response: LoginResponse = try await apiClient.request(.login(username: username, password: password))
            if response.success, let token = response.token {
                saveToken(token)
                self.username = response.username
                isAuthenticated = true
                appLog(.info, .auth, "Login success: \(response.username ?? "?")")
            } else {
                self.error = response.error ?? "登入失敗"
            }
        } catch let appError as AppError {
            self.error = appError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func logout() async {
        try? await apiClient.requestVoid(.logout)
        clearToken()
        isAuthenticated = false
        username = nil
    }

    func handleUnauthorized() {
        appLog(.warning, .auth, "Session expired — redirecting to login")
        clearToken()
        isAuthenticated = false
        username = nil
    }

    // MARK: - Keychain

    private func saveToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    nonisolated static func loadTokenStatic() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func clearToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
