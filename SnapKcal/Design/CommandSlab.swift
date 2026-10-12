import SwiftUI

struct CommandSlab: View {
    var body: some View {
        Theme.Color.carbon
            .overlay {
                Canvas { context, size in
                    let dot = Path(ellipseIn: CGRect(x: 0, y: 0, width: 1, height: 1))
                    for x in stride(from: 0, to: size.width, by: 4) {
                        for y in stride(from: 0, to: size.height, by: 4) {
                            context.fill(dot.offsetBy(dx: x, dy: y), with: .color(.white.opacity(0.06)))
                        }
                    }
                }
            }
    }
}
