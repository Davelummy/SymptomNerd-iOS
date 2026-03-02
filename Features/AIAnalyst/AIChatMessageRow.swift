import SwiftUI
import UIKit

struct AIChatMessageRow: View {
    let message: AIChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.spacingS) {
            if message.role == .assistant {
                aiAvatar
                assistantBubble
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                userBubble
            }
        }
        .padding(.horizontal, Theme.spacingS)
    }

    // MARK: - Bubbles

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.content)
                .font(Typography.body)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.spacingM)
                .padding(.vertical, 10)
                .background(
                    .ultraThinMaterial,
                    in: BubbleShape(tail: .leading)
                )
                .overlay(
                    BubbleShape(tail: .leading)
                        .stroke(Theme.glassStroke, lineWidth: 1)
                )

            Text(message.createdAt.formatted(.dateTime.hour().minute()))
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, Theme.spacingXS)
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = message.content
            }
        }
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .font(Typography.body)
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.spacingM)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Theme.accentDeep, Theme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: BubbleShape(tail: .trailing)
                )
                .overlay(
                    BubbleShape(tail: .trailing)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Theme.accent.opacity(0.25), radius: 6, x: 0, y: 3)

            Text(message.createdAt.formatted(.dateTime.hour().minute()))
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
                .padding(.trailing, Theme.spacingXS)
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = message.content
            }
        }
    }

    // MARK: - AI avatar

    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Theme.accentDeep, Theme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 30)
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Bubble shape with directional tail

private struct BubbleShape: Shape {
    enum Tail { case leading, trailing }
    let tail: Tail
    private let cornerRadius: CGFloat = 16
    private let tailSize: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = cornerRadius
        let t = tailSize
        let w = rect.width
        let h = rect.height

        if tail == .leading {
            // Main rounded rect shifted right to make room for tail
            let inner = CGRect(x: t, y: 0, width: w - t, height: h)
            path.addRoundedRect(in: inner, cornerSize: CGSize(width: r, height: r))
            // Tail on left at bottom
            path.move(to: CGPoint(x: t, y: h - r - t))
            path.addLine(to: CGPoint(x: 0, y: h - r))
            path.addLine(to: CGPoint(x: t, y: h - r + 2))
        } else {
            // Main rounded rect
            let inner = CGRect(x: 0, y: 0, width: w - t, height: h)
            path.addRoundedRect(in: inner, cornerSize: CGSize(width: r, height: r))
            // Tail on right at bottom
            path.move(to: CGPoint(x: w - t, y: h - r - t))
            path.addLine(to: CGPoint(x: w, y: h - r))
            path.addLine(to: CGPoint(x: w - t, y: h - r + 2))
        }

        return path
    }
}

#Preview {
    VStack(spacing: Theme.spacingM) {
        AIChatMessageRow(message: AIChatMessage(
            id: .init(), role: .assistant,
            content: "Based on your logs, I can see a pattern of headaches appearing after poor sleep nights.",
            createdAt: Date()
        ))
        AIChatMessageRow(message: AIChatMessage(
            id: .init(), role: .user,
            content: "What might be causing my symptoms?",
            createdAt: Date()
        ))
    }
    .padding()
}
