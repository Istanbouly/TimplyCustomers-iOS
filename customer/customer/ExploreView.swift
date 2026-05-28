import SwiftUI

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.businesses.isEmpty {
                    emptyState
                } else {
                    businessList
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search businesses")
            .navigationDestination(for: BusinessItem.self) { biz in
                BusinessDetailView(business: biz)
            }
            .navigationDestination(for: ServicesDestination.self) { dest in
                ServicesView(destination: dest)
            }
            .navigationDestination(for: SlotPickerDestination.self) { dest in
                SlotPickerView(destination: dest, onComplete: { path = NavigationPath() })
            }
        }
        .task { await viewModel.loadFirst() }
    }

    // MARK: - Business list

    private var businessList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.businesses) { biz in
                    BusinessCard(business: biz)
                        .onTapGesture { path.append(biz) }
                        .onAppear {
                            if biz.id == viewModel.businesses.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .refreshable { await viewModel.loadFirst() }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(.systemGray3))
                Text(viewModel.searchText.isEmpty ? "No businesses yet" : "No results for \"\(viewModel.searchText)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 120)
        }
        .refreshable { await viewModel.loadFirst() }
    }
}

// MARK: - Business card

struct BusinessCard: View {
    let business: BusinessItem

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(url: business.ownerAvatar, name: business.businessName, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(business.businessName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if let address = business.address, !address.isEmpty {
                    Label(address, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let rating = business.avgRating, rating > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(red: 0.95, green: 0.65, blue: 0.10))
                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                            .fontWeight(.medium)
                        if let count = business.reviewCount, count > 0 {
                            Text("(\(count))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color(.systemGray3))
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
    }
}

// MARK: - Reusable avatar (with memory cache to prevent flicker on refresh)

struct AvatarView: View {
    let url: String?
    let name: String
    let size: CGFloat

    @State private var image: UIImage? = nil

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.indigo.opacity(0.12))
                .frame(width: size, height: size)

            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(initials)
                    .font(.system(size: size * 0.33, weight: .semibold))
                    .foregroundStyle(.indigo)
            }
        }
        .task(id: url) { await loadImage() }
    }

    private func loadImage() async {
        guard let urlStr = url, let u = URL(string: urlStr) else { return }
        if let cached = ImageCache.shared.get(u) {
            await MainActor.run { image = cached }
            return
        }
        guard let (data, _) = try? await URLSession.shared.data(from: u),
              let loaded = UIImage(data: data)
        else { return }
        ImageCache.shared.set(u, image: loaded)
        await MainActor.run { image = loaded }
    }

    private var initials: String {
        let parts = name.components(separatedBy: " ").filter { !$0.isEmpty }
        return String(parts.prefix(2).compactMap { $0.first }).uppercased()
    }
}
