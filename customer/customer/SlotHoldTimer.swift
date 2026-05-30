import SwiftUI
import Combine
import Foundation

// MARK: - Response model

private struct LockResponse: Decodable {
    let locked: Bool
    let expiresAt: Double?
    let heldUntil: Double?
    let error: String?
    enum CodingKeys: String, CodingKey {
        case locked
        case expiresAt = "expires_at"
        case heldUntil = "held_until"
        case error
    }
}

// MARK: - Slot hold timer

@MainActor
final class SlotHoldTimer: ObservableObject {
    // Own slot countdown (shown in PolicyView / PaymentView / SetupCardView)
    @Published var secondsRemaining: Int = 600
    @Published var isActive = false
    @Published var isExpired = false

    // Lock acquisition loading state
    @Published var isAcquiring = false

    // Conflict state (slot held by another customer)
    @Published var conflictMessage: String? = nil
    @Published var conflictSecondsRemaining: Int = 0

    private var slug: String = ""
    private var date: String = ""
    private var time: String = ""
    private var eventTypeId: String = ""
    private var lockToken: String = ""

    private var countdownTask: Task<Void, Never>?
    private var conflictCountdownTask: Task<Void, Never>?

    // MARK: - Public API

    /// Try to acquire a 10-minute slot hold. Returns true on success; false if held by another customer (conflict state populated).
    func tryAcquire(slug: String, date: String, time: String, eventTypeIds: [String]) async -> Bool {
        release()
        clearConflict()

        lockToken        = UUID().uuidString
        self.slug        = slug
        self.date        = date
        self.time        = time
        self.eventTypeId = eventTypeIds.first ?? ""
        isAcquiring      = true

        let result = await performAcquire()
        isAcquiring = false

        if result.locked {
            secondsRemaining = 600
            isActive  = true
            isExpired = false
            startCountdown()
            return true
        }

        // Conflict — slot held by another customer
        lockToken       = ""
        conflictMessage = result.error
        if let heldUntilMs = result.heldUntil {
            let secsLeft = max(0, Int((heldUntilMs / 1000) - Date().timeIntervalSince1970))
            conflictSecondsRemaining = secsLeft
            if secsLeft > 0 { startConflictCountdown() }
        }
        return false
    }

    /// Release the held slot. Call when the user navigates back without completing a booking.
    func release() {
        stopCountdown()
        let token     = lockToken
        let savedSlug = slug
        let savedDate = date
        let savedTime = time
        lockToken = ""
        isActive  = false
        isExpired = false

        guard !token.isEmpty, !savedSlug.isEmpty else { return }
        Task {
            await performRelease(slug: savedSlug, date: savedDate, time: savedTime, token: token)
        }
    }

    func clearConflict() {
        conflictCountdownTask?.cancel()
        conflictCountdownTask = nil
        conflictMessage = nil
        conflictSecondsRemaining = 0
    }

    // MARK: - Time labels

    var timeLabel: String { formatted(secondsRemaining) }
    var conflictTimeLabel: String { formatted(conflictSecondsRemaining) }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Countdowns

    private func startCountdown() {
        stopCountdown()
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
                guard let self, self.isActive else { return }
                if self.secondsRemaining > 0 { self.secondsRemaining -= 1 }
                if self.secondsRemaining == 0 {
                    self.isExpired = true
                    self.isActive  = false
                    self.stopCountdown()
                }
            }
        }
    }

    private func stopCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func startConflictCountdown() {
        conflictCountdownTask?.cancel()
        conflictCountdownTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
                guard let self, self.conflictSecondsRemaining > 0 else { return }
                self.conflictSecondsRemaining -= 1
            }
        }
    }

    // MARK: - Network

    private func performAcquire() async -> (locked: Bool, error: String?, heldUntil: Double?) {
        guard let url = URL(string: APIClient.baseURL + "/book/\(slug)/slots/lock") else {
            return (true, nil, nil)   // fail open — booking attempt will surface the real error
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "date":          date,
            "start_time":    time,
            "event_type_id": eventTypeId,
            "lock_token":    lockToken
        ])
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse else {
            return (true, nil, nil)   // network error — fail open
        }
        let decoded = try? JSONDecoder().decode(LockResponse.self, from: data)
        if http.statusCode == 409, let d = decoded, !d.locked {
            return (false, d.error, d.heldUntil)
        }
        return (decoded?.locked ?? true, nil, nil)
    }

    private func performRelease(slug: String, date: String, time: String, token: String) async {
        guard let url = URL(string: APIClient.baseURL + "/book/\(slug)/slots/lock") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "date":       date,
            "start_time": time,
            "lock_token": token
        ])
        _ = try? await URLSession.shared.data(for: req)
    }
}

// MARK: - SlotCountdownBanner (shown in PolicyView / PaymentView / SetupCardView)

struct SlotCountdownBanner: View {
    @ObservedObject var holdTimer: SlotHoldTimer

    var body: some View {
        if holdTimer.isExpired {
            expiredBanner
        } else if holdTimer.isActive {
            activeBanner
        }
    }

    private var activeBanner: some View {
        let isUrgent = holdTimer.secondsRemaining < 60
        return HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.caption2)
            Text("Slot held for")
                .font(.caption)
            Text(holdTimer.timeLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
            Spacer()
        }
        .foregroundStyle(isUrgent ? Color.red : Color.indigo)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isUrgent ? Color.red.opacity(0.08) : Color.indigo.opacity(0.08))
        .animation(.easeInOut(duration: 0.3), value: isUrgent)
    }

    private var expiredBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.caption2)
            Text("Slot hold expired — go back and pick a new time.")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(Color.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.08))
    }
}
