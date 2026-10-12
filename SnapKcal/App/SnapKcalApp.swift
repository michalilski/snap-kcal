import SwiftData
import SwiftUI

@main
struct SnapKcalApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .modelContainer(environment.container)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if environment.settings.onboardingDone {
                RootTabView()
            } else {
                OnboardingFlow()
            }
        }
        .task { environment.store.recoverStuckMeals() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { environment.refreshToday() }
        }
    }
}
