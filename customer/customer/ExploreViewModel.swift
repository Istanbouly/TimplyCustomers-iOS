import Foundation
import Combine

class ExploreViewModel: ObservableObject {
    @Published var businesses: [BusinessItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var searchText = ""
    @Published var hasMore = false

    private var page = 1
    private var cancellables = Set<AnyCancellable>()

    init() {
        $searchText
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { await self?.loadFirst() }
            }
            .store(in: &cancellables)
    }

    func loadFirst() async {
        let firstLoad = await MainActor.run { businesses.isEmpty }
        // Only show full-screen spinner on first load — pull-to-refresh refreshes in place
        if firstLoad { await MainActor.run { isLoading = true } }
        await fetch(page: 1, append: false)
        await MainActor.run { isLoading = false; page = 1 }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        await MainActor.run { isLoadingMore = true }
        await fetch(page: page + 1, append: true)
        await MainActor.run { isLoadingMore = false }
    }

    private func fetch(page: Int, append: Bool) async {
        var path = "/businesses?page=\(page)&limit=20"
        let q = searchText.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty, let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "&search=\(enc)"
        }

        guard let url = URL(string: APIClient.baseURL + path) else { return }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let result = try? JSONDecoder().decode(BusinessListResponse.self, from: data)
        else { return }

        await MainActor.run {
            if append {
                self.businesses.append(contentsOf: result.businesses)
            } else {
                self.businesses = result.businesses
            }
            self.hasMore = result.hasMore
            self.page = page
        }
    }
}

class BusinessDetailViewModel: ObservableObject {
    @Published var team: TeamResponse? = nil
    @Published var isLoading = true
    @Published var selectedMemberId: String? = nil

    func load(slug: String) async {
        await MainActor.run { isLoading = true }
        guard let url = URL(string: APIClient.baseURL + "/businesses/\(slug)/team"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let result = try? JSONDecoder().decode(TeamResponse.self, from: data)
        else {
            await MainActor.run { isLoading = false }
            return
        }
        await MainActor.run {
            team = result
            // Pre-select owner if they're the only option
            if result.staff.isEmpty {
                selectedMemberId = result.owner.id
            }
            isLoading = false
        }
    }
}
