import SwiftUI

struct MealRow: View {
    let meal: Meal
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Font.link).lineLimit(1)
                Text(meal.eatenAt.formatted(date: .omitted, time: .shortened)).font(Theme.Font.micro)
            }
            .foregroundStyle(Theme.Color.carbon)
            Spacer(minLength: Theme.Spacing.s)
            trailing
        }
        .padding(Theme.Spacing.s)
        .frame(minHeight: 72)
        .inset()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mealRow")
    }

    private var title: String {
        switch meal.status {
        case .analyzing: String(localized: "Analyzing…")
        case .failed: meal.errorMessage ?? String(localized: "Analysis failed")
        case .done: meal.name
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if let data = meal.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.Color.lavender
            }
        }
        .frame(width: 56, height: 56)
        .clipped()
        .overlay(Rectangle().stroke(Theme.Color.carbon, lineWidth: 1))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var trailing: some View {
        switch meal.status {
        case .analyzing:
            BlinkingDots()
        case .failed:
            Button("Retry", action: onRetry)
                .buttonStyle(.commit)
                .accessibilityIdentifier("rowRetry")
        case .done:
            HStack(spacing: Theme.Spacing.s) {
                ScoreBadge(score: meal.healthScore)
                Text(meal.kcal.formatted())
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Theme.Color.carbon)
                    .accessibilityLabel(Text("\(meal.kcal) kilocalories"))
                ChevronChip()
            }
        }
    }
}

struct UndoToast: View {
    let name: String
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text("Deleted \(name)").font(Theme.Font.body).foregroundStyle(.white).lineLimit(1)
            Spacer()
            Button("Undo", action: onUndo).buttonStyle(.primary).accessibilityIdentifier("undoButton")
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Color.carbon)
    }
}

struct KcalPlate: View {
    let eaten: Int
    let target: Int

    private var progress: Double { min(Double(eaten) / Double(max(target, 1)), 1) }
    private var isOver: Bool { eaten > target }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.s) {
                OutlinedText(text: eaten.formatted())
                    .accessibilityLabel(Text("\(eaten) kilocalories eaten"))
                    .accessibilityIdentifier("dayTotal")
                Text("/ \(target.formatted())").uiLabelStyle()
            }
            Text(isOver ? "\((eaten - target).formatted()) kcal over" : "\((target - eaten).formatted()) kcal left")
                .uiLabelStyle(isOver ? Theme.Color.red : Theme.Color.carbon)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Theme.Color.carbon
                    (isOver ? Theme.Color.red : Theme.Color.amber).frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 10)
            .overlay(alignment: .top) { Rectangle().fill(Theme.Color.chromeIndigo).frame(height: 1) }
            .accessibilityHidden(true)
        }
    }
}
