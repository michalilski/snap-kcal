import SwiftData
import SwiftUI
import UIKit

@main
struct SnapKcalApp: App {
    @State private var environment = AppEnvironment()

    init() {
        NavigationBarStyle.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .modelContainer(environment.container)
                .preferredColorScheme(.dark)
                .fontDesign(.monospaced)
                .environment(\.locale, AppLocale.current)
                .tint(Theme.Color.textPrimary)
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

@MainActor
enum NavigationBarStyle {
    static func apply() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.shadowColor = UIColor(white: 0.18, alpha: 1)
        appearance.titleTextAttributes = [
            .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.white,
            .kern: 1.5,
        ]
        appearance.largeTitleTextAttributes = [
            .font: UIFont.monospacedSystemFont(ofSize: 28, weight: .light),
            .foregroundColor: UIColor.white,
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
