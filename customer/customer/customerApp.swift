import SwiftUI

@main
struct customerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isAuthenticated = KeychainService.getAccessToken() != nil
    @State private var customerName: String = ""
    @ObservedObject private var navigationState = AppNavigationState.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthenticated {
                    TabView(selection: $navigationState.selectedTab) {
                        ProfileView(isAuthenticated: $isAuthenticated)
                            .tabItem {
                                Label("My Bookings", systemImage: "calendar")
                            }
                            .tag(0)
                        ExploreView()
                            .tabItem {
                                Label("Explore", systemImage: "magnifyingglass")
                            }
                            .tag(1)
                        SettingsView(isAuthenticated: $isAuthenticated)
                            .tabItem {
                                Label("Settings", systemImage: "gearshape")
                            }
                            .tag(2)
                    }
                } else {
                    LoginView(isAuthenticated: $isAuthenticated, customerName: $customerName)
                }
            }
            .environmentObject(navigationState)
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
