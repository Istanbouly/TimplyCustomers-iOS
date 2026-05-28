import SwiftUI

struct CustomerBookingDetailView: View {
    let booking: CustomerBooking
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Status banner
                    statusBanner

                    // Details card
                    VStack(spacing: 0) {
                        detailRow(icon: "scissors",
                                  label: booking.displayServiceName,
                                  sub: durationAndPrice)

                        if let biz = booking.businesses {
                            Divider().padding(.leading, 52)
                            detailRow(icon: "building.2",
                                      label: biz.name,
                                      sub: providerLabel)
                        }

                        Divider().padding(.leading, 52)
                        detailRow(icon: "calendar",
                                  label: booking.formattedDate)

                        Divider().padding(.leading, 52)
                        detailRow(icon: "clock",
                                  label: booking.formattedTime,
                                  sub: endTimeLabel)

                        if let booked = bookedOnLabel {
                            Divider().padding(.leading, 52)
                            detailRow(icon: "checkmark.circle", label: booked)
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(.systemGray5), lineWidth: 1))
                    .padding(.horizontal, 20)

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
        }
    }

    // MARK: - Status banner

    private var statusBanner: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text(statusLabel)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(dotColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(dotColor.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Detail row

    private func detailRow(icon: String, label: String, sub: String? = nil) -> some View {
        HStack(alignment: sub != nil ? .top : .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.indigo)
            }
            .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let sub = sub {
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

    // MARK: - Helpers

    private var statusLabel: String {
        switch booking.status {
        case "confirmed": return "Confirmed"
        case "pending":   return "Pending Confirmation"
        default:          return "Cancelled"
        }
    }

    private var dotColor: Color {
        switch booking.status {
        case "confirmed": return Color(red: 0.13, green: 0.70, blue: 0.40)
        case "pending":   return Color(red: 0.95, green: 0.65, blue: 0.10)
        default:          return Color(red: 0.90, green: 0.27, blue: 0.27)
        }
    }

    private var durationAndPrice: String? {
        var parts: [String] = []

        if let dur = booking.totalDurationMinutes {
            let h = dur / 60, m = dur % 60
            if h > 0 && m > 0 { parts.append("\(h)h \(m)m") }
            else if h > 0 { parts.append("\(h)h") }
            else { parts.append("\(m) min") }
        }

        let rows = booking.bookingEventTypes ?? []
        let multiCents = rows.compactMap { $0.eventTypes?.priceCents }.reduce(0, +)
        let singleCents = booking.eventTypes?.priceCents ?? 0
        let totalCents = multiCents > 0 ? multiCents : singleCents
        if totalCents > 0 {
            parts.append(String(format: "$%.0f", Double(totalCents) / 100.0))
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var providerLabel: String? {
        guard let provider = booking.providerInfo else { return nil }
        return provider.role == "staff" ? provider.name : "\(provider.name) (Owner)"
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
}

