import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = HomeViewModel()
    @State private var showLogFlow = false
    @State private var galleryIndex = 0
    private let galleryTimer = Timer.publish(every: 3.2, on: .main, in: .common).autoconnect()
    private var twoColumnGrid: [GridItem] {
        [
            GridItem(.flexible(), spacing: Theme.spacingS, alignment: .top),
            GridItem(.flexible(), spacing: Theme.spacingS, alignment: .top)
        ]
    }

    private let galleryItems: [GalleryItem] = [
        GalleryItem(
            title: "Daily log streak",
            subtitle: "Consistent symptom logging helps your care team see trends sooner.",
            imageName: "progress-1",
            tint: Theme.accent,
            ctaTitle: "Log now"
        ),
        GalleryItem(
            title: "Pattern tracking",
            subtitle: "Compare triggers, timing, and severity across recent entries.",
            imageName: "progress-2",
            tint: Theme.accentSecondary,
            ctaTitle: "See insights"
        ),
        GalleryItem(
            title: "Clinic-ready summary",
            subtitle: "Generate a concise report before your next appointment.",
            imageName: "progress-3",
            tint: Theme.accentDeep,
            ctaTitle: "Prepare export"
        )
    ]

    private var isPadLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || horizontalSizeClass == .regular
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                heroCard
                summaryStrip
                galleryStrip
                ctaRow
                servicesCarousel
                quickActions
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showLogFlow = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Theme.accent, Theme.accentSecondary)
                }
            }
        }
        .task {
            viewModel.configure(client: SwiftDataStore(context: modelContext))
            await viewModel.load()
        }
        .onReceive(galleryTimer) { _ in
            guard !galleryItems.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.6)) {
                galleryIndex = (galleryIndex + 1) % galleryItems.count
            }
        }
        .sheet(isPresented: $showLogFlow) {
            LogSymptomFlowView {
                Task { await viewModel.load() }
            }
        }
    }

    private func quickActionLabel(title: String, systemImage: String) -> some View {
        VStack(spacing: Theme.spacingXS) {
            Image(systemName: systemImage)
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Theme.accent, Theme.accentSecondary)
            Text(title)
                .font(Typography.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacingS)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .stroke(Theme.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
        .foregroundStyle(Theme.accentDeep)
    }

    private var heroCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                Text("Hello \(authManager.displayName.isEmpty ? "there" : authManager.displayName)")
                    .font(Typography.title2)
                Text("Your personal symptom dashboard.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: Theme.spacingS) {
                    Button {
                        showLogFlow = true
                    } label: {
                        HStack(spacing: Theme.spacingS) {
                            Image(systemName: "plus.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.white, Theme.accentSecondary)
                            Text("Log Symptom")
                                .font(Typography.headline)
                                .foregroundStyle(Color.white)
                        }
                        .padding(.horizontal, Theme.spacingM)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [Theme.accent, Theme.accentDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var summaryStrip: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                Text("Today summary")
                    .font(Typography.headline)
                if let last = viewModel.lastEntry {
                    Text("Last: \(last.symptomType.name) • \(last.severity)/10")
                        .font(Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("No symptoms logged yet.")
                        .font(Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                }
                HStack(spacing: Theme.spacingS) {
                    ChipView(title: String(format: "Avg %.1f/10", viewModel.averageSeverity))
                    ChipView(title: "Streak \(viewModel.streakDays)")
                    ChipView(title: "Logs \(viewModel.entries.count)")
                }
            }
        }
    }

    private var ctaRow: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Text("Get insights")
                .font(Typography.headline)
            LazyVGrid(columns: twoColumnGrid, spacing: Theme.spacingS) {
                NavigationLink {
                    AIChatView()
                } label: {
                    ctaCard(
                        title: "Ask Symptom Nerd AI",
                        subtitle: "Pattern-based guidance",
                        systemImage: "sparkles",
                        tint: Theme.accent
                    )
                }

                NavigationLink {
                    AIInsightsView()
                } label: {
                    ctaCard(
                        title: "Analyze last 7 days",
                        subtitle: "Trends and correlations",
                        systemImage: "chart.line.uptrend.xyaxis",
                        tint: Theme.accentSecondary
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var galleryStrip: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Text("Your progress gallery")
                .font(Typography.headline)
            GeometryReader { proxy in
                let cardHeight: CGFloat = isPadLayout ? 320 : 230
                let horizontalInset: CGFloat = isPadLayout ? 56 : 0
                let cardWidth = max(0, proxy.size.width - horizontalInset)
                TabView(selection: $galleryIndex) {
                    ForEach(Array(galleryItems.enumerated()), id: \.offset) { index, item in
                        photoCard(
                            title: item.title,
                            subtitle: item.subtitle,
                            imageName: item.imageName,
                            tint: item.tint,
                            ctaTitle: item.ctaTitle,
                            height: cardHeight
                        )
                        .frame(width: cardWidth, height: cardHeight)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, horizontalInset / 2)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            .frame(height: isPadLayout ? 332 : 236)
        }
    }

    private var servicesCarousel: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Text("Services")
                .font(Typography.headline)
            if isPadLayout {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: Theme.spacingS),
                    GridItem(.flexible(), spacing: Theme.spacingS),
                    GridItem(.flexible(), spacing: Theme.spacingS)
                ], spacing: Theme.spacingS) {
                    NavigationLink { PharmacistEntryView() } label: {
                        serviceCard(title: "Pharmacist", subtitle: "Chat or call", systemImage: "cross.case.fill", tint: Theme.accentDeep, fixedWidth: nil)
                    }
                    NavigationLink { KnowledgeBaseView() } label: {
                        serviceCard(title: "Learn", subtitle: "How to track well", systemImage: "book.fill", tint: Theme.accentSecondary, fixedWidth: nil)
                    }
                    NavigationLink { ExportView() } label: {
                        serviceCard(title: "Export", subtitle: "Doctor-ready PDF", systemImage: "square.and.arrow.up", tint: Theme.accentDeep, fixedWidth: nil)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.spacingS) {
                        NavigationLink { PharmacistEntryView() } label: {
                            serviceCard(title: "Pharmacist", subtitle: "Chat or call", systemImage: "cross.case.fill", tint: Theme.accentDeep, fixedWidth: 170)
                        }
                        NavigationLink { KnowledgeBaseView() } label: {
                            serviceCard(title: "Learn", subtitle: "How to track well", systemImage: "book.fill", tint: Theme.accentSecondary, fixedWidth: 170)
                        }
                        NavigationLink { ExportView() } label: {
                            serviceCard(title: "Export", subtitle: "Doctor-ready PDF", systemImage: "square.and.arrow.up", tint: Theme.accentDeep, fixedWidth: 170)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var quickActions: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                Text("Quick actions")
                    .font(Typography.headline)
                HStack(spacing: Theme.spacingS) {
                    NavigationLink {
                        TimelineView()
                    } label: {
                        quickActionLabel(title: "Timeline", systemImage: "calendar")
                    }

                    NavigationLink {
                        ExportView()
                    } label: {
                        quickActionLabel(title: "Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private func ctaCard(title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            Image(systemName: systemImage)
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(tint, Theme.accentSoft)
            Text(title)
                .font(Typography.headline)
                .lineLimit(2)
            Text(subtitle)
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .padding(Theme.spacingM)
        .background(.ultraThinMaterial)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .fill(Theme.glassFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .stroke(Theme.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        .shadow(color: Theme.cardShadow, radius: 18, x: 0, y: 10)
    }

    private func serviceCard(title: String, subtitle: String, systemImage: String, tint: Color, fixedWidth: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            Image(systemName: systemImage)
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(tint, Theme.accentSoft)
            Text(title)
                .font(Typography.headline)
            Text(subtitle)
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: fixedWidth == nil ? .infinity : fixedWidth, alignment: .leading)
        .frame(minHeight: 126, alignment: .topLeading)
        .padding(Theme.spacingM)
        .background(.ultraThinMaterial)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .fill(Theme.glassFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .stroke(Theme.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        .shadow(color: Theme.cardShadow, radius: 18, x: 0, y: 10)
    }

    private func photoCard(title: String, subtitle: String, imageName: String, tint: Color, ctaTitle: String, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            localGalleryFallback(imageName: imageName, tint: tint)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.62)
                ],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: Theme.spacingS) {
                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    Text(title)
                        .font(Typography.headline)
                        .foregroundStyle(Color.white)
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(Color.white.opacity(0.9))
                        .lineLimit(2)
                }
                Spacer(minLength: Theme.spacingS)
                Text(ctaTitle)
                    .font(Typography.caption)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.8))
                    )
            }
            .padding(Theme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                    .stroke(Theme.glassStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
            .padding(Theme.spacingM)
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .stroke(Theme.glassStroke, lineWidth: 1)
        )
        .shadow(color: Theme.cardShadow, radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private func localGalleryFallback(imageName: String, tint: Color) -> some View {
        if UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            LinearGradient(
                colors: [Theme.accentSoft, tint.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct GalleryItem {
    let title: String
    let subtitle: String
    let imageName: String
    let tint: Color
    let ctaTitle: String
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
