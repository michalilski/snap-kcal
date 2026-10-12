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
                Theme.Color.canvas
            }
        }
        .background(Theme.Color.canvas)
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
            Text(viewModel.month.formatted(.dateTime.month(.wide).year())).uiLabelStyle()
            Spacer()
            if !viewModel.isCurrentMonth {
                Button("Today") { viewModel.jumpToToday() }.buttonStyle(.primary)
            }
            Button { viewModel.step(months: 1) } label: { Image(systemName: "chevron.right") }
                .frame(width: 44, height: 44)
                .accessibilityLabel(Text("Next month"))
        }
        .foregroundStyle(Theme.Color.carbon)
        .plate()
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.m) {
            item(Theme.Color.canvasSoft, "Under")
            item(Theme.Color.amber, "On target")
            item(Theme.Color.red, "Over")
        }
        .font(Theme.Font.micro)
        .foregroundStyle(Theme.Color.carbon)
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
                        .font(.system(size: 10, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(cell.status == .over ? Color.white : Theme.Color.carbon)
        .padding(3)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
        .background(fill)
        .accessibilityElement(children: .combine)
    }

    private var fill: Color {
        guard cell.dayNumber != nil else { return .clear }
        switch cell.status {
        case .empty: return Theme.Color.platinum
        case .under: return Theme.Color.canvasSoft
        case .onTarget: return Theme.Color.amber
        case .over: return Theme.Color.red
        case .future: return Theme.Color.platinum.opacity(0.5)
        }
    }
}
