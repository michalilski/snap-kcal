import SwiftUI

struct RootTabView: View {
    @State private var selection = AppTab.today

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch selection {
                case .today: NavigationStack { DayLogView(mode: .today) }
                case .calendar: NavigationStack { CalendarView() }
                case .stats: NavigationStack { StatsView() }
                case .setup: NavigationStack { SettingsView() }
                }
            }
            .frame(maxHeight: .infinity)
            CommandBar(selection: $selection)
        }
        .background(Theme.Color.canvas.ignoresSafeArea())
    }
}
