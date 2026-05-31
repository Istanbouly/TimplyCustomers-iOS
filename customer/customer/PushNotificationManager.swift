import UIKit
import UserNotifications

@MainActor
class PushNotificationManager {
    static let shared = PushNotificationManager()
    private var currentToken: String?

    private init() {}

    // Call after a successful login to request permission and register for push
    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error { print("[Push] Permission error: \(error.localizedDescription)") }
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // Called by AppDelegate when APNs returns a device token
    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        currentToken = token
        Task { await registerWithBackend(token: token) }
    }

    // Call before clearing the Keychain on logout
    func unregisterCurrentToken() async {
        guard let token = currentToken else { return }
        await unregisterFromBackend(token: token)
        currentToken = nil
    }

    // MARK: - Private

    private func registerWithBackend(token: String) async {
        guard let accessToken = KeychainService.getAccessToken() else { return }

        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""

        do {
            let _: OkResponse = try await APIClient.post(
                path: "/customer/device-token",
                body: [
                    "token": token,
                    "platform": "ios",
                    "environment": environment,
                    "device_id": deviceId,
                ],
                token: accessToken
            )
            print("[Push] Token registered")
        } catch {
            print("[Push] Failed to register token: \(error.localizedDescription)")
        }
    }

    private func unregisterFromBackend(token: String) async {
        guard let accessToken = KeychainService.getAccessToken() else { return }
        do {
            let _: OkResponse = try await APIClient.delete(
                path: "/customer/device-token/\(token)",
                token: accessToken
            )
        } catch {
            // Best-effort — don't block logout
            print("[Push] Failed to unregister token: \(error.localizedDescription)")
        }
    }
}

private struct OkResponse: Decodable { let ok: Bool }
