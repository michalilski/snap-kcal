import Charts
import SwiftUI

struct StatsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: StatsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                StatsContent(viewModel: viewModel)
            } else {
                Theme.Color.canvas
            }
        }
        .background(Theme.Color.canvas)
        .navigationDestination(for: DayRoute.self) { route in
            DayLogView(mode: .day(DayKey.startOfDay(route.dayKey)))
        }
        .task {
            if viewModel == nil { viewModel = StatsViewModel(store: environment.store) }
            viewModel?.load()
        }
        .onChange(of: environment.dataVersion) { viewModel?.load() }
    }
}

private struct StatsContent: View {
    @Bindable var viewModel: StatsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Picker("Period", selection: $viewModel.period) {
                    Text("Week").tag(StatsViewModel.Period.week)
                    Text("Month").tag(StatsViewModel.Period.month)
                }
                .pickerStyle(.segmented)
                header
                Text("Today so far: \(viewModel.todaySoFar.formatted()) kcal").uiLabelStyle()
                summary
                chart
            }
            .padding(Theme.Spacing.l)
        }
    }

    private var header: some View {
        HStack {
            Button { viewModel.step(-1) } label: { Image(systemName: "chevron.left") }
                .frame(width: 44, height: 44)
                .accessibilityLabel(Text("Previous period"))
            Spacer()
            Text(periodTitle).uiLabelStyle()
            Spacer()
            Button { viewModel.step(1) } label: { Image(systemName: "chevron.right") }
                .frame(width: 44, height: 44)
                .disabled(!viewModel.canStepForward)
                .accessibilityLabel(Text("Next period"))
        }
        .foregroundStyle(Theme.Color.carbon)
        .plate()
    }

    private var periodTitle: String {
        guard let interval = viewModel.interval else { return "" }
        if viewModel.period == .month { return interval.start.formatted(.dateTime.month(.wide).year()) }
        let end = interval.end.addingTimeInterval(-1)
        return "\(interval.start.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated)))"
    }

    @ViewBuilder
    private var summary: some View {
        if let summary = viewModel.summary {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(alignment: .lastTextBaseline) {
                    OutlinedText(text: summary.average.formatted())
                    Text("avg kcal / day").uiLabelStyle()
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("statsAverage")
                Text(summary.vsTarget >= 0 ? "+\(summary.vsTarget.formatted()) over target" : "\(summary.vsTarget.formatted()) under target")
                    .uiLabelStyle(summary.vsTarget > 0 ? Theme.Color.red : Theme.Color.carbon)
                HStack(spacing: Theme.Spacing.s) {
                    dayStat("Max", summary.max)
                    dayStat("Min", summary.min)
                }
                HStack(spacing: Theme.Spacing.s) {
                    stat("Days logged", "\(summary.daysLogged) / \(summary.daysElapsed)")
                    stat("On target", "\(summary.onTargetDays)")
                }
            }
            .plate()
        } else {
            Text("No completed days logged in this period yet.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.carbon)
                .plate(Theme.Color.lavender)
        }
    }

    private func dayStat(_ title: LocalizedStringKey, _ day: DayTotal) -> some View {
        NavigationLink(value: DayRoute(dayKey: day.dayKey)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).uiLabelStyle()
                Text(day.kcal.formatted()).font(.system(size: 20, weight: .black).italic())
                Text(DayKey.startOfDay(day.dayKey).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))).font(Theme.Font.micro)
            }
            .foregroundStyle(Theme.Color.carbon)
            .padding(Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .inset()
        }
        .buttonStyle(.plain)
    }

    private func stat(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).uiLabelStyle()
            Text(value).font(.system(size: 20, weight: .black).italic())
        }
        .foregroundStyle(Theme.Color.carbon)
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .inset()
    }

    private var chart: some View {
        let stub = Double(viewModel.target) * 0.03
        return Chart {
            ForEach(viewModel.bars) { bar in
                BarMark(
                    x: .value("Day", bar.date, unit: .day),
                    y: .value("kcal", bar.kcal.map(Double.init) ?? stub)
                )
                .foregroundStyle(color(bar))
            }
            RuleMark(y: .value("Target", viewModel.target))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundStyle(Theme.Color.carbon)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: viewModel.period == .week ? 1 : 7)) { _ in
                AxisValueLabel(format: viewModel.period == .week ? .dateTime.weekday(.narrow) : .dateTime.day())
            }
        }
        .frame(height: 220)
        .padding(Theme.Spacing.m)
        .background(Theme.Color.surface)
        .overlay(Rectangle().stroke(Theme.Color.chromeIndigo, lineWidth: 1))
    }

    private func color(_ bar: DayBar) -> Color {
        switch bar.status {
        case .empty, .future: Theme.Color.platinum
        case .under: Theme.Color.canvasSoft
        case .onTarget: Theme.Color.amber
        case .over: Theme.Color.red
        }
    }
}
