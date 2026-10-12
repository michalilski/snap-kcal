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

    var index: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
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
        .background(BarBackground().ignoresSafeArea(edges: .bottom))
    }

    private func item(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return VStack(spacing: Theme.Spacing.xs) {
            Rectangle().fill(isSelected ? Theme.Color.textPrimary : .clear).frame(height: 2)
            Text(String(format: "%02d", tab.index)).font(Theme.Font.data).foregroundStyle(Theme.Color.textMuted)
            HStack(spacing: 2) {
                if isSelected { Text("[") }
                Text(tab.title).textCase(.uppercase)
                if isSelected { Text("]") }
            }
            .font(Theme.Font.navLink)
            .tracking(1)
        }
        .padding(.bottom, Theme.Spacing.s)
        .foregroundStyle(isSelected ? Theme.Color.textPrimary : Theme.Color.textMuted)
        .frame(maxWidth: .infinity, minHeight: 52)
        .contentShape(Rectangle())
    }
}
