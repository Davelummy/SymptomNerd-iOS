import SwiftUI

struct TimelineEntryDetailView: View {
    let entry: SymptomEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {

                // ── Hero header ──────────────────────────────────────────────
                CardView {
                    HStack(alignment: .top, spacing: Theme.spacingM) {
                        // Severity gauge
                        VStack(spacing: 4) {
                            Text("\(entry.severity)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("/ 10")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .frame(width: 68, height: 72)
                        .background(
                            Theme.severityColor(for: entry.severity),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .shadow(color: Theme.severityColor(for: entry.severity).opacity(0.4),
                                radius: 8, x: 0, y: 4)

                        VStack(alignment: .leading, spacing: Theme.spacingXS) {
                            Text(entry.symptomType.name)
                                .font(Typography.title2)
                            Text(severityLabel)
                                .font(Typography.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.severityColor(for: entry.severity))
                            Text(DateHelpers.relativeDayString(for: entry.createdAt))
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }

                // ── Context stats row ────────────────────────────────────────
                if entry.onset != nil || entry.durationMinutes != nil
                    || entry.bodyLocation != nil {
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible()),
                                        .init(.flexible())], spacing: Theme.spacingS) {
                        if let onset = entry.onset {
                            statTile(icon: "clock",
                                     label: "Onset",
                                     value: onset.formatted(.dateTime.hour().minute()))
                        }
                        if let dur = entry.durationMinutes {
                            statTile(icon: "timer",
                                     label: "Duration",
                                     value: "\(dur) min")
                        }
                        if let region = entry.bodyLocation?.regionName {
                            statTile(icon: "mappin.circle",
                                     label: "Location",
                                     value: region)
                        }
                    }
                }

                // ── Qualities ────────────────────────────────────────────────
                if !entry.qualities.isEmpty {
                    tagSection(title: "Qualities",
                               icon: "waveform.path",
                               tags: entry.qualities.map { $0.displayName },
                               color: Theme.accent)
                }

                // ── Associated symptoms ──────────────────────────────────────
                if !entry.associatedSymptoms.isEmpty {
                    tagSection(title: "Associated symptoms",
                               icon: "link",
                               tags: entry.associatedSymptoms.map { $0.displayName },
                               color: Theme.accentSecondary)
                }

                // ── Triggers ─────────────────────────────────────────────────
                if !entry.possibleTriggers.isEmpty {
                    tagSection(title: "Possible triggers",
                               icon: "bolt",
                               tags: entry.possibleTriggers.map { $0.displayName },
                               color: Theme.warningAmber)
                }

                // ── Red flags ────────────────────────────────────────────────
                if !entry.redFlags.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingS) {
                            Label("Red flags", systemImage: "exclamationmark.triangle.fill")
                                .font(Typography.headline)
                                .foregroundStyle(Theme.errorRed)
                            FlowLayout(spacing: Theme.spacingXS) {
                                ForEach(entry.redFlags, id: \.self) { flag in
                                    chipView(flag.displayName, color: Theme.errorRed)
                                }
                            }
                        }
                    }
                }

                // ── Context ──────────────────────────────────────────────────
                contextCard

                // ── Notes ────────────────────────────────────────────────────
                if !entry.notes.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingXS) {
                            Label("Notes", systemImage: "note.text")
                                .font(Typography.headline)
                            Text(entry.notes)
                                .font(Typography.body)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }

                // ── AI ───────────────────────────────────────────────────────
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Label("AI analysis", systemImage: "sparkles")
                            .font(Typography.headline)
                        NavigationLink {
                            AIChatView()
                        } label: {
                            PrimaryButtonLabel(title: "Analyze this entry",
                                               systemImage: "sparkles")
                        }
                    }
                }

                Text("AI insights are informational and not a diagnosis.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, Theme.spacingL)
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Entry detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private var severityLabel: String {
        switch entry.severity {
        case 0:     return "None"
        case 1...3: return "Mild"
        case 4...5: return "Moderate"
        case 6...7: return "Severe"
        case 8...9: return "Very severe"
        default:    return "Unbearable"
        }
    }

    @ViewBuilder
    private var contextCard: some View {
        let ctx = entry.context
        let hasContext = ctx.sleepHours != nil || ctx.hydrationLiters != nil
            || ctx.caffeineMg != nil || ctx.alcoholUnits != nil
            || ctx.periodTag != nil || !ctx.medsTaken.isEmpty

        if hasContext {
            CardView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    Label("Context", systemImage: "list.bullet.clipboard")
                        .font(Typography.headline)

                    let rows: [(String, String, String)] = [
                        ("moon.zzz", "Sleep",
                         ctx.sleepHours.map { "\($0) hrs" } ?? ""),
                        ("drop", "Hydration",
                         ctx.hydrationLiters.map { "\($0) L" } ?? ""),
                        ("cup.and.saucer", "Caffeine",
                         ctx.caffeineMg.map { "\($0) mg" } ?? ""),
                        ("wineglass", "Alcohol",
                         ctx.alcoholUnits.map { "\($0) units" } ?? ""),
                        ("cross.case", "Medications",
                         ctx.medsTaken.isEmpty ? "" : ctx.medsTaken.joined(separator: ", ")),
                        ("circle.hexagonpath", "Cycle phase",
                         ctx.periodTag?.displayName ?? "")
                    ].filter { !$0.2.isEmpty }

                    ForEach(rows, id: \.0) { icon, label, value in
                        HStack {
                            Label(label, systemImage: icon)
                                .font(Typography.body)
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text(value)
                                .font(Typography.body)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
            }
        }
    }

    private func statTile(icon: String, label: String, value: String) -> some View {
        VStack(spacing: Theme.spacingXS) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.accent)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.spacingS)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
            .stroke(Theme.glassStroke, lineWidth: 1))
    }

    private func tagSection(title: String, icon: String,
                            tags: [String], color: Color) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                Label(title, systemImage: icon)
                    .font(Typography.headline)
                FlowLayout(spacing: Theme.spacingXS) {
                    ForEach(tags, id: \.self) { tag in
                        chipView(tag, color: color)
                    }
                }
            }
        }
    }

    private func chipView(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Typography.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12),
                        in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
            .foregroundStyle(color)
    }
}

// MARK: - Flow layout (wrapping chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews,
                      cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width > width && rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        TimelineEntryDetailView(
            entry: SymptomEntry(
                symptomType: SymptomType(name: "Headache"),
                severity: 7,
                qualities: [.throbbing, .pressure],
                possibleTriggers: [.stress, .sleep]
            )
        )
    }
}
