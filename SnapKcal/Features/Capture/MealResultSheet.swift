import SwiftUI

struct MealResultSheet: View {
    @Bindable var viewModel: CaptureViewModel
    let alternativeModels: [AIModel]
    @State private var isAdjusting = false
    @State private var isAddingNote = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                photo
                content
            }
            .padding(Theme.Spacing.l)
        }
        .background(Theme.Color.periwinkle.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var photo: some View {
        if let data = viewModel.currentMeal?.photo ?? viewModel.currentMeal?.thumbnail, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: 220)
                .clipped()
                .overlay(Rectangle().stroke(Theme.Color.carbon, lineWidth: 2))
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .analyzing:
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                LoadingLabel(text: "Reading your plate…")
                    .accessibilityIdentifier("analyzingLabel")
                Button("Close") { viewModel.dismissWhileAnalyzing() }.buttonStyle(.dark)
            }
        case .result:
            if let meal = viewModel.currentMeal { ResultDetails(meal: meal, viewModel: viewModel, isAdjusting: $isAdjusting, isAddingNote: $isAddingNote) }
        case .notFood:
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text("No food detected").font(Theme.Font.title).foregroundStyle(Theme.Color.carbon)
                    .accessibilityIdentifier("noFoodLabel")
                Text("Try a photo where the meal fills most of the frame.").font(Theme.Font.body)
                Button("Retake") { viewModel.retake() }.buttonStyle(.commit)
            }
        case .failed(_, let message):
            failed(message)
        default:
            EmptyView()
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Analysis failed").font(Theme.Font.title).foregroundStyle(Theme.Color.red)
            Text(message).font(Theme.Font.body).foregroundStyle(Theme.Color.carbon)
                .accessibilityIdentifier("failedMessage")
            Text("The photo is kept in your log, you can retry later.").font(Theme.Font.micro)
            HStack {
                Button("Retry") { viewModel.retry() }.buttonStyle(.commit).accessibilityIdentifier("retryButton")
                if !alternativeModels.isEmpty {
                    Menu {
                        ForEach(alternativeModels) { model in
                            Button("\(model.provider.displayName) · \(model.displayName)") { viewModel.retry(with: model) }
                        }
                    } label: {
                        Text("Switch model")
                    }
                    .buttonStyle(.primary)
                }
                Spacer()
                Button("Delete") { viewModel.discard() }.buttonStyle(.destructive)
            }
        }
    }
}

private struct ResultDetails: View {
    let meal: Meal
    let viewModel: CaptureViewModel
    @Binding var isAdjusting: Bool
    @Binding var isAddingNote: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            KcalHero(kcal: meal.kcal, low: meal.kcalLow, high: meal.kcalHigh)
            Text(meal.name).font(Theme.Font.title).foregroundStyle(Theme.Color.carbon)
                .accessibilityIdentifier("resultMealName")
            Text(meal.summary).font(Theme.Font.body).lineSpacing(4).foregroundStyle(Theme.Color.carbon)
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                ScoreBadge(score: meal.healthScore, showsNumber: true)
                Text(meal.scoreReason).font(Theme.Font.body).foregroundStyle(Theme.Color.carbon)
            }
            if !meal.tip.isEmpty { TipBox(text: meal.tip) }
            MacroChips(meal: meal)
            Text("Confidence: \(meal.confidence.rawValue)").font(Theme.Font.micro)
            if isAdjusting { AdjustPanel(meal: meal, viewModel: viewModel) }
            if isAddingNote { NotePanel(viewModel: viewModel) }
            actions
        }
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack {
                Button("Done") { viewModel.finish() }.buttonStyle(.commit).accessibilityIdentifier("doneButton")
                Button("Adjust") { isAdjusting.toggle() }.buttonStyle(.primary)
                Button("Add note") { isAddingNote.toggle() }.buttonStyle(.primary)
            }
            Button("Delete") { viewModel.discard() }.buttonStyle(.destructive)
        }
        .frame(maxWidth: .infinity)
    }
}

struct KcalHero: View {
    let kcal: Int
    let low: Int
    let high: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.s) {
                OutlinedText(text: kcal.formatted())
                Text("kcal").uiLabelStyle()
            }
            if high > 0 {
                Text("\(low.formatted())–\(high.formatted()) kcal").font(Theme.Font.micro).foregroundStyle(Theme.Color.carbon)
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
        VStack(alignment: .leading, spacing: 0) {
            Text("Tip").uiLabelStyle()
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Color.amber)
            Text(text)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.carbon)
                .padding(Theme.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Color.surface)
                .overlay(Rectangle().stroke(Theme.Color.amber, lineWidth: 2))
        }
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
        Text("\(label) \(Int(grams.rounded())) g")
            .font(Theme.Font.micro)
            .foregroundStyle(Theme.Color.carbon)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .inset()
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
                    .buttonStyle(.dark).accessibilityLabel(Text("Minus 50 kcal"))
                TextField("kcal", text: $typed)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(Theme.Font.link)
                    .padding(Theme.Spacing.s)
                    .inset(Theme.Color.surface)
                    .onSubmit(commitTyped)
                Button { viewModel.setManualKcal(meal.kcal + 50) } label: { Image(systemName: "plus") }
                    .buttonStyle(.dark).accessibilityLabel(Text("Plus 50 kcal"))
                Button("Set", action: commitTyped).buttonStyle(.commit)
            }
            HStack {
                ForEach(Self.portions, id: \.1) { label, value in
                    Button(label) { viewModel.setPortion(value) }
                        .buttonStyle(meal.kcalSource == .portion && meal.portionMultiplier == value ? .commit : .primary)
                }
            }
            if meal.kcalSource != .model {
                Button("Reset to estimate (\(meal.kcalEstimated))") { viewModel.resetToEstimate() }
                    .font(Theme.Font.micro)
                    .foregroundStyle(Theme.Color.carbon)
            }
        }
        .padding(Theme.Spacing.m)
        .inset(Theme.Color.canvasSoft)
        .onAppear { typed = "\(meal.kcal)" }
        .onChange(of: meal.kcal) { typed = "\(meal.kcal)" }
    }

    private func commitTyped() {
        if let value = Int(typed) { viewModel.setManualKcal(value) }
    }
}

struct NotePanel: View {
    @Bindable var viewModel: CaptureViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            TextField("e.g. cooked in 2 tbsp oil", text: $viewModel.note, axis: .vertical)
                .font(Theme.Font.body)
                .padding(Theme.Spacing.s)
                .inset(Theme.Color.surface)
                .accessibilityIdentifier("noteField")
            Button("Re-estimate") { viewModel.reEstimate() }
                .buttonStyle(.commit)
                .disabled(viewModel.note.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
