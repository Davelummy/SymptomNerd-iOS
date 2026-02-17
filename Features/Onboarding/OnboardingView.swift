import SwiftUI
import UIKit

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var selection = 0
    @Environment(\.colorScheme) private var colorScheme

    private let pages: [OnboardingContent] = [
        OnboardingContent(
            title: "Log what you feel",
            message: "Capture symptoms quickly with context that matters each day.",
            imageName: "onboarding-1",
            iconName: "pencil.and.list.clipboard",
            iconTint: Theme.accent
        ),
        OnboardingContent(
            title: "See patterns clearly",
            message: "AI and charts reveal trends across symptom timing and triggers.",
            imageName: "onboarding-2",
            iconName: "chart.line.uptrend.xyaxis",
            iconTint: Theme.accentSecondary
        ),
        OnboardingContent(
            title: "Escalate to care quickly",
            message: "Move from AI insights to pharmacist chat or live call when needed.",
            imageName: "onboarding-3",
            iconName: "phone.fill",
            iconTint: Theme.accentDeep
        )
    ]

    var body: some View {
        GeometryReader { proxy in
            let isPad = UIDevice.current.userInterfaceIdiom == .pad || proxy.size.width >= 700
            let horizontalPadding: CGFloat = isPad ? 52 : 20
            let contentWidth = max(280, proxy.size.width - horizontalPadding * 2)
            let imageHeight = isPad ? min(420, max(280, proxy.size.height * 0.4)) : min(280, max(200, proxy.size.height * 0.3))
            let pageHeight = isPad ? min(740, max(520, proxy.size.height * 0.68)) : min(560, max(430, proxy.size.height * 0.6))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Theme.spacingM) {
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("Symptom Nerd")
                            .font(Typography.title)
                            .foregroundStyle(headerTitleColor)
                        Text("Track. Notice patterns. Share with care.")
                            .font(Typography.body)
                            .foregroundStyle(headerSubtitleColor)
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.top, proxy.safeAreaInsets.top + Theme.spacingXS)

                    TabView(selection: $selection) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            OnboardingPage(content: page, imageHeight: imageHeight)
                                .frame(width: contentWidth, height: pageHeight, alignment: .top)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(width: contentWidth, height: pageHeight, alignment: .top)

                    HStack(spacing: Theme.spacingS) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == selection ? Theme.accent : Theme.textSecondary.opacity(0.35))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .frame(width: contentWidth, alignment: .center)

                    Button {
                        if selection < pages.count - 1 {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selection += 1
                            }
                        } else {
                            onComplete()
                        }
                    } label: {
                        HStack(spacing: Theme.spacingS) {
                            Text(selection < pages.count - 1 ? "Continue" : "Get Started")
                                .font(Typography.headline)
                            Image(systemName: selection < pages.count - 1 ? "arrow.right" : "checkmark")
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, Theme.spacingL)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.accent, Theme.accentDeep],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.24 : 0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Theme.spacingXS)

                    Text("You can update permissions any time in Settings.")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(width: contentWidth)
                        .padding(.bottom, max(Theme.spacingS, proxy.safeAreaInsets.bottom))
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var headerTitleColor: Color {
        Color(red: 0.06, green: 0.09, blue: 0.16)
    }

    private var headerSubtitleColor: Color {
        Color(red: 0.20, green: 0.28, blue: 0.36).opacity(0.82)
    }
}

private struct OnboardingContent {
    let title: String
    let message: String
    let imageName: String
    let iconName: String
    let iconTint: Color
}

private struct OnboardingPage: View {
    let content: OnboardingContent
    let imageHeight: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: Theme.spacingM) {
            ZStack(alignment: .topLeading) {
                onboardingImage
                    .frame(maxWidth: .infinity, minHeight: imageHeight, maxHeight: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))

                Image(systemName: content.iconName)
                    .font(.title3)
                    .foregroundStyle(content.iconTint)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(Theme.spacingM)
            }
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08), lineWidth: 1)
            )

            VStack(spacing: Theme.spacingXS) {
                Text(content.title)
                    .font(Typography.title2)
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
            .padding(.horizontal, Theme.spacingM)
            .padding(.vertical, Theme.spacingS)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))

            VStack(spacing: Theme.spacingXS) {
                Text(content.message)
                    .font(Typography.body)
                    .foregroundStyle(messageColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .center)
            .padding(.horizontal, Theme.spacingM)
            .padding(.vertical, Theme.spacingS)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.07), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        }
    }

    @ViewBuilder
    private var onboardingImage: some View {
        if UIImage(named: content.imageName) != nil {
            Image(content.imageName)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [Theme.accentSoft, Theme.accentSecondary.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
            .fill(colorScheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.68))
    }

    private var titleColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.96)
            : Color(red: 0.08, green: 0.10, blue: 0.15)
    }

    private var messageColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.9)
            : Color(red: 0.16, green: 0.20, blue: 0.26).opacity(0.95)
    }
}

#Preview {
    OnboardingView { }
}
