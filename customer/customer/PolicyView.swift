import SwiftUI
import Combine

struct PolicyView: View {
    let destination: SlotPickerDestination
    let selectedDate: String
    let selectedTime: String
    let isPay: Bool
    let onComplete: () -> Void
    let onBook: ([String: Any]) async -> Void

    @State private var showPaymentView = false
    @State private var showSetupCardView = false
    @State private var isProcessing = false
    @State private var savedCards: [SavedPaymentMethod] = []
    @State private var isLoadingCards = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Booking Policies")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Please review the policies for this booking before continuing.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Cancellation policy
                    if destination.cancellationPolicyEnabled {
                        policyCard(
                            icon: "arrow.uturn.backward.circle",
                            title: "Cancellation Policy",
                            body: cancellationText
                        )
                    }

                    // No-show policy
                    if destination.noShowPolicyEnabled {
                        policyCard(
                            icon: "person.fill.xmark",
                            title: "No-Show Policy",
                            body: noShowText
                        )
                    }

                    // Refund policy
                    if let rp = destination.refundPolicy, !rp.isEmpty {
                        policyCard(
                            icon: "creditcard.and.123",
                            title: "Refund Policy",
                            body: rp
                        )
                    }

                    // Card-on-file warning (when no saved card and policy requires one)
                    if requiresCardOnFile && !isPay && !isLoadingCards && savedCards.isEmpty {
                        cardRequiredBanner
                    }

                    Spacer(minLength: 100)
                }
            }

            actionBar
        }
        .navigationTitle("Review Policies")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if requiresCardOnFile { await fetchSavedCards() }
        }
        .navigationDestination(isPresented: $showPaymentView) {
            PaymentView(
                memberSlug:      destination.memberSlug,
                memberName:      destination.memberName,
                businessName:    destination.businessName,
                eventTypeIds:    destination.selectedEventTypeIds,
                eventTypeNames:  destination.selectedEventTypeNames,
                selectedDate:    selectedDate,
                selectedTime:    selectedTime,
                totalPriceCents: destination.totalPriceCents,
                policySnapshot:  policySnapshot,
                onComplete:      onComplete
            )
        }
        .navigationDestination(isPresented: $showSetupCardView) {
            SetupCardView(
                destination:    destination,
                policySnapshot: policySnapshot,
                onComplete:     onComplete,
                onBook:         onBook
            )
        }
    }

    // MARK: - Card required banner

    private var cardRequiredBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "creditcard.fill")
                .font(.subheadline)
                .foregroundStyle(Color.indigo)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text("Card on file required")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("This business requires a card on file to secure your booking due to their cancellation or no-show policy. Please use \"Pay Now\" — your card will be saved for future bookings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.indigo.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.indigo.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // MARK: - Policy card

    private func policyCard(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.1))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(.indigo)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // MARK: - Action bar

    private var actionBar: some View {
        let cardBlocked = requiresCardOnFile && !isPay && savedCards.isEmpty && !isLoadingCards

        return VStack(spacing: 0) {
            Divider()
            VStack(spacing: 8) {
                if isPay {
                    // Pay Now
                    Button {
                        showPaymentView = true
                    } label: {
                        Text("Agree & Pay \(priceLabel)")
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
                } else if isLoadingCards {
                    ProgressView()
                        .padding(.top, 16)
                } else if cardBlocked {
                    // No saved card — save card via SetupIntent (no charge)
                    if destination.stripeChargesEnabled {
                        Button {
                            showSetupCardView = true
                        } label: {
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
                    } else {
                        Text("Please contact the business to complete this booking.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }
                } else {
                    // Pay in Person or Book Appointment (card on file if required)
                    Button {
                        isProcessing = true
                        Task {
                            await onBook(bookingParams)
                            isProcessing = false
                        }
                    } label: {
                        Group {
                            if isProcessing {
                                ProgressView().tint(.white)
                            } else {
                                Text(destination.stripeChargesEnabled && destination.totalPriceCents > 0
                                     ? "Agree & Pay in Person"
                                     : "Agree & Book Appointment")
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
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }

                if !cardBlocked {
                    Text("By continuing you agree to the above policies.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 12)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Fetch saved cards

    private func fetchSavedCards() async {
        guard let token = KeychainService.getAccessToken() else { return }
        isLoadingCards = true
        defer { isLoadingCards = false }

        if let response = try? await APIClient.get(
            path: "/customer/payment-methods",
            token: token
        ) as PaymentMethodsResponse {
            savedCards = response.paymentMethods
        }
    }

    // MARK: - Computed

    private var requiresCardOnFile: Bool {
        let price = destination.totalPriceCents
        let cancApplies = destination.cancellationPolicyEnabled &&
            (destination.cancellationFeeType == "fixed"
                ? destination.cancellationFeeAmount > 0
                : price > 0)
        let noShowApplies = destination.noShowPolicyEnabled &&
            (destination.noShowFeeType == "fixed"
                ? destination.noShowFeeAmount > 0
                : price > 0)
        return cancApplies || noShowApplies
    }

    private var policySnapshot: [String: Any] {
        var snap: [String: Any] = [:]
        if destination.cancellationPolicyEnabled {
            snap["cancellation_policy_hours_snapshot"]  = destination.cancellationPolicyHours
            snap["cancellation_fee_type_snapshot"]      = destination.cancellationFeeType
            snap["cancellation_fee_amount_snapshot"]    = destination.cancellationFeeAmount
        }
        if destination.noShowPolicyEnabled {
            snap["no_show_fee_type_snapshot"]   = destination.noShowFeeType
            snap["no_show_fee_amount_snapshot"] = destination.noShowFeeAmount
        }
        if let rp = destination.refundPolicy, !rp.isEmpty {
            snap["refund_policy_snapshot"] = rp
        }
        return snap
    }

    /// All params merged — policy snapshot + card IDs if applicable
    private var bookingParams: [String: Any] {
        var params: [String: Any] = [:]
        if !policySnapshot.isEmpty { params["policy_snapshot"] = policySnapshot }
        if let card = savedCards.first {
            if destination.cancellationPolicyEnabled { params["cancellation_pm_id"] = card.id }
            if destination.noShowPolicyEnabled       { params["no_show_pm_id"]       = card.id }
        }
        return params
    }

    private var priceLabel: String {
        String(format: "($%.0f)", Double(destination.totalPriceCents) / 100.0)
    }

    private var cancellationText: String {
        let hours = destination.cancellationPolicyHours
        let feeStr = feeString(type: destination.cancellationFeeType,
                               amount: destination.cancellationFeeAmount,
                               priceCents: destination.totalPriceCents)
        if feeStr == "Free" {
            return "Free cancellation any time before your appointment."
        }
        return "Free cancellation up to \(hours) hour\(hours == 1 ? "" : "s") before your appointment. After that, a \(feeStr) cancellation fee applies."
    }

    private var noShowText: String {
        let feeStr = feeString(type: destination.noShowFeeType,
                               amount: destination.noShowFeeAmount,
                               priceCents: destination.totalPriceCents)
        return "If you do not show up for your appointment, a \(feeStr) no-show fee will be charged."
    }

    private func feeString(type: String, amount: Double, priceCents: Int) -> String {
        if amount <= 0 { return "Free" }
        if type == "percentage" {
            let dollarAmount = Double(priceCents) / 100.0 * (amount / 100.0)
            return String(format: "$%.2f (%.0f%%)", dollarAmount, amount)
        }
        return String(format: "$%.2f", amount / 100.0)
    }
}
