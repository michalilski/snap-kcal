import SwiftUI

struct ComponentGallery: View {
    @State private var tab = AppTab.today

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    PanelTitle("Kcal summary")
                    MetricText(text: "1,120")
                    Text("/ 1,950").uiLabelStyle()
                }
                .panel()

                HStack {
                    Text("Meal row").font(Theme.Font.link)
                    Spacer()
                    ScoreBadge(score: 8)
                    ScoreBadge(score: 4, showsNumber: true)
                    ChevronChip()
                }
                .padding(Theme.Spacing.m)
                .tile()

                HStack {
                    Button("Primary") {}.buttonStyle(.primary)
                    Button("Secondary") {}.buttonStyle(.secondary)
                    Button("Minimal") {}.buttonStyle(.minimal)
                    Button("Delete") {}.buttonStyle(.danger)
                }

                Divider1px()
                LoadingLabel(text: "Reading your plate…")
                SnapButton {}.frame(maxWidth: .infinity)
                TabBar(selection: $tab)
            }
            .padding(Theme.Spacing.l)
        }
        .background(Theme.Color.background)
    }
}

#Preview { ComponentGallery() }
