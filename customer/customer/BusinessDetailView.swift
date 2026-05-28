import SwiftUI

struct BusinessDetailView: View {
    let business: BusinessItem
    @StateObject private var viewModel = BusinessDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let team = viewModel.team {
                teamContent(team: team)
            }
        }
        .navigationTitle(business.businessName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await viewModel.load(slug: business.ownerSlug) }
    }

    // MARK: - Team content

    private func teamContent(team: TeamResponse) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {

                    // Business header
                    VStack(spacing: 10) {
                        AvatarView(url: business.ownerAvatar, name: business.businessName, size: 72)

                        VStack(spacing: 4) {
                            Text(business.businessName)
                                .font(.title3)
                                .fontWeight(.bold)

                            if let address = business.address, !address.isEmpty {
                                Label(address, systemImage: "mappin.and.ellipse")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let rating = business.avgRating, rating > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color(red: 0.95, green: 0.65, blue: 0.10))
                                    Text(String(format: "%.1f", rating))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    if let count = business.reviewCount, count > 0 {
                                        Text("· \(count) reviews")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 24)

                    // Team selector
                    VStack(alignment: .leading, spacing: 12) {
                        let allMembers = allTeamMembers(team: team)

                        if allMembers.count > 1 {
                            Text("Book with")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)
                        }

                        VStack(spacing: 8) {
                            ForEach(allMembers) { member in
                                TeamMemberRow(
                                    member: member,
                                    isOwner: member.id == team.owner.id,
                                    isSelected: viewModel.selectedMemberId == member.id
                                ) {
                                    viewModel.selectedMemberId = member.id
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 80)
                }
            }

            // Sticky Start Booking button
            VStack(spacing: 0) {
                Divider()
                NavigationLink(value: servicesDestination(team: team)) {
                    Text("Start Booking")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(viewModel.selectedMemberId == nil ? Color(.systemGray4) : Color.indigo)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemBackground))
        }
    }

    private func servicesDestination(team: TeamResponse) -> ServicesDestination? {
        guard let id = viewModel.selectedMemberId else { return nil }
        let member: TeamMember?
        if team.owner.id == id { member = team.owner }
        else { member = team.staff.first { $0.id == id } }
        guard let m = member else { return nil }
        return ServicesDestination(
            memberSlug:      m.slug,
            memberName:      m.name,
            memberAvatarUrl: m.avatarUrl,
            businessName:    business.businessName
        )
    }

    private func allTeamMembers(team: TeamResponse) -> [TeamMember] {
        var members = [team.owner]
        members.append(contentsOf: team.staff)
        return members
    }
}

// MARK: - Team member row

struct TeamMemberRow: View {
    let member: TeamMember
    let isOwner: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                AvatarView(url: member.avatarUrl, name: member.name, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(member.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.primary)
                        if isOwner {
                            Text("Owner")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.indigo)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.indigo.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.indigo : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.indigo)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.indigo.opacity(0.06) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.indigo.opacity(0.4) : Color(.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
