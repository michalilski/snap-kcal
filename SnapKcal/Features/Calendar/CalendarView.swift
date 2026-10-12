import SwiftUI

struct DayRoute: Hashable {
    let dayKey: String
}

struct CalendarView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: CalendarViewModel?

    var body: some View {
        Group {
            if let viewModel {
                CalendarContent(viewModel: viewModel)
            } else {
                Theme.Color.background
            }
        }
        .background(Theme.Color.background)
        .navigationDestination(for: DayRoute.self) { route in
            DayLogView(mode: .day(DayKey.startOfDay(route.dayKey)))
        }
        .task {
            if viewModel == nil { viewModel = CalendarViewModel(store: environment.store) }
            viewModel?.load()
        }
        .onChange(of: environment.dataVersion) { viewModel?.load() }
    }
}

private struct CalendarContent: View {
    let viewModel: CalendarViewModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                header
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(viewModel.weekdaySymbols.indices, id: \.self) { index in
                        Text(viewModel.weekdaySymbols[index]).uiLabelStyle()
                    }
                    ForEach(viewModel.cells) { cell in
                        if let key = cell.dayKey, cell.status != .future {
                            NavigationLink(value: DayRoute(dayKey: key)) { CalendarCellView(cell: cell) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("day-\(key)")
                        } else {
                            CalendarCellView(cell: cell)
                        }
                    }
                }
                legend
            }
            .padding(Theme.Spacing.l)
        }
    }

    private var header: some View {
        HStack {
            Button { viewModel.step(months: -1) } label: { Image(systemName: "chevron.left") }
                .frame(width: 44, height: 44)
                .accessibilityLabel(Text("Previous month"))
            Spacer()
            Text(viewModel.month.appFormatted(.dateTime.month(.wide).year())).uiLabelStyle()
            Spacer()
            if !viewModel.isCurrentMonth {
                Button("Today") { viewModel.jumpToToday() }.buttonStyle(.secondary)
            }
            Button { viewModel.step(months: 1) } label: { Image(systemName: "chevron.right") }
                .frame(width: 44, height: 44)
                .accessibilityLabel(Text("Next month"))
        }
        .foregroundStyle(Theme.Color.textPrimary)
        .panel()
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.m) {
            item(DayStatus.under.color, "Under")
            item(DayStatus.onTarget.color, "On target")
            item(DayStatus.over.color, "Over")
        }
        .font(Theme.Font.micro)
        .foregroundStyle(Theme.Color.textPrimary)
    }

    private func item(_ color: Color, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(color).frame(width: 12, height: 12)
            Text(label)
        }
    }
}

struct CalendarCellView: View {
    let cell: CalendarCell

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let number = cell.dayNumber {
                Text("\(number)").font(Theme.Font.micro)
                Spacer(minLength: 0)
                if let total = cell.totalKcal, total > 0 {
                    Text(total.formatted())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(cell.status == .future ? Theme.Color.textMuted : Theme.Color.textPrimary)
        .padding(3)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
        .background(fill, in: RoundedRectangle(cornerRadius: 2))
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var fill: Color {
        guard cell.dayNumber != nil else { return .clear }
        switch cell.status {
        case .empty, .future: return Theme.Color.surface
        default: return cell.status.color.opacity(0.28)
        }
    }

    private var stroke: Color {
        guard cell.dayNumber != nil else { return .clear }
        switch cell.status {
        case .empty, .future: return Theme.Color.border
        default: return cell.status.color.opacity(0.7)
        }
    }
}
