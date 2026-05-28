import SwiftUI

struct BookingConfirmationView: View {
    let serviceName: String
    let memberName: String
    let businessName: String
    let dateStr: String
    let timeStr: String
    let status: String        // "confirmed" or "pending"
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(isConfirmed ? Color.indigo.opacity(0.1) : Color(red: 0.95, green: 0.65, blue: 0.10).opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: isConfirmed ? "checkmark.circle.fill" : "clock.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(isConfirmed ? Color.indigo : Color(red: 0.95, green: 0.65, blue: 0.10))
            }
            .padding(.bottom, 24)

            // Title
            Text(isConfirmed ? "Booking Confirmed!" : "Booking Pending")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 8)

            Text(isConfirmed
                 ? "Your appointment has been booked successfully."
                 : "Your request has been sent and is awaiting confirmation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 36)

            // Details card
            VStack(spacing: 0) {
                detailRow(icon: "scissors", label: serviceName)
                Divider().padding(.leading, 44)
                detailRow(icon: "person", label: memberName, sub: businessName)
                Divider().padding(.leading, 44)
                detailRow(icon: "calendar", label: dateStr)
                Divider().padding(.leading, 44)
                detailRow(icon: "clock", label: timeStr)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
            .padding(.horizontal, 20)

            Spacer()

            // Done button
            Button(action: onComplete) {
                Text("Done")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
    }

    private var isConfirmed: Bool { status == "confirmed" }

    private func detailRow(icon: String, label: String, sub: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.indigo)
                .frame(width: 20)
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let sub = sub {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 14)
    }
}
