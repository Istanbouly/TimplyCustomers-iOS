import Foundation
import Combine

class SignUpViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var awaitingOTP = false

    // Preserved across OTP step
    private(set) var pendingEmail = ""
    private(set) var pendingPassword = ""
    private(set) var pendingPhone = ""

    // MARK: - Step 1: Sign up

    func signUp(name: String, email: String, password: String, phone: String) async -> Bool {
        await setLoading(true)
        defer { Task { await setLoading(false) } }

        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)

        do {
            let response: SignUpResponse = try await APIClient.login(
                path: "/customer/signup",
                body: [
                    "email": normalizedEmail,
                    "password": password,
                    "name": name.trimmingCharacters(in: .whitespaces),
                ]
            )
            if response.awaitingVerification {
                pendingEmail    = normalizedEmail
                pendingPassword = password
                pendingPhone    = phone
                await MainActor.run { awaitingOTP = true }
            }
            return true
        } catch APIError.serverError(let msg) {
            await MainActor.run { errorMessage = msg }
            return false
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    // MARK: - Step 2: Verify OTP → login → setup

    func verifyOTP(code: String) async -> (success: Bool, name: String) {
        await setLoading(true)
        defer { Task { await setLoading(false) } }

        do {
            // Confirm email
            let _: VerifyOTPResponse = try await APIClient.login(
                path: "/customer/verify-signup-otp",
                body: ["email": pendingEmail, "code": code]
            )

            // Sign in to get tokens
            let loginResponse: LoginResponse = try await APIClient.login(
                path: "/auth/login",
                body: ["email": pendingEmail, "password": pendingPassword]
            )
            let accessToken = loginResponse.session.accessToken

            // Create customer record
            var setupBody: [String: Any] = [
                "terms_and_privacy_accepted_at": ISO8601DateFormatter().string(from: Date()),
            ]
            if !pendingPhone.isEmpty { setupBody["phone"] = pendingPhone }

            let setupResponse: CustomerSetupResponse = try await APIClient.post(
                path: "/customer/setup",
                body: setupBody,
                token: accessToken
            )

            KeychainService.saveTokens(
                accessToken: accessToken,
                refreshToken: loginResponse.session.refreshToken
            )

            return (true, setupResponse.customer.name ?? "")

        } catch APIError.serverError(let msg) {
            await MainActor.run { errorMessage = msg }
            return (false, "")
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return (false, "")
        }
    }

    // MARK: - Resend OTP

    func resendOTP() async {
        guard !pendingEmail.isEmpty else { return }
        _ = try? await APIClient.login(
            path: "/customer/resend-signup-otp",
            body: ["email": pendingEmail]
        ) as [String: Bool]
    }

    // MARK: - Helpers

    @MainActor
    private func setLoading(_ value: Bool) {
        isLoading = value
        if value { errorMessage = nil }
    }
}
