import Foundation
import Security

struct KeychainService {
    private static let accessTokenKey = "com.timply.customer.accessToken"
    private static let refreshTokenKey = "com.timply.customer.refreshToken"

    static func saveTokens(accessToken: String, refreshToken: String) {
        save(key: accessTokenKey, value: accessToken)
        save(key: refreshTokenKey, value: refreshToken)
    }

    static func getAccessToken() -> String? {
        return read(key: accessTokenKey)
    }

    static func getRefreshToken() -> String? {
        return read(key: refreshTokenKey)
    }

    static func clearTokens() {
        delete(key: accessTokenKey)
        delete(key: refreshTokenKey)
    }

    /// Sign-out: clears access token but keeps refresh token so Face ID can re-authenticate.
    static func clearAccessToken() {
        delete(key: accessTokenKey)
    }

    // MARK: - Private helpers

    private static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String:   data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
