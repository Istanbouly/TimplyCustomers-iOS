import SwiftUI
import Combine
import StripePaymentSheet

// MARK: - ViewModel

@MainActor
final class SetupCardViewModel: ObservableObject {
    @Published var paymentSheet: PaymentSheet?
    @Published var isLoading = false
    @Published var loadError: String?

    func load() async {
        guard let token = KeychainService.getAccessToken() else { return }
        isLoading = true
        defer { isLoading = false }

        guard let response = try? await APIClient.post(
            path: "/customer/setup-intent",
            body: [:],
            token: token
        ) as SetupIntentResponse else {
            loadError = "Failed to initialize card setup. Please try again."
            return
        }

        StripeAPI.defaultPublishableKey = response.publishableKey

        var config = PaymentSheet.Configuration()
        config.merchantDisplayName = "Timply"
        config.customer = .init(id: response.customerId, ephemeralKeySecret: response.ephemeralKey)

        paymentSheet = PaymentSheet(
            setupIntentClientSecret: response.setupIntentClientSecret,
            configuration: config
        )
    }
}

// MARK: - View

struct SetupCardView: View {
    let destination: SlotPickerDestination
    let policySnapshot: [String: Any]
    let onComplete: () -> Void
    let onBook: ([String: Any]) async -> Void

    @EnvironmentObject var holdTimer: SlotHoldTimer
    @StateObject private var vm = SetupCardViewModel()
    @State private var resultError: String?
    @State private var isBooking = false

    var body: some View {
        VStack(spacing: 0) {
            SlotCountdownBanner(holdTimer: holdTimer)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Card Required")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("A card on file is required to secure your appointment. You won't be charged now — it's only used if a cancellation or no-show fee applies.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Spacer(minLength: 100)
                }
            }

            actionBar
        }
        .navigationTitle("Save Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await vm.load() }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 8) {
                if vm.isLoading || isBooking {
                    ProgressView().padding(.top, 16)
                } else if let error = resultError ?? vm.loadError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                } else if let sheet = vm.paymentSheet {
                    PaymentSheet.PaymentButton(
                        paymentSheet: sheet,
                        onCompletion: { result in
                            Task { await handleResult(result) }
                        }
                    ) {
                        Text("Save Card & Book Appointment")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }

                Text("You won't be charged now. Your card secures the appointment against any applicable fees.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Handlers

    private func handleResult(_ result: PaymentSheetResult) async {
        switch result {
        case .completed:
            await bookWithSavedCard()
        case .canceled:
            break
        case .failed(let error):
            resultError = error.localizedDescription
        }
    }

    private func bookWithSavedCard() async {
        guard let token = KeychainService.getAccessToken() else { return }
        isBooking = true
        defer { isBooking = false }

        guard let response = try? await APIClient.get(
            path: "/customer/payment-methods",
            token: token
        ) as PaymentMethodsResponse,
              let card = response.paymentMethods.first else {
            resultError = "Could not retrieve saved card. Please try again."
            return
        }

        var params: [String: Any] = [:]
        if !policySnapshot.isEmpty { params["policy_snapshot"] = policySnapshot }
        if destination.cancellationPolicyEnabled { params["cancellation_pm_id"] = card.id }
        if destination.noShowPolicyEnabled       { params["no_show_pm_id"]       = card.id }

        await onBook(params)
    }
}
