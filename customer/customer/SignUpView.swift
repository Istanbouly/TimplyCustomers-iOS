import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @Binding var isAuthenticated: Bool
    @Binding var customerName: String
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var phone = ""
    @State private var termsAccepted = false
    @State private var showPassword = false
    @State private var showConfirm = false

    // OTP state
    @State private var otpCode = ""
    @FocusState private var otpFocused: Bool

    var passwordsMatch: Bool { password == confirmPassword }
    var formValid: Bool {
        !name.isEmpty && !email.isEmpty && password.count >= 6 &&
        passwordsMatch && termsAccepted
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if viewModel.awaitingOTP {
                        otpSection
                    } else {
                        formSection
                    }
                }
                .padding(24)
            }
            .navigationTitle(viewModel.awaitingOTP ? "Verify Email" : "Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sign-up form

    private var formSection: some View {
        VStack(spacing: 16) {

            field(label: "Full Name") {
                TextField("", text: $name, prompt: Text("Jane Smith").foregroundColor(.gray))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .tint(Color(.label))
                    .fieldStyle()
            }

            field(label: "Email") {
                TextField("", text: $email, prompt: Text("you@example.com").foregroundColor(.gray))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .tint(Color(.label))
                    .fieldStyle()
            }

            field(label: "Password") {
                passwordField(text: $password, show: $showPassword, placeholder: "Min. 6 characters")
            }

            field(label: "Confirm Password") {
                passwordField(text: $confirmPassword, show: $showConfirm, placeholder: "Re-enter password")
                if !confirmPassword.isEmpty && !passwordsMatch {
                    Text("Passwords do not match.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            field(label: "Phone Number (optional)") {
                TextField("", text: $phone, prompt: Text("+1 555 000 0000").foregroundColor(.gray))
                    .keyboardType(.phonePad)
                    .tint(Color(.label))
                    .fieldStyle()
            }

            // Terms
            HStack(alignment: .top, spacing: 10) {
                Button {
                    termsAccepted.toggle()
                } label: {
                    Image(systemName: termsAccepted ? "checkmark.square.fill" : "square")
                        .foregroundStyle(termsAccepted ? Color.indigo : Color(.systemGray3))
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text("I agree to the ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    +
                    Text("Terms of Service")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                    +
                    Text(" and ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    +
                    Text("Privacy Policy")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await submit() }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create Account").fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .background(Color.indigo)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(!formValid || viewModel.isLoading)
            .opacity(formValid ? 1 : 0.6)
            .padding(.top, 8)
        }
    }

    // MARK: - OTP verification

    private var otpSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 48))
                    .foregroundStyle(.indigo)
                Text("Check your email")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("We sent a 6-digit code to\n\(viewModel.pendingEmail)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)

            TextField("", text: $otpCode, prompt: Text("000000").foregroundColor(.gray))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .tracking(8)
                .focused($otpFocused)
                .onChange(of: otpCode) { _, v in
                    otpCode = String(v.filter(\.isNumber).prefix(6))
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await verifyOTP() }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Verify").fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .background(Color.indigo)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(otpCode.count < 6 || viewModel.isLoading)
            .opacity(otpCode.count < 6 ? 0.6 : 1)

            Button {
                Task { await viewModel.resendOTP() }
            } label: {
                Text("Resend code")
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
            }
        }
        .onAppear { otpFocused = true }
    }

    // MARK: - Actions

    private func submit() async {
        let ok = await viewModel.signUp(
            name: name, email: email, password: password, phone: phone
        )
        _ = ok
    }

    private func verifyOTP() async {
        let result = await viewModel.verifyOTP(code: otpCode)
        if result.success {
            customerName = result.name
            isAuthenticated = true
            dismiss()
        }
    }

    // MARK: - Helpers

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func passwordField(text: Binding<String>, show: Binding<Bool>, placeholder: String) -> some View {
        ZStack(alignment: .trailing) {
            Group {
                if show.wrappedValue {
                    TextField(placeholder, text: text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .tint(Color(.label))
            .padding()
            .padding(.trailing, 44)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button { show.wrappedValue.toggle() } label: {
                Image(systemName: show.wrappedValue ? "eye.slash" : "eye")
                    .foregroundStyle(Color(.systemGray))
                    .padding(.trailing, 14)
            }
            .buttonStyle(.plain)
        }
    }
}

private extension View {
    func fieldStyle() -> some View {
        self
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
