import SwiftUI

struct PharmacistChatView: View {
    let handoff: HandoffPayload
    @StateObject private var viewModel = PharmacistChatViewModel()
    @State private var showCall = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Theme.spacingM)
                .padding(.top, Theme.spacingS)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.spacingS) {
                        ForEach(viewModel.messages) { message in
                            PharmacistMessageRow(message: message)
                                .id(message.id)
                        }
                        if viewModel.isLoading {
                            PharmacistTypingRow()
                        }
                    }
                    .padding(.horizontal, Theme.spacingM)
                    .padding(.top, Theme.spacingM)
                    .padding(.bottom, Theme.spacingL)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(Typography.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, Theme.spacingM)
                    .padding(.bottom, Theme.spacingXS)
            }

            inputBar
                .padding(.horizontal, Theme.spacingM)
                .padding(.bottom, Theme.spacingS)
        }
        .navigationTitle("Pharmacist Chat")
        .safeAreaPadding(.bottom, Theme.tabBarHeight)
        .dismissKeyboardOnTap()
        .task {
            await viewModel.configure(service: PharmacistServiceFactory.makeService(), handoff: handoff)
        }
        .sheet(isPresented: $showCall) {
            NavigationStack {
                PharmacistCallView(handoff: handoff)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            HStack(spacing: Theme.spacingS) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle().stroke(Theme.glassStroke, lineWidth: 1)
                        )
                    Image(systemName: "cross.case.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Theme.accent, Theme.accentSecondary)
                }

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    Text("Pharmacist chat")
                        .font(Typography.headline)
                    Text(viewModel.statusText.isEmpty ? "Connecting you to a pharmacist." : viewModel.statusText)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if viewModel.statusText.isEmpty {
                    ProgressView()
                        .tint(Theme.accent)
                }
                Button {
                    showCall = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                        Text("Call")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if !viewModel.statusText.isEmpty {
                PharmacistStatusView(statusText: viewModel.statusText, queuePosition: viewModel.queuePosition)
            }
        }
        .padding(Theme.spacingM)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .stroke(Theme.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
    }

    private var inputBar: some View {
        HStack(spacing: Theme.spacingS) {
            TextField("Type a message…", text: $viewModel.input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)

            Button {
                Task { await viewModel.send() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(Color.white)
                    .padding(10)
                    .background(Theme.accent)
                    .clipShape(Circle())
            }
            .disabled(viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
        }
    }
}

private struct PharmacistMessageRow: View {
    let message: PharmacistMessage

    var body: some View {
        if message.role == .system {
            Text(message.content)
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.spacingXS)
        } else {
            HStack {
                if message.role == .pharmacist {
                    bubble(alignment: .leading, isUser: false)
                    Spacer(minLength: 40)
                } else {
                    Spacer(minLength: 40)
                    bubble(alignment: .trailing, isUser: true)
                }
            }
        }
    }

    private func bubble(alignment: Alignment, isUser: Bool) -> some View {
        let fillStyle: AnyShapeStyle = isUser ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.ultraThinMaterial)
        let strokeStyle: AnyShapeStyle = isUser
            ? AnyShapeStyle(Color.white.opacity(0.25))
            : AnyShapeStyle(Theme.glassStroke)

        return VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            Text(message.content)
                .font(Typography.body)
                .foregroundStyle(isUser ? Color.white : Theme.textPrimary)
                .padding(Theme.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                        .fill(fillStyle)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                        .stroke(strokeStyle, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))

            Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: 260, alignment: alignment)
    }
}

private struct PharmacistTypingRow: View {
    var body: some View {
        HStack {
            TypingIndicatorView()
                .padding(.horizontal, Theme.spacingM)
                .padding(.vertical, Theme.spacingS)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                        .stroke(Theme.glassStroke, lineWidth: 1)
                )
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        PharmacistChatView(handoff: HandoffPayload(userMessage: "Question", summarizedLogs: "Summary", attachedRange: DateInterval(start: Date(), end: Date())))
    }
}
