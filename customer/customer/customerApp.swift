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
                        SettingsView(isAuthenticated: $isAuthenticated)
                            .tabItem {
                                Label("Settings", systemImage: "gearshape")
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
                    DispatchQueue.main.async {
                        isAuthenticated = false
                    }
                }
            }
        }
    }
}
