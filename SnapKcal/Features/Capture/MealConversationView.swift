import PhotosUI
import SwiftUI

/// The meal's message history: each user message (photo and/or text) followed by the estimate it produced.
struct MealConversationView: View {
    let meal: Meal
    let isRefining: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ForEach(meal.orderedTurns) { turn in
                UserBubble(turn: turn)
                if let reply = turn.reply {
                    ReplyBubble(reply: reply)
                } else if isRefining {
                    LoadingLabel(text: "Updating estimate…")
                }
            }
        }
    }
}

private struct UserBubble: View {
    let turn: MealTurn

    var body: some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
            if let data = turn.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 105)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                    .accessibilityLabel(Text("Your photo"))
            }
            if let text = turn.text {
                Text(text)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.onAccent)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, Theme.Spacing.s)
                    .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("userBubble")
    }
}

private struct ReplyBubble: View {
    let reply: MealAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if reply.isFood {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text("\(reply.kcalTotal) kcal").headlineStyle(Theme.Font.metric)
                    Text(reply.mealName).font(Theme.Font.link).foregroundStyle(Theme.Color.textPrimary).lineLimit(2)
                }
            }
            Text(reply.description).font(Theme.Font.body).foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: 300, alignment: .leading)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("replyBubble")
    }
}

/// Text field with optional photo attachment (camera or library) for describing or refining a meal.
struct MessageComposer: View {
    let placeholder: LocalizedStringKey
    var sendTitle: LocalizedStringKey = "Send"
    let isBusy: Bool
    let onSend: (UIImage?, String) -> Void

    @State private var text = ""
    @State private var image: UIImage?
    @State private var showsCamera = false
    @State private var libraryItem: PhotosPickerItem?

    private var canSend: Bool {
        !isBusy && (image != nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let image {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 66)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                    Button { self.image = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Color.onAccent, Theme.Color.accent)
                    }
                    .offset(x: 6, y: -6)
                    .accessibilityLabel(Text("Remove photo"))
                }
            }
            HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
                attachMenu
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .font(Theme.Font.body)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, 10)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityIdentifier("composerField")
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.Color.onAccent)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.Color.accent))
                }
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.3)
                .accessibilityLabel(Text(sendTitle))
                .accessibilityIdentifier("composerSend")
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker(onImage: { image = $0; showsCamera = false }, onCancel: { showsCamera = false })
                .ignoresSafeArea()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                image = await LibraryPhotoLoader.load(item)?.image
                libraryItem = nil
            }
        }
    }

    private var attachMenu: some View {
        Menu {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showsCamera = true } label: { Label("Take photo", systemImage: "camera") }
            }
            PhotosPicker(selection: $libraryItem, matching: .images) { Label("Choose photo", systemImage: "photo") }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Color.textPrimary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.Color.surface))
        }
        .accessibilityLabel(Text("Attach photo"))
        .accessibilityIdentifier("composerAttach")
    }

    private func send() {
        guard canSend else { return }
        onSend(image, text)
        text = ""
        image = nil
    }
}
