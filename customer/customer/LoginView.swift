import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Binding var isAuthenticated: Bool
    @Binding var customerName: String

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var biometricType: LABiometryType = .none
    @State private var showSignUp = false
    @State private var googleLoading = false
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        GeometryReader { geo in
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Logo / header
                VStack(spacing: 16) {
                    Image("TimplyLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 48)
                    Text("Sign in to your account")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 48)

                // Google sign-in
                VStack(spacing: 16) {
                    Button {
                        Task { await signInWithGoogle() }
                    } label: {
                        HStack(spacing: 10) {
                            if googleLoading {
                                ProgressView().tint(Color(.label))
                            } else {
                                GoogleLogoShape()
                                    .frame(width: 18, height: 18)
                                Text("Continue with Google")
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color(.label))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray3), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(googleLoading)

                    HStack(spacing: 12) {
                        Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                        Text("or").font(.caption).foregroundStyle(.secondary)
                        Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                    }
                }
                .padding(.horizontal, 24)

                // Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        TextField("", text: $email, prompt: Text("you@example.com").foregroundColor(.gray))
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .tint(Color(.label))
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        ZStack(alignment: .trailing) {
                            Group {
                                if showPassword {
                                    TextField("••••••••", text: $password)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                } else {
                                    SecureField("••••••••", text: $password)
                                }
                            }
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await signIn() } }
                            .tint(Color(.label))
                            .padding()
                            .padding(.trailing, 44)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(Color(.systemGray))
                                    .padding(.trailing, 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }

                    // Sign in button
                    Button {
                        Task { await signIn() }
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .background(Color.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(email.isEmpty || password.isEmpty || viewModel.isLoading)
                    .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                    .padding(.top, 8)

                    // Face ID / Touch ID
                    if biometricType != .none && KeychainService.getRefreshToken() != nil {
                        Button {
                            Task { await signInWithBiometrics() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: biometricType == .faceID ? "faceid" : "touchid")
                                Text(biometricType == .faceID ? "Sign in with Face ID" : "Sign in with Touch ID")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .background(Color(.systemGray6))
                        .foregroundStyle(Color(.label))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)

                // Create account
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Sign up") { showSignUp = true }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.indigo)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer(minLength: 0)
            }
            .frame(minHeight: geo.size.height)
        }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { detectBiometrics() }
        .sheet(isPresented: $showSignUp) {
            SignUpView(isAuthenticated: $isAuthenticated, customerName: $customerName)
        }
    }

    // MARK: - Google sign-in

    private func signInWithGoogle() async {
        googleLoading = true
        defer { googleLoading = false }
        guard let result = await GoogleSignIn.shared.signIn() else { return }
        KeychainService.saveTokens(accessToken: result.accessToken, refreshToken: result.refreshToken)
        customerName = result.name
        isAuthenticated = true
    }

    // MARK: - Sign in

    private func signIn() async {
        focusedField = nil
        let result = await viewModel.login(email: email, password: password)
        if result.success {
            customerName = result.name
            isAuthenticated = true
        }
    }

    // MARK: - Biometrics

    private func detectBiometrics() {
        let ctx = LAContext()
        var error: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = ctx.biometryType
        }
    }

    private func signInWithBiometrics() async {
        let ctx = LAContext()
        let reason = biometricType == .faceID ? "Sign in with Face ID" : "Sign in with Touch ID"
        guard (try? await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)) == true else { return }

        guard let refreshToken = KeychainService.getRefreshToken() else { return }
        guard let newToken = await refreshAccessToken(refreshToken: refreshToken) else {
            await MainActor.run { viewModel.errorMessage = "Session expired. Please sign in with your password." }
            return
        }

        // Fetch name after biometric refresh
        if let profile = try? await APIClient.get(path: "/customer/me", token: newToken) as CustomerProfileResponse {
            customerName = profile.customer.name ?? ""
        }
        isAuthenticated = true
    }

    private func refreshAccessToken(refreshToken: String) async -> String? {
        guard let url = URL(string: APIClient.baseURL + "/auth/refresh") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(RefreshResponse.self, from: data)
        else { return nil }

        KeychainService.saveTokens(accessToken: decoded.accessToken, refreshToken: decoded.refreshToken)
        return decoded.accessToken
    }
}

// MARK: - Google logo

struct GoogleLogoShape: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(colors: [
                        Color(red: 0.259, green: 0.522, blue: 0.957),
                        Color(red: 0.984, green: 0.737, blue: 0.020),
                        Color(red: 0.918, green: 0.263, blue: 0.208),
                        Color(red: 0.204, green: 0.659, blue: 0.325),
                        Color(red: 0.259, green: 0.522, blue: 0.957),
                    ], center: .center),
                    lineWidth: 2.5
                )
            Text("G")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(red: 0.259, green: 0.522, blue: 0.957))
        }
    }
}
