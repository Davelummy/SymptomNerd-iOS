import SwiftUI

struct TypingIndicatorView: View {
    @State private var scale: CGFloat = 0.6

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .frame(width: 8, height: 8)
            Circle()
                .frame(width: 8, height: 8)
            Circle()
                .frame(width: 8, height: 8)
        }
        .foregroundStyle(Theme.textSecondary)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                scale = 1.0
            }
        }
    }
}

#Preview {
    TypingIndicatorView()
        .padding()
}
