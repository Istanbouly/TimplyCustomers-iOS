import SwiftUI
import Combine

struct SlotPickerView: View {
    let destination: SlotPickerDestination
    let onComplete: () -> Void

    @StateObject private var viewModel: SlotPickerViewModel
    @State private var showPolicyView = false
    @State private var showPaymentView = false
    @State private var pendingIsPay = false

    init(destination: SlotPickerDestination, onComplete: @escaping () -> Void) {
        self.destination = destination
        self.onComplete = onComplete
        self._viewModel = StateObject(wrappedValue: SlotPickerViewModel(destination: destination))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date strip
            dateStrip

            Divider()

            // Slots area
            if viewModel.isLoadingSlots {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.slots.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(.systemGray3))
                    Text("No availability on this day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                slotsGrid
            }

            // Sticky confirm button
            if let selected = viewModel.selectedTime {
                confirmBar(time: selected)
            }
        }
        .navigationTitle("Pick a Time")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.generateDates()
            Task { await viewModel.fetchNextAvailable() }
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            Task { await viewModel.fetchSlots() }
        }
        .navigationDestination(isPresented: $viewModel.showConfirmationScreen) {
            BookingConfirmationView(
                serviceName:  viewModel.confirmedServiceName,
                memberName:   destination.memberName,
                businessName: destination.businessName,
                dateStr:      viewModel.confirmedDate,
                timeStr:      viewModel.confirmedTime,
                status:       viewModel.confirmedStatus,
                onComplete:   onComplete
            )
        }
        .navigationDestination(isPresented: $showPolicyView) {
            if let date = viewModel.selectedDate, let time = viewModel.selectedTime {
                PolicyView(
                    destination:  destination,
                    selectedDate: date,
                    selectedTime: time,
                    isPay:        pendingIsPay,
                    onComplete:   onComplete,
                    onBook: { params in
                        await viewModel.confirmBooking(extraParams: params)
                    }
                )
            }
        }
        .navigationDestination(isPresented: $showPaymentView) {
            if let date = viewModel.selectedDate, let time = viewModel.selectedTime {
                PaymentView(
                    memberSlug:      destination.memberSlug,
                    memberName:      destination.memberName,
                    businessName:    destination.businessName,
                    eventTypeIds:    destination.selectedEventTypeIds,
                    eventTypeNames:  destination.selectedEventTypeNames,
                    selectedDate:    date,
                    selectedTime:    time,
                    totalPriceCents: destination.totalPriceCents,
                    policySnapshot:  [:],
                    onComplete:      onComplete
                )
            }
        }
        .alert("Something went wrong", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Please try again.")
        }
    }

    // MARK: - Date strip

    private var dateStrip: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select a date")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    Task { await viewModel.fetchNextAvailable() }
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isLoadingNextAvailable {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.indigo)
                        } else {
                            Image(systemName: "calendar.badge.clock")
                                .font(.caption)
                        }
                        Text("Next available")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.indigo)
                }
                .disabled(viewModel.isLoadingNextAvailable)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.availableDates, id: \.self) { dateStr in
                            DateChip(
                                dateStr: dateStr,
                                isSelected: viewModel.selectedDate == dateStr
                            ) {
                                viewModel.selectedDate = dateStr
                            }
                            .id(dateStr)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onAppear {
                    if let first = viewModel.availableDates.first {
                        proxy.scrollTo(first, anchor: .leading)
                    }
                }
                .onChange(of: viewModel.selectedDate) { _, newVal in
                    if let val = newVal {
                        withAnimation { proxy.scrollTo(val, anchor: .center) }
                    }
                }
            }
        }
    }

    // MARK: - Slots grid

    private var slotsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 10) {
                ForEach(viewModel.slots, id: \.self) { slot in
                    SlotChip(
                        time: slot,
                        isSelected: viewModel.selectedTime == slot
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.selectedTime = slot
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Text("Times shown in \(timezoneAbbreviation)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
                .padding(.bottom, 120)
        }
    }

    private var timezoneAbbreviation: String {
        let tz = TimeZone(identifier: destination.timezone) ?? .current
        return tz.abbreviation(for: Date()) ?? destination.timezone
    }

    // MARK: - Confirm bar

    private var showPayButton: Bool {
        destination.stripeChargesEnabled && destination.totalPriceCents > 0
    }

    private var priceLabel: String {
        String(format: "$%.0f", Double(destination.totalPriceCents) / 100.0)
    }

    private func confirmBar(time: String) -> some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 8) {
                // Summary row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(destination.selectedEventTypeNames.joined(separator: " + "))
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        if let date = viewModel.selectedDate {
                            Text("\(formatDisplayDate(date)) · \(formatTime(time))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                if showPayButton {
                    // Pay Now button
                    Button {
                        pendingIsPay = true
                        if destination.hasPolicies { showPolicyView = true }
                        else { showPaymentView = true }
                    } label: {
                        Text("Pay Now (\(priceLabel))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)

                    if !destination.requireUpfrontPayment {
                        // Pay in Person — secondary option
                        Button {
                            pendingIsPay = false
                            if destination.hasPolicies { showPolicyView = true }
                            else { Task { await viewModel.confirmBooking() } }
                        } label: {
                            Text("Pay in Person")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.indigo)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.indigo.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                } else {
                    // No Stripe — straight booking
                    Button {
                        pendingIsPay = false
                        if destination.hasPolicies { showPolicyView = true }
                        else { Task { await viewModel.confirmBooking() } }
                    } label: {
                        Group {
                            if viewModel.isBooking {
                                ProgressView().tint(.white)
                            } else {
                                Text("Book Appointment")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.indigo)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isBooking)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 12)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Helpers

    private func formatDisplayDate(_ dateStr: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dateStr) else { return dateStr }
        let out = DateFormatter()
        out.dateFormat = "EEE, MMM d"
        return out.string(from: d)
    }

    private func formatTime(_ time: String) -> String {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return time }
        let h = parts[0], m = parts[1]
        let period = h >= 12 ? "PM" : "AM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12):\(String(format: "%02d", m)) \(period)"
    }
}

// MARK: - DateChip

struct DateChip: View {
    let dateStr: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(dayLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .secondary)
                Text(dayNumber)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? .white : Color.primary)
            }
            .frame(width: 44, height: 56)
            .background(isSelected ? Color.indigo : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dateStr) else { return "" }
        let out = DateFormatter()
        out.dateFormat = "EEE"
        return out.string(from: d).uppercased()
    }

    private var dayNumber: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dateStr) else { return "" }
        let out = DateFormatter()
        out.dateFormat = "d"
        return out.string(from: d)
    }
}

