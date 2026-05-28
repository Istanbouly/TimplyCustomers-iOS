import Foundation

struct BusinessListResponse: Decodable {
    let businesses: [BusinessItem]
    let hasMore: Bool
    let total: Int
}

struct BusinessItem: Identifiable, Decodable, Hashable {
    let id: String
    let ownerSlug: String
    let ownerName: String?
    let ownerAvatar: String?
    let businessName: String
    let address: String?
    let avgRating: Double?
    let reviewCount: Int?
}

struct TeamResponse: Decodable {
    let owner: TeamMember
    let staff: [TeamMember]
}

struct TeamMember: Identifiable, Decodable {
    let id: String
    let name: String
    let slug: String
    let avatarUrl: String?
}
