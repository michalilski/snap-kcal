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
            if viewModel == nil { viewModel = CalendarViewModel(store: environment.store, workouts: environment.workouts) }
            viewModel?.load()
            await refreshWorkouts()
        }
        .onChange(of: environment.dataVersion) { viewModel?.load() }
        .onChange(of: viewModel?.month) { Task { await refreshWorkouts() } }
    }

    private func refreshWorkouts() async {
        guard let interval = viewModel?.monthInterval else { return }
        await environment.workouts.refresh(interval)
        viewModel?.load()
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
            Text(viewModel.month.appFormatted(.dateTime.month(.wide).year())).headlineStyle(Theme.Font.metric)
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
                        .font(.system(size: 11, weight: .heavy).width(.condensed))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(cell.status.textColor)
        .padding(3)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
        .background(fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var fill: Color {
        cell.dayNumber == nil ? .clear : cell.status.color
    }
}
