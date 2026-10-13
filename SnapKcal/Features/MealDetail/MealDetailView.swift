import SwiftData
import SwiftUI

struct MealDetailView: View {
    let mealID: PersistentIdentifier
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: MealDetailViewModel?

    var body: some View {
        Group {
            if let viewModel, let meal = viewModel.meal, !meal.isDeleted {
                MealDetailContent(meal: meal, viewModel: viewModel)
            } else {
                Theme.Color.background
            }
        }
        .background(Theme.Color.background)
        .task {
            if viewModel == nil { viewModel = MealDetailViewModel(mealID: mealID, environment: environment) }
        }
    }
}

private struct MealDetailContent: View {
    @Bindable var meal: Meal
    let viewModel: MealDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kcalText = ""
    @State private var eatenAt = Date.now

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                photo
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    KcalHero(kcal: meal.kcal, low: meal.kcalLow, high: meal.kcalHigh)
                    if meal.kcalSource != .model {
                        Text("Original estimate: \(meal.kcalEstimated) kcal").font(Theme.Font.micro)
                    }
                    Text(meal.summary).font(Theme.Font.body)
                    HStack(alignment: .top) {
                        ScoreBadge(score: meal.healthScore, showsNumber: true)
                        Text(meal.scoreReason).font(Theme.Font.body)
                    }
                    if !meal.tip.isEmpty { TipBox(text: meal.tip) }
                    MacroChips(meal: meal)
                }
                .foregroundStyle(Theme.Color.textPrimary)
                .panel()
                conversationSection
                editSection
                itemsSection
                provenanceSection
                Button("Delete meal") {
                    viewModel.delete()
                    dismiss()
                }
                .buttonStyle(.danger)
            }
            .padding(Theme.Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(meal.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = meal.name
            kcalText = "\(meal.kcal)"
            eatenAt = meal.eatenAt
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let data = meal.photo, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.panel).stroke(Theme.Color.border, lineWidth: 1))
                .accessibilityHidden(true)
        }
    }

    private var conversationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PanelTitle("Refine")
            MealConversationView(meal: meal, isRefining: viewModel.isReanalyzing)
            if viewModel.isReanalyzing && meal.orderedTurns.last?.reply != nil {
                LoadingLabel(text: "Updating estimate…")
            }
            if let error = viewModel.refineError {
                RefineErrorView(
                    message: error,
                    onRetry: { Task { await viewModel.retryFollowUp() } },
                    onDiscard: viewModel.discardFollowUp
                )
            }
            MessageComposer(placeholder: "Add details or a photo to refine", isBusy: viewModel.isReanalyzing) { image, text in
                Task {
                    await viewModel.sendFollowUp(image: image, text: text)
                    kcalText = "\(meal.kcal)"
                    name = meal.name
                }
            }
        }
        .panel()
    }

    private var editSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PanelTitle("Edit")
            TextField("Name", text: $name)
                .font(Theme.Font.link)
                .padding(Theme.Spacing.s)
                .tile(Theme.Color.background, stroke: Theme.Color.border)
                .onSubmit { viewModel.rename(name) }
            HStack {
                TextField("kcal", text: $kcalText)
                    .keyboardType(.numberPad)
                    .font(Theme.Font.link)
                    .padding(Theme.Spacing.s)
                    .tile(Theme.Color.background, stroke: Theme.Color.border)
                Button("Save") {
                    viewModel.rename(name)
                    if let value = Int(kcalText) { viewModel.setKcal(value) }
                }
                .buttonStyle(.primary)
                if meal.kcalSource != .model {
                    Button("Reset") {
                        viewModel.resetToEstimate()
                        kcalText = "\(meal.kcal)"
                    }
                    .buttonStyle(.secondary)
                }
            }
            DatePicker("Eaten at", selection: $eatenAt, in: ...Date.now)
                .font(Theme.Font.link)
                .onChange(of: eatenAt) { _, date in viewModel.move(to: date) }
                .accessibilityIdentifier("eatenAtPicker")
        }
        .panel()
    }

    @ViewBuilder
    private var itemsSection: some View {
        if !meal.items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PanelTitle("Detected items")
                ForEach(Array(meal.items.enumerated()), id: \.offset) { _, item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name).font(Theme.Font.link)
                            Text(item.portion).font(Theme.Font.micro)
                        }
                        Spacer()
                        Text("\(item.kcal) kcal").font(Theme.Font.link)
                    }
                    .padding(Theme.Spacing.s)
                    .tile()
                }
            }
            .foregroundStyle(Theme.Color.textPrimary)
            .panel()
        }
    }

    private var provenanceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PanelTitle("Analysis")
            Text("\(meal.provider.displayName) · \(meal.modelId)").font(Theme.Font.data)
            if let note = meal.userNote { Text("Note: \(note)").font(Theme.Font.micro) }
            if let input = meal.inputTokens, let output = meal.outputTokens {
                Text("Tokens: \(input) in / \(output) out").font(Theme.Font.data)
            }
            if viewModel.isReanalyzing {
                LoadingLabel(text: "Reading your plate…")
            } else if !viewModel.availableModels.isEmpty, !meal.turns.isEmpty || meal.photo != nil {
                Menu {
                    ForEach(viewModel.availableModels) { model in
                        Button("\(model.provider.displayName) · \(model.displayName)") {
                            Task { await viewModel.reanalyze(with: model) }
                        }
                    }
                } label: {
                    Text("Re-analyze with…")
                }
                .buttonStyle(.secondary)
            }
        }
        .foregroundStyle(Theme.Color.textPrimary)
        .panel()
    }
}
