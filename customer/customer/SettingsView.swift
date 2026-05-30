import SwiftUI

struct SettingsView: View {
    @Binding var isAuthenticated: Bool
    @State private var showDeleteAlert = false
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign out")
                        }
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete my account")
                        }
                    }
                } header: {
                    Text("Account")
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    KeychainService.clearAccessToken()
                    isAuthenticated = false
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Account deletion is not yet available. Please contact support if you need to delete your account.")
            }
        }
    }
}
