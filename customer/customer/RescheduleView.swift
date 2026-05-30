import SwiftUI
import Combine

struct RescheduleView: View {
    let bookingId: String
    let memberSlug: String
    let eventTypeIds: [String]
    let totalDurationMinutes: Int
    let serviceName: String
    let onRescheduled: () -> Void

    @StateObject private var vm = RescheduleViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showMonthPicker = false
    @State private var pickerMonth = Calendar.current.component(.month, from: Date())
    @State private var pickerYear  = Calendar.current.component(.year,  from: Date())
    @State private var noDatesBanner = false

    var body: some View {
        VStack(spacing: 0) {
            dateStrip
            Divider()

            if vm.isLoadingSlots {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.slots.isEmpty && vm.selectedDate != nil {
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

            if let selected = vm.selectedTime {
                confirmBar(time: selected)
            }
        }
        .navigationTitle("Reschedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            vm.setup(memberSlug: memberSlug, eventTypeIds: eventTypeIds)
            Task { await vm.fetchNextAvailable() }
        }
        .onChange(of: vm.selectedDate) { _, _ in
            Task { await vm.fetchSlots() }
        }
        .alert("Error", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Please try again.")
        }
        .sheet(isPresented: $showMonthPicker) {
            monthPickerSheet
        }
    }

    // MARK: - Month/year picker sheet

    private var monthPickerSheet: some View {
        let months = (1...12).map { DateFormatter().monthSymbols[$0 - 1] }
        let currentYear = Calendar.current.component(.year, from: Date())
        let years = Array(currentYear...(currentYear + 2))

        return NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Picker("Month", selection: $pickerMonth) {
                        ForEach(1...12, id: \.self) { m in
                            Text(months[m - 1]).tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("Year", selection: $pickerYear) {
                        ForEach(years, id: \.self) { y in
                            Text(String(y)).tag(y)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }

                if noDatesBanner {
                    Text("No available dates in \(months[pickerMonth - 1]) \(pickerYear)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }

                Button {
                    jumpToMonth()
                } label: {
                    Text("Jump to \(months[pickerMonth - 1]) \(pickerYear)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.indigo)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Jump to Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showMonthPicker = false }
                }
            }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }

    private func jumpToMonth() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        let cal = Calendar.current

        let match = vm.availableDates.first { dateStr in
            guard let d = df.date(from: dateStr) else { return false }
            return cal.component(.month, from: d) == pickerMonth &&
                   cal.component(.year,  from: d) == pickerYear
        }

        if let match {
            vm.selectedDate = match   // triggers scroll via existing onChange
            showMonthPicker = false
        } else {
            noDatesBanner = true
        }
    }

    // MARK: - Helpers

    private var selectedMonthYearLabel: String {
        guard let dateStr = vm.selectedDate else {
            let df = DateFormatter()
            df.dateFormat = "MMMM yyyy"
            return df.string(from: Date())
        }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        guard let d = df.date(from: dateStr) else { return "" }
        let out = DateFormatter()
        out.dateFormat = "MMMM yyyy"
        return out.string(from: d)
    }

    // MARK: - Date strip

    private var dateStrip: some View {
        VStack(spacing: 0) {
            // Row 1 — title + next available
            HStack {
                Text("Pick a new date")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    Task { await vm.fetchNextAvailable() }
                } label: {
                    HStack(spacing: 4) {
                        if vm.isLoadingNextAvailable {
                            ProgressView().scaleEffect(0.7).tint(.indigo)
                        } else {
                            Image(systemName: "calendar.badge.clock").font(.caption)
                        }
                        Text("Next available")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.indigo)
                }
                .disabled(vm.isLoadingNextAvailable)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Row 2 — month/year jump picker
            Button {
                // Seed picker with the currently selected date before showing
                if let current = vm.selectedDate {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd"
                    df.locale = Locale(identifier: "en_US_POSIX")
                    if let d = df.date(from: current) {
                        pickerMonth = Calendar.current.component(.month, from: d)
                        pickerYear  = Calendar.current.component(.year,  from: d)
                    }
                }
                noDatesBanner = false
                showMonthPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(selectedMonthYearLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.availableDates, id: \.self) { dateStr in
                            DateChip(
                                dateStr: dateStr,
                                isSelected: vm.selectedDate == dateStr
                            ) {
                                vm.selectedDate = dateStr
                            }
                            .id(dateStr)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onAppear {
                    if let first = vm.availableDates.first {
                        proxy.scrollTo(first, anchor: .leading)
                    }
                }
                .onChange(of: vm.selectedDate) { _, newVal in
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
                ForEach(vm.slots, id: \.self) { slot in
                    SlotChip(time: slot, isSelected: vm.selectedTime == slot) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            vm.selectedTime = slot
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Confirm bar

    private func confirmBar(time: String) -> some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(serviceName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        if let date = vm.selectedDate {
                            Text("\(formatDisplayDate(date)) · \(formatTime(time))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Button {
                    Task {
                        await vm.confirmReschedule(
                            bookingId: bookingId,
                            durationMinutes: totalDurationMinutes,
                            onRescheduled: onRescheduled,
                            dismiss: { dismiss() }
                        )
                    }
                } label: {
                    Group {
                        if vm.isRescheduling {
                            ProgressView().tint(.white)
                        } else {
                            Text("Confirm Reschedule")
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
                .disabled(vm.isRescheduling)
                .padding(.horizontal, 16)
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
        guard parts.count >= 2 else { return time }
        let h = parts[0], m = parts[1]
        let period = h >= 12 ? "PM" : "AM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12):\(String(format: "%02d", m)) \(period)"
    }
}

// MARK: - ViewModel

@MainActor
final class RescheduleViewModel: ObservableObject {
    private var memberSlug = ""
    private var eventTypeIds: [String] = []

    @Published var availableDates: [String] = []
    @Published var selectedDate: String? = nil
    @Published var slots: [String] = []
    @Published var selectedTime: String? = nil
    @Published var isLoadingSlots = false
    @Published var isLoadingNextAvailable = false
    @Published var isRescheduling = false
    @Published var showError = false
    @Published var errorMessage: String? = nil

    func setup(memberSlug: String, eventTypeIds: [String]) {
        self.memberSlug = memberSlug
        self.eventTypeIds = eventTypeIds
        generateDates()
    }

    private func generateDates() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var dates: [String] = []
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")

        // Generate 1 year from tomorrow so jump-to-month works for any future date
        for i in 1...365 {
            guard let d = cal.date(byAdding: .day, value: i, to: today) else { continue }
            dates.append(fmt.string(from: d))
        }

        availableDates = dates
        // Don't auto-select — fetchNextAvailable sets the initial date
    }

    func fetchNextAvailable() async {
        guard !memberSlug.isEmpty else { return }
        isLoadingNextAvailable = true
        defer { isLoadingNextAvailable = false }

        let etParam = eventTypeIds.joined(separator: ",")
        guard let url = URL(string: APIClient.baseURL + "/book/\(memberSlug)/next-available?event_type_id=\(etParam)") else { return }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let result = try? JSONDecoder().decode(NextAvailableResponse.self, from: data),
              let date = result.date
        else { return }

        if !availableDates.contains(date) {
            availableDates = (availableDates + [date]).sorted()
        }
        selectedDate = date   // triggers onChange → fetchSlots()
    }

    func fetchSlots() async {
        guard let date = selectedDate, !memberSlug.isEmpty else { return }
        isLoadingSlots = true
        selectedTime = nil
        defer { isLoadingSlots = false }

        let etParam = eventTypeIds.joined(separator: ",")
        let path = "/book/\(memberSlug)/slots?date=\(date)&event_type_id=\(etParam)"
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

    func confirmReschedule(
        bookingId: String,
        durationMinutes: Int,
        onRescheduled: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) async {
        guard let date = selectedDate,
              let time = selectedTime,
              let token = KeychainService.getAccessToken()
        else { return }

        isRescheduling = true
        defer { isRescheduling = false }

        let endTime = computeEndTime(startTime: time, durationMinutes: durationMinutes)

        do {
            let _: RescheduleResponse = try await APIClient.patch(
                path: "/customer/bookings/\(bookingId)",
                body: ["date": date, "start_time": time, "end_time": endTime],
                token: token
            )
            onRescheduled()
            dismiss()
        } catch APIError.serverError(let msg) {
            errorMessage = msg
            showError = true
        } catch {
            errorMessage = "Could not reschedule. Please try again."
            showError = true
        }
    }

    private func computeEndTime(startTime: String, durationMinutes: Int) -> String {
        let parts = startTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return startTime }
        let totalMinutes = parts[0] * 60 + parts[1] + durationMinutes
        let h = (totalMinutes / 60) % 24
        let m = totalMinutes % 60
        return String(format: "%02d:%02d:00", h, m)
    }
}

// MARK: - Response model

struct RescheduleResponse: Decodable {
    struct BookingData: Decodable { let id: String }
    let booking: BookingData?
}
