import Foundation

struct CustomerBookingsResponse: Decodable {
    let bookings: [CustomerBooking]
}

struct CustomerBookingsPageResponse: Decodable {
    let bookings: [CustomerBooking]
    let total: Int
    let page: Int
    let hasMore: Bool
    enum CodingKeys: String, CodingKey {
        case bookings, total, page
        case hasMore = "has_more"
    }
}

struct CustomerBooking: Identifiable, Decodable {
    let id: String
    let date: String
    let startTime: String
    let endTime: String?
    let status: String
    let createdAt: String?
    let eventTypeId: String?       // raw FK — used for single-service slot fetching
    let cancellationPmId: String?
    let businesses: BusinessInfo?
    let eventTypes: EventTypeInfo?
    let bookingEventTypes: [BookingEventTypeRow]?
    let providerInfo: ProviderInfo?
    let bookingPolicies: BookingPolicySnapshot?

    // MARK: - Nested types

    struct BusinessInfo: Decodable {
        let name: String
        let slug: String?
        let cancellationPolicyEnabled: Bool?
        let cancellationPolicyHours: Int?
        let cancellationFeeType: String?
        let cancellationFeeAmount: Double?  // cents (fixed) or raw % (percentage)
        let refundPolicy: String?
        enum CodingKeys: String, CodingKey {
            case name, slug
            case cancellationPolicyEnabled = "cancellation_policy_enabled"
            case cancellationPolicyHours   = "cancellation_policy_hours"
            case cancellationFeeType       = "cancellation_fee_type"
            case cancellationFeeAmount     = "cancellation_fee_amount"
            case refundPolicy              = "refund_policy"
        }
    }

    struct ProviderInfo: Decodable {
        let name: String
        let role: String
        let bookingSlug: String?
        enum CodingKeys: String, CodingKey {
            case name, role
            case bookingSlug = "booking_slug"
        }
    }

    struct EventTypeInfo: Decodable {
        let id: String?
        let name: String
        let durationMinutes: Int?
        let priceCents: Int?
        enum CodingKeys: String, CodingKey {
            case id, name
            case durationMinutes = "duration_minutes"
            case priceCents      = "price_cents"
        }
    }

    struct BookingEventTypeRow: Decodable {
        let eventTypes: EventTypeInfo?
        enum CodingKeys: String, CodingKey { case eventTypes = "event_types" }
    }

    /// Policy terms snapshotted at booking time (beats live business policy for fee disputes)
    struct BookingPolicySnapshot: Decodable {
        let hours: Int?
        let feeType: String?
        let feeAmount: Int?  // cents (fixed) or raw % (percentage) — integer in DB
        let refundPolicySnapshot: String?
        enum CodingKeys: String, CodingKey {
            case hours                = "cancellation_policy_hours_snapshot"
            case feeType              = "cancellation_fee_type_snapshot"
            case feeAmount            = "cancellation_fee_amount_snapshot"
            case refundPolicySnapshot = "refund_policy_snapshot"
        }
    }

    let paidOnline: Bool?

    enum CodingKeys: String, CodingKey {
        case id, date, status, businesses
        case startTime         = "start_time"
        case endTime           = "end_time"
        case createdAt         = "created_at"
        case eventTypeId       = "event_type_id"
        case cancellationPmId  = "cancellation_pm_id"
        case paidOnline        = "paid_online"
        case eventTypes        = "event_types"
        case bookingEventTypes = "booking_event_types"
        case providerInfo      = "profiles"
        case bookingPolicies   = "booking_policies"
    }

    // MARK: - Service display

    /// Event type IDs for slot fetching (multi takes priority over single)
    var eventTypeIds: [String] {
        let multi = bookingEventTypes?.compactMap { $0.eventTypes?.id } ?? []
        if !multi.isEmpty { return multi }
        if let id = eventTypeId { return [id] }
        return []
    }

    /// All services as a flat list (multi-service takes priority over single)
    var servicesList: [EventTypeInfo] {
        let multi = bookingEventTypes?.compactMap { $0.eventTypes } ?? []
        if !multi.isEmpty { return multi }
        if let single = eventTypes { return [single] }
        return []
    }

    var displayServiceName: String {
        let names = servicesList.map { $0.name }
        return names.isEmpty ? "Appointment" : names.joined(separator: ", ")
    }

    var totalDurationMinutes: Int? {
        let multi = bookingEventTypes?.compactMap { $0.eventTypes?.durationMinutes } ?? []
        if !multi.isEmpty { return multi.reduce(0, +) }
        return eventTypes?.durationMinutes
    }

