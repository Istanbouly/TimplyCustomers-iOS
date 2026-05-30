// MARK: - PaymentView
//
// Requires the StripePaymentSheet Swift package:
//   Xcode → File → Add Package Dependencies
//   URL: https://github.com/stripe/stripe-ios
//   Select product: StripePaymentSheet

import SwiftUI
import Combine
import StripePaymentSheet

struct PaymentView: View {
    let memberSlug: String
    let memberName: String
    let businessName: String
    let eventTypeIds: [String]
    let eventTypeNames: [String]
    let selectedDate: String
    let selectedTime: String
    let totalPriceCents: Int
    let policySnapshot: [String: Any]
    let onComplete: () -> Void

    @EnvironmentObject var holdTimer: SlotHoldTimer
    @StateObject private var viewModel = PaymentViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = viewModel.loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(.systemGray3))
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Try Again") {
                        Task { await viewModel.load(slug: memberSlug, eventTypeIds: eventTypeIds) }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.indigo)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                paymentContent
            }
        }
        .navigationTitle("Payment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await viewModel.load(slug: memberSlug, eventTypeIds: eventTypeIds) }
        .navigationDestination(isPresented: $viewModel.showConfirmationScreen) {
            BookingConfirmationView(
                serviceName:  viewModel.confirmedServiceName,
                memberName:   memberName,
                businessName: businessName,
                dateStr:      viewModel.confirmedDate,
                timeStr:      viewModel.confirmedTime,
                status:       viewModel.confirmedStatus,
                onComplete:   onComplete
            )
        }
        .alert("Payment Failed", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Please try again.")
        }
    }

    // MARK: - Payment content

    @ViewBuilder
    private var paymentContent: some View {
        VStack(spacing: 0) {
            SlotCountdownBanner(holdTimer: holdTimer)

            ScrollView {
                VStack(spacing: 20) {
                    // Order summary card
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Order Summary")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 10)

                        Divider().padding(.leading, 16)

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(eventTypeNames.joined(separator: " + "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(memberName) · \(businessName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(priceLabel)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Divider().padding(.leading, 16)

                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formattedDate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formattedTime)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
                    .padding(.horizontal, 16)

                    Spacer(minLength: 80)
                }
                .padding(.top, 20)
            }

            // Sticky pay button
            let price = totalPriceCents
            VStack(spacing: 0) {
                Divider()
                if let sheet = viewModel.paymentSheet {
                    PaymentSheet.PaymentButton(
                        paymentSheet: sheet,
                        onCompletion: { result in
                            Task {
                                await viewModel.handlePaymentResult(
                                    result,
                                    slug:           memberSlug,
                                    eventTypeIds:   eventTypeIds,
                                    date:           selectedDate,
                                    time:           selectedTime,
                                    eventTypeNames: eventTypeNames,
                                    priceCents:     price,
                                    policySnapshot: policySnapshot
                                )
                            }
                        }
                    ) {
                        HStack(spacing: 6) {
                            if viewModel.isConfirming {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "lock.fill")
                                    .font(.subheadline)
                                Text("Pay \(priceLabel)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.indigo)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(viewModel.isConfirming)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                    Text("Secured by Stripe")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }
            }
            .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Helpers

    private var priceLabel: String {
        String(format: "$%.0f", Double(totalPriceCents) / 100.0)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: selectedDate) else { return selectedDate }
        let out = DateFormatter()
        out.dateFormat = "EEE, MMM d"
        return out.string(from: d)
    }

    private var formattedTime: String {
        let parts = selectedTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return selectedTime }
        let h = parts[0], m = parts[1]
        let period = h >= 12 ? "PM" : "AM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12):\(String(format: "%02d", m)) \(period)"
    }
}

// MARK: - ViewModel

@MainActor
class PaymentViewModel: ObservableObject {
    @Published var paymentSheet: PaymentSheet? = nil
    @Published var isLoading = true
    @Published var loadError: String? = nil
    @Published var isConfirming = false
    @Published var showConfirmationScreen = false
    @Published var showError = false
    @Published var errorMessage: String? = nil

    var confirmedServiceName = ""
    var confirmedDate = ""
    var confirmedTime = ""
    var confirmedStatus = "confirmed"
    private var paymentIntentId: String? = nil

    func load(slug: String, eventTypeIds: [String]) async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        guard let token = KeychainService.getAccessToken() else {
            loadError = "Not logged in."
            return
        }

        do {
            let body: [String: Any] = ["event_type_ids": eventTypeIds]
            let response: PaymentIntentResponse = try await APIClient.post(
                path: "/customer/payment-intent/\(slug)",
                body: body,
                token: token
            )

            StripeAPI.defaultPublishableKey = response.publishableKey

            var config = PaymentSheet.Configuration()
            config.merchantDisplayName = "Timply"
            config.customer = .init(
                id: response.customerId,
                ephemeralKeySecret: response.ephemeralKey
            )
            config.allowsDelayedPaymentMethods = false
            config.savePaymentMethodOptInBehavior = .requiresOptIn

            // Extract PI ID from client_secret (format: pi_xxx_secret_yyy)
            paymentIntentId = response.clientSecret.components(separatedBy: "_secret_").first

            paymentSheet = PaymentSheet(
                paymentIntentClientSecret: response.clientSecret,
                configuration: config
            )
        } catch APIError.serverError(let msg) {
            loadError = msg
        } catch {
            loadError = "Could not load payment info. Please try again."
        }
    }

    func handlePaymentResult(
        _ result: PaymentSheetResult,
        slug: String,
        eventTypeIds: [String],
        date: String,
        time: String,
        eventTypeNames: [String],
        priceCents: Int,
        policySnapshot: [String: Any]
    ) async {
        switch result {
        case .completed:
            await confirmBooking(
                slug:           slug,
                eventTypeIds:   eventTypeIds,
                date:           date,
                time:           time,
                eventTypeNames: eventTypeNames,
                priceCents:     priceCents,
                policySnapshot: policySnapshot
            )
        case .canceled:
            break
        case .failed(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func confirmBooking(
        slug: String,
        eventTypeIds: [String],
        date: String,
        time: String,
        eventTypeNames: [String],
        priceCents: Int,
        policySnapshot: [String: Any]
    ) async {
        guard let token = KeychainService.getAccessToken() else { return }

        isConfirming = true
        defer { isConfirming = false }

        do {
            var body: [String: Any] = [
                "event_type_ids":       eventTypeIds,
                "date":                 date,
                "start_time":           time,
                "paid_online":          true,
                "payment_amount_cents": priceCents,
            ]
            if let piId = paymentIntentId { body["payment_intent_id"] = piId }
            if !policySnapshot.isEmpty    { body["policy_snapshot"]   = policySnapshot }
            let result: MobileBookingResponse = try await APIClient.post(
                path: "/customer/book/\(slug)",
                body: body,
                token: token
            )

            if result.success == true {
                let timeParts = time.split(separator: ":").compactMap { Int($0) }
                let h = timeParts.first ?? 0
                let m = timeParts.count > 1 ? timeParts[1] : 0
                let period = h >= 12 ? "PM" : "AM"
                let h12 = h % 12 == 0 ? 12 : h % 12

                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                var dateStr = date
                if let d = df.date(from: date) {
                    let out = DateFormatter()
                    out.dateFormat = "EEE, MMM d"
                    dateStr = out.string(from: d)
                }

                confirmedServiceName = eventTypeNames.joined(separator: " + ")
                confirmedDate = dateStr
                confirmedTime = "\(h12):\(String(format: "%02d", m)) \(period)"
                confirmedStatus = result.status ?? "confirmed"
                showConfirmationScreen = true
            }
        } catch APIError.serverError(let msg) {
            errorMessage = msg
            showError = true
        } catch {
            errorMessage = "Booking failed after payment. Please contact support."
            showError = true
        }
    }
}
