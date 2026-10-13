import SwiftUI

struct MealResultSheet: View {
    @Bindable var viewModel: CaptureViewModel
    let alternativeModels: [AIModel]
    @State private var isAdjusting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                content
            }
            .padding(Theme.Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Color.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .composing:
            ComposeStep(viewModel: viewModel)
        case .analyzing:
            if let meal = viewModel.currentMeal { MealConversationView(meal: meal, isRefining: false) }
            LoadingLabel(text: "Reading your plate…")
                .accessibilityIdentifier("analyzingLabel")
            Button("Close") { viewModel.dismissWhileAnalyzing() }.buttonStyle(.secondary)
        case .result:
            if let meal = viewModel.currentMeal {
                ResultDetails(meal: meal, viewModel: viewModel, isAdjusting: $isAdjusting)
            }
        case .notFood:
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text("No food detected").headlineStyle(Theme.Font.title)
                    .accessibilityIdentifier("noFoodLabel")
                Text("Try a photo where the meal fills most of the frame, or describe it in words.").font(Theme.Font.body)
                Button("Retake") { viewModel.retake() }.buttonStyle(.primary)
            }
        case .failed(_, let message):
            failed(message)
        default:
            EmptyView()
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if let meal = viewModel.currentMeal { MealConversationView(meal: meal, isRefining: false) }
            Text("Analysis failed").font(Theme.Font.title).textCase(.uppercase).foregroundStyle(Theme.Color.danger)
            Text(message).font(Theme.Font.body).foregroundStyle(Theme.Color.textPrimary)
                .accessibilityIdentifier("failedMessage")
            Text("The meal is kept in your log, you can retry later.").font(Theme.Font.micro)
            HStack {
                Button("Retry") { viewModel.retry() }.buttonStyle(.primary).accessibilityIdentifier("retryButton")
                if !alternativeModels.isEmpty {
                    Menu {
                        ForEach(alternativeModels) { model in
                            Button("\(model.provider.displayName) · \(model.displayName)") { viewModel.retry(with: model) }
                        }
                    } label: {
                        Text("Switch model")
                    }
                    .buttonStyle(.secondary)
                }
                Spacer()
                Button("Delete") { viewModel.discard() }.buttonStyle(.danger)
            }
        }
    }
}

private struct ComposeStep: View {
    @Bindable var viewModel: CaptureViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text(viewModel.pendingImage == nil ? "Describe your meal" : "Add details").headlineStyle()
            if let image = viewModel.pendingImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.image, style: .continuous))
                    .accessibilityHidden(true)
            }
            TextField(
                viewModel.pendingImage == nil ? "e.g. grahamka z Żabki, 2 eggs and a coffee" : "Optional, e.g. this toast also has ham",
                text: $viewModel.note,
                axis: .vertical
            )
            .lineLimit(2...6)
            .font(Theme.Font.body)
            .padding(Theme.Spacing.m)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
            .accessibilityIdentifier("composeField")
            Text("Any language works, answers come back in English.").font(Theme.Font.micro).foregroundStyle(Theme.Color.textSecondary)
            HStack {
                Button("Cancel") { viewModel.cancelPicking() }.buttonStyle(.secondary)
                Spacer()
                Button("Analyze") { viewModel.submit() }
                    .buttonStyle(.primary)
                    .disabled(!viewModel.canSubmit)
                    .accessibilityIdentifier("analyzeButton")
            }
        }
    }
}

private struct ResultDetails: View {
    let meal: Meal
    let viewModel: CaptureViewModel
    @Binding var isAdjusting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            MealEstimateSummary(meal: meal)
            if isAdjusting { AdjustPanel(meal: meal, viewModel: viewModel) }
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                PanelTitle("Conversation")
                MealConversationView(meal: meal, isRefining: viewModel.isRefining)
                if let error = viewModel.refineError {
                    RefineErrorView(message: error, onRetry: viewModel.retryFollowUp, onDiscard: viewModel.discardFollowUp)
                }
                MessageComposer(placeholder: "Add details or a photo to refine", isBusy: viewModel.isRefining) { image, text in
                    viewModel.sendFollowUp(image: image, text: text)
                }
            }
            actions
        }
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack {
                Button("Done") { viewModel.finish() }.buttonStyle(.primary).accessibilityIdentifier("doneButton")
                Button("Adjust") { isAdjusting.toggle() }.buttonStyle(.secondary)
            }
            Button("Delete") { viewModel.discard() }.buttonStyle(.danger)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Current numbers of a meal: kcal hero, name, description, score, tip and macros.
