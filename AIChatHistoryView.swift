import SwiftUI

struct AIChatHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [AIChatMessage] = []
    private let store = AIConversationStore()

    var body: some View {
        NavigationStack {
            List {
                if messages.isEmpty {
                    Text("No saved conversations yet.")
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(messages) { message in
                        VStack(alignment: .leading, spacing: Theme.spacingXS) {
                            Text(message.role == .assistant ? "AI" : "You")
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                            Text(message.content)
                                .font(Typography.body)
                        }
                        .padding(.vertical, Theme.spacingXS)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Chat History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        store.clear()
                        messages = []
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                messages = store.load()
            }
        }
    }
}

#Preview {
    AIChatHistoryView()
}
