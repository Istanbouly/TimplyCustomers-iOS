import Foundation

struct LoginResponse: Decodable {
    let session: Session
    let user: AuthUser?

    struct Session: Decodable {
        let accessToken: String
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken  = "access_token"
            case refreshToken = "refresh_token"
        }
    }

    struct AuthUser: Decodable {
        let appMetadata: AppMetadata?
        enum CodingKeys: String, CodingKey { case appMetadata = "app_metadata" }
    }

    struct AppMetadata: Decodable {
        let timplyRole: String?
        enum CodingKeys: String, CodingKey { case timplyRole = "timply_role" }
    }
}

struct RefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct CustomerProfileResponse: Decodable {
    let customer: CustomerProfile
}

struct SignUpResponse: Decodable {
    let awaitingVerification: Bool
    enum CodingKeys: String, CodingKey {
        case awaitingVerification = "awaiting_verification"
    }
}

struct VerifyOTPResponse: Decodable {
    let verified: Bool
}

struct CustomerSetupResponse: Decodable {
    let customer: CustomerProfile
}

struct GoogleSessionResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct CustomerProfile: Decodable {
    let id: String
    let email: String
    let name: String?
    let avatarUrl: String?
    let phone: String?

    enum CodingKeys: String, CodingKey {
        case id, email, name, phone
        case avatarUrl = "avatar_url"
    }
}