struct MealEstimateSummary: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            KcalHero(kcal: meal.kcal, low: meal.kcalLow, high: meal.kcalHigh)
            Text(meal.name).headlineStyle(Theme.Font.title)
                .accessibilityIdentifier("resultMealName")
            Text(meal.summary).font(Theme.Font.body).lineSpacing(4).foregroundStyle(Theme.Color.textPrimary)
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                ScoreBadge(score: meal.healthScore, showsNumber: true)
                Text(meal.scoreReason).font(Theme.Font.body).foregroundStyle(Theme.Color.textPrimary)
            }
            if !meal.tip.isEmpty { TipBox(text: meal.tip) }
            MacroChips(meal: meal)
        }
    }
}

struct RefineErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(message).font(Theme.Font.body).foregroundStyle(Theme.Color.danger)
                .accessibilityIdentifier("refineError")
            HStack {
                Button("Retry", action: onRetry).buttonStyle(.secondary)
                Button("Discard message", action: onDiscard).buttonStyle(.minimal)
            }
        }
    }
}

struct KcalHero: View {
    let kcal: Int
    let low: Int
    let high: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.s) {
                MetricText(text: kcal.formatted())
                Text("kcal").headlineStyle(Theme.Font.metric)
            }
            if high > 0 {
                Text("\(low.formatted())–\(high.formatted()) kcal").font(Theme.Font.data).foregroundStyle(Theme.Color.textMuted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(kcal) kilocalories, range \(low) to \(high)"))
        .accessibilityIdentifier("kcalHero")
    }
}

struct TipBox: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            Image(systemName: "lightbulb.fill").foregroundStyle(Theme.Color.textPrimary)
            Text(text).font(Theme.Font.body).foregroundStyle(Theme.Color.textPrimary)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct MacroChips: View {
    let meal: Meal

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            chip("P", meal.proteinG)
            chip("C", meal.carbsG)
            chip("F", meal.fatG)
        }
    }

    private func chip(_ label: String, _ grams: Double) -> some View {
        Tag(text: "\(label) \(Int(grams.rounded())) g")
    }
}

struct AdjustPanel: View {
    let meal: Meal
    let viewModel: CaptureViewModel
    @State private var typed = ""

    private static let portions: [(String, Double)] = [("½×", 0.5), ("1×", 1), ("1½×", 1.5), ("2×", 2)]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Button { viewModel.setManualKcal(meal.kcal - 50) } label: { Image(systemName: "minus") }
                    .buttonStyle(.minimal).accessibilityLabel(Text("Minus 50 kcal"))
                TextField("kcal", text: $typed)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(Theme.Font.link)
                    .padding(Theme.Spacing.s)
                    .tile(Theme.Color.background, stroke: Theme.Color.border)
                    .onSubmit(commitTyped)
                Button { viewModel.setManualKcal(meal.kcal + 50) } label: { Image(systemName: "plus") }
                    .buttonStyle(.minimal).accessibilityLabel(Text("Plus 50 kcal"))
                Button("Set", action: commitTyped).buttonStyle(.primary)
            }
            HStack {
                ForEach(Self.portions, id: \.1) { label, value in
                    Button(label) { viewModel.setPortion(value) }
                        .buttonStyle(meal.kcalSource == .portion && meal.portionMultiplier == value ? .primary : .secondary)
                }
            }
            if meal.kcalSource != .model {
                Button("Reset to estimate (\(meal.kcalEstimated))") { viewModel.resetToEstimate() }
                    .font(Theme.Font.micro)
                    .foregroundStyle(Theme.Color.textPrimary)
            }
        }
        .padding(Theme.Spacing.m)
        .panel(padding: Theme.Spacing.m)
        .onAppear { typed = "\(meal.kcal)" }
        .onChange(of: meal.kcal) { typed = "\(meal.kcal)" }
    }

    private func commitTyped() {
        if let value = Int(typed) { viewModel.setManualKcal(value) }
    }
}
