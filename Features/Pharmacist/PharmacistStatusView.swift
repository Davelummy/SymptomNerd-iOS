import SwiftUI

struct PharmacistStatusView: View {
    let statusText: String
    let queuePosition: Int?

    var body: some View {
        HStack(spacing: Theme.spacingS) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
            if let queuePosition {
                Text("• Queue \(queuePosition)")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

#Preview {
    PharmacistStatusView(statusText: "Typically replies in 10-15 minutes", queuePosition: 2)
        .padding()
}
