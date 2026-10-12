import SwiftUI

struct ComponentGallery: View {
    @State private var tab = AppTab.today

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    PanelTitle("Kcal plate")
                    OutlinedText(text: "1,120")
                    Text("/ 1,950").uiLabelStyle()
                }
                .plate()

                HStack {
                    Text("Meal row").font(Theme.Font.link)
                    Spacer()
                    ScoreBadge(score: 8)
                    ScoreBadge(score: 4, showsNumber: true)
                    ChevronChip()
                }
                .padding(Theme.Spacing.m)
                .inset()

                HStack {
                    Button("Primary") {}.buttonStyle(.primary)
                    Button("Commit") {}.buttonStyle(.commit)
                    Button("Dark") {}.buttonStyle(.dark)
                    Button("Delete") {}.buttonStyle(.destructive)
                }

                DottedDivider()
                LoadingLabel(text: "Reading your plate…")
                SnapButton {}.frame(maxWidth: .infinity)
                CommandBar(selection: $tab)
            }
            .padding(Theme.Spacing.l)
        }
        .background(Theme.Color.canvas)
    }
}

#Preview { ComponentGallery() }
