import SwiftUI
import Combine

/// Shared navigation state — used to deep-link from push notification taps into booking detail.
@MainActor
class AppNavigationState: ObservableObject {
    static let shared = AppNavigationState()
    private init() {}

    /// Set when a push notification is tapped. Consumed by ProfileView to open the booking detail sheet.
    @Published var pendingBookingId: String?

    /// Controls which tab is active (0 = My Bookings, 1 = Explore, 2 = Settings).
    @Published var selectedTab: Int = 0
}
