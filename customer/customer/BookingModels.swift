import Foundation

struct BookPageResponse: Decodable {
    let businessName: String
    let timezone: String
    let bookingSlug: String
    let avatarUrl: String?
    let eventTypes: [EventType]
    let availableDays: [Int]
    let allowMultiService: Bool
    let maxServicesPerBooking: Int
    let requireUpfrontPayment: Bool
    let stripeChargesEnabled: Bool
    let maxWorkingMinutes: Int
    let cancellationPolicyEnabled: Bool
    let cancellationPolicyHours: Int
    let cancellationFeeType: String
    let cancellationFeeAmount: Double
    let noShowPolicyEnabled: Bool
    let noShowFeeType: String
    let noShowFeeAmount: Double
    let refundPolicy: String?

    enum CodingKeys: String, CodingKey {
        case businessName              = "business_name"
        case timezone
        case bookingSlug               = "booking_slug"
        case avatarUrl                 = "avatar_url"
        case eventTypes                = "event_types"
        case availableDays             = "available_days"
        case allowMultiService         = "allow_multi_service"
        case maxServicesPerBooking     = "max_services_per_booking"
        case requireUpfrontPayment     = "require_upfront_payment"
        case stripeChargesEnabled      = "stripe_charges_enabled"
        case maxWorkingMinutes         = "max_working_minutes"
        case cancellationPolicyEnabled = "cancellation_policy_enabled"
        case cancellationPolicyHours   = "cancellation_policy_hours"
        case cancellationFeeType       = "cancellation_fee_type"
        case cancellationFeeAmount     = "cancellation_fee_amount"
        case noShowPolicyEnabled       = "no_show_policy_enabled"
        case noShowFeeType             = "no_show_fee_type"
        case noShowFeeAmount           = "no_show_fee_amount"
        case refundPolicy              = "refund_policy"
    }
}

struct EventType: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let durationMinutes: Int
    let description: String?
    let priceCents: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case durationMinutes = "duration_minutes"
        case priceCents      = "price_cents"
    }

    var durationLabel: String {
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m) min"
    }

    var priceLabel: String? {
        guard let cents = priceCents, cents > 0 else { return nil }
        return String(format: "$%.0f", Double(cents) / 100.0)
    }
}

struct SlotsResponse: Decodable {
    let slots: [String]
    let message: String?
}

struct NextAvailableResponse: Decodable {
    let date: String?
    let slots: [String]
    let message: String?
}

struct MobileBookingResponse: Decodable {
    let success: Bool
    let status: String?
    let bookingId: String?
    let autoConfirm: Bool?

    enum CodingKeys: String, CodingKey {
        case success, status
        case bookingId   = "booking_id"
        case autoConfirm = "auto_confirm"
    }
}

// Navigation value types (must be Hashable for NavigationStack)

struct ServicesDestination: Hashable {
    let memberSlug: String
    let memberName: String
    let memberAvatarUrl: String?
    let businessName: String
}

struct SlotPickerDestination: Hashable {
    let memberSlug: String
    let memberName: String
    let businessName: String
    let selectedEventTypeIds: [String]
    let selectedEventTypeNames: [String]
    let totalDurationMinutes: Int
    let availableDays: [Int]   // 0=Sun … 6=Sat
    let timezone: String       // IANA identifier e.g. "America/New_York"
    let stripeChargesEnabled: Bool
    let requireUpfrontPayment: Bool
    let totalPriceCents: Int
    let cancellationPolicyEnabled: Bool
    let cancellationPolicyHours: Int
    let cancellationFeeType: String
    let cancellationFeeAmount: Double
    let noShowPolicyEnabled: Bool
    let noShowFeeType: String
    let noShowFeeAmount: Double
    let refundPolicy: String?

    var hasPolicies: Bool {
        cancellationPolicyEnabled || noShowPolicyEnabled || (refundPolicy != nil && !refundPolicy!.isEmpty)
    }
}

struct SavedPaymentMethod: Decodable {
    let id: String
    let brand: String
    let last4: String
    let expMonth: Int
    let expYear: Int
    enum CodingKeys: String, CodingKey {
        case id, brand, last4
        case expMonth = "exp_month"
        case expYear  = "exp_year"
    }
}

struct PaymentMethodsResponse: Decodable {
    let paymentMethods: [SavedPaymentMethod]
    enum CodingKeys: String, CodingKey {
        case paymentMethods = "payment_methods"
    }
}

struct PaymentIntentResponse: Decodable {
    let clientSecret: String
    let ephemeralKey: String
    let customerId: String
    let publishableKey: String
    enum CodingKeys: String, CodingKey {
        case clientSecret   = "client_secret"
        case ephemeralKey   = "ephemeral_key"
        case customerId     = "customer_id"
        case publishableKey = "publishable_key"
    }
}

struct SetupIntentResponse: Decodable {
    let setupIntentClientSecret: String
    let ephemeralKey: String
    let customerId: String
    let publishableKey: String
    enum CodingKeys: String, CodingKey {
        case setupIntentClientSecret = "setup_intent_client_secret"
        case ephemeralKey            = "ephemeral_key"
        case customerId              = "customer_id"
        case publishableKey          = "publishable_key"
    }
}
