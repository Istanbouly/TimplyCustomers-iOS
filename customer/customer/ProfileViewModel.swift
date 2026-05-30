import Foundation
import Combine

class ProfileViewModel: ObservableObject {
    @Published var profile: CustomerProfile? = nil
    @Published var upcoming: [CustomerBooking] = []
    @Published var past: [CustomerBooking]     = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil

    @Published var upcomingHasMore = false
    @Published var pastHasMore     = false
    @Published var upcomingLoading = false
    @Published var pastLoading     = false

    private var upcomingPage = 1
    private var pastPage     = 1
    private let pageSize     = 10

    private var localDate: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.string(from: Date())
    }

    // Initial load — profile + first page of each tab in parallel
    func load() async {
        guard let token = KeychainService.getAccessToken() else { return }
        let firstLoad = await MainActor.run { upcoming.isEmpty && past.isEmpty && profile == nil }
        if firstLoad { await MainActor.run { isLoading = true } }
        await MainActor.run {
            errorMessage = nil
            upcomingPage = 1
            pastPage     = 1
        }

        let d = localDate
        async let profileFetch: CustomerProfileResponse      = APIClient.get(path: "/customer/me", token: token)
        async let upcomingFetch: CustomerBookingsPageResponse = APIClient.get(path: "/customer/bookings?filter=upcoming&page=1&page_size=\(pageSize)&date=\(d)", token: token)
        async let pastFetch: CustomerBookingsPageResponse     = APIClient.get(path: "/customer/bookings?filter=past&page=1&page_size=\(pageSize)&date=\(d)", token: token)

        do {
            let (p, u, pa) = try await (profileFetch, upcomingFetch, pastFetch)
            await MainActor.run {
                profile        = p.customer
                upcoming       = u.bookings
                upcomingHasMore = u.hasMore
                past           = pa.bookings
                pastHasMore    = pa.hasMore
                isLoading      = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading    = false
            }
        }
    }

    func loadMoreUpcoming() async {
        guard upcomingHasMore, !upcomingLoading else { return }
        guard let token = KeychainService.getAccessToken() else { return }
        await MainActor.run { upcomingLoading = true }
        let nextPage = upcomingPage + 1
        let d = localDate
        do {
            let result: CustomerBookingsPageResponse = try await APIClient.get(
                path: "/customer/bookings?filter=upcoming&page=\(nextPage)&page_size=\(pageSize)&date=\(d)",
                token: token
            )
            await MainActor.run {
                upcoming.append(contentsOf: result.bookings)
                upcomingHasMore = result.hasMore
                upcomingPage    = nextPage
                upcomingLoading = false
            }
        } catch {
            await MainActor.run { upcomingLoading = false }
        }
    }

    func loadMorePast() async {
        guard pastHasMore, !pastLoading else { return }
        guard let token = KeychainService.getAccessToken() else { return }
        await MainActor.run { pastLoading = true }
        let nextPage = pastPage + 1
        let d = localDate
        do {
            let result: CustomerBookingsPageResponse = try await APIClient.get(
                path: "/customer/bookings?filter=past&page=\(nextPage)&page_size=\(pageSize)&date=\(d)",
                token: token
            )
            await MainActor.run {
                past.append(contentsOf: result.bookings)
                pastHasMore = result.hasMore
                pastPage    = nextPage
                pastLoading = false
            }
        } catch {
            await MainActor.run { pastLoading = false }
        }
    }
}
