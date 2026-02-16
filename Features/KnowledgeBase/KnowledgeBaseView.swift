import SwiftUI

struct KnowledgeBaseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Knowledge Base")
                            .font(Typography.title2)
                        Text("Educational content to help you prepare for conversations with clinicians.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                ForEach(sampleArticles, id: \.title) { article in
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingXS) {
                            Text(article.title)
                                .font(Typography.headline)
                            Text(article.summary)
                                .font(Typography.body)
                                .foregroundStyle(Theme.textSecondary)
                            Text("Read more")
                                .font(Typography.caption)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }

                Text("Content is educational and not medical advice.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Learn")
    }

    private var sampleArticles: [(title: String, summary: String)] {
        [
            ("How to describe symptoms", "Tips for sharing timing, intensity, and triggers."),
            ("Preparing for a visit", "Bring your trends, questions, and medication list."),
            ("Tracking red flags", "Know when to seek urgent care.")
        ]
    }
}

#Preview {
    NavigationStack {
        KnowledgeBaseView()
    }
}
