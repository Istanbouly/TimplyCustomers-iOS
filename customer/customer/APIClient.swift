import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:              return "Invalid URL."
        case .unauthorized:            return "Invalid email or password."
        case .serverError(let msg):    return msg
        case .unknown:                 return "Something went wrong. Please try again."
        }
    }
}

struct APIClient {
    // Switch this to https://api.timply.ai/api for production
    static let baseURL = "https://api-staging.timply.ai/api"

    /// Called when a token refresh fails — root app should sign the user out.
    static var onUnauthorized: (() -> Void)?

    // MARK: - Login (bypasses refresh interceptor — surfaces real server error messages)

    static func login<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        if !(200...299).contains(http.statusCode) {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                ?? "Something went wrong. Please try again."
            throw APIError.serverError(msg)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - POST

    static func post<T: Decodable>(
        path: String,
        body: [String: Any],
        token: String? = nil
    ) async throws -> T {
        try await request(method: "POST", path: path, body: body, token: token)
    }

    // MARK: - GET

    static func get<T: Decodable>(
        path: String,
        token: String
    ) async throws -> T {
        try await request(method: "GET", path: path, body: nil, token: token)
    }

    // MARK: - PATCH

    static func patch<T: Decodable>(
        path: String,
        body: [String: Any],
        token: String
    ) async throws -> T {
        try await request(method: "PATCH", path: path, body: body, token: token)
    }

    // MARK: - DELETE

    static func delete<T: Decodable>(
        path: String,
        token: String
    ) async throws -> T {
        try await request(method: "DELETE", path: path, body: nil, token: token)
    }

    // MARK: - Shared request builder

    private static func request<T: Decodable>(
        method: String,
        path: String,
        body: Any?,
        token: String?
    ) async throws -> T {
        do {
            return try await execute(method: method, path: path, body: body, token: token)
        } catch APIError.unauthorized {
            guard let refreshToken = KeychainService.getRefreshToken() else {
                await signOut()
                throw APIError.unauthorized
            }
            guard let newToken = await refreshAccessToken(refreshToken: refreshToken) else {
                await signOut()
                throw APIError.unauthorized
            }
            return try await execute(method: method, path: path, body: body, token: newToken)
        }
    }

    // MARK: - Single HTTP execute (no retry logic)

    private static func execute<T: Decodable>(
        method: String,
        path: String,
        body: Any?,
        token: String?
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body  { req.httpBody = try? JSONSerialization.data(withJSONObject: body) }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        if http.statusCode == 401 { throw APIError.unauthorized }
        if !(200...299).contains(http.statusCode) {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Server error"
            throw APIError.serverError(msg)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Token Refresh

    private static func refreshAccessToken(refreshToken: String) async -> String? {
        guard let url = URL(string: baseURL + "/auth/refresh") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(RefreshResponse.self, from: data)
        else { return nil }

        KeychainService.saveTokens(
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken
        )
        return decoded.accessToken
    }

    // MARK: - Force sign-out

    private static func signOut() async {
        KeychainService.clearTokens()
        await MainActor.run { onUnauthorized?() }
    }
}