    var totalPriceCents: Int {
        let multi = bookingEventTypes?.compactMap { $0.eventTypes?.priceCents } ?? []
        if !multi.isEmpty { return multi.reduce(0, +) }
        return eventTypes?.priceCents ?? 0
    }

    // MARK: - State helpers

    var isUpcoming: Bool {
        date >= todayString() && status != "cancelled"
    }

    var isCancellable: Bool {
        isUpcoming && (status == "confirmed" || status == "pending")
    }

    // MARK: - Cancellation fee logic

    private var effectiveHours: Int? {
        bookingPolicies?.hours ?? businesses?.cancellationPolicyHours
    }

    private var effectiveFeeType: String? {
        bookingPolicies?.feeType ?? businesses?.cancellationFeeType
    }

    /// Returns the effective fee amount in cents (fixed) or as a raw percentage number
    private var effectiveFeeAmountDouble: Double? {
        if let snapAmt = bookingPolicies?.feeAmount { return Double(snapAmt) }
        return businesses?.cancellationFeeAmount
    }

    /// True if the customer is currently within the cancellation fee window
    var isInCancellationFeeWindow: Bool {
        // cancellationPmId != nil → policy was active at booking time (used as proxy for enabled)
        // paidOnline == true → customer already paid; no additional fee should apply
        guard cancellationPmId != nil,
              paidOnline != true,
              let hours = effectiveHours else { return false }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timeStr = startTime.count <= 5 ? startTime + ":00" : startTime
        guard let appointmentAt = df.date(from: "\(date) \(timeStr)") else { return false }

        let hoursUntil = appointmentAt.timeIntervalSinceNow / 3600
        return hoursUntil > 0 && hoursUntil < Double(hours)
    }

    /// Human-readable cancellation fee string, e.g. "$25.00" or "$40.00 (10%)"
    var cancellationFeeString: String? {
        guard let feeType = effectiveFeeType,
              let feeAmt = effectiveFeeAmountDouble,
              feeAmt > 0 else { return nil }

        if feeType == "percentage" {
            let dollarAmount = Double(totalPriceCents) / 100.0 * (feeAmt / 100.0)
            return String(format: "$%.2f (%.0f%%)", dollarAmount, feeAmt)
        }
        return String(format: "$%.2f", feeAmt / 100.0)
    }

    // MARK: - Formatted strings

    var formattedDate: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        guard let d = df.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateFormat = "EEE, MMM d"
        return out.string(from: d)
    }

    var formattedTime: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["HH:mm:ss", "HH:mm"] {
            df.dateFormat = fmt
            if let d = df.date(from: startTime) {
                let out = DateFormatter()
                out.dateFormat = "h:mm a"
                return out.string(from: d)
            }
        }
        return startTime
    }

    private func todayString() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.string(from: Date())
    }
}

// MARK: - Payment models

struct PaymentAttempt: Decodable {
    let amountCents: Int
    let status: String
    let attemptedAt: String

    enum CodingKeys: String, CodingKey {
        case amountCents = "amount_cents"
        case status
        case attemptedAt = "attempted_at"
    }

    var formattedDate: String {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let df2 = ISO8601DateFormatter()
        df2.formatOptions = [.withInternetDateTime]
        let d = df.date(from: attemptedAt) ?? df2.date(from: attemptedAt)
        guard let d else { return attemptedAt }
        let out = DateFormatter()
        out.dateFormat = "MMM d, yyyy"
        return out.string(from: d)
    }

    var amountLabel: String {
        String(format: "$%.2f", Double(amountCents) / 100.0)
    }

    var statusLabel: String {
        switch status {
        case "succeeded": return "Paid"
        case "pending":   return "Pending"
        default:          return status.capitalized
        }
    }
}

struct BookingPaymentResponse: Decodable {
    let payments: [PaymentAttempt]
}

struct CancelBookingResponse: Decodable {
    let feeChargedCents: Int
    enum CodingKeys: String, CodingKey {
        case feeChargedCents = "fee_charged_cents"
    }
}

struct BookingNote: Identifiable, Decodable {
    let id: String
    let body: String
    let authorName: String
    let createdAt: String
    enum CodingKeys: String, CodingKey {
        case id, body
        case authorName = "author_name"
        case createdAt  = "created_at"
    }

    var formattedDate: String {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let df2 = ISO8601DateFormatter()
        df2.formatOptions = [.withInternetDateTime]
        guard let d = df.date(from: createdAt) ?? df2.date(from: createdAt) else { return "" }
        let out = DateFormatter()
        out.dateFormat = "MMM d, h:mm a"
        return out.string(from: d)
    }
}
