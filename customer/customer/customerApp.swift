import SwiftUI

@main
struct customerApp: App {
    @State private var isAuthenticated = KeychainService.getAccessToken() != nil
    @State private var customerName: String = ""

    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthenticated {
                    TabView {
                        ProfileView(isAuthenticated: $isAuthenticated)
                            .tabItem {
                                Label("My Bookings", systemImage: "calendar")
                            }
                        ExploreView()
                            .tabItem {
                                Label("Explore", systemImage: "magnifyingglass")
                            }
                    }
                } else {
                    LoginView(isAuthenticated: $isAuthenticated, customerName: $customerName)
                }
            }
            .tint(.indigo)
            .preferredColorScheme(.light)
            .onAppear {
                APIClient.onUnauthorized = {
                    isAuthenticated = false
                }
            }
        }
    }
}
