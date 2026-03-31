import Foundation
import Security
import LocalAuthentication

// MARK: - Biometric Settings

/// Biometric authentication state persistence
/// Stores whether user has enabled biometric authentication
struct BiometricSettings: Codable {
    var isEnabled: Bool
    var lastEnabledDate: Date?

    static let key = "biometric-auth-settings"

    static func load() -> BiometricSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(BiometricSettings.self, from: data) else {
            return BiometricSettings(isEnabled: false, lastEnabledDate: nil)
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

@Observable @MainActor
final class AuthManager {
    var isAuthenticated = false
    var username: String?
    var isLoading = false
    var error: String?
    var isLockedOut = false
    var lockoutSecondsRemaining = 0

    // Biometric authentication
    private var biometricSettings = BiometricSettings.load()

    // Login lockout state (persisted in UserDefaults)
    private static let lockoutKey = "login-lockout"
    private static let failedAttemptsKey = "login-failed-attempts"
    private let maxAttempts = 5
    private let lockoutDurationSeconds = 15 * 60  // 15 minutes

    private struct LockoutState: Codable {
        var until: Date
        var attempts: Int
    }
    var isBiometricEnabled: Bool {
        get { biometricSettings.isEnabled }
        set {
            biometricSettings.isEnabled = newValue
            if newValue {
                biometricSettings.lastEnabledDate = Date()
            }
            biometricSettings.save()
        }
    }

    private let apiClient: APIClient
    private nonisolated static let keychainService = "com.openclaw.monitor"
    private nonisolated static let keychainAccount = "session-token"

    // MARK: - Login Lockout

    /// Check if currently in lockout period and update UI state
    private func refreshLockoutState() {
        guard let data = UserDefaults.standard.data(forKey: Self.lockoutKey),
              let state = try? JSONDecoder().decode(LockoutState.self, from: data) else {
            isLockedOut = false
            lockoutSecondsRemaining = 0
            return
        }
        if Date() < state.until {
            isLockedOut = true
            lockoutSecondsRemaining = Int(state.until.timeIntervalSinceNow)
        } else {
            // Lockout expired — reset
            isLockedOut = false
            lockoutSecondsRemaining = 0
            UserDefaults.standard.removeObject(forKey: Self.lockoutKey)
        }
    }

    private func recordFailedLogin() {
        let state: LockoutState
        if let existing = try? JSONDecoder().decode(LockoutState.self, from: UserDefaults.standard.data(forKey: Self.lockoutKey) ?? Data()),
           Date() < existing.until {
            // Already locked out — don't increment further
            state = existing
        } else {
            let attempts = (try? JSONDecoder().decode(LockoutState.self, from: UserDefaults.standard.data(forKey: Self.lockoutKey) ?? Data()))?.attempts ?? 0
            let newAttempts = attempts + 1
            if newAttempts >= maxAttempts {
                state = LockoutState(until: Date().addingTimeInterval(TimeInterval(lockoutDurationSeconds)), attempts: newAttempts)
            } else {
                state = LockoutState(until: Date(), attempts: newAttempts)
            }
        }
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.lockoutKey)
        }
        refreshLockoutState()
    }

    private func clearLockout() {
        UserDefaults.standard.removeObject(forKey: Self.lockoutKey)
        isLockedOut = false
        lockoutSecondsRemaining = 0
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        // Token provider reads from Keychain (thread-safe OS API)
        apiClient.setTokenProvider {
            AuthManager.loadTokenStatic()
        }
    }

    /// Check if biometric authentication is available
    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Biometric type description (Face ID / Touch ID / None)
    var biometricTypeName: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "生物辨識不可用"
        }
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "生物辨識"
        }
    }

    /// Authenticate using biometrics (for app unlock or sensitive actions)
    func authenticateWithBiometrics() async -> Bool {
        guard isBiometricEnabled else { return false }

        let context = LAContext()
        context.localizedCancelTitle = "取消"
        context.localizedFallbackTitle = "使用密碼"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "驗證身份以存取 OpenClaw Monitor"
            )
            return success
        } catch {
            appLog(.warning, .auth, "Biometric auth failed: \(error.localizedDescription)")
            return false
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
        refreshLockoutState()
        if isLockedOut {
            error = "登入失敗次數過多，請 \(lockoutSecondsRemaining / 60) 分鐘後再試"
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response: LoginResponse = try await apiClient.request(.login(username: username, password: password))
            if response.success, let token = response.token {
                saveToken(token)
                self.username = response.username
                isAuthenticated = true
                clearLockout()
                #if DEBUG
                appLog(.info, .auth, "Login success: \(response.username ?? "?")")
                #else
                appLog(.info, .auth, "Login success")
                #endif
            } else {
                recordFailedLogin()
                self.error = response.error ?? "登入失敗"
            }
        } catch let appError as AppError {
            recordFailedLogin()
            self.error = appError.localizedDescription
        } catch {
            recordFailedLogin()
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