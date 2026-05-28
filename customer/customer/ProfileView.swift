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
                            bookingsList
                                .padding(.top, 12)
                        }
                    }
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("My Bookings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        KeychainService.clearAccessToken()
                        isAuthenticated = false
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(item: $selectedBooking) { booking in
            CustomerBookingDetailView(booking: booking)
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
        let items = selectedTab == 0 ? viewModel.upcoming : viewModel.past
        return Group {
            if items.isEmpty {
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
                LazyVStack(spacing: 10) {
                    ForEach(items) { booking in
                        BookingCard(booking: booking)
                            .onTapGesture { selectedBooking = booking }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Helpers

    private func initials(from name: String) -> String {
        let parts = name.components(separatedBy: " ").filter { !$0.isEmpty }
        return String(parts.prefix(2).compactMap { $0.first }).uppercased()
    }
}

// MARK: - Booking card

struct BookingCard: View {
    let booking: CustomerBooking

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Calendar icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "calendar")
                    .font(.system(size: 17))
                    .foregroundStyle(.indigo)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(booking.displayServiceName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            if let dur = booking.totalDurationMinutes {
                                Text("\(dur) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(booking.businesses?.name ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: booking.status)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(booking.formattedDate) · \(booking.formattedTime)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .opacity(booking.isUpcoming ? 1 : 0.75)
    }
}

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
