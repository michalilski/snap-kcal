import SwiftUI
import UIKit

struct AISetupSection: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var keyInput = ""

    var body: some View {
        let provider = viewModel.settings.activeProvider
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Picker("Provider", selection: Binding(get: { viewModel.settings.activeProvider }, set: { viewModel.settings.activeProvider = $0 })) {
                ForEach(Provider.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("providerPicker")

            keyRow(provider)
            modelRow(provider)
            testRow
        }
        .onChange(of: viewModel.settings.activeProvider) { keyInput = "" }
    }

    private func keyRow(_ provider: Provider) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text("\(provider.displayName) API key").font(Theme.Font.link)
                Spacer()
                if let masked = viewModel.keys[provider] ?? nil {
                    Text(masked).font(Theme.Font.micro).accessibilityIdentifier("maskedKey")
                }
            }
            HStack(spacing: Theme.Spacing.s) {
                SecureField("Paste key", text: $keyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(Theme.Font.body)
                    .padding(Theme.Spacing.s)
                    .frame(minHeight: 44)
                    .inset(Theme.Color.surface)
                    .accessibilityIdentifier("apiKeyField")
                Button("Paste") {
                    keyInput = UIPasteboard.general.string ?? ""
                }
                .buttonStyle(.primary)
                Button("Save") {
                    viewModel.setKey(keyInput, for: provider)
                    keyInput = ""
                }
                .buttonStyle(.commit)
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("saveKey")
            }
            if viewModel.hasKey(provider) && !viewModel.isMock {
                Button("Remove key") { viewModel.setKey("", for: provider) }
                    .font(Theme.Font.micro)
                    .foregroundStyle(Theme.Color.red)
            }
        }
    }

    private func modelRow(_ provider: Provider) -> some View {
        NavigationLink {
            ModelPickerView(viewModel: viewModel, provider: provider)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Model").font(Theme.Font.link)
                    Text(viewModel.selectedModel(provider)?.displayName ?? String(localized: "Not selected"))
                        .font(Theme.Font.micro)
                }
                Spacer()
                if let id = viewModel.settings.modelId(for: provider), viewModel.settings.testedModels.contains(id) {
                    Image(systemName: "checkmark").accessibilityLabel(Text("Tested"))
                }
                ChevronChip()
            }
            .foregroundStyle(Theme.Color.carbon)
            .padding(Theme.Spacing.m)
            .frame(minHeight: 44)
            .inset()
        }
        .accessibilityIdentifier("modelRow")
    }

    private var testRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button("Test") { Task { await viewModel.testActiveModel() } }
                .buttonStyle(.primary)
                .disabled(viewModel.testState == .running)
                .accessibilityIdentifier("testModel")
            switch viewModel.testState {
            case .idle: EmptyView()
            case .running: LoadingLabel(text: "Testing")
            case .ok(let latency):
                Text("OK · \(latency.formatted(.number.precision(.fractionLength(1)))) s").uiLabelStyle()
            case .failed(let message):
                Text(message).font(Theme.Font.micro).foregroundStyle(Theme.Color.red)
            }
        }
    }
}

struct ModelPickerView: View {
    @Bindable var viewModel: SettingsViewModel
    let provider: Provider
    @State private var manualId = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let error = viewModel.loadError[provider] {
                Text(error).font(Theme.Font.micro).foregroundStyle(Theme.Color.red)
            }
            Section("Enter model ID manually") {
                HStack {
                    TextField("model-id", text: $manualId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Use") {
                        viewModel.selectModel(.manual(manualId.trimmingCharacters(in: .whitespaces), provider: provider))
                        dismiss()
                    }
                    .disabled(manualId.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section("Available models") {
                if viewModel.loading[provider] == true { LoadingLabel(text: "Loading models") }
                ForEach(viewModel.models[provider] ?? []) { model in
                    Button {
                        viewModel.selectModel(model)
                        dismiss()
                    } label: { row(model) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Color.canvas)
        .navigationTitle(provider.displayName)
        .refreshable { await viewModel.refreshModels(provider, force: true) }
        .task {
            if (viewModel.models[provider] ?? []).isEmpty { await viewModel.refreshModels(provider) }
        }
    }

    private func row(_ model: AIModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName).font(Theme.Font.link)
                if model.displayName != model.id { Text(model.id).font(Theme.Font.micro) }
            }
            if model.isFastHint {
                Text("Fast").font(Theme.Font.micro).padding(.horizontal, 4).background(Theme.Color.amber)
            }
            Spacer()
            if viewModel.settings.testedModels.contains(model.id) { Image(systemName: "checkmark.seal") }
            if viewModel.settings.modelId(for: provider) == model.id { Image(systemName: "checkmark") }
        }
        .foregroundStyle(Theme.Color.carbon)
    }
}
