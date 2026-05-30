import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Binding var isAuthenticated: Bool
    @State private var selectedTab = 0
    @State private var selectedBooking: CustomerBooking? = nil


    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            profileHeader
                            tabPicker
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                            bookingsList
                        }
                    }
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("My Bookings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await viewModel.load() }
        .sheet(item: $selectedBooking) { booking in
            CustomerBookingDetailView(booking: booking) {
                Task { await viewModel.load() }
            }
        }
    }

    // MARK: - Profile header

    private var profileHeader: some View {
        VStack(spacing: 10) {
            AvatarView(url: viewModel.profile?.avatarUrl, name: viewModel.profile?.name ?? "", size: 64)
                .padding(.top, 20)
            VStack(spacing: 2) {
                Text(viewModel.profile?.name ?? "")
                    .font(.headline)
                Text(viewModel.profile?.email ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(title: "Upcoming", count: viewModel.upcoming.count, index: 0)
            tabButton(title: "Archive",  count: viewModel.past.count,     index: 1)
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func tabButton(title: String, count: Int, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = index }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(selectedTab == index ? Color.indigo.opacity(0.15) : Color(.systemGray4))
                    .foregroundStyle(selectedTab == index ? Color.indigo : Color(.systemGray))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selectedTab == index ? Color(.systemBackground) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .foregroundStyle(selectedTab == index ? Color.primary : Color.secondary)
            .padding(3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bookings list

    private var bookingsList: some View {
        let items   = selectedTab == 0 ? viewModel.upcoming    : viewModel.past
        let hasMore = selectedTab == 0 ? viewModel.upcomingHasMore : viewModel.pastHasMore
        let isLoadingMore = selectedTab == 0 ? viewModel.upcomingLoading : viewModel.pastLoading

        return Group {
            if items.isEmpty && !isLoadingMore {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(.systemGray3))
                    Text(selectedTab == 0 ? "No upcoming appointments" : "No past appointments")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text(selectedTab == 0 ? "Upcoming" : "Past")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, booking in
                            CallLogRow(booking: booking)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedBooking = booking }
                                .onAppear {
                                    // Trigger next page when last item appears
                                    if index == items.count - 1 {
                                        Task {
                                            if selectedTab == 0 {
                                                await viewModel.loadMoreUpcoming()
                                            } else {
                                                await viewModel.loadMorePast()
                                            }
                                        }
                                    }
                                }
                            if index < items.count - 1 {
                                Divider().padding(.leading, 70)
                            }
                        }
                    }
                    .background(Color(.systemBackground))

                    if isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else if !hasMore && !items.isEmpty {
                        Text("All caught up")
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray3))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Call log row

struct CallLogRow: View {
    let booking: CustomerBooking

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBg)
                    .frame(width: 42, height: 42)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            .padding(.leading, 16)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(booking.displayServiceName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(booking.isUpcoming ? Color.primary : Color.secondary)
                Text(booking.businesses?.name ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Right side: date + status
            VStack(alignment: .trailing, spacing: 3) {
                Text(booking.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                StatusBadge(status: booking.status)
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    private var iconName: String {
        switch booking.status {
        case "cancelled": return "xmark"
        case "no_show":   return "person.slash"
        default:          return "scissors"
        }
    }

    private var iconColor: Color {
        switch booking.status {
        case "confirmed": return .indigo
        case "pending":   return Color(red: 0.85, green: 0.55, blue: 0.0)
        case "cancelled": return Color(red: 0.75, green: 0.20, blue: 0.20)
        default:          return .secondary
        }
    }

    private var iconBg: Color {
        switch booking.status {
        case "confirmed": return Color.indigo.opacity(0.1)
        case "pending":   return Color(red: 0.85, green: 0.55, blue: 0.0).opacity(0.1)
        case "cancelled": return Color(red: 0.75, green: 0.20, blue: 0.20).opacity(0.1)
        default:          return Color(.systemGray5)
        }
    }
}

// MARK: - Status badge

struct StatusBadge: View {
    let status: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(bgColor)
        .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case "confirmed": return "Confirmed"
        case "pending":   return "Pending"
        case "no_show":   return "No show"
        default:          return "Cancelled"
        }
    }

    private var dotColor: Color {
        switch status {
        case "confirmed": return Color(red: 0.13, green: 0.70, blue: 0.40)
        case "pending":   return Color(red: 0.95, green: 0.65, blue: 0.10)
        default:          return Color(red: 0.90, green: 0.27, blue: 0.27)
        }
    }

    private var bgColor: Color {
        switch status {
        case "confirmed": return Color(red: 0.13, green: 0.70, blue: 0.40).opacity(0.12)
        case "pending":   return Color(red: 0.95, green: 0.65, blue: 0.10).opacity(0.12)
        default:          return Color(red: 0.90, green: 0.27, blue: 0.27).opacity(0.12)
        }
    }
}
