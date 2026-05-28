import Foundation
import Combine

class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    func login(email: String, password: String) async -> (success: Bool, name: String) {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        defer { Task { await MainActor.run { isLoading = false } } }

        do {
            // Step 1: Authenticate with backend
            let response: LoginResponse = try await APIClient.login(
                path: "/auth/login",
                body: ["email": email, "password": password]
            )

            // Step 2: Verify role from the login response (app_metadata.timply_role)
            let role = response.user?.appMetadata?.timplyRole ?? ""
            guard role == "timply_customer" else {
                await MainActor.run { errorMessage = "This app is for customers only." }
                return (false, "")
            }

            // Step 3: Store tokens
            KeychainService.saveTokens(
                accessToken: response.session.accessToken,
                refreshToken: response.session.refreshToken
            )

            // Step 4: Fetch name (best-effort, non-blocking)
            let name = (try? await APIClient.get(path: "/customer/me", token: response.session.accessToken) as CustomerProfileResponse)?.customer.name ?? ""

            return (true, name)

        } catch APIError.serverError(let msg) {
            await MainActor.run { errorMessage = msg }
            return (false, "")
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return (false, "")
        }
    }
}
