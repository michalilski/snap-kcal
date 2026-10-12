import SwiftUI

struct BarBackground: View {
    var body: some View {
        Theme.Color.surface
            .overlay(alignment: .top) { Rectangle().fill(Theme.Color.border).frame(height: 1) }
    }
}
