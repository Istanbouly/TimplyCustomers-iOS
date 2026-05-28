import SwiftUI

struct WelcomeView: View {
    let customerName: String
    @Binding var isAuthenticated: Bool

    private var firstName: String {
        customerName.components(separatedBy: " ").first ?? customerName
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("TimplyLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 48)

            VStack(spacing: 8) {
                Text("Welcome\(firstName.isEmpty ? "" : ", \(firstName)")!")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("You're signed in to Timply.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                KeychainService.clearAccessToken()
                isAuthenticated = false
            } label: {
                Text("Sign Out")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .background(Color(.systemGray6))
            .foregroundStyle(.red)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}
