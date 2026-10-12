import SwiftUI

struct BodyForm: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Picker("Sex", selection: $draft.sex) {
                Text("Male").tag(Sex.male)
                Text("Female").tag(Sex.female)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("sexPicker")

            DatePicker("Birth date", selection: $draft.birthDate, in: ...Date.now, displayedComponents: .date)
                .font(Theme.Font.link)
            Text("Age \(draft.age)").font(Theme.Font.micro)

            NumberField(title: "Height (cm)", value: $draft.heightCm, format: .number.precision(.fractionLength(0)), identifier: "heightField")
            NumberField(title: "Weight (kg)", value: $draft.weightKg, format: .number.precision(.fractionLength(0...1)), identifier: "weightField")

            if !draft.isValid {
                Text("Height 120–250 cm, weight 30–300 kg, age 13–100.")
                    .font(Theme.Font.micro)
                    .foregroundStyle(Theme.Color.red)
            }
        }
    }
}

struct NumberField: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let format: FloatingPointFormatStyle<Double>
    let identifier: String

    var body: some View {
        HStack {
            Text(title).font(Theme.Font.link)
            Spacer()
            TextField(title, value: $value, format: format)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(Theme.Font.link)
                .frame(width: 100)
                .padding(Theme.Spacing.s)
                .inset(Theme.Color.surface)
                .accessibilityIdentifier(identifier)
        }
    }
}

struct ActivityPicker: View {
    @Binding var level: Int

    static let options: [(title: LocalizedStringKey, detail: LocalizedStringKey)] = [
        ("Sedentary", "Desk job, little exercise"),
        ("Light", "Exercise 1–3 days/week or 7k+ steps"),
        ("Moderate", "Exercise 3–5 days/week"),
        ("Very active", "Hard exercise 6–7 days/week or physical job"),
    ]

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            ForEach(0..<4, id: \.self) { index in
                Button { level = index } label: {
                    HStack(spacing: Theme.Spacing.m) {
                        Text("\(index)").font(.system(size: 24, weight: .black).italic())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.options[index].title).font(Theme.Font.link)
                            Text(Self.options[index].detail).font(Theme.Font.micro)
                        }
                        Spacer()
                        Image(systemName: level == index ? "largecircle.fill.circle" : "circle")
                    }
                    .foregroundStyle(Theme.Color.carbon)
                    .padding(Theme.Spacing.m)
                    .frame(minHeight: 56)
                    .inset(level == index ? Theme.Color.amber : Theme.Color.platinum)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("activity-\(index)")
                .accessibilityAddTraits(level == index ? .isSelected : [])
            }
        }
    }
}

struct GoalPicker: View {
    @Binding var goal: Goal
    let targets: NutritionCalculator.Targets

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(Goal.allCases, id: \.self) { option in
                    Button { goal = option } label: {
                        VStack(spacing: Theme.Spacing.xs) {
                            Text(option.title).uiLabelStyle()
                            Text(targets.value(for: option).formatted())
                                .font(.system(size: 22, weight: .black).italic())
                                .foregroundStyle(Theme.Color.carbon)
                            Text("kcal").font(Theme.Font.micro).foregroundStyle(Theme.Color.carbon)
                        }
                        .frame(maxWidth: .infinity, minHeight: 84)
                        .inset(goal == option ? Theme.Color.amber : Theme.Color.platinum)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("goal-\(option.rawValue)")
                    .accessibilityAddTraits(goal == option ? .isSelected : [])
                }
            }
            if targets.loseRaisedToFloor {
                Text("Target raised to a safe minimum").font(Theme.Font.micro).foregroundStyle(Theme.Color.carbon)
            }
            Text("Estimates only, not medical advice.").font(Theme.Font.micro).foregroundStyle(Theme.Color.carbon)
        }
    }
}

extension Goal {
    var title: LocalizedStringKey {
        switch self {
        case .lose: "Lose"
        case .maintain: "Maintain"
        case .gain: "Gain"
        }
    }
}
