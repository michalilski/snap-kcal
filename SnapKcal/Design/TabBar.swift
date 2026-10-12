import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case today, calendar, stats, setup

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .today: "Today"
        case .calendar: "Calendar"
        case .stats: "Stats"
        case .setup: "Setup"
        }
    }

    var icon: String {
        switch self {
        case .today: "house"
        case .calendar: "calendar"
        case .stats: "chart.bar"
        case .setup: "person"
        }
    }

    var selectedIcon: String {
        switch self {
        case .today: "house.fill"
        case .calendar: "calendar"
        case .stats: "chart.bar.fill"
        case .setup: "person.fill"
        }
    }
}

struct TabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button { selection = tab } label: { item(tab) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tab-\(tab.rawValue)")
                    .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.top, Theme.Spacing.s)
        .background(BarBackground().ignoresSafeArea(edges: .bottom))
    }

    private func item(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: isSelected ? tab.selectedIcon : tab.icon).font(.system(size: 20))
            Text(tab.title).font(Theme.Font.navLink)
        }
        .foregroundStyle(isSelected ? Theme.Color.textPrimary : Theme.Color.textMuted)
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
    }
}
