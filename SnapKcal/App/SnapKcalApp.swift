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
                .preferredColorScheme(.light)
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
        appearance.backgroundColor = .white
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .medium),
            .foregroundColor: UIColor(white: 0.07, alpha: 1),
        ]
        appearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .black, width: .condensed),
            .foregroundColor: UIColor(white: 0.07, alpha: 1),
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
