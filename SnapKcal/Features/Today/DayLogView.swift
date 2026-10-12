import PhotosUI
import SwiftData
import SwiftUI

struct MealRoute: Hashable {
    let id: PersistentIdentifier
}

struct DayLogView: View {
    enum Mode: Equatable {
        case today
        case day(Date)
    }

    let mode: Mode
    @Environment(AppEnvironment.self) private var environment
    @State private var today: TodayViewModel?
    @State private var capture: CaptureViewModel?

    var body: some View {
        Group {
            if let today, let capture {
                DayLogContent(today: today, capture: capture, showsTitle: mode != .today)
            } else {
                Theme.Color.background
            }
        }
        .task {
            guard today == nil else { return }
            let anchor = if case .day(let date) = mode { date } else { Date.now }
            today = TodayViewModel(anchor: anchor, store: environment.store, onChange: environment.dataChanged)
            capture = CaptureViewModel(store: environment.store, analyzer: environment.analyzer, settings: environment.settings, onChange: environment.dataChanged)
        }
        .onChange(of: environment.todayKey) {
            if mode == .today { today?.anchor = .now }
        }
    }
}

private struct DayLogContent: View {
    @Bindable var today: TodayViewModel
    @Bindable var capture: CaptureViewModel
    let showsTitle: Bool
    @Environment(AppEnvironment.self) private var environment
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            DayMealsList(dayKey: today.dayKey, today: today, capture: capture)
            if let candidate = today.undoCandidate {
                UndoToast(name: candidate.name) { today.undoDelete() }
            }
            snapBar
        }
        .background(Theme.Color.background)
        .navigationTitle(showsTitle ? today.anchor.appFormatted(.dateTime.day().month(.abbreviated).year()) : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(showsTitle ? .visible : .hidden, for: .navigationBar)
        .navigationDestination(for: MealRoute.self) { route in
            MealDetailView(mealID: route.id)
        }
        .fullScreenCover(isPresented: Binding(get: { capture.isPickingCamera }, set: { if !$0 && capture.isPickingCamera { capture.cancelPicking() } })) {
            CameraPicker(onImage: { capture.photoPicked($0, captureDate: nil) }, onCancel: capture.cancelPicking)
                .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: Binding(get: { capture.isPickingLibrary }, set: { if !$0 && capture.isPickingLibrary && pickerItem == nil { capture.cancelPicking() } }),
            selection: $pickerItem,
            matching: .images
        )
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let loaded = await LibraryPhotoLoader.load(item) {
                    capture.photoPicked(loaded.image, captureDate: loaded.captureDate)
                } else {
                    capture.cancelPicking()
                }
                pickerItem = nil
            }
        }
        .sheet(isPresented: Binding(get: { capture.isSheetPresented }, set: { if !$0 { capture.sheetDismissed() } })) {
            MealResultSheet(viewModel: capture, alternativeModels: alternativeModels)
                .interactiveDismissDisabled(!environment.settings.autoSave && isShowingResult)
        }
    }

    private var isShowingResult: Bool {
        if case .result = capture.phase { true } else { false }
    }

    private var alternativeModels: [AIModel] {
        Provider.allCases
            .filter { environment.apiKey(for: $0) != nil }
            .flatMap { environment.catalog.cached($0).prefix(6) }
    }

    private var snapBar: some View {
        VStack(spacing: Theme.Spacing.s) {
            if !environment.hasActiveKey {
                Label("Add an API key in SETUP", systemImage: "key")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.warning)
                    .padding(Theme.Spacing.s)
                    .frame(maxWidth: .infinity)
                    .tile(Theme.Color.warning.opacity(0.1), stroke: Theme.Color.warning.opacity(0.4))
                    .padding(.horizontal, Theme.Spacing.l)
                    .accessibilityIdentifier("missingKeyBanner")
            }
            HStack {
                Spacer()
                SnapButton { snap(.camera) }
                    .disabled(!environment.hasActiveKey)
                    .onLongPressGesture { snap(.library) }
                    .overlay(alignment: .trailing) {
                        Button { snap(.library) } label: {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 17))
                                .foregroundStyle(Theme.Color.textSecondary)
                                .frame(width: 44, height: 44)
                                .overlay(Rectangle().stroke(Theme.Color.border, lineWidth: 1))
                        }
                        .disabled(!environment.hasActiveKey)
                        .offset(x: 68)
                        .accessibilityLabel(Text("Pick from library"))
                        .accessibilityIdentifier("libraryButton")
                    }
                Spacer()
            }
        }
        .padding(.vertical, Theme.Spacing.s)
    }

    private func snap(_ source: PhotoSource) {
        Haptics(settings: environment.settings).snap()
        if environment.isMock && ProcessInfo.processInfo.arguments.contains("-mockPhoto") {
            capture.snap(for: today.anchor, source: source)
            capture.photoPicked(LibraryPhotoLoader.sampleMealImage(), captureDate: nil)
            return
        }
        capture.snap(for: today.anchor, source: source)
    }
}

private struct DayMealsList: View {
    @Query private var meals: [Meal]
    let today: TodayViewModel
    let capture: CaptureViewModel

    init(dayKey: String, today: TodayViewModel, capture: CaptureViewModel) {
        let key = dayKey
        _meals = Query(filter: #Predicate<Meal> { $0.dayKey == key }, sort: \Meal.eatenAt)
        self.today = today
        self.capture = capture
    }

    var body: some View {
        List {
            header
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            if meals.isEmpty {
                VStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "camera.viewfinder").font(.system(size: 28, weight: .light))
                    Text("No meals yet. Tap SNAP to log one.").font(Theme.Font.body)
                }
                .foregroundStyle(Theme.Color.textMuted)
                .frame(maxWidth: .infinity, minHeight: 140)
                .tile(Theme.Color.background)
                .padding(.horizontal, Theme.Spacing.l)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(meals) { meal in
                MealRow(meal: meal) { capture.retry(meal: meal) }
                    .background(NavigationLink(value: MealRoute(id: meal.persistentModelID)) { EmptyView() }.opacity(0))
                    .listRowInsets(EdgeInsets(top: 3, leading: Theme.Spacing.l, bottom: 4, trailing: Theme.Spacing.l))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", role: .destructive) { today.delete(meal) }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack {
                Button { today.step(days: -1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel(Text("Previous day"))
                    .frame(width: 44, height: 44)
                Spacer()
                Text(dateTitle).uiLabelStyle().accessibilityIdentifier("dayTitle")
                Spacer()
                Button { today.step(days: 1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel(Text("Next day"))
                    .frame(width: 44, height: 44)
                    .disabled(!today.canStepForward)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Color.textSecondary)
            KcalSummary(eaten: today.total(for: meals), target: today.targetKcal)
        }
        .panel()
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.m)
    }

    private var dateTitle: String {
        today.isToday ? String(localized: "Today") : today.anchor.appFormatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }
}
