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
        case .today: "fork.knife"
        case .calendar: "calendar"
        case .stats: "chart.bar.fill"
        case .setup: "gearshape.fill"
        }
    }
}

struct CommandBar: View {
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
        .background(CommandSlab().ignoresSafeArea(edges: .bottom))
    }

    private func item(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: tab.icon).font(.system(size: 16, weight: .bold))
            Text(tab.title).font(Theme.Font.navLink).tracking(0.5).textCase(.uppercase)
            Rectangle().fill(isSelected ? Theme.Color.amber : .clear).frame(width: 36, height: 3)
        }
        .foregroundStyle(isSelected ? Color.white : Theme.Color.navGold)
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
    }
}
