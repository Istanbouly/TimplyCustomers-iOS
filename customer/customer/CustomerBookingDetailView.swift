import SwiftUI

struct CustomerBookingDetailView: View {
    let booking: CustomerBooking
    let onCancelled: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var payments: [PaymentAttempt] = []
    @State private var isLoadingPayments = true
    @State private var notes: [BookingNote] = []
    @State private var isLoadingNotes = false
    @State private var newNoteText = ""
    @State private var isPostingNote = false
    @State private var showRescheduleView = false
    @State private var showCancelAlert = false
    @State private var isCancelling = false
    @State private var cancellationError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusBanner
                    servicesSection
                    detailsCard
                    paymentsSection
                    notesSection

                    if let error = cancellationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    if booking.isCancellable {
                        rescheduleButton
                        cancelButton
                    }

                    Spacer(minLength: 24)
                }
                .padding(.top, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Booking Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showRescheduleView) {
                if let slug = booking.providerInfo?.bookingSlug,
                   let dur  = booking.totalDurationMinutes {
                    RescheduleView(
                        bookingId:            booking.id,
                        memberSlug:           slug,
                        eventTypeIds:         booking.eventTypeIds,
                        totalDurationMinutes: dur,
                        serviceName:          booking.displayServiceName,
                        onRescheduled: {
                            onCancelled()   // same effect — refresh the list
                        }
                    )
                }
            }
            .alert(cancelAlertTitle, isPresented: $showCancelAlert) {
                Button("Keep Appointment", role: .cancel) {}
                Button("Cancel Anyway", role: .destructive) {
                    Task { await cancelBooking() }
                }
            } message: {
                Text(cancelAlertMessage)
            }
        }
        .task {
            await loadPayments()
            if booking.isUpcoming { await loadNotes() }
        }
    }

    // MARK: - Status banner

    private var statusBanner: some View {
        HStack(spacing: 10) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Text(statusLabel)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(statusColor.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Services section

    private var servicesSection: some View {
        let services = booking.servicesList
        return VStack(spacing: 0) {
            if services.isEmpty {
                iconRow(icon: "scissors", label: "Appointment")
            } else {
                ForEach(Array(services.enumerated()), id: \.offset) { index, service in
                    if index > 0 { Divider().padding(.leading, 52) }
                    serviceRow(service)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func serviceRow(_ service: CustomerBooking.EventTypeInfo) -> some View {
        iconRow(
            icon: "scissors",
            label: service.name,
            sub: serviceSub(service)
        )
    }

    private func serviceSub(_ service: CustomerBooking.EventTypeInfo) -> String? {
        var parts: [String] = []
        if let dur = service.durationMinutes { parts.append(durationLabel(dur)) }
        if let cents = service.priceCents, cents > 0 { parts.append(String(format: "$%.0f", Double(cents) / 100.0)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Details card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            if let biz = booking.businesses {
                iconRow(icon: "building.2", label: biz.name, sub: providerLabel)
                Divider().padding(.leading, 52)
            }
            iconRow(icon: "calendar", label: booking.formattedDate)
            Divider().padding(.leading, 52)
            iconRow(icon: "clock", label: booking.formattedTime, sub: endTimeLabel)
            if let booked = bookedOnLabel {
                Divider().padding(.leading, 52)
                iconRow(icon: "checkmark.circle", label: booked)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // MARK: - Payments section

    @ViewBuilder
    private var paymentsSection: some View {
        if isLoadingPayments {
            HStack(spacing: 8) {
                ProgressView()
                Text("Loading payments…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
            .padding(.horizontal, 20)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Payment")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    if payments.isEmpty {
                        // No card charge — customer chose to pay in person
                        HStack(spacing: 10) {
                            Image(systemName: "banknote")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("Pay in person")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    } else {
                        ForEach(Array(payments.enumerated()), id: \.offset) { index, payment in
                            if index > 0 { Divider().padding(.horizontal, 16) }
                            paymentRow(payment)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Notes section

    @ViewBuilder
    private var notesSection: some View {
        if booking.isUpcoming {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    if isLoadingNotes {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(16)
                    } else {
                        ForEach(notes) { note in
                            noteRow(note)
                            Divider().padding(.leading, 16)
                        }
                    }

                    // Add note input
                    HStack(alignment: .bottom, spacing: 10) {
                        TextField("Add a note…", text: $newNoteText, axis: .vertical)
                            .font(.subheadline)
                            .lineLimit(4...8)
                            .frame(minHeight: 72, alignment: .topLeading)
                        if isPostingNote {
                            ProgressView().padding(.bottom, 4)
                        } else {
                            Button {
                                Task { await postNote() }
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(newNoteText.trimmingCharacters(in: .whitespaces).isEmpty
                                                     ? Color(.systemGray4) : Color.indigo)
                            }
                            .buttonStyle(.plain)
                            .disabled(newNoteText.trimmingCharacters(in: .whitespaces).isEmpty)
                            .padding(.bottom, 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    private func noteRow(_ note: BookingNote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.authorName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                Text(note.formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(note.body)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func paymentRow(_ payment: PaymentAttempt) -> some View {
        let pColor = paymentColor(payment.status)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.amountLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(payment.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(payment.statusLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(pColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(pColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Reschedule button

    private var rescheduleButton: some View {
        Button {
            showRescheduleView = true
        } label: {
            Text("Reschedule Appointment")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.indigo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.indigo.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.indigo.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Cancel button

    private var cancelButton: some View {
        let red = Color(red: 0.90, green: 0.27, blue: 0.27)
        return Button {
            showCancelAlert = true
        } label: {
            Group {
                if isCancelling {
                    ProgressView().tint(red)
                } else {
                    Text("Cancel Appointment")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(red)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(red.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isCancelling)
        .padding(.horizontal, 20)
    }

    // MARK: - Alert

    private var cancelAlertTitle: String {
        if booking.paidOnline == true { return "Cancel Appointment" }
        return booking.isInCancellationFeeWindow ? "Cancellation Fee Applies" : "Cancel Appointment"
    }

    private var cancelAlertMessage: String {
        // Customer already paid upfront — no additional fee, but address refund situation
        if booking.paidOnline == true {
            let businessName = booking.businesses?.name ?? "the business"
            let refundPolicy = booking.bookingPolicies?.refundPolicySnapshot ?? booking.businesses?.refundPolicy
            let disclaimer = "Timply does not process refunds. Any disputes are between you and \(businessName)."
            if let policy = refundPolicy, !policy.isEmpty {
                return "This booking was paid online. No cancellation fee will be charged.\n\nRefund policy at time of booking: \"\(policy)\"\n\n\(disclaimer)"
            }
            return "This booking was paid online. No cancellation fee will be charged.\n\n\(disclaimer)"
        }
        // Pay-in-person path — fee may apply
        if booking.isInCancellationFeeWindow, let fee = booking.cancellationFeeString {
            return "You're within the cancellation window. A fee of \(fee) will be charged to your saved card. This cannot be undone."
        }
        return "Are you sure you want to cancel this appointment? This cannot be undone."
    }

    // MARK: - Actions

    private func loadPayments() async {
        guard let token = KeychainService.getAccessToken() else {
            isLoadingPayments = false
            return
        }
        if let response = try? await APIClient.get(
            path: "/customer/bookings/\(booking.id)/payment",
            token: token
        ) as BookingPaymentResponse {
            payments = response.payments
        }
        isLoadingPayments = false
    }

    private func loadNotes() async {
        guard let token = KeychainService.getAccessToken() else { return }
        isLoadingNotes = true
        defer { isLoadingNotes = false }
        if let loaded = try? await APIClient.get(
            path: "/customer/bookings/\(booking.id)/notes",
            token: token
        ) as [BookingNote] {
            notes = loaded
        }
    }

    private func postNote() async {
        let trimmed = newNoteText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let token = KeychainService.getAccessToken() else { return }
        isPostingNote = true
        defer { isPostingNote = false }
        if let note = try? await APIClient.post(
            path: "/customer/bookings/\(booking.id)/notes",
            body: ["body": trimmed],
            token: token
        ) as BookingNote {
            notes.append(note)
            newNoteText = ""
        }
    }

    private func cancelBooking() async {
        guard let token = KeychainService.getAccessToken() else { return }
        isCancelling = true
        do {
            let _: CancelBookingResponse = try await APIClient.delete(
                path: "/customer/bookings/\(booking.id)",
                token: token
            )
            onCancelled()
            dismiss()
        } catch {
            isCancelling = false
            cancellationError = error.localizedDescription
        }
    }

    // MARK: - Reusable row

    private func iconRow(icon: String, label: String, sub: String? = nil) -> some View {
        HStack(alignment: sub != nil ? .top : .center, spacing: 12) {
            ZStack {
                Circle().fill(Color.indigo.opacity(0.1)).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.indigo)
            }
            .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let sub {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.trailing, 14)
    }

    // MARK: - Computed helpers

    private var statusLabel: String {
        switch booking.status {
        case "confirmed": return "Confirmed"
        case "pending":   return "Pending Confirmation"
        default:          return "Cancelled"
        }
    }

    private var statusColor: Color {
        switch booking.status {
        case "confirmed": return Color(red: 0.13, green: 0.70, blue: 0.40)
        case "pending":   return Color(red: 0.95, green: 0.65, blue: 0.10)
        default:          return Color(red: 0.90, green: 0.27, blue: 0.27)
        }
    }

    private func paymentColor(_ status: String) -> Color {
        switch status {
        case "succeeded": return Color(red: 0.13, green: 0.70, blue: 0.40)
        case "pending":   return Color(red: 0.95, green: 0.65, blue: 0.10)
        default:          return Color(red: 0.90, green: 0.27, blue: 0.27)
        }
    }

    private var providerLabel: String? {
        guard let p = booking.providerInfo else { return nil }
        return p.role == "staff" ? p.name : "\(p.name) (Owner)"
    }

    private var endTimeLabel: String? {
        guard let end = booking.endTime else { return nil }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["HH:mm:ss", "HH:mm"] {
            df.dateFormat = fmt
            if let d = df.date(from: end) {
                let out = DateFormatter()
                out.dateFormat = "h:mm a"
                return "Until \(out.string(from: d))"
            }
        }
        return nil
    }

    private var bookedOnLabel: String? {
        guard let raw = booking.createdAt else { return nil }
        let df = ISO8601DateFormatter()
        guard let d = df.date(from: raw) else { return nil }
        let out = DateFormatter()
        out.dateFormat = "MMM d, yyyy"
        return "Booked on \(out.string(from: d))"
    }

    private func durationLabel(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m) min"
    }
}
