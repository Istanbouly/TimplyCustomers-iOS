import Foundation

struct CustomerBookingsResponse: Decodable {
    let bookings: [CustomerBooking]
}

struct CustomerBooking: Identifiable, Decodable {
    let id: String
    let date: String
    let startTime: String
    let endTime: String?
    let status: String
    let createdAt: String?
    let businesses: BusinessInfo?
    let eventTypes: EventTypeInfo?
    let bookingEventTypes: [BookingEventTypeRow]?
    let providerInfo: ProviderInfo?

    struct BusinessInfo: Decodable {
        let name: String
        let slug: String?
    }

    struct ProviderInfo: Decodable {
        let name: String
        let role: String
    }

    struct EventTypeInfo: Decodable {
        let name: String
        let durationMinutes: Int?
        let priceCents: Int?
        enum CodingKeys: String, CodingKey {
            case name
            case durationMinutes = "duration_minutes"
            case priceCents = "price_cents"
        }
    }

    struct BookingEventTypeRow: Decodable {
        let eventTypes: EventTypeInfo?
        enum CodingKeys: String, CodingKey { case eventTypes = "event_types" }
    }

    enum CodingKeys: String, CodingKey {
        case id, date, status, businesses
        case startTime         = "start_time"
        case endTime           = "end_time"
        case createdAt         = "created_at"
        case eventTypes        = "event_types"
        case bookingEventTypes = "booking_event_types"
        case providerInfo      = "profiles"
    }

    // MARK: - Computed

    var displayServiceName: String {
        let multi = bookingEventTypes?.compactMap { $0.eventTypes?.name } ?? []
        if !multi.isEmpty { return multi.joined(separator: ", ") }
        return eventTypes?.name ?? "Appointment"
    }

    var totalDurationMinutes: Int? {
        let multi = bookingEventTypes?.compactMap { $0.eventTypes?.durationMinutes } ?? []
        if !multi.isEmpty { return multi.reduce(0, +) }
        return eventTypes?.durationMinutes
    }

    var isUpcoming: Bool {
        let today = todayString()
        return date >= today && status != "cancelled"
    }

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
