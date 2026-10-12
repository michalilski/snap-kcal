import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                SettingsContent(viewModel: viewModel)
            } else {
                Theme.Color.canvas
            }
        }
        .navigationTitle("Setup")
        .toolbarBackground(Theme.Color.canvas, for: .navigationBar)
        .task {
            if viewModel == nil { viewModel = SettingsViewModel(environment: environment) }
        }
    }
}

private struct SettingsContent: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var confirmDelete = 0
    @State private var exportURLs: [URL] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                profileSection
                aiSection
                behaviourSection
                dataSection
                aboutSection
            }
            .padding(Theme.Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Color.canvas)
        .onDisappear { viewModel.updateProfile() }
        .confirmationDialog("Delete all data?", isPresented: Binding(get: { confirmDelete == 1 }, set: { if !$0 && confirmDelete == 1 { confirmDelete = 0 } })) {
            Button("Delete meals, profile and keys", role: .destructive) { confirmDelete = 2 }
        }
        .confirmationDialog("This cannot be undone. Are you sure?", isPresented: Binding(get: { confirmDelete == 2 }, set: { if !$0 { confirmDelete = 0 } })) {
            Button("Delete everything", role: .destructive) { viewModel.deleteAllData() }
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PanelTitle("Profile")
            BodyForm(draft: $viewModel.draft)
            DottedDivider()
            Text("Activity").uiLabelStyle()
            ActivityPicker(level: $viewModel.draft.activityLevel)
            DottedDivider()
            Text("Goal").uiLabelStyle()
            GoalPicker(goal: $viewModel.draft.goal, targets: viewModel.targets)
            Button("Save profile") { viewModel.updateProfile() }
                .buttonStyle(.commit)
                .disabled(!viewModel.draft.isValid)
                .accessibilityIdentifier("saveProfile")
        }
        .plate()
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PanelTitle("AI")
            AISetupSection(viewModel: viewModel)
            DottedDivider()
            Picker("Analysis detail", selection: Binding(get: { viewModel.settings.analysisDetail }, set: { viewModel.settings.analysisDetail = $0 })) {
                Text("Fast").tag(AnalysisDetail.fast)
                Text("Accurate").tag(AnalysisDetail.accurate)
            }
            .pickerStyle(.segmented)
            Toggle("Save last raw response", isOn: Binding(get: { viewModel.settings.saveRawResponse }, set: { viewModel.settings.saveRawResponse = $0 }))
                .font(Theme.Font.micro)
        }
        .plate()
    }

    private var behaviourSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PanelTitle("Behaviour")
            Toggle("Auto-save meals", isOn: Binding(get: { viewModel.settings.autoSave }, set: { viewModel.settings.autoSave = $0 }))
            Toggle("Haptics", isOn: Binding(get: { viewModel.settings.haptics }, set: { viewModel.settings.haptics = $0 }))
        }
        .font(Theme.Font.link)
        .tint(Theme.Color.signal)
        .plate()
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PanelTitle("Data")
            HStack {
                Button("Prepare export") { exportURLs = [viewModel.exportJSON(), viewModel.exportCSV()] }
                    .buttonStyle(.primary)
                if !exportURLs.isEmpty {
                    ShareLink(items: exportURLs) { Text("Share JSON + CSV") }.buttonStyle(.commit)
                }
            }
            Button("Delete all data") { confirmDelete = 1 }
                .buttonStyle(.destructive)
                .accessibilityIdentifier("deleteAll")
        }
        .plate()
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PanelTitle("About")
            Text("Snap Kcal \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                .font(Theme.Font.body)
            Text("Photos are sent only to the AI provider you choose.").font(Theme.Font.body)
            Text("Estimates only, not medical advice.").font(Theme.Font.micro)
        }
        .foregroundStyle(Theme.Color.carbon)
        .plate()
    }
}
