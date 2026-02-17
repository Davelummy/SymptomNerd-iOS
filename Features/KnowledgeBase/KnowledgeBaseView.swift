import SwiftUI

struct KnowledgeBaseView: View {
    @State private var articles: [KnowledgeArticle] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                LearnHeaderCard()

                ForEach(articles) { article in
                    LearnTopicCard(article: article)
                }

                Text("Content is educational and not medical advice.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Learn")
        .task {
            articles = KnowledgeBaseLoader.loadArticles()
        }
    }
}

private struct LearnHeaderCard: View {
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                Text("Learn")
                    .font(Typography.title2)
                Text("Short guides to help you track clearly and talk with clinicians.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: Theme.spacingS) {
                    LearnBadge(title: "How to log")
                    LearnBadge(title: "AI safety")
                    LearnBadge(title: "Export tips")
                }
            }
        }
    }
}

private struct LearnTopicCard: View {
    let article: KnowledgeArticle

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                HStack(spacing: Theme.spacingS) {
                    Image(systemName: iconName(for: article.id))
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Theme.accent, Theme.accentSecondary)
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text(article.title)
                            .font(Typography.headline)
                        Text(article.summary)
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                ForEach(article.sections) { section in
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text(section.heading)
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                        ForEach(section.bullets, id: \.self) { bullet in
                            Text("• \(bullet)")
                                .font(Typography.body)
                        }
                    }
                    .padding(.top, Theme.spacingXS)
                }
            }
        }
    }

    private func iconName(for id: String) -> String {
        switch id {
        case "getting-started": return "sparkles"
        case "describe-symptoms": return "pencil.and.list.clipboard"
        case "using-ai": return "brain.head.profile"
        case "exporting": return "square.and.arrow.up"
        case "prepare-visit": return "stethoscope"
        case "safety": return "exclamationmark.triangle.fill"
        default: return "book.fill"
        }
    }
}

private struct LearnBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Typography.caption)
            .padding(.horizontal, Theme.spacingS)
            .padding(.vertical, Theme.spacingXS)
            .background(.ultraThinMaterial)
            .overlay(
                Capsule().stroke(Theme.glassStroke, lineWidth: 1)
            )
            .clipShape(Capsule())
            .foregroundStyle(Theme.accentDeep)
    }
}

struct KnowledgeArticle: Identifiable, Codable {
    let id: String
    let title: String
    let summary: String
    let sections: [KnowledgeSection]
}

struct KnowledgeSection: Identifiable, Codable {
    let id: UUID
    let heading: String
    let bullets: [String]

    init(id: UUID = UUID(), heading: String, bullets: [String]) {
        self.id = id
        self.heading = heading
        self.bullets = bullets
    }

    private enum CodingKeys: String, CodingKey {
        case heading
        case bullets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        heading = try container.decode(String.self, forKey: .heading)
        bullets = try container.decode([String].self, forKey: .bullets)
        id = UUID()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(heading, forKey: .heading)
        try container.encode(bullets, forKey: .bullets)
    }
}

enum KnowledgeBaseLoader {
    static func loadArticles() -> [KnowledgeArticle] {
        guard let url = Bundle.main.url(forResource: "KnowledgeBase", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([KnowledgeArticle].self, from: data) else {
            return []
        }
        return decoded
    }
}

#Preview {
    NavigationStack {
        KnowledgeBaseView()
    }
}