// MARK: - SlotChip

struct SlotChip: View {
    let time: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(formattedTime)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.indigo : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Color.indigo : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var formattedTime: String {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return time }
        let h = parts[0], m = parts[1]
        let period = h >= 12 ? "PM" : "AM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12):\(String(format: "%02d", m)) \(period)"
    }
}

// MARK: - ViewModel

@MainActor
class SlotPickerViewModel: ObservableObject {
    let destination: SlotPickerDestination

    @Published var availableDates: [String] = []
    @Published var selectedDate: String? = nil
    @Published var slots: [String] = []
    @Published var selectedTime: String? = nil
    @Published var isLoadingSlots = false
    @Published var isLoadingNextAvailable = false
    @Published var isBooking = false
    @Published var showConfirmationScreen = false
    @Published var confirmedServiceName = ""
    @Published var confirmedDate = ""
    @Published var confirmedTime = ""
    @Published var confirmedStatus = "confirmed"
    @Published var showError = false
    @Published var errorMessage: String? = nil

    init(destination: SlotPickerDestination) {
        self.destination = destination
    }

    func generateDates() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var dates: [String] = []
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        for i in 0..<120 {
            guard let d = cal.date(byAdding: .day, value: i, to: today) else { continue }
            let weekday = cal.component(.weekday, from: d) - 1  // 0=Sun
            if destination.availableDays.contains(weekday) {
                dates.append(fmt.string(from: d))
            }
            if dates.count >= 60 { break }
        }

        availableDates = dates
        // Don't auto-select — fetchNextAvailable sets the initial date
    }

    func fetchNextAvailable() async {
        isLoadingNextAvailable = true
        defer { isLoadingNextAvailable = false }

        let etParam = destination.selectedEventTypeIds.joined(separator: ",")
        guard let url = URL(string: APIClient.baseURL + "/book/\(destination.memberSlug)/next-available?event_type_id=\(etParam)") else { return }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let result = try? JSONDecoder().decode(NextAvailableResponse.self, from: data),
              let date = result.date
        else { return }

        // Ensure the date is in the strip (may be beyond the 60-date window)
        if !availableDates.contains(date) {
            availableDates = (availableDates + [date]).sorted()
        }
        selectedDate = date   // triggers onChange → fetchSlots()
    }

    func fetchSlots() async {
        guard let date = selectedDate else { return }
        isLoadingSlots = true
        selectedTime = nil
        defer { isLoadingSlots = false }

        let etParam = destination.selectedEventTypeIds.joined(separator: ",")
        let path = "/book/\(destination.memberSlug)/slots?date=\(date)&event_type_id=\(etParam)"
        guard let url = URL(string: APIClient.baseURL + path) else { return }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let result = try? JSONDecoder().decode(SlotsResponse.self, from: data)
        else {
            slots = []
            return
        }

        slots = result.slots
    }

    func confirmBooking(extraParams: [String: Any] = [:]) async {
        guard let date = selectedDate,
              let time = selectedTime,
              let token = KeychainService.getAccessToken()
        else { return }

        isBooking = true
        defer { isBooking = false }

        do {
            var body: [String: Any] = [
                "event_type_ids": destination.selectedEventTypeIds,
                "date":           date,
                "start_time":     time,
            ]
            for (key, value) in extraParams { body[key] = value }
            let result: MobileBookingResponse = try await APIClient.post(
                path:  "/customer/book/\(destination.memberSlug)",
                body:  body,
                token: token
            )

            if result.success == true {
                let timeParts = time.split(separator: ":").compactMap { Int($0) }
                let h = timeParts.first ?? 0
                let m = timeParts.count > 1 ? timeParts[1] : 0
                let period = h >= 12 ? "PM" : "AM"
                let h12 = h % 12 == 0 ? 12 : h % 12
                let timeStr = "\(h12):\(String(format: "%02d", m)) \(period)"

                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                var dateStr = date
                if let d = df.date(from: date) {
                    let out = DateFormatter()
                    out.dateFormat = "EEE, MMM d"
                    dateStr = out.string(from: d)
                }

                confirmedServiceName = destination.selectedEventTypeNames.joined(separator: " + ")
                confirmedDate = dateStr
                confirmedTime = timeStr
                confirmedStatus = result.status ?? "confirmed"
                showConfirmationScreen = true
            }
        } catch APIError.serverError(let msg) {
            errorMessage = msg
            showError = true
        } catch {
            errorMessage = "Could not complete booking. Please try again."
            showError = true
        }
    }
}
