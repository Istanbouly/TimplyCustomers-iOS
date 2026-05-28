import Foundation
import Combine

class ProfileViewModel: ObservableObject {
    @Published var profile: CustomerProfile? = nil
    @Published var bookings: [CustomerBooking] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil

    var upcoming: [CustomerBooking] { bookings.filter { $0.isUpcoming } }
    var past: [CustomerBooking]     { bookings.filter { !$0.isUpcoming } }

    func load() async {
        guard let token = KeychainService.getAccessToken() else { return }
        // Only show the full-screen spinner on first load — pull-to-refresh refreshes in place
        let firstLoad = await MainActor.run { bookings.isEmpty && profile == nil }
        if firstLoad { await MainActor.run { isLoading = true } }
        await MainActor.run { errorMessage = nil }

        async let profileFetch: CustomerProfileResponse  = APIClient.get(path: "/customer/me", token: token)
        async let bookingsFetch: CustomerBookingsResponse = APIClient.get(path: "/customer/bookings", token: token)

        do {
            let (p, b) = try await (profileFetch, bookingsFetch)
            await MainActor.run {
                profile  = p.customer
                bookings = b.bookings
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
