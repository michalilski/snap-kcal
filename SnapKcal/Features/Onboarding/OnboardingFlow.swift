import SwiftUI

struct OnboardingFlow: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: OnboardingViewModel?
    @State private var settingsViewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let viewModel, let settingsViewModel {
                NavigationStack {
                    OnboardingContent(viewModel: viewModel, settingsViewModel: settingsViewModel)
                        .toolbar(.hidden, for: .navigationBar)
                }
            } else {
                Theme.Color.background
            }
        }
        .task {
            if viewModel == nil {
                viewModel = OnboardingViewModel(store: environment.store, settings: environment.settings)
                settingsViewModel = SettingsViewModel(environment: environment)
            }
        }
    }
}

private struct OnboardingContent: View {
    @Bindable var viewModel: OnboardingViewModel
    let settingsViewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    step
                }
                .padding(Theme.Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .background(Theme.Color.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Snap Kcal").font(Theme.Font.title).foregroundStyle(Theme.Color.textPrimary)
            Text("Step \(viewModel.step + 1) of \(OnboardingViewModel.stepCount)").uiLabelStyle()
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(0..<OnboardingViewModel.stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= viewModel.step ? Theme.Color.accent : Theme.Color.surfaceRaised)
                        .frame(height: 3)
                }
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var step: some View {
        switch viewModel.step {
        case 0:
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                PanelTitle("Body")
                BodyForm(draft: $viewModel.draft)
            }
            .panel()
        case 1:
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                PanelTitle("Activity")
                ActivityPicker(level: $viewModel.draft.activityLevel)
            }
            .panel()
        case 2:
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                PanelTitle("Daily goal")
                GoalPicker(goal: $viewModel.draft.goal, targets: viewModel.targets)
            }
            .panel()
        default:
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                PanelTitle("AI setup")
                AISetupSection(viewModel: settingsViewModel)
                Text("You can skip this and add a key later in SETUP.").font(Theme.Font.micro)
            }
            .panel()
        }
    }

    private var footer: some View {
        HStack {
            if viewModel.step > 0 {
                Button("Back") { viewModel.back() }
                    .buttonStyle(.minimal)
                    .accessibilityIdentifier("onboardingBack")
            }
            Spacer()
            Button(viewModel.isLastStep ? "Start" : "Next") { viewModel.next() }
                .buttonStyle(.primary)
                .disabled(!viewModel.canContinue)
                .accessibilityIdentifier("onboardingNext")
        }
        .padding(Theme.Spacing.l)
        .background(BarBackground().ignoresSafeArea(edges: .bottom))
    }
}
