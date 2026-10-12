import SwiftUI

struct BarBackground: View {
    var body: some View {
        Theme.Color.background
            .overlay(alignment: .top) { Rectangle().fill(Theme.Color.surfaceRaised).frame(height: 1) }
    }
}
