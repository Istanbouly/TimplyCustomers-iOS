import SwiftUI
import Combine

struct ServicesView: View {
    let destination: ServicesDestination
    @StateObject private var viewModel = ServicesViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let page = viewModel.page {
                servicesList(page: page)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(.systemGray3))
                    Text(viewModel.loadError ?? "Could not load services.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Select Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await viewModel.load(slug: destination.memberSlug) }
    }

    // MARK: - Services list

    private func servicesList(page: BookPageResponse) -> some View {
        let allowMulti  = page.allowMultiService
        let maxServices = page.maxServicesPerBooking

        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Member header
                    HStack(spacing: 12) {
                        AvatarView(url: destination.memberAvatarUrl, name: destination.memberName, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(destination.memberName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(destination.businessName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    if allowMulti {
                        Text("Select up to \(maxServices) service\(maxServices == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                    }

                    VStack(spacing: 8) {
                        ForEach(page.eventTypes) { et in
                            EventTypeRow(
                                eventType: et,
                                isSelected: viewModel.selectedIds.contains(et.id),
                                allowMulti: allowMulti
                            ) {
                                viewModel.toggle(id: et.id, allowMulti: allowMulti, max: maxServices)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 80)
                }
            }

            // Sticky bottom bar
            VStack(spacing: 0) {
                Divider()
                if let validationErr = viewModel.validationError {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.90, green: 0.27, blue: 0.27))
                        Text(validationErr)
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.90, green: 0.27, blue: 0.27))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                continueLink(page: page)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
            .background(Color(.systemBackground))
        }
    }

    @ViewBuilder
    private func continueLink(page: BookPageResponse) -> some View {
        let selected = page.eventTypes.filter { viewModel.selectedIds.contains($0.id) }
        let total    = selected.reduce(0) { $0 + $1.durationMinutes }

        if viewModel.selectedIds.isEmpty || viewModel.validationError != nil {
            Button {} label: {
                Text("Continue")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray4))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(true)
        } else {
            let totalPriceCents = selected.compactMap { $0.priceCents }.reduce(0, +)
            let dest = SlotPickerDestination(
                memberSlug:                  destination.memberSlug,
                memberName:                  destination.memberName,
                businessName:                destination.businessName,
                selectedEventTypeIds:        selected.map(\.id),
                selectedEventTypeNames:      selected.map(\.name),
                totalDurationMinutes:        total,
                availableDays:               page.availableDays,
                timezone:                    page.timezone,
                stripeChargesEnabled:        page.stripeChargesEnabled,
                requireUpfrontPayment:       page.requireUpfrontPayment,
                totalPriceCents:             totalPriceCents,
                cancellationPolicyEnabled:   page.cancellationPolicyEnabled,
                cancellationPolicyHours:     page.cancellationPolicyHours,
                cancellationFeeType:         page.cancellationFeeType,
                cancellationFeeAmount:       page.cancellationFeeAmount,
                noShowPolicyEnabled:         page.noShowPolicyEnabled,
                noShowFeeType:               page.noShowFeeType,
                noShowFeeAmount:             page.noShowFeeAmount,
                refundPolicy:                page.refundPolicy
            )
            NavigationLink(value: dest) {
                HStack(spacing: 6) {
                    Text("Continue")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("· \(formatDuration(total))")
                        .font(.subheadline)
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m) min"
    }
}

// MARK: - EventType row

struct EventTypeRow: View {
    let eventType: EventType
    let isSelected: Bool
    let allowMulti: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(eventType.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.primary)

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(eventType.durationLabel)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)

                        if let price = eventType.priceLabel {
                            Text("·")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            Text(price)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.indigo)
                        }
                    }

                    if let desc = eventType.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Checkbox (multi) or radio (single)
                if allowMulti {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isSelected ? Color.indigo : Color(.systemGray4), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.indigo)
                        }
                    }
                } else {
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

// MARK: - ViewModel

@MainActor
class ServicesViewModel: ObservableObject {
    @Published var page: BookPageResponse? = nil
    @Published var isLoading = true
    @Published var loadError: String? = nil
    @Published var selectedIds: Set<String> = []
    @Published var validationError: String? = nil

    func load(slug: String) async {
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: APIClient.baseURL + "/book/\(slug)") else { return }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let result = try? JSONDecoder().decode(BookPageResponse.self, from: data)
        else {
            loadError = "Could not load services. Please try again."
            return
        }
        page = result
    }

    func toggle(id: String, allowMulti: Bool, max: Int) {
        guard let page = page else { return }

        if allowMulti {
            var newIds = selectedIds
            if newIds.contains(id) {
                newIds.remove(id)
            } else if newIds.count < max {
                newIds.insert(id)
            }

            // Check total duration against max working minutes
            let total = page.eventTypes
                .filter { newIds.contains($0.id) }
                .reduce(0) { $0 + $1.durationMinutes }

            if page.maxWorkingMinutes > 0 && total > page.maxWorkingMinutes {
                let hours = page.maxWorkingMinutes / 60
                let mins  = page.maxWorkingMinutes % 60
                let limitStr = mins > 0 ? "\(hours)h \(mins)min" : "\(hours)h"
                let totalH = total / 60
                let totalM = total % 60
                let totalStr = totalM > 0 ? "\(totalH)h \(totalM)min" : "\(totalH)h"
                validationError = "The selected services total \(totalStr) which exceeds the maximum working hours for this business (\(limitStr)). Please remove a service to continue."
            } else {
                validationError = nil
            }

            selectedIds = newIds
        } else {
            selectedIds = [id]
            validationError = nil
        }
    }
}
