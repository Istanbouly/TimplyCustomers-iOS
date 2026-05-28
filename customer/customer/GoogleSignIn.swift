import AuthenticationServices
import UIKit

class GoogleSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleSignIn()

    /// Opens Google OAuth in a system browser and returns (accessToken, refreshToken, name) on success.
    func signIn() async -> (accessToken: String, refreshToken: String, name: String)? {
        guard let url = URL(string: APIClient.baseURL + "/auth/google?source=mobile") else { return nil }

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: "timply"
                ) { callbackURL, error in
                    guard error == nil,
                          let callbackURL,
                          let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                          let sessionCode = components.queryItems?.first(where: { $0.name == "session_code" })?.value
                    else {
                        continuation.resume(returning: nil)
                        return
                    }

                    Task {
                        // Exchange session code for tokens
                        guard let sessionURL = URL(string: APIClient.baseURL + "/auth/google/session?code=\(sessionCode)"),
                              let (data, response) = try? await URLSession.shared.data(from: sessionURL),
                              let http = response as? HTTPURLResponse,
                              http.statusCode == 200,
                              let tokenSession = try? JSONDecoder().decode(GoogleSessionResponse.self, from: data)
                        else {
                            continuation.resume(returning: nil)
                            return
                        }

                        // Fetch customer name (best-effort)
                        let name = (try? await APIClient.get(
                            path: "/customer/me",
                            token: tokenSession.accessToken
                        ) as CustomerProfileResponse)?.customer.name ?? ""

                        continuation.resume(returning: (tokenSession.accessToken, tokenSession.refreshToken, name))
                    }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
