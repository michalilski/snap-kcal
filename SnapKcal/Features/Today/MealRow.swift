import SwiftUI

struct MealRow: View {
    let meal: Meal
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.Font.link)
                    .foregroundStyle(meal.status == .failed ? Theme.Color.danger : Theme.Color.textPrimary)
                    .lineLimit(1)
                Text(meal.eatenAt.appFormatted(.dateTime.hour().minute()))
                    .font(Theme.Font.data)
                    .foregroundStyle(Theme.Color.textMuted)
            }
            Spacer(minLength: Theme.Spacing.s)
            trailing
        }
        .padding(Theme.Spacing.s)
        .frame(minHeight: 64)
        .tile(Theme.Color.surface)
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

    private var thumbnail: some View {
        Group {
            if let data = meal.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.Color.surfaceRaised
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var trailing: some View {
        switch meal.status {
        case .analyzing:
            PulseIndicator()
        case .failed:
            Button("Retry", action: onRetry)
                .buttonStyle(.secondary)
                .accessibilityIdentifier("rowRetry")
        case .done:
            HStack(spacing: Theme.Spacing.m) {
                ScoreBadge(score: meal.healthScore)
                Text(meal.kcal.formatted())
                    .font(Theme.Font.metric)
                    .foregroundStyle(Theme.Color.textPrimary)
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
            Text("Deleted \(name)").font(Theme.Font.body).foregroundStyle(Theme.Color.textPrimary).lineLimit(1)
            Spacer()
            Button("Undo", action: onUndo).buttonStyle(.minimal).accessibilityIdentifier("undoButton")
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.xs)
        .tile()
        .padding(.horizontal, Theme.Spacing.l)
    }
}

struct KcalSummary: View {
    let eaten: Int
    let target: Int

    private var progress: Double { min(Double(eaten) / Double(max(target, 1)), 1) }
    private var isOver: Bool { eaten > target }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                MetricText(text: eaten.formatted())
                    .accessibilityLabel(Text("\(eaten) kilocalories eaten"))
                    .accessibilityIdentifier("dayTotal")
                Text("/ \(target.formatted()) kcal")
                    .font(Theme.Font.data)
                    .foregroundStyle(Theme.Color.textMuted)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(isOver ? "Over" : "Remaining").uiLabelStyle()
                    Text(abs(target - eaten).formatted())
                        .font(Theme.Font.metric)
                        .foregroundStyle(isOver ? Theme.Color.danger : Theme.Color.textPrimary)
                }
            }
            HStack(spacing: Theme.Spacing.s) {
                SegmentBar(progress: progress, color: isOver ? Theme.Color.danger : Theme.Color.textPrimary)
                Text(String(format: "%3d%%", Int((Double(eaten) / Double(max(target, 1)) * 100).rounded())))
                    .font(Theme.Font.data)
                    .foregroundStyle(isOver ? Theme.Color.danger : Theme.Color.textSecondary)
            }
        }
    }
}
